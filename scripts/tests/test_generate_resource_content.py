"""Locks the paragraph-formatting-aware heading rule (260919-kix) and proves
the two topics that stay opted out of it are unaffected by the extractor edit.
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

from docx import Document
from docx.shared import Pt

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_resource_content as generator  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
IV_CANNULA_JSON = ROOT / "enchiridion" / "assets" / "data" / "resources" / "iv_cannula.json"
NEW_SUBTOPIC_LABELS = ["Advantages", "Disadvantages", "Precautions", "Complications"]


def _bold_run_paragraph(text: str, bold: bool, size_pt: float | None):
    document = Document()
    paragraph = document.add_paragraph()
    run = paragraph.add_run(text)
    run.bold = bold
    if size_pt is not None:
        run.font.size = Pt(size_pt)
    return paragraph


def _checklist_items(subsections: list[dict]) -> list[str]:
    return [
        item
        for subsection in subsections
        for group in subsection["content_groups"]
        for block in group["blocks"]
        if block["type"] == "checklist"
        for item in block["items"]
    ]


class StyledHeadingParagraphTest(unittest.TestCase):
    def test_bold_large_run_is_a_styled_heading_when_threshold_set(self):
        paragraph = _bold_run_paragraph("Advantages", bold=True, size_pt=18.0)
        self.assertTrue(generator.styled_heading_paragraph(paragraph, 13.5))

    def test_same_paragraph_is_not_a_styled_heading_when_topic_opts_out(self):
        # This is the guard that keeps Sutures and Abdominal Examination frozen:
        # min_pt=None means the topic never enables this signal.
        paragraph = _bold_run_paragraph("Advantages", bold=True, size_pt=18.0)
        self.assertFalse(generator.styled_heading_paragraph(paragraph, None))

    def test_bold_paragraph_with_no_explicit_run_size_is_not_a_styled_heading(self):
        # The "Cannula blockage" case: bold, but no explicit run size, so it
        # must stay a list item even though min_pt is set.
        paragraph = _bold_run_paragraph("Cannula blockage", bold=True, size_pt=None)
        self.assertFalse(generator.styled_heading_paragraph(paragraph, 13.5))

    def test_large_run_without_bold_is_not_a_styled_heading(self):
        paragraph = _bold_run_paragraph("Some content line", bold=False, size_pt=18.0)
        self.assertFalse(generator.styled_heading_paragraph(paragraph, 13.5))


class IvCannulaShippedAssetTest(unittest.TestCase):
    """Reads the committed asset rather than regenerating, so this asserts
    what actually ships."""

    def setUp(self):
        payload = json.loads(IV_CANNULA_JSON.read_text(encoding="utf-8"))
        self.subsections = payload["sections"][0]["subsections"]

    def test_four_labels_are_subsection_titles(self):
        titles = [s["subsection_title"] for s in self.subsections]
        for label in NEW_SUBTOPIC_LABELS:
            self.assertIn(label, titles)

    def test_none_of_the_four_labels_survive_as_a_checklist_item(self):
        flat_items = _checklist_items(self.subsections)
        for label in NEW_SUBTOPIC_LABELS:
            self.assertNotIn(label, flat_items)

    def test_complications_checklist_ends_with_cannula_blockage(self):
        complications = next(
            s for s in self.subsections if s["subsection_title"] == "Complications"
        )
        items = _checklist_items([complications])
        self.assertEqual(items[-1], "Cannula blockage")


class OptedOutTopicsStabilityTest(unittest.TestCase):
    """sutures and abdominal_examination default bold_heading_min_pt to None,
    so regenerating them must reproduce the committed JSON byte for byte."""

    def setUp(self):
        self._original_data_dir = generator.RESOURCE_DATA_DIR
        self._original_asset_dir = generator.RESOURCE_ASSET_DIR
        self._tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self._tempdir.cleanup)
        self.addCleanup(self._restore_module_globals)
        temp_root = Path(self._tempdir.name)
        generator.RESOURCE_DATA_DIR = temp_root / "resources"
        generator.RESOURCE_ASSET_DIR = temp_root / "resources_assets"
        generator.RESOURCE_DATA_DIR.mkdir(parents=True, exist_ok=True)
        generator.RESOURCE_ASSET_DIR.mkdir(parents=True, exist_ok=True)

    def _restore_module_globals(self):
        generator.RESOURCE_DATA_DIR = self._original_data_dir
        generator.RESOURCE_ASSET_DIR = self._original_asset_dir

    def test_sutures_and_abdominal_examination_are_byte_identical(self):
        specs_by_slug = {spec.slug: spec for spec in generator.TOPICS}
        for slug in ("sutures", "abdominal_examination"):
            with self.subTest(slug=slug):
                generator.build_topic_json(specs_by_slug[slug])
                produced = (generator.RESOURCE_DATA_DIR / f"{slug}.json").read_bytes()
                committed = (
                    ROOT / "enchiridion" / "assets" / "data" / "resources" / f"{slug}.json"
                ).read_bytes()
                self.assertEqual(produced, committed)


if __name__ == "__main__":
    unittest.main()
