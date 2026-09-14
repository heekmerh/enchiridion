"""
DOCX Processor for Enchiridion Medical Textbook

Reads final.docx directly using python-docx, maps heading styles to the
full Flutter app hierarchy, and writes book.json to both:
  - scripts/output/book.json         (local reference)
  - enchiridion/assets/data/book.json (app asset, ready to run)

Usage:
    python docx_processor.py              # full conversion
    python docx_processor.py --discover   # print all paragraph styles found
"""

import json
import re
import sys
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table as DocxTable
from docx.text.paragraph import Paragraph
import logging

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# ── Paths ──────────────────────────────────────────────────────────────────────

DOCX_PATH = Path(__file__).parent / "final" / "final.docx"
OUTPUT_PATH = Path(__file__).parent / "output" / "book.json"

# ── Book-level metadata (edit here if needed) ──────────────────────────────────

BOOK_META = {
    "id": "medical-codex-001",
    "title": "Enchiridion",
    "author": "Hikma Akinfunmilola Atanda",
    "coverUrl": "assets/icon/logo.png",
}

# ── Heading style → hierarchy level mapping ────────────────────────────────────
# Run --discover to see what styles your docx actually uses, then adjust here.

HEADING_MAP: dict[str, int] = {
    "Heading 1": 1,
    "Heading 2": 2,
    "Heading 3": 3,
    "Heading 4": 4,
    "Title": 1,       # document title → chapter
    "Subtitle": 3,    # subtitle → subsection
}

# Styles that are always plain content (never heading-detected)
CONTENT_STYLES = {"Normal (Web)", "List Paragraph", "HTML Preformatted"}

# ── Regexes ────────────────────────────────────────────────────────────────────

CLINICAL_PEARLS_RE = re.compile(r'clinical\s*pearl', re.IGNORECASE)
RED_FLAGS_RE = re.compile(r'red\s*flag', re.IGNORECASE)
MNEMONIC_ITEM_RE = re.compile(r'^([A-Z])\s*[-=\u2013\u2014]\s*(.+)')
QUOTED_WORD_RE = re.compile(r'[\u201c\u201d\u2018\u2019"\']([\w\-]+)[\u201c\u201d\u2018\u2019"\']')
EMOJI_RE = re.compile(r'^([\U0001F000-\U0001FFFF\u2600-\u27BF\u00A9\u00AE]+)\s*')


# ── Helpers ────────────────────────────────────────────────────────────────────

def to_id(text: str) -> str:
    """Slugify text to snake_case for use as an ID."""
    text = re.sub(r'[^\w\s]', ' ', text.lower())
    return '_'.join(text.split())[:60]


def split_emoji(text: str) -> tuple[str | None, str]:
    """Split a leading emoji from text. Returns (emoji_or_None, clean_text)."""
    m = EMOJI_RE.match(text)
    if m:
        return m.group(1).strip(), text[m.end():].strip()
    return None, text


def is_list_item(para: Paragraph) -> bool:
    """True if the paragraph is any kind of list item."""
    style = para.style.name if para.style else ''
    if 'List' in style:
        return True
    numPr = para._p.find(qn('w:numPr'))
    if numPr is None:
        return False
    numId = numPr.find(qn('w:numId'))
    return numId is not None and numId.get(qn('w:val'), '0') != '0'


def is_numbered_list(para: Paragraph) -> bool:
    """True if the paragraph uses a numbered/ordered list style."""
    style = para.style.name if para.style else ''
    return 'Number' in style or ('List' in style and 'Number' in style)


def detect_normal_level(text: str) -> int | None:
    """
    Heuristic for 'Normal' style paragraphs that are actually headings.
    Returns 3 (subsection), 4 (content group), or None (plain content).

    Rules:
    - Short ALL-CAPS text (with or without a leading emoji) → subsection (3)
    - Emoji-prefixed with mixed-case content → content group (4)
    - Otherwise → None (treat as body text)
    """
    emoji, clean = split_emoji(text)
    if not clean:
        return None
    # All-caps and reasonably short → subsection heading
    if clean.replace(' ', '').isupper() and len(clean) <= 70:
        return 3
    # Emoji-prefixed but not all-caps → content group heading
    if emoji:
        return 4
    return None


# ── Block classification ───────────────────────────────────────────────────────

