"""Focused checks for the source document's unreliable styles and inline figures."""

import json
import struct
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

from docx import Document
from docx.shared import Pt, RGBColor

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_paediatrics import convert  # noqa: E402


def tiny_png() -> bytes:
    def chunk(name: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data)) + name + data
            + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"\x00\xff\x00\x00"))
        + chunk(b"IEND", b"")
    )


class PaediatricsConversionTest(unittest.TestCase):
    def test_split_topic_name_and_empty_category_heading_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            document = Document()
            document.add_paragraph("CHAPTER START", style="Heading 1")
            for title in ("MAJOR TOPIC", "(SUBTITLE)", "CATEGORY", "NEXT TOPIC"):
                paragraph = document.add_paragraph()
                run = paragraph.add_run(title)
                run.bold = True
                run.font.size = Pt(24)
                run.font.color.rgb = RGBColor(0x12, 0x34, 0x56)
                if title in ("(SUBTITLE)", "NEXT TOPIC"):
                    document.add_paragraph("Body content")

            source = root / "book.docx"
            chapter_map = root / "chapter_map.json"
            document.save(source)
            chapter_map.write_text(json.dumps([{
                "chapter_id": "sample",
                "chapter_title": "Sample",
                "anchor_texts": ["CHAPTER START"],
            }]))
            book = convert(source, chapter_map, root / "assets", "assets/test")
            sections = book["chapters"][0]["sections"]
            self.assertEqual(
                [s["section_title"] for s in sections],
                ["MAJOR TOPIC (SUBTITLE)", "CATEGORY", "NEXT TOPIC"],
            )
            self.assertEqual(sections[1]["subsections"], [])

    def test_direct_formatting_and_image_order_override_word_styles(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            image = root / "figure.png"
            image.write_bytes(tiny_png())
            document = Document()

            document.add_paragraph("CHAPTER START", style="Heading 1")
            topic = document.add_paragraph(style="Heading 3")
            heading = topic.add_run("MAJOR TOPIC")
            heading.bold = True
            heading.font.size = Pt(24)
            heading.font.color.rgb = RGBColor(0x12, 0x34, 0x56)
            document.add_paragraph("SUBTOPIC", style="Heading 1")
            body = document.add_paragraph()
            body.add_run("Before the image")
            body.add_run().add_picture(str(image))
            body.add_run("After the image")
            image_only = document.add_paragraph(style="Heading 2")
            image_only.add_run().add_picture(str(image))

            source = root / "book.docx"
            chapter_map = root / "chapter_map.json"
            document.save(source)
            chapter_map.write_text(json.dumps([{
                "chapter_id": "sample",
                "chapter_title": "Sample",
                "anchor_texts": ["CHAPTER START"],
            }]))

            book = convert(source, chapter_map, root / "assets", "assets/test")
            sections = book["chapters"][0]["sections"]
            self.assertEqual([s["section_title"] for s in sections], ["MAJOR TOPIC"])
            self.assertEqual(sections[0]["section_color"], "#123456")
            self.assertEqual(
                [s["subsection_title"] for s in sections[0]["subsections"]],
                ["SUBTOPIC"],
            )
            blocks = [
                block
                for group in sections[0]["subsections"][0]["content_groups"]
                for block in group["blocks"]
            ]
            self.assertEqual(
                [block["type"] for block in blocks],
                ["paragraph", "image", "paragraph", "image"],
            )
            self.assertEqual(blocks[0]["text"], "Before the image")
            self.assertEqual(blocks[2]["text"], "After the image")
            self.assertEqual(blocks[1]["assetPath"], blocks[3]["assetPath"])
            self.assertTrue((root / "assets" / "image1.png").exists())


if __name__ == "__main__":
    unittest.main()
