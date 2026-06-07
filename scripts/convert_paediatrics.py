"""
convert_paediatrics.py
Converts the Paediatrics DOCX to the Enchiridion book.json format.

Usage:
    python convert_paediatrics.py

Output:
    scripts/paediatrics.json   — drop into enchiridion/assets/data/

Structure produced:
    book
    └── chapters[]                (defined by chapter_map.json)
        └── sections[]            (H1 / bold-ALL_CAPS Normal inside chapter)
            └── subsections[]     (H2 inside section)
                └── content_groups[]  (H3/H4 or named content run)
                    └── blocks[]  (paragraph / table / mnemonic / checklist /
                                   red_flags / clinical_pearls / key_value /
                                   algorithm)
"""

import sys, io, json, re, unicodedata
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import docx
from docx.oxml.ns import qn
from pathlib import Path

# ── paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).parent
DOCX_PATH    = SCRIPT_DIR / "final" / "enchiridion pediatrics final app copy.docx"
MAP_PATH     = SCRIPT_DIR / "chapter_map.json"
OUT_PATH     = SCRIPT_DIR / "paediatrics.json"

# ── helpers ──────────────────────────────────────────────────────────────────

def slug(text: str) -> str:
    """Lowercase, strip emoji/punctuation, replace spaces with underscores."""
    text = unicodedata.normalize("NFKD", text)
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"[\s\-]+", "_", text.strip()).lower()[:80]


def clean(text: str) -> str:
    return text.strip()


def is_bold(para) -> bool:
    return any(run.bold for run in para.runs if run.text.strip())


def is_all_caps_heading(text: str) -> bool:
    stripped = re.sub(r"[^\w\s]", "", text).strip()
    return len(stripped) > 4 and stripped == stripped.upper()


def detect_block_type(text: str) -> str:
    """Heuristic classification of a paragraph into a block type hint."""
    t = text.lower()
    if re.search(r"(mnemonic|mnemonics)\s*[:—]", t):
        return "mnemonic_header"
    if re.search(r"(red flag|danger sign|warning sign|🚨)", t):
        return "red_flags_header"
    if re.search(r"(clinical pearl|🔑|key point|key fact|remember:)", t):
        return "clinical_pearls_header"
    if re.search(r"(step[- ]by[- ]step|steps:|procedure:|management step)", t):
        return "algorithm_header"
    return "paragraph"


def paragraph_to_block(para, doc_tables_map: dict) -> dict | None:
    """Convert a single paragraph to a block dict, or None to skip."""
    text = clean(para.text)
    if not text:
        return None
    return {"type": "paragraph", "text": text}


def table_to_block(table) -> dict:
    """Convert a python-docx Table to a table block."""
    if not table.rows:
        return {"type": "paragraph", "text": ""}
    columns = [clean(c.text) for c in table.rows[0].cells]
    rows    = [[clean(c.text) for c in row.cells] for row in table.rows[1:]]
    # deduplicate merged cells (python-docx repeats merged cell text)
    seen_cols: list[str] = []
    deduped_cols: list[str] = []
    col_indices: list[int] = []
    for i, c in enumerate(columns):
        if c not in seen_cols:
            seen_cols.append(c)
            deduped_cols.append(c)
            col_indices.append(i)
    deduped_rows = [[row[i] for i in col_indices] for row in rows]
    return {"type": "table", "columns": deduped_cols, "rows": deduped_rows}


# ── document element iterator ────────────────────────────────────────────────

def iter_block_items(doc):
    """
    Yield (kind, obj) tuples in document order:
      ("para", paragraph) | ("table", table)
    This preserves the interleaved position of tables within the text flow.
    """
    body = doc.element.body
    for child in body:
        if child.tag == qn("w:p"):
            yield ("para", docx.text.paragraph.Paragraph(child, doc))
        elif child.tag == qn("w:tbl"):
            yield ("table", docx.table.Table(child, doc))


# ── content group builder ────────────────────────────────────────────────────

def flush_group(groups: list, group_id: str, group_title: str, blocks: list):
    """Append a completed content_group if it has any blocks."""
    blocks = [b for b in blocks if b]
    if not blocks:
        return
    groups.append({
        "group_id":    group_id,
        "group_title": group_title,
        "group_subtitle": None,
        "group_icon":  None,
        "blocks":      blocks,
    })


def flush_subsection(subsections: list, sub_id: str, sub_title: str, groups: list):
    if not groups:
        return
    subsections.append({
        "subsection_id":    sub_id,
        "subsection_title": sub_title,
        "subsection_icon":  None,
        "content_groups":   groups,
    })