def classify_blocks(group_title: str, raw: list[dict]) -> list[dict]:
    """
    Convert a list of raw paragraph/table items collected under a content group
    into typed content blocks matching the Flutter ContentBlock schema.
    """
    # Whole-group override: clinical pearls
    if CLINICAL_PEARLS_RE.search(group_title):
        items = [b['text'] for b in raw if b.get('text')]
        return [{"type": "clinical_pearls", "items": items}] if items else []

    # Whole-group override: red flags
    if RED_FLAGS_RE.search(group_title):
        items = [b['text'] for b in raw if b.get('text')]
        return [{"type": "red_flags", "items": items}] if items else []

    result = []
    i = 0
    while i < len(raw):
        b = raw[i]

        if b['kind'] == 'table':
            result.append(b['block'])
            i += 1

        elif b['kind'] == 'numbered':
            # Collect consecutive numbered items → algorithm
            steps = []
            while i < len(raw) and raw[i]['kind'] == 'numbered':
                steps.append(raw[i]['text'])
                i += 1
            result.append({"type": "algorithm", "title": group_title, "steps": steps})

        elif b['kind'] == 'bullet':
            # Collect consecutive bullet items
            items = []
            while i < len(raw) and raw[i]['kind'] == 'bullet':
                items.append(raw[i]['text'])
                i += 1

            # Detect mnemonic pattern: every item matches "X - label"
            mnemonic_matches = [MNEMONIC_ITEM_RE.match(t) for t in items]
            if all(mnemonic_matches) and len(items) >= 3:
                m = QUOTED_WORD_RE.search(group_title)
                mnemonic_word = m.group(1) if m else group_title
                mnemonic_items = [
                    {"key": mx.group(1), "label": mx.group(2).strip(), "value": None}
                    for mx in mnemonic_matches
                ]
                result.append({"type": "mnemonic", "mnemonic": mnemonic_word, "items": mnemonic_items})
            else:
                result.append({"type": "checklist", "title": None, "items": items})

        else:  # plain paragraph
            if b.get('text'):
                result.append({"type": "paragraph", "text": b['text']})
            i += 1

    return result


# ── Converter class ────────────────────────────────────────────────────────────

class DocxConverter:
    """State machine that walks document body elements and builds the JSON tree."""

    def __init__(self, docx_path: Path):
        self.doc = Document(str(docx_path))
        self.chapters: list[dict] = []

        # Current context
        self._chapter: dict | None = None
        self._section: dict | None = None
        self._subsection: dict | None = None
        self._group: dict | None = None
        self._group_raw: list[dict] = []

        # Counters
        self._chapter_n = 0
        self._section_n = 0
        self._subsection_n = 0
        self._group_n = 0

    # ── Flush helpers ──────────────────────────────────────────────────────────

    def _flush_group(self):
        if self._group is None:
            return
        self._group['blocks'] = classify_blocks(self._group['group_title'], self._group_raw)
        self._group_raw = []
        if self._subsection is not None:
            self._subsection['content_groups'].append(self._group)
        self._group = None

    def _flush_subsection(self):
        self._flush_group()
        if self._subsection is None:
            return
        if self._section is not None:
            self._section['subsections'].append(self._subsection)
        self._subsection = None

    def _flush_section(self):
        self._flush_subsection()
        if self._section is None:
            return
        if self._chapter is not None:
            self._chapter['sections'].append(self._section)
        self._section = None

    def _flush_chapter(self):
        self._flush_section()
        if self._chapter is None:
            return
        self.chapters.append(self._chapter)
        self._chapter = None

    # ── Ensure helpers (create containers lazily when content arrives early) ───

    def _ensure_group(self) -> bool:
        """Guarantee chapter/section/subsection/group all exist. Returns False
        if there is no active chapter (content before the first heading)."""
        if self._chapter is None:
            return False
        if self._section is None:
            self._section_n += 1
            self._section = {
                "section_id": "general",
                "section_title": "General",
                "section_order": self._section_n,
                "subsections": [],
            }
        if self._subsection is None:
            self._subsection_n += 1
            self._subsection = {
                "subsection_id": "general",
                "subsection_title": "General",
                "subsection_icon": None,
                "content_groups": [],
            }
        if self._group is None:
            self._group_n += 1
            self._group = {
                "group_id": "content",
                "group_title": "Content",
                "group_subtitle": None,
                "group_icon": None,
                "blocks": [],
            }
        return True

    # ── Heading handlers ───────────────────────────────────────────────────────

    def _on_h1(self, text: str):
        self._flush_chapter()
        self._chapter_n += 1
        self._section_n = self._subsection_n = self._group_n = 0
        emoji, clean = split_emoji(text)
        self._chapter = {
            "chapter_metadata": {
                "chapter_id": to_id(clean),
                "chapter_title": clean,
                "chapter_icon": emoji,
                "description": None,
                "position_in_book": self._chapter_n,
            },
            "sections": [],
        }

    def _on_h2(self, text: str):
        if self._chapter is None:
            self._on_h1("Main")
        self._flush_section()
        self._section_n += 1
        self._subsection_n = self._group_n = 0
        self._section = {
            "section_id": to_id(text),
            "section_title": text,
            "section_order": self._section_n,
            "subsections": [],
        }

    def _on_h3(self, text: str):
        if self._chapter is None:
            self._on_h1("Main")
        if self._section is None:
            self._on_h2("General")
        self._flush_subsection()
        self._subsection_n += 1
        self._group_n = 0
        emoji, clean = split_emoji(text)
        self._subsection = {
            "subsection_id": to_id(clean),
            "subsection_title": clean,
            "subsection_icon": emoji,
            "content_groups": [],
        }

    def _on_h4(self, text: str):
        if self._chapter is None:
            self._on_h1("Main")
        if self._section is None:
            self._on_h2("General")
        if self._subsection is None:
            self._on_h3("General")
        self._flush_group()
        self._group_n += 1
        emoji, clean = split_emoji(text)
        self._group = {
            "group_id": to_id(clean),
            "group_title": clean,
            "group_subtitle": None,
            "group_icon": emoji,
            "blocks": [],
        }

    # ── Main entry point ───────────────────────────────────────────────────────

    def convert(self) -> dict:
        for elem in self.doc.element.body:
            tag = elem.tag.split('}')[-1]

            if tag == 'tbl':
                table = DocxTable(elem, self.doc)
                if not self._ensure_group():
                    continue
                rows = [
                    [cell.text.strip() for cell in row.cells]
                    for row in table.rows
                ]
                columns = rows[0] if rows else []
                data_rows = rows[1:] if len(rows) > 1 else []
                self._group_raw.append({
                    'kind': 'table',
                    'block': {"type": "table", "columns": columns, "rows": data_rows},
                })

            elif tag == 'p':
                para = Paragraph(elem, self.doc)
                text = para.text.strip()
                if not text:
                    continue

                style = para.style.name if para.style else 'Normal'
                level = HEADING_MAP.get(style)

                # For 'Normal' style, use heuristics to detect pseudo-headings
                if level is None and style == 'Normal':
                    level = detect_normal_level(text)

                if level == 1:
                    self._on_h1(text)
                elif level == 2:
                    self._on_h2(text)
                elif level == 3:
                    self._on_h3(text)
                elif level == 4:
                    self._on_h4(text)
                else:
                    if not self._ensure_group():
                        continue
                    if style == 'HTML Preformatted':
                        # Strip leading "- " or "– " bullet markers
                        clean = re.sub(r'^[-\u2013\u2022]\s*', '', text)
                        self._group_raw.append({'kind': 'bullet', 'text': clean})
                    elif is_numbered_list(para):
                        self._group_raw.append({'kind': 'numbered', 'text': text})
                    elif is_list_item(para):
                        self._group_raw.append({'kind': 'bullet', 'text': text})
                    else:
                        self._group_raw.append({'kind': 'paragraph', 'text': text})

        self._flush_chapter()
        return {**BOOK_META, "chapters": self.chapters}


