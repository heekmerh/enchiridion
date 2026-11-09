import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_paediatrics_toc import match_in_order, normalize, toc_entries  # noqa: E402


class TocAuditTest(unittest.TestCase):
    def test_page_only_toc_row_is_blank_not_a_heading(self):
        paragraph = SimpleNamespace(
            text="\t502", style=SimpleNamespace(name="toc 1"))
        entries, blanks, styles = toc_entries(
            SimpleNamespace(paragraphs=[paragraph]))
        self.assertEqual(entries, [])
        self.assertEqual(blanks, 1)
        self.assertEqual(styles, ["toc 1"])

    def test_normalize_drops_toc_numbering_and_emoji(self):
        self.assertEqual(normalize("1. 🌡️ FEVER"), normalize("FEVER"))

    def test_earlier_same_named_heading_does_not_hide_missing_later_topic(self):
        entries = [{"title": "LARYNGITIS", "page": "10"},
                   {"title": "EAR INFECTIONS", "page": "11"}]
        headings = [("Ear infections", "genetics", "group"),
                    ("LARYNGITIS", "respiratory", "section")]
        results = match_in_order(entries, headings)
        self.assertIsNotNone(results[0]["match"])
        self.assertIsNone(results[1]["match"])
        self.assertEqual(results[1]["other_positions"][0][1], "genetics")


if __name__ == "__main__":
    unittest.main()