def flush_section(sections: list, sec_id: str, sec_title: str, subsections: list):
    if not subsections:
        return
    sections.append({
        "section_id":    sec_id,
        "section_title": sec_title,
        "section_order": len(sections) + 1,
        "subsections":   subsections,
    })


# ── mnemonic / list collector ─────────────────────────────────────────────────

def try_collect_mnemonic(items_ahead: list) -> dict | None:
    """
    Given subsequent paragraphs, try to parse a mnemonic block.
    Returns the block dict or None.
    items_ahead: list of (text, style) tuples
    """
    parsed = []
    for text, _ in items_ahead:
        # Match  "A – Label: value"  or  "A: label"  or  "A. label"
        m = re.match(r"^([A-Z])\s*[.:\-–—]\s*(.+)", text)
        if m:
            key, label = m.group(1), m.group(2).strip()
            # Try to split label: value
            parts = re.split(r"\s*[:–—]\s*", label, 1)
            parsed.append({"key": key, "label": parts[0], "value": parts[1] if len(parts) > 1 else None})
        elif re.match(r"^[A-Z]\s*$", text.strip()):
            parsed.append({"key": text.strip(), "label": "", "value": None})
        else:
            break
    if len(parsed) >= 2:
        return {"type": "mnemonic", "mnemonic": "", "items": parsed}, len(parsed)
    return None, 0


# ── main conversion ───────────────────────────────────────────────────────────

