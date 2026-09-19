"""
Generate app-owned resource JSON/assets from the source DOCX and question files.

Outputs:
  - enchiridion/assets/data/exam_prep_questions.json
  - enchiridion/assets/data/resources/*.json
  - enchiridion/assets/resources/content/<topic>/*
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from docx import Document
from docx.oxml.ns import qn
from docx.table import Table
from docx.text.paragraph import Paragraph


ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "enchiridion"
CONTENT_DIR = ROOT / "scripts" / "content"
DATA_DIR = APP_DIR / "assets" / "data"
RESOURCE_DATA_DIR = DATA_DIR / "resources"
RESOURCE_ASSET_DIR = APP_DIR / "assets" / "resources" / "content"
QUESTION_SOURCE = CONTENT_DIR / "question.json"
QUESTION_TARGET = DATA_DIR / "exam_prep_questions.json"


@dataclass(frozen=True)
class TopicSpec:
    slug: str
    title: str
    source_path: Path
    description: str
    # Opts this topic into detecting headings by Word run formatting (bold +
    # an explicit run size at or above this many points) in addition to the
    # three style/text-shape rules in is_heading(). Left at the default
    # (None, i.e. opted out) for sutures and abdominal_examination: the same
    # bold-and-large-run pattern matches ordinary content lines in those two
    # sources (see the counts in 260919-kix's plan research findings), so
    # enabling it there would restructure already-shipped topics.
    bold_heading_min_pt: float | None = None


TOPICS = [
    TopicSpec(
        slug="sutures",
        title="Sutures",
        source_path=CONTENT_DIR / "SUTURES_instrumentation.docx",
        description="Core suture concepts, classification, and technique illustrations.",
    ),
    TopicSpec(
        slug="iv_cannula",
        title="IV Cannula",
        source_path=CONTENT_DIR / "IV_Cannula_instrumentation.docx",
        description="Peripheral venous cannula anatomy, uses, precautions, and insertion flow.",
        bold_heading_min_pt=13.5,
    ),
    TopicSpec(
        slug="abdominal_examination",
        title="Abdominal Examination",
        source_path=CONTENT_DIR / "ABDOMINAL_EXAMINATION_osce.docx",
        description="A structured OSCE abdominal examination guide with image support.",
    ),
]


def fix_block_text(value: str) -> str:
    text = value.replace("\xa0", " ").strip()
    if not text:
        return ""
    if any(marker in text for marker in ("Â", "â", "ð")):
        try:
            repaired = text.encode("latin-1", "ignore").decode("utf-8", "ignore")
            if repaired:
                text = repaired
        except Exception:
            pass
    replacements = {
        "â€”": "—",
        "â€“": "–",
        "â€™": "'",
        "â€˜": "'",
        'â€œ': '"',
        'â€\x9d': '"',
        "â†’": "→",
        "Â°": "°",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [re.sub(r"[^\S\n]+", " ", line).strip()
             for line in text.split("\n")]
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def fix_text(value: str) -> str:
    return re.sub(r"\s+", " ", fix_block_text(value)).strip()


def ensure_dirs() -> None:
    RESOURCE_DATA_DIR.mkdir(parents=True, exist_ok=True)
    RESOURCE_ASSET_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)


def normalize_questions() -> None:
    raw = QUESTION_SOURCE.read_text(encoding="utf-8", errors="replace").strip()
    payload = [json.loads(repair_json_object_text(obj)) for obj in split_json_objects(raw)]
    normalized = []
    for index, item in enumerate(payload, start=1):
        for key in ("question", "options", "answer", "explanation"):
            if key not in item:
                raise ValueError(f"Question {index} is missing required key: {key}")
        options = {
            key.lower(): fix_text(str(value))
            for key, value in item["options"].items()
            if str(value).strip()
        }
        normalized.append(
            {
                "id": f"exam-{index:04d}",
                "question_text": fix_block_text(item["question"]),
                "options": options,
                "correct_option": str(item["answer"]).lower(),
                "explanation": fix_block_text(item["explanation"]),
                "osce_tip": fix_block_text(item.get("osce_tip", "")) or None,
                "question_number": index,
                "topic": fix_text(item.get("topic", "")) or None,
            }
        )
    # Keep the bundled asset's existing CRLF line endings. The meaningful
    # change in this regeneration is the escaped newlines inside explanations.
    with QUESTION_TARGET.open("w", encoding="utf-8", newline="\r\n") as target:
        json.dump(normalized, target, ensure_ascii=False, indent=2)


def split_json_objects(raw: str) -> list[str]:
    objects = []
    depth = 0
    in_string = False
    escaped = False
    start_index = None

    for index, char in enumerate(raw):
      if in_string:
        if escaped:
          escaped = False
        elif char == "\\":
          escaped = True
        elif char == '"':
          in_string = False
        continue

      if char == '"':
        in_string = True
        continue

      if char == "{":
        if depth == 0:
          start_index = index
        depth += 1
      elif char == "}":
        depth -= 1
        if depth == 0 and start_index is not None:
          objects.append(raw[start_index : index + 1])
          start_index = None

    return objects


def repair_json_object_text(raw: str) -> str:
    repaired = raw
    repaired = re.sub(
        r'(\}|\]|"(?:[^"\\]|\\.)*"|\d+|true|false|null)(\s*\n\s*)"([A-Za-z_]+)"\s*:',
        r'\1,\2"\3":',
        repaired,
    )
    repaired = re.sub(r",(\s*[}\]])", r"\1", repaired)
    return repaired


def iter_block_items(document: Document) -> Iterable[tuple[str, Paragraph | Table]]:
    body = document.element.body
    for child in body:
        if child.tag == qn("w:p"):
            yield ("paragraph", Paragraph(child, document))
        elif child.tag == qn("w:tbl"):
            yield ("table", Table(child, document))


def extract_images(document: Document, paragraph: Paragraph, output_dir: Path) -> list[str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    rel_paths = []
    seen = getattr(document, "_enchiridion_image_map", {})
    if not hasattr(document, "_enchiridion_image_counter"):
        document._enchiridion_image_counter = 0
    for run in paragraph.runs:
        for blip in run._element.xpath(".//a:blip"):
            rel_id = blip.get(qn("r:embed"))
            if not rel_id:
                continue
            if rel_id in seen:
                rel_paths.append(seen[rel_id])
                continue
            image_part = document.part.related_parts[rel_id]
            suffix = Path(str(image_part.partname)).suffix or ".png"
            document._enchiridion_image_counter += 1
            filename = f"image_{document._enchiridion_image_counter:02d}{suffix}"
            file_path = output_dir / filename
            file_path.write_bytes(image_part.blob)
            asset_path = (
                f"assets/resources/content/{output_dir.name}/{filename}"
            )
            seen[rel_id] = asset_path
            rel_paths.append(asset_path)
    document._enchiridion_image_map = seen
    return rel_paths


def styled_heading_paragraph(paragraph: Paragraph | None, min_pt: float | None) -> bool:
    if min_pt is None or paragraph is None:
        return False
    runs = [run for run in paragraph.runs if run.text.strip()]
    if not runs:
        return False
    if not all(run.bold for run in runs):
        return False
    sizes = [run.font.size.pt for run in runs if run.font.size is not None]
    if not sizes:
        return False
    return max(sizes) >= min_pt


def is_heading(
    text: str,
    style_name: str,
    paragraph: Paragraph | None = None,
    bold_heading_min_pt: float | None = None,
) -> bool:
    if style_name.startswith("Heading"):
        return True
    if len(text) <= 110:
        if re.match(r"^\d+(\.\d+)*[\.)]?\s+[A-Za-z]", text):
            return True
        letters_only = re.sub(r"[^A-Za-z ]", "", text).strip()
        if bool(letters_only) and letters_only == letters_only.upper():
            return True
    return styled_heading_paragraph(paragraph, bold_heading_min_pt)


def clean_heading(text: str) -> str:
    text = fix_text(text)
    text = re.sub(r"^\d+(\.\d+)*[\.)]?\s*", "", text)
    return text.strip(" :-")


def checklist_candidate(text: str, style_name: str) -> bool:
    if "List" in style_name:
        return True
    if text.startswith(("•", "-", "–")):
        return True
    stripped = re.sub(r"^\d+[\.)]\s*", "", text)
    if len(stripped.split()) <= 10 and not stripped.endswith((".", "?", "!", ":")):
        return True
    return False


def table_block(table: Table) -> dict:
    rows = [[fix_text(cell.text) for cell in row.cells] for row in table.rows]
    if not rows:
        return {"type": "paragraph", "text": ""}
    header = rows[0]
    body = rows[1:]
    return {
        "type": "table",
        "columns": header,
        "rows": body,
    }


def paragraph_block(text: str) -> dict:
    return {"type": "paragraph", "text": fix_text(text)}


def checklist_block(items: list[str]) -> dict:
    return {
        "type": "checklist",
        "items": [fix_text(re.sub(r"^[•\-–]\s*", "", item)) for item in items],
    }


def image_block(asset_path: str, caption: str | None) -> dict:
    return {
        "type": "image",
        "assetPath": asset_path,
        "caption": fix_text(caption or "") or None,
    }


def build_topic_json(spec: TopicSpec) -> None:
    document = Document(str(spec.source_path))
    output_dir = RESOURCE_ASSET_DIR / spec.slug
    output_dir.mkdir(parents=True, exist_ok=True)

    subsections = []
    current_title = "Overview"
    current_groups = []
    current_group_title = ""
    current_blocks: list[dict] = []
    pending_checklist: list[str] = []

    def flush_checklist() -> None:
        nonlocal pending_checklist
        if pending_checklist:
            current_blocks.append(checklist_block(pending_checklist))
            pending_checklist = []

    def flush_group() -> None:
        nonlocal current_group_title, current_blocks
        flush_checklist()
        if not current_blocks:
            return
        current_groups.append(
            {
                "group_id": f"{spec.slug}_group_{len(current_groups) + 1}",
                "group_title": current_group_title,
                "group_subtitle": None,
                "group_icon": None,
                "blocks": current_blocks,
            }
        )
        current_group_title = ""
        current_blocks = []

    def flush_subsection() -> None:
        nonlocal current_title, current_groups
        flush_group()
        if not current_groups:
            return
        subsections.append(
            {
                "subsection_id": f"{spec.slug}_subsection_{len(subsections) + 1}",
                "subsection_title": current_title,
                "subsection_icon": None,
                "content_groups": current_groups,
            }
        )
        current_groups = []

    body_items = list(iter_block_items(document))
    if body_items and body_items[0][0] == "paragraph":
        first_text = fix_text(body_items[0][1].text)  # type: ignore[index]
        if first_text:
            current_title = clean_heading(first_text)

    for kind, item in body_items:
        if kind == "table":
            flush_checklist()
            current_blocks.append(table_block(item))  # type: ignore[arg-type]
            continue

        paragraph = item  # type: ignore[assignment]
        text = fix_text(paragraph.text)
        style_name = paragraph.style.name if paragraph.style else "Normal"
        images = extract_images(document, paragraph, output_dir)

        if images and text and len(text.split()) <= 18:
            flush_checklist()
            current_blocks.extend(
                image_block(asset_path, text if idx == 0 else None)
                for idx, asset_path in enumerate(images)
            )
            continue
        if images:
            flush_checklist()
            if text:
                current_blocks.append(paragraph_block(text))
            current_blocks.extend(image_block(asset_path, None) for asset_path in images)
            continue
        if not text:
            flush_checklist()
            continue
        if text == spec.title or text.upper() == spec.title.upper():
            continue
        if is_heading(text, style_name, paragraph, spec.bold_heading_min_pt):
            cleaned = clean_heading(text)
            if not cleaned:
                continue
            flush_subsection()
            current_title = cleaned
            continue
        if text.endswith(":") and len(text.split()) <= 12:
            flush_group()
            current_group_title = text.rstrip(":")
            continue
        if checklist_candidate(text, style_name):
            pending_checklist.append(text)
            continue

        flush_checklist()
        current_blocks.append(paragraph_block(text))

    flush_subsection()

    if not subsections:
        subsections = [
            {
                "subsection_id": f"{spec.slug}_subsection_1",
                "subsection_title": spec.title,
                "subsection_icon": None,
                "content_groups": [
                    {
                        "group_id": f"{spec.slug}_group_1",
                        "group_title": "",
                        "group_subtitle": None,
                        "group_icon": None,
                        "blocks": [paragraph_block(spec.description)],
                    }
                ],
            }
        ]

    payload = {
        "chapter_metadata": {
            "chapter_id": spec.slug,
            "chapter_title": spec.title,
            "chapter_icon": None,
            "description": spec.description,
            "position_in_book": 1,
            "tags": [spec.title],
            "chapter_color": None,
        },
        "sections": [
            {
                "section_id": f"{spec.slug}_section_1",
                "section_title": spec.title,
                "section_order": 1,
                "subsections": subsections,
            }
        ],
    }

    target = RESOURCE_DATA_DIR / f"{spec.slug}.json"
    target.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--questions-only", action="store_true",
                        help="Regenerate the exam question asset only")
    parser.add_argument("--topic", action="append", dest="topics", metavar="SLUG",
                        help="Regenerate only this topic's JSON (repeatable). "
                             "Skips normalize_questions() entirely so a single-"
                             "topic run cannot rewrite the exam question asset.")
    args = parser.parse_args()
    ensure_dirs()

    if args.topics:
        known = {spec.slug: spec for spec in TOPICS}
        unknown = [slug for slug in args.topics if slug not in known]
        if unknown:
            valid = ", ".join(sorted(known))
            raise SystemExit(
                f"Unknown topic slug(s): {', '.join(unknown)}. Valid slugs: {valid}"
            )
        for slug in args.topics:
            build_topic_json(known[slug])
        print(f"Generated resource content asset(s) for: {', '.join(args.topics)}.")
        return

    normalize_questions()
    if not args.questions_only:
        for spec in TOPICS:
            build_topic_json(spec)
    print("Generated exam prep questions" +
          ("." if args.questions_only else " and resource content assets."))


if __name__ == "__main__":
    main()
