"""Compare the DOCX table of contents with extracted book headings in order.

This is an independent coverage check. The TOC does not define the book
hierarchy; it can be stale and all entries in this source use the same style.
"""

import bisect
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

from docx import Document


SCRIPT_DIR = Path(__file__).parent
SOURCE = SCRIPT_DIR / "final" / "enchiridion pediatrics final app copy.docx"
BOOK = SCRIPT_DIR.parent / "enchiridion" / "assets" / "data" / "paediatrics.json"
REPORT = SCRIPT_DIR / "output" / "paediatrics_toc_audit.md"


def normalize(title: str) -> str:
    title = unicodedata.normalize("NFKD", title).casefold()
    title = re.sub(r"^\s*\d+(?:\.\d+)*[.)]?\s*", "", title)
    title = "".join(char for char in title if char.isalnum() or char.isspace())
    return re.sub(r"\s+", " ", title).strip()


def toc_entries(document):
    entries = []
    blanks = 0
    styles = set()
    for paragraph in document.paragraphs:
        if not paragraph.style.name.lower().startswith("toc"):
            continue
        styles.add(paragraph.style.name)
        title, separator, page = paragraph.text.rpartition("\t")
        if not separator:
            title, page = paragraph.text, ""
        title = title.strip()
        if not title:
            blanks += 1
            continue
        entries.append({"title": title, "page": page.strip()})
    return entries, blanks, sorted(styles)


def book_headings(book):
    headings = []
    for chapter in book["chapters"]:
        chapter_id = chapter["chapter_metadata"]["chapter_id"]
        for section in chapter["sections"]:
            headings.append((section["section_title"], chapter_id, "section"))
            for subsection in section["subsections"]:
                headings.append((subsection["subsection_title"], chapter_id, "subsection"))
                for group in subsection["content_groups"]:
                    if group["group_title"]:
                        headings.append((group["group_title"], chapter_id, "group"))
    return headings


def match_in_order(entries, headings):
    """Require monotonically increasing book positions, even for duplicates."""
    positions = defaultdict(list)
    for index, (title, _, _) in enumerate(headings):
        positions[normalize(title)].append(index)
    cursor = -1
    results = []
    for entry in entries:
        candidates = positions.get(normalize(entry["title"]), [])
        next_position = bisect.bisect_right(candidates, cursor)
        if next_position == len(candidates):
            results.append({**entry, "match": None,
                            "other_positions": [headings[i] for i in candidates]})
            continue
        cursor = candidates[next_position]
        title, chapter_id, level = headings[cursor]
        results.append({**entry, "match": {
            "title": title, "chapter_id": chapter_id,
            "level": level, "position": cursor,
        }})
    return results


def render_report(entries, blanks, styles, results):
    matched = sum(result["match"] is not None for result in results)
    lines = [
        "# Paediatrics table-of-contents audit",
        "",
        f"Source: `scripts/final/enchiridion pediatrics final app copy.docx`",
        f"Book: `enchiridion/assets/data/paediatrics.json`",
        "",
        f"- Non-empty TOC entries: **{len(entries)}**; blank TOC entries: **{blanks}**.",
        f"- Headings matched in book order: **{matched}/{len(entries)}**.",
        f"- TOC styles: `{', '.join(styles)}`. A single style does not establish heading levels.",
        "- This checks title presence and order. It does not verify the clinical text, images, or page numbers.",
        "",
        "## Unmatched entries",
        "",
    ]
    unmatched = [r for r in results if r["match"] is None]
    if unmatched:
        for entry in unmatched:
            other = entry["other_positions"]
            note = (
                f"; same title occurs elsewhere at {', '.join(f'{h[1]}:{h[2]}' for h in other)}"
                if other else ""
            )
            lines.append(f"- `{entry['title']}` (TOC page {entry['page'] or '?'}){note}")
    else:
        lines.append("None.")
    lines.extend(["", "## Ordered matches", "",
                  "| TOC title | TOC page | Book chapter | Level | Book heading |",
                  "|---|---:|---|---|---|"])
    for entry in results:
        match = entry["match"]
        if match is None:
            continue
        title = entry["title"].replace("|", "\\|")
        book_title = match["title"].replace("|", "\\|")
        lines.append(
            f"| {title} | {entry['page']} | {match['chapter_id']} | "
            f"{match['level']} | {book_title} |"
        )
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    document = Document(SOURCE)
    book = json.loads(BOOK.read_text(encoding="utf-8"))
    entries, blanks, styles = toc_entries(document)
    results = match_in_order(entries, book_headings(book))
    REPORT.write_text(render_report(entries, blanks, styles, results), encoding="utf-8")
    matched = sum(result["match"] is not None for result in results)
    print(f"TOC headings matched in book order: {matched}/{len(entries)}")
    print(f"Blank entries: {blanks}; report: {REPORT}")
    for result in results:
        if result["match"] is None:
            print(f"Unmatched: {result['title']}")
    if matched != len(entries):
        raise SystemExit(1)