def convert(docx_path: Path, map_path: Path) -> dict:
    doc    = docx.Document(str(docx_path))
    chmap  = json.loads(map_path.read_text(encoding="utf-8"))

    # Collect all block items in order first
    items = list(iter_block_items(doc))

    # ── PRE-SCAN: find the first heading occurrence of each chapter ────────────
    # This determines document-order chapter boundaries rather than relying on
    # chapter_map order, which prevents wrong-chapter captures.
    def norm(t: str) -> str:
        """Strip emoji/punctuation, lowercase."""
        return re.sub(r"[^\w\s\-&'\"(),./]", "", t).strip().lower()

    def heading_like(para, style: str) -> bool:
        t = para.text.strip()
        t_no_emoji = re.sub(r"[^\w\s\-&'\"(),./]", "", t).strip()
        return (
            style in ("Heading 1", "Heading 2", "Heading 3")
            or (style in ("Normal", "Normal (Web)") and is_bold(para)
                and is_all_caps_heading(t_no_emoji))
        )

    # Map chapter_id → (item_index, chapter_dict)
    chapter_positions: dict[str, tuple[int, dict]] = {}
    for idx, (kind, obj) in enumerate(items):
        if kind != "para":
            continue
        para = obj
        style = para.style.name
        if not heading_like(para, style):
            continue
        t_norm = norm(para.text)
        for ch in chmap:
            if ch["chapter_id"] in chapter_positions:
                continue  # already found this chapter
            for anchor in ch["anchor_texts"]:
                if norm(anchor) == t_norm or norm(anchor) in t_norm:
                    chapter_positions[ch["chapter_id"]] = (idx, ch)
                    break

    # Sort chapters by their document position
    sorted_chapters = sorted(chapter_positions.values(), key=lambda x: x[0])
    # Build index → chapter dict for O(1) lookup during walk
    chapter_boundary_map: dict[int, dict] = {idx: ch for idx, ch in sorted_chapters}

    # Build anchor → chapter lookup (kept for fallback, not used for boundaries)
    anchor_to_chapter: dict[str, dict] = {}
    for ch in chmap:
        for anchor in ch["anchor_texts"]:
            anchor_to_chapter[norm(anchor)] = ch

    # Pre-build section_anchor sets per chapter (normalised for fast lookup)
    # Chapters without section_anchors use automatic heading detection.
    section_anchor_sets: dict[str, set] = {}
    for ch in chmap:
        if "section_anchors" in ch:
            section_anchor_sets[ch["chapter_id"]] = {norm(a) for a in ch["section_anchors"]}

    # ── state ─────────────────────────────────────────────────────────────────
    chapters: list      = []
    cur_chapter: dict | None = None
    _sec_counter  = [0]   # monotonic counters ensure globally unique IDs
    _sub_counter  = [0]
    _grp_counter  = [0]
    cur_sections: list  = []
    cur_section_id      = ""
    cur_section_title   = ""
    cur_subsections: list = []
    cur_sub_id          = ""
    cur_sub_title       = ""
    cur_groups: list    = []
    cur_group_id        = ""
    cur_group_title     = ""
    cur_blocks: list    = []

    # Accumulators for multi-line block patterns
    pending_type        = None   # "red_flags" | "clinical_pearls" | "algorithm" | "checklist" | "mnemonic"
    pending_items: list = []
    pending_mnemonic_word = ""

    def emit_pending():
        nonlocal pending_type, pending_items, pending_mnemonic_word
        if not pending_items:
            pending_type = None
            return
        if pending_type == "red_flags":
            cur_blocks.append({"type": "red_flags", "items": pending_items[:]})
        elif pending_type == "clinical_pearls":
            cur_blocks.append({"type": "clinical_pearls", "items": pending_items[:]})
        elif pending_type == "algorithm":
            cur_blocks.append({"type": "algorithm", "title": "", "steps": pending_items[:]})
        elif pending_type == "checklist":
            cur_blocks.append({"type": "checklist", "title": None, "items": pending_items[:]})
        elif pending_type == "mnemonic":
            parsed = []
            for raw in pending_items:
                m = re.match(r"^([A-Z])\s*[.:\-–—]\s*(.+)", raw)
                if m:
                    key, rest = m.group(1), m.group(2).strip()
                    parts = re.split(r"\s*[:–—]\s*", rest, 1)
                    parsed.append({"key": key, "label": parts[0], "value": parts[1] if len(parts) > 1 else None})
                else:
                    parsed.append({"key": "", "label": raw, "value": None})
            if parsed:
                cur_blocks.append({"type": "mnemonic", "mnemonic": pending_mnemonic_word, "items": parsed})
        pending_type  = None
        pending_items = []
        pending_mnemonic_word = ""

    def save_chapter():
        nonlocal cur_chapter, cur_sections, cur_section_id, cur_section_title
        nonlocal cur_subsections, cur_sub_id, cur_sub_title
        nonlocal cur_groups, cur_group_id, cur_group_title, cur_blocks
        emit_pending()
        flush_group(cur_groups, cur_group_id, cur_group_title, cur_blocks)
        cur_blocks = []
        flush_subsection(cur_subsections, cur_sub_id, cur_sub_title, cur_groups)
        cur_groups = []
        flush_section(cur_sections, cur_section_id, cur_section_title, cur_subsections)
        cur_subsections = []
        if cur_chapter and cur_sections:
            chapters.append({
                "chapter_metadata": {
                    "chapter_id":       cur_chapter["chapter_id"],
                    "chapter_title":    cur_chapter["chapter_title"],
                    "chapter_icon":     None,
                    "description":      None,
                    "position_in_book": len(chapters) + 1,
                },
                "sections": cur_sections,
            })
        cur_sections = []

    def open_chapter(ch: dict, heading_text: str = ""):
        nonlocal cur_chapter, cur_section_id, cur_section_title, cur_sub_id, cur_sub_title
        nonlocal cur_group_id, cur_group_title
        save_chapter()
        cur_chapter = ch
        # The anchor heading becomes the first section; its content is the intro.
        # Subsection title matches section title so no "Overview" dummy appears.
        first = heading_text or ch["chapter_title"]
        _sec_counter[0] += 1
        _sub_counter[0] += 1
        _grp_counter[0] += 1
        _sid = f"{ch['chapter_id']}_s{_sec_counter[0]}"
        cur_section_id    = _sid
        cur_section_title = first
        cur_sub_id        = f"{_sid}_b{_sub_counter[0]}"
        cur_sub_title     = first
        cur_group_id      = f"{cur_sub_id}_g{_grp_counter[0]}"
        cur_group_title   = ""

    def open_section(title: str):
        nonlocal cur_section_id, cur_section_title, cur_sub_id, cur_sub_title
        nonlocal cur_group_id, cur_group_title, cur_groups, cur_subsections, cur_blocks
        emit_pending()
        flush_group(cur_groups, cur_group_id, cur_group_title, cur_blocks)
        cur_blocks = []
        flush_subsection(cur_subsections, cur_sub_id, cur_sub_title, cur_groups)
        cur_groups = []
        flush_section(cur_sections, cur_section_id, cur_section_title, cur_subsections)
        cur_subsections   = []
        _sec_counter[0] += 1
        _sub_counter[0] += 1
        _grp_counter[0] += 1
        _sid = f"{cur_chapter['chapter_id'] if cur_chapter else 'x'}_s{_sec_counter[0]}"
        cur_section_id    = _sid
        cur_section_title = title
        cur_sub_id        = f"{_sid}_b{_sub_counter[0]}"
        cur_sub_title     = title
        cur_group_id      = f"{cur_sub_id}_g{_grp_counter[0]}"
        cur_group_title   = ""

    def open_subsection(title: str):
        nonlocal cur_sub_id, cur_sub_title, cur_group_id, cur_group_title, cur_groups, cur_blocks
        emit_pending()
        flush_group(cur_groups, cur_group_id, cur_group_title, cur_blocks)
        cur_blocks   = []
        flush_subsection(cur_subsections, cur_sub_id, cur_sub_title, cur_groups)
        cur_groups   = []
        _sub_counter[0] += 1
        _grp_counter[0] += 1
        cur_sub_id   = f"{cur_section_id}_b{_sub_counter[0]}"
        cur_sub_title = title
        cur_group_id  = f"{cur_sub_id}_g{_grp_counter[0]}"
        cur_group_title = ""

    def open_group(title: str):
        nonlocal cur_group_id, cur_group_title, cur_blocks
        emit_pending()
        flush_group(cur_groups, cur_group_id, cur_group_title, cur_blocks)
        cur_blocks      = []
        _grp_counter[0] += 1
        cur_group_id    = f"{cur_sub_id}_g{_grp_counter[0]}"
        cur_group_title = title

    # ── walk document ──────────────────────────────────────────────────────────
    i = 0
    while i < len(items):
        kind, obj = items[i]

        # ── TABLE ──────────────────────────────────────────────────────────────
        if kind == "table":
            emit_pending()
            cur_blocks.append(table_to_block(obj))
            i += 1
            continue

        # ── PARAGRAPH ──────────────────────────────────────────────────────────
        para  = obj
        style = para.style.name
        text  = clean(para.text)

        if not text:
            i += 1
            continue

        text_lower = text.lower()

        # ── chapter boundary (index-based, from pre-scan) ───────────────────
        if i in chapter_boundary_map:
            open_chapter(chapter_boundary_map[i], text)
            i += 1
            continue

        # ── skip if no chapter yet (preamble / TOC noise) ──────────────────
        if cur_chapter is None:
            i += 1
            continue

        # ── heading detection ───────────────────────────────────────────────
        # When the current chapter defines section_anchors, those anchors
        # control exactly which headings become sections vs subsections.
        cur_ch_id = cur_chapter["chapter_id"] if cur_chapter else ""
        sec_anchors = section_anchor_sets.get(cur_ch_id)  # None if not defined

        text_no_emoji = re.sub(r"[^\w\s\-&'\"(),./]", "", text).strip()
        text_norm_local = norm(text)

        if sec_anchors is not None:
            # ── Chapter with explicit section_anchors (e.g. OVERVIEW) ──────────
            # Any heading that matches a section_anchor → open_section.
            # Any other heading-like paragraph → open_subsection or open_group.
            # Only check on heading-like lines (bold or heading style), not body text.
            is_heading_para = (
                style.startswith("Heading")
                or (style in ("Normal", "Normal (Web)") and is_bold(para))
            )
            # Match if exact, or if the text is just the anchor + minor suffix
            # (e.g. trailing colon/number). Reject full-sentence matches.
            def _sec_match(t: str, a: str) -> bool:
                if t == a:
                    return True
                if t.startswith(a) and len(t) <= len(a) + 6:
                    return True  # e.g. "dental development:" or "dental development 1"
                return False
            is_section_anchor = is_heading_para and any(
                _sec_match(text_norm_local, a) for a in sec_anchors
            )
            if is_section_anchor and len(text) > 4:
                open_section(text)
                i += 1
                continue
            # Non-anchor headings: H1/bold-caps → subsection, H3/H4 → group
            if style == "Heading 1" or (
                style in ("Normal", "Normal (Web)") and is_bold(para)
                and is_all_caps_heading(text_no_emoji) and len(text) > 5
            ):
                open_subsection(text)
                i += 1
                continue
            if style in ("Heading 2", "Heading 3", "Heading 4"):
                open_group(text)
                i += 1
                continue
            if style in ("Normal", "Normal (Web)") and is_bold(para) and len(text) > 5:
                open_group(text)
                i += 1
                continue
        else:
            # ── Standard automatic detection ────────────────────────────────────
            if style == "Heading 1":
                open_section(text)
                i += 1
                continue

            if style == "Heading 2":
                open_subsection(text)
                i += 1
                continue

            if style in ("Heading 3", "Heading 4"):
                open_group(text)
                i += 1
                continue

            # Bold ALL-CAPS Normal → section
            if style in ("Normal", "Normal (Web)") and is_bold(para) and is_all_caps_heading(text_no_emoji):
                if len(text) > 6 and not text.startswith("📌") and not text.startswith("🔍"):
                    open_section(text)
                    i += 1
                    continue

            # Bold mixed-case Normal → group
            if style in ("Normal", "Normal (Web)") and is_bold(para) and not is_all_caps_heading(text_no_emoji):
                if len(text) > 5 and not re.match(r"^[\d•\-]", text):
                    open_group(text)
                    i += 1
                    continue

        # ── block type detection ─────────────────────────────────────────────
        hint = detect_block_type(text)

        if hint == "red_flags_header":
            emit_pending()
            pending_type = "red_flags"
            i += 1
            continue

        if hint == "clinical_pearls_header":
            emit_pending()
            pending_type = "clinical_pearls"
            i += 1
            continue

        if hint == "mnemonic_header":
            emit_pending()
            pending_type = "mnemonic"
            # Try to extract the mnemonic word from the header
            m = re.search(r'"([A-Z]{2,})"', text)
            pending_mnemonic_word = m.group(1) if m else ""
            i += 1
            continue

        if hint == "algorithm_header":
            emit_pending()
            pending_type = "algorithm"
            i += 1
            continue

        # List Paragraph style → checklist or continuation of pending list
        if style == "List Paragraph":
            if pending_type in ("red_flags", "clinical_pearls", "checklist", "mnemonic", "algorithm"):
                pending_items.append(text)
            else:
                emit_pending()
                pending_type = "checklist"
                pending_items.append(text)
            i += 1
            continue

        # Numbered list  "1. ..."  → algorithm step
        if re.match(r"^\d+\.\s+", text):
            if pending_type == "algorithm":
                pending_items.append(re.sub(r"^\d+\.\s+", "", text))
            else:
                emit_pending()
                pending_type = "algorithm"
                pending_items.append(re.sub(r"^\d+\.\s+", "", text))
            i += 1
            continue

        # Bullet  "• …"  or  "- …" → checklist
        if re.match(r"^[•\-]\s+", text):
            if pending_type == "checklist":
                pending_items.append(re.sub(r"^[•\-]\s+", "", text))
            else:
                emit_pending()
                pending_type = "checklist"
                pending_items.append(re.sub(r"^[•\-]\s+", "", text))
            i += 1
            continue

        # Mnemonic letter item  "A – Label"  while inside a mnemonic block
        if pending_type == "mnemonic" and re.match(r"^[A-Z]\s*[.:\-–—]", text):
            pending_items.append(text)
            i += 1
            continue

        # Continuation of red_flags / clinical_pearls
        if pending_type in ("red_flags", "clinical_pearls") and style in ("Normal", "Normal (Web)", "Normal (Web)"):
            # If it looks like a list item (short, no trailing period or mid-sentence), continue
            if len(text) < 200 and not text.endswith((".","?")):
                pending_items.append(text)
                i += 1
                continue

        # Default: plain paragraph — emit any pending first
        emit_pending()
        if text:
            cur_blocks.append({"type": "paragraph", "text": text})
        i += 1

    # flush final state
    save_chapter()

    return {
        "id":       "paediatrics-001",
        "title":    "Paediatrics",
        "author":   "Hikma Akinfunmilola Atanda",
        "coverUrl": "assets/books/Paediatrics.png",
        "chapters": chapters,
    }


