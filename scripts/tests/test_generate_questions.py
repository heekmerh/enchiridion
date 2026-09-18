import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import generate_resource_content as generator  # noqa: E402


ROOT = Path(__file__).resolve().parents[2]
BASE_COMMIT = "5abc039de6901f333b38bbe785b1835743945876"
ASSET_PATH = "enchiridion/assets/data/exam_prep_questions.json"


def collapse(value):
    return re.sub(r"\s+", " ", value).strip()


class TextNormalizationTest(unittest.TestCase):
    def test_block_text_preserves_structure_and_cleans_lines(self):
        cases = {
            "Why?\n\nKey Clues:\n- High fever\n- Hypotension":
                "Why?\n\nKey Clues:\n- High fever\n- Hypotension",
            "Line  one\t\tstill  one\nLine   two":
                "Line one still one\nLine two",
            "a\r\nb\rc": "a\nb\nc",
            "a\n\n\n\n\nb": "a\n\nb",
            "  \n  padded  \n  ": "padded",
            "\xa0": "",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(generator.fix_block_text(source), expected)

    def test_single_line_text_retains_existing_whitespace_collapse(self):
        cases = {
            "Why?\n\nKey Clues:\n- High fever\n- Hypotension":
                "Why? Key Clues: - High fever - Hypotension",
            "Line  one\t\tstill  one\nLine   two":
                "Line one still one Line two",
            "a\r\nb\rc": "a b c",
            "a\n\n\n\n\nb": "a b",
            "  \n  padded  \n  ": "padded",
            "\xa0": "",
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(generator.fix_text(source), expected)


class QuestionGenerationTest(unittest.TestCase):
    def test_source_has_493_complete_question_objects(self):
        raw = generator.QUESTION_SOURCE.read_text(encoding="utf-8")
        objects = [json.loads(generator.repair_json_object_text(obj))
                   for obj in generator.split_json_objects(raw)]
        self.assertEqual(len(objects), 493)
        for index, item in enumerate(objects, start=1):
            with self.subTest(index=index):
                self.assertTrue(
                    {"question", "options", "answer", "explanation"}
                    <= item.keys()
                )

    def test_missing_required_key_reports_question_index(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source.json"
            target = Path(temp) / "target.json"
            complete = {"question": "Q", "options": {},
                        "answer": "A", "explanation": "Because."}
            for missing in complete:
                with self.subTest(missing=missing):
                    source.write_text(json.dumps({
                        key: value for key, value in complete.items()
                        if key != missing
                    }), encoding="utf-8")
                    with patch.object(generator, "QUESTION_SOURCE", source), \
                         patch.object(generator, "QUESTION_TARGET", target):
                        with self.assertRaisesRegex(
                            ValueError, rf"1.*{missing}"
                        ):
                            generator.normalize_questions()

    def test_regenerated_asset_preserves_clinical_wording(self):
        before = json.loads(subprocess.check_output(
            ["git", "show", f"{BASE_COMMIT}:{ASSET_PATH}"], cwd=ROOT,
            text=True,
        ))
        after = json.loads((ROOT / ASSET_PATH).read_text(encoding="utf-8"))
        self.assertEqual(len(before), len(after))
        self.assertEqual(len(after), 493)
        self.assertGreaterEqual(
            sum("\n\n" in row["explanation"] for row in after), 400
        )
        for index, (old, new) in enumerate(zip(before, after), start=1):
            with self.subTest(index=index):
                self.assertEqual(new["id"], f"exam-{index:04d}")
                self.assertIsNone(new["osce_tip"])
                self.assertIsNone(new["topic"])
                self.assertIn("\n", new["explanation"])
                self.assertEqual(set(old), set(new))
                for key in ("question_text", "explanation"):
                    self.assertEqual(collapse(new[key]), old[key])
                self.assertEqual(set(new["options"]), set(old["options"]))
                for key in old["options"]:
                    self.assertEqual(collapse(new["options"][key]),
                                     old["options"][key])
                for key in ("correct_option", "question_number", "osce_tip", "topic"):
                    self.assertEqual(new[key], old[key])


if __name__ == "__main__":
    unittest.main()