# ── Discovery mode ─────────────────────────────────────────────────────────────

def safe_print(text: str):
    """Print with emoji replaced by ? on terminals that can't handle them."""
    print(text.encode(sys.stdout.encoding or 'utf-8', errors='replace').decode(sys.stdout.encoding or 'utf-8', errors='replace'))


def discover_styles(docx_path: Path):
    """Print all paragraph styles used in the document with examples."""
    doc = Document(str(docx_path))
    styles: dict[str, list[str]] = {}
    for elem in doc.element.body:
        if elem.tag.split('}')[-1] != 'p':
            continue
        para = Paragraph(elem, doc)
        style = para.style.name if para.style else 'Normal'
        text = para.text.strip()[:80]
        if style not in styles:
            styles[style] = []
        if text and len(styles[style]) < 2:
            styles[style].append(text)

    safe_print(f"\nStyles found in {docx_path.name}:\n")
    for style, examples in sorted(styles.items()):
        safe_print(f"  [{style}]")
        for ex in examples:
            safe_print(f'    e.g. "{ex}"')
    safe_print(f"\n{len(styles)} distinct styles found.")
    safe_print("\nUpdate HEADING_MAP in docx_processor.py if your styles differ from 'Heading 1/2/3/4'.")


# ── Entry point ────────────────────────────────────────────────────────────────

def main():
    if '--discover' in sys.argv:
        discover_styles(DOCX_PATH)
        return

    if not DOCX_PATH.exists():
        logger.error(f"DOCX not found: {DOCX_PATH}")
        return

    logger.info("=== DOCX → book.json Pipeline ===\n")
    logger.info(f"Input : {DOCX_PATH}")

    converter = DocxConverter(DOCX_PATH)
    book = converter.convert()

    # Save to scripts/output/
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(book, f, indent=2, ensure_ascii=False)
    logger.info(f"\n✓ Saved  : {OUTPUT_PATH}")
    logger.info(f"  Run /fix-book-json to correct and deploy to assets/data/book.json")

    # Summary
    chap_count = len(book['chapters'])
    section_count = sum(len(c['sections']) for c in book['chapters'])
    subsection_count = sum(
        len(s['subsections'])
        for c in book['chapters']
        for s in c['sections']
    )
    block_count = sum(
        len(g['blocks'])
        for c in book['chapters']
        for s in c['sections']
        for sub in s['subsections']
        for g in sub['content_groups']
    )

    logger.info(f"\n=== Summary ===")
    logger.info(f"  Chapters    : {chap_count}")
    logger.info(f"  Sections    : {section_count}")
    logger.info(f"  Subsections : {subsection_count}")
    logger.info(f"  Blocks      : {block_count}")


if __name__ == "__main__":
    main()