# ── run ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Converting… (this may take 30–60 seconds)")
    book = convert(DOCX_PATH, MAP_PATH)
    OUT_PATH.write_text(json.dumps(book, ensure_ascii=False, indent=2), encoding="utf-8")

    # Stats
    total_sections    = sum(len(ch["sections"]) for ch in book["chapters"])
    total_subsections = sum(len(s["subsections"]) for ch in book["chapters"] for s in ch["sections"])
    total_groups      = sum(len(sub["content_groups"]) for ch in book["chapters"]
                            for s in ch["sections"] for sub in s["subsections"])
    total_blocks      = sum(len(g["blocks"]) for ch in book["chapters"]
                            for s in ch["sections"] for sub in s["subsections"]
                            for g in sub["content_groups"])
    block_types: dict = {}
    for ch in book["chapters"]:
        for s in ch["sections"]:
            for sub in s["subsections"]:
                for g in sub["content_groups"]:
                    for b in g["blocks"]:
                        block_types[b["type"]] = block_types.get(b["type"], 0) + 1

    print(f"\n✓ Written to {OUT_PATH}")
    print(f"  Chapters:     {len(book['chapters'])}")
    print(f"  Sections:     {total_sections}")
    print(f"  Subsections:  {total_subsections}")
    print(f"  Groups:       {total_groups}")
    print(f"  Blocks:       {total_blocks}")
    print(f"  Block types:  {dict(sorted(block_types.items(), key=lambda x: -x[1]))}")
