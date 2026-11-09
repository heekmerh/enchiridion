"""Extract document-body images as ordered content blocks.

The Word package may also contain HD Photo fallback files and decorative VML
shapes. Only drawings with an image relationship in the body become book blocks.
"""

from pathlib import Path

from docx.oxml.ns import qn


VML_IMAGE = "{urn:schemas-microsoft-com:vml}imagedata"
W_TEXT = qn("w:t")
W_TAB = qn("w:tab")
W_BREAK = qn("w:br")
A_BLIP = qn("a:blip")


class DocxMediaExtractor:
    def __init__(self, document, asset_dir: Path, asset_prefix: str):
        self.document = document
        self.asset_dir = asset_dir
        self.asset_prefix = asset_prefix.rstrip("/")
        self.extracted: set[str] = set()

    def _image_block(self, node):
        relation_id = (
            node.get(qn("r:embed")) if node.tag == A_BLIP else node.get(qn("r:id"))
        )
        if not relation_id:
            return None
        image_part = self.document.part.related_parts.get(relation_id)
        if image_part is None or not image_part.content_type.startswith("image/"):
            return None
        filename = Path(str(image_part.partname)).name
        target = self.asset_dir / filename
        self.asset_dir.mkdir(parents=True, exist_ok=True)
        if filename not in self.extracted:
            target.write_bytes(image_part.blob)
            self.extracted.add(filename)
        return {
            "type": "image",
            "assetPath": f"{self.asset_prefix}/{filename}",
        }

    def paragraph_blocks(self, paragraph):
        """Split text around inline and anchored drawings in XML reading order."""
        blocks = []
        text = []

        def flush_text():
            value = "".join(text).strip()
            if value:
                blocks.append({"type": "paragraph", "text": value})
            text.clear()

        for node in paragraph._p.iter():
            if node.tag == W_TEXT:
                text.append(node.text or "")
            elif node.tag == W_TAB:
                text.append("\t")
            elif node.tag == W_BREAK:
                text.append("\n")
            elif node.tag in (A_BLIP, VML_IMAGE):
                block = self._image_block(node)
                if block:
                    flush_text()
                    blocks.append(block)
        flush_text()
        return blocks

    def table_image_blocks(self, table):
        """Place images in table cells immediately after their table block."""
        blocks = []
        for node in table._tbl.iter():
            if node.tag in (A_BLIP, VML_IMAGE):
                block = self._image_block(node)
                if block:
                    blocks.append(block)
        return blocks
