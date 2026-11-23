"""Locks the OSCE extractor to the source's own structure: Word list marks
become nested bullet/numbered lists, numbered sections stay the top level,
spoken lines are quotes and bold survives inline."""

import sys
import unittest
from pathlib import Path

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_osce_content as generator  # noqa: E402

BULLET_NUM_ID = "1"
DECIMAL_NUM_ID = "5"


class _Sink:
    def asset_paths(self, document, paragraph):
        return []


def _heading(document, text, size):
    run = document.add_paragraph().add_run(text)
    run.bold = True
    run.font.size = Pt(size)


def _listed(document, text, num_id, level=0):
    paragraph = document.add_paragraph(text)
    p_pr = paragraph._p.get_or_add_pPr()
    num_pr = OxmlElement("w:numPr")
    ilvl = OxmlElement("w:ilvl")
    ilvl.set(qn("w:val"), str(level))
    num = OxmlElement("w:numId")
    num.set(qn("w:val"), num_id)
    num_pr.append(ilvl)
    num_pr.append(num)
    p_pr.append(num_pr)
    return paragraph


def _build(document):
    builder = generator.ChapterBuilder("topic", "Obstetric history taking")
    generator.feed_document(builder, document, _Sink(), "Obstetric history taking", True)
    return builder.payload(None)["sections"][0]["subsections"]


def _source():
    document = Document()
    _heading(document, "OBSTETRIC HISTORY TAKING", 24)
    _heading(document, "1. WHAT THE STATION MAY SAY", 18)
    document.add_paragraph("Take a history.")
    _heading(document, "2. THE OVERALL STRUCTURE", 24)
    document.add_paragraph("Keep it simple.")
    _heading(document, "3. INTRODUCTION", 24)
    _heading(document, "What you say", 13.5)
    document.add_paragraph('"Could I confirm your name and age, please?"')
    document.add_paragraph("Look for:")
    _listed(document, "Cyanosis", BULLET_NUM_ID)
    _listed(document, "Tongue", BULLET_NUM_ID, level=1)
    mixed = document.add_paragraph("Ask about ")
    mixed.add_run("pain").bold = True
    mixed.add_run(" first.")
    _listed(document, "Wash hands", DECIMAL_NUM_ID)
    document.add_paragraph("An interruption.")
    _listed(document, "Ensure privacy", DECIMAL_NUM_ID)
    return document


class OsceExtractionTest(unittest.TestCase):
    def setUp(self):
        self.subsections = _build(_source())
        self.intro = self.subsections[2]
        self.blocks = self.intro["content_groups"][0]["blocks"]

    def test_numbered_sections_are_the_top_level_whatever_their_size(self):
        self.assertEqual(
            [s["subsection_title"] for s in self.subsections],
            ["1. WHAT THE STATION MAY SAY", "2. THE OVERALL STRUCTURE", "3. INTRODUCTION"],
        )
        self.assertEqual(self.intro["content_groups"][0]["group_title"], "What you say")

    def test_spoken_lines_are_quotes_not_checkmarks(self):
        self.assertEqual(self.blocks[0]["style"], "quote")
        self.assertNotIn("checklist", {block["type"] for block in self.blocks})

    def test_word_lists_keep_nesting_and_take_their_lead_in_as_title(self):
        bullets = self.blocks[1]
        self.assertEqual(bullets["type"], "list")
        self.assertEqual(bullets["title"], "Look for:")
        self.assertEqual(
            [(item["text"], item["level"], item.get("label")) for item in bullets["items"]],
            [("Cyanosis", 0, None), ("Tongue", 1, None)],
        )

    def test_inline_bold_is_kept(self):
        self.assertEqual(self.blocks[2]["text"], "Ask about **pain** first.")

    def test_numbering_continues_across_an_interruption(self):
        labels = [block["items"][0].get("label") for block in self.blocks if block["type"] == "list"][1:]
        self.assertEqual(labels, ["1.", "2."])


class CopyLabelTest(unittest.TestCase):
    def test_pasted_copy_prescription_button_is_dropped(self):
        document = Document()
        _heading(document, "1. EXAMPLE PRESCRIPTION", 18)
        document.add_paragraph("Rx: Indapamide 1.5 mg")
        document.add_paragraph("Copy prescription")
        document.add_paragraph("Copy the prescription onto the chart.")
        texts = [
            block.get("text")
            for group in _build(document)[0]["content_groups"]
            for block in group["blocks"]
        ]
        self.assertEqual(
            texts, ["Rx: Indapamide 1.5 mg", "Copy the prescription onto the chart."]
        )


if __name__ == "__main__":
    unittest.main()
