"""
Generate the OSCE resource cards from osce_manifest.json and Hikma's source files.

Usage:
  python3 generate_osce_content.py --source-dir DIR [--card KEY ...] [--catalog-only]

DIR holds the source files named by their Slack file id (F0XXXX.docx / .mp3).
They are not committed. Outputs:
  - enchiridion/assets/data/resources/<topic>.json
  - enchiridion/assets/resources/content/<card>/<topic>_NN.webp
  - enchiridion/assets/audio/sounds/<sound>_<n>.mp3
  - enchiridion/lib/data/resource_catalog.dart
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import shutil
from pathlib import Path

from docx import Document
from docx.oxml.ns import qn
from docx.text.hyperlink import Hyperlink
from docx.text.paragraph import Paragraph
from docx.text.run import Run
from PIL import Image, UnidentifiedImageError

from normalize_sounds import normalize

from generate_resource_content import (
    APP_DIR,
    RESOURCE_ASSET_DIR,
    RESOURCE_DATA_DIR,
    fix_block_text,
    fix_text,
    iter_block_items,
    table_block,
)

SCRIPTS_DIR = Path(__file__).resolve().parent
MANIFEST = SCRIPTS_DIR / "osce_manifest.json"
SOUND_DIR = APP_DIR / "assets" / "audio" / "sounds"
CATALOG_TARGET = APP_DIR / "lib" / "data" / "resource_catalog.dart"
IMAGE_MAX_WIDTH = 900
IMAGE_QUALITY = 70
GROUP_MIN_PT = 12.5
HEADING_MAX_WORDS = 14
LISTEN_SUFFIX = re.compile(r"\s*\(tap to listen\)\s*:?\s*$", re.IGNORECASE)
SOUND_RENAMES = {"pulmonary friction rub": "pericardial friction rub"}


def slug_for(topic_id: str) -> str:
    return topic_id.replace("-", "_")


def norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


class ImageSink:
    def __init__(self, card: str, slug: str):
        self.card = card
        self.slug = slug
        self.count = 0
        self.seen: dict[str, str | None] = {}
        self.skipped = 0
        self.bytes_written = 0

    def asset_paths(self, document: Document, paragraph: Paragraph) -> list[str]:
        paths = []
        for run in paragraph.runs:
            for blip in run._element.xpath(".//a:blip"):
                rel_id = blip.get(
                    "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed"
                )
                if not rel_id or rel_id not in document.part.related_parts:
                    continue
                blob = document.part.related_parts[rel_id].blob
                key = hashlib.sha1(blob).hexdigest()
                if key not in self.seen:
                    self.seen[key] = self._write(blob)
                if self.seen[key]:
                    paths.append(self.seen[key])
        return paths

    def _write(self, blob: bytes) -> str | None:
        try:
            image = Image.open(io.BytesIO(blob))
            image.load()
        except (UnidentifiedImageError, OSError):
            self.skipped += 1
            return None
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGBA" if "A" in image.getbands() or image.mode == "P" else "RGB")
        if image.width > IMAGE_MAX_WIDTH:
            height = round(image.height * IMAGE_MAX_WIDTH / image.width)
            image = image.resize((IMAGE_MAX_WIDTH, height), Image.LANCZOS)
        self.count += 1
        filename = f"{self.slug}_{self.count:02d}.webp"
        target = RESOURCE_ASSET_DIR / self.card / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target, "WEBP", quality=IMAGE_QUALITY, method=4)
        self.bytes_written += target.stat().st_size
        return f"assets/resources/content/{self.card}/{filename}"


def run_points(paragraph: Paragraph) -> tuple[bool, float]:
    runs = [run for run in paragraph.runs if run.text.strip()]
    if not runs:
        return False, 0.0
    bold = all(run.bold for run in runs)
    sizes = [run.font.size.pt for run in runs if run.font.size is not None]
    return bold, max(sizes) if sizes else 0.0


def heading_text(text: str) -> str:
    return fix_text(text).rstrip(" :").strip()


def plain(text: str) -> str:
    return text.replace("**", "")


def inner_runs(paragraph: Paragraph) -> list[Run]:
    runs: list[Run] = []
    for item in paragraph.iter_inner_content():
        runs.extend(item.runs if isinstance(item, Hyperlink) else [item])
    return runs


def rich_text(paragraph: Paragraph) -> str:
    segments: list[list] = []
    for run in inner_runs(paragraph):
        text = run.text.replace("*", "∗")
        if not text:
            continue
        bold = bool(run.bold) and bool(text.strip())
        if segments and segments[-1][1] == bold:
            segments[-1][0] += text
        else:
            segments.append([text, bold])
    out = []
    for text, bold in segments:
        if not bold:
            out.append(text)
            continue
        core = text.strip()
        lead = text[: len(text) - len(text.lstrip())]
        trail = text[len(text.rstrip()):]
        out.append(f"{lead}**{core}**{trail}")
    return fix_block_text("".join(out)).replace("****", "")


ROMAN = [(1000, "m"), (900, "cm"), (500, "d"), (400, "cd"), (100, "c"), (90, "xc"),
         (50, "l"), (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]


def letters(n: int) -> str:
    out = ""
    while n > 0:
        n, rem = divmod(n - 1, 26)
        out = chr(97 + rem) + out
    return out


def format_number(n: int, fmt: str) -> str:
    if fmt in ("lowerLetter", "upperLetter"):
        value = letters(n)
        return value.upper() if fmt == "upperLetter" else value
    if fmt in ("lowerRoman", "upperRoman"):
        value, rest = "", n
        for amount, numeral in ROMAN:
            while rest >= amount:
                value += numeral
                rest -= amount
        return value.upper() if fmt == "upperRoman" else value
    if fmt == "decimalZero":
        return f"{n:02d}"
    return str(n)


class Numbering:
    """Resolves Word's own list marks (w:numPr) to a nesting level and, for
    ordered lists, the label Word would print, continuing counters across
    interruptions the way Word does."""

    def __init__(self, document: Document):
        self.formats: dict[tuple[str, int], tuple[str, int, str]] = {}
        self.counters: dict[str, dict[int, int]] = {}
        try:
            root = document.part.numbering_part.element
        except (KeyError, NotImplementedError, AttributeError):
            return
        abstract: dict[str, dict[int, tuple[str, int, str]]] = {}
        for node in root.findall(qn("w:abstractNum")):
            levels = {}
            for lvl in node.findall(qn("w:lvl")):
                fmt = lvl.find(qn("w:numFmt"))
                start = lvl.find(qn("w:start"))
                text = lvl.find(qn("w:lvlText"))
                levels[int(lvl.get(qn("w:ilvl")))] = (
                    fmt.get(qn("w:val")) if fmt is not None else "bullet",
                    int(start.get(qn("w:val"))) if start is not None else 1,
                    text.get(qn("w:val")) if text is not None else "",
                )
            abstract[node.get(qn("w:abstractNumId"))] = levels
        for node in root.findall(qn("w:num")):
            ref = node.find(qn("w:abstractNumId"))
            levels = dict(abstract.get(ref.get(qn("w:val")) if ref is not None else "", {}))
            for override in node.findall(qn("w:lvlOverride")):
                start = override.find(qn("w:startOverride"))
                if start is None:
                    continue
                level = int(override.get(qn("w:ilvl")))
                fmt, _, text = levels.get(level, ("decimal", 1, f"%{level + 1}."))
                levels[level] = (fmt, int(start.get(qn("w:val"))), text)
            for level, spec in levels.items():
                self.formats[(node.get(qn("w:numId")), level)] = spec

    def item(self, paragraph: Paragraph) -> tuple[int, str | None] | None:
        p_pr = paragraph._p.pPr
        if p_pr is None or p_pr.numPr is None or p_pr.numPr.numId is None:
            return None
        num_id = str(p_pr.numPr.numId.val)
        if num_id == "0":
            return None
        level = p_pr.numPr.ilvl.val if p_pr.numPr.ilvl is not None else 0
        fmt, start, pattern = self.formats.get((num_id, level), ("bullet", 1, ""))
        counts = self.counters.setdefault(num_id, {})
        for deeper in [key for key in counts if key > level]:
            del counts[deeper]
        counts[level] = counts.get(level, start - 1) + 1
        if fmt in ("bullet", "none", ""):
            return level, None
        label = pattern or f"%{level + 1}."
        for upper in range(level + 1):
            upper_fmt, upper_start, _ = self.formats.get((num_id, upper), ("decimal", 1, ""))
            label = label.replace(f"%{upper + 1}", format_number(counts.get(upper, upper_start), upper_fmt))
        return level, label.strip() or None


def is_lead_in(text: str) -> bool:
    value = plain(text).strip()
    return value.endswith(":") and len(value.split()) <= 12


def is_spoken(text: str) -> bool:
    value = plain(text).strip()
    return value[:1] in ('"', "“") and len(value) > 2


class ChapterBuilder:
    def __init__(self, slug: str, title: str):
        self.slug = slug
        self.title = title
        self.subsections: list[dict] = []
        self.sub_title = "Overview"
        self.sub_title_set = False
        self.groups: list[dict] = []
        self.group_title = ""
        self.blocks: list[dict] = []
        self.list_items: list[dict] = []
        self.list_title: str | None = None

    def flush_list(self) -> None:
        if self.list_items:
            block: dict = {"type": "list"}
            if self.list_title:
                block["title"] = self.list_title
            block["items"] = self.list_items
            self.blocks.append(block)
        self.list_items = []
        self.list_title = None

    def flush_group(self) -> None:
        self.flush_list()
        if self.blocks or self.group_title:
            self.groups.append({
                "group_id": f"{self.slug}_group_{sum(len(s['content_groups']) for s in self.subsections) + len(self.groups) + 1}",
                "group_title": self.group_title,
                "group_subtitle": None,
                "group_icon": None,
                "blocks": self.blocks,
            })
        self.group_title = ""
        self.blocks = []

    def flush_subsection(self) -> None:
        self.flush_group()
        if self.groups or self.sub_title_set:
            self.subsections.append({
                "subsection_id": f"{self.slug}_subsection_{len(self.subsections) + 1}",
                "subsection_title": self.sub_title,
                "subsection_icon": None,
                "content_groups": self.groups,
            })
        self.groups = []
        self.sub_title_set = False

    def start_subsection(self, title: str) -> None:
        self.flush_subsection()
        self.sub_title = title
        self.sub_title_set = True

    def awaiting_group_content(self) -> bool:
        return bool(self.group_title) and not self.blocks and not self.list_items

    def start_group(self, title: str) -> None:
        self.flush_group()
        self.group_title = title

    def add_paragraph(self, text: str, style: str | None = None) -> None:
        self.flush_list()
        block: dict = {"type": "paragraph", "text": text}
        if style:
            block["style"] = style
        self.blocks.append(block)

    def add_list_item(self, text: str, level: int, label: str | None) -> None:
        if not self.list_items and self.blocks:
            last = self.blocks[-1]
            if last["type"] == "paragraph" and not last.get("style") and is_lead_in(last["text"]):
                self.list_title = self.blocks.pop()["text"].rstrip()
        item: dict = {"text": text, "level": level}
        if label:
            item["label"] = label
        self.list_items.append(item)

    def add_block(self, block: dict) -> None:
        self.flush_list()
        self.blocks.append(block)

    def add_images(self, paths: list[str], caption: str | None) -> None:
        self.flush_list()
        for index, path in enumerate(paths):
            self.blocks.append({
                "type": "image",
                "assetPath": path,
                "caption": (caption or None) if index == 0 else None,
            })

    def payload(self, description: str | None) -> dict:
        self.flush_subsection()
        return {
            "chapter_metadata": {
                "chapter_id": self.slug,
                "chapter_title": self.title,
                "chapter_icon": None,
                "description": description,
                "position_in_book": 1,
                "tags": [self.title],
                "chapter_color": None,
            },
            "sections": [{
                "section_id": f"{self.slug}_section_1",
                "section_title": self.title,
                "section_order": 1,
                "subsections": self.subsections,
            }],
        }


def is_banner(text: str, title: str, index: int) -> bool:
    if index > 4:
        return False
    plain_text = norm(text)
    if not plain_text or plain_text.isdigit():
        return True
    if "osce" in plain_text.split() and len(plain_text.split()) <= 3:
        return True
    return plain_text == norm(title) or norm(title) in plain_text and len(plain_text) <= len(norm(title)) + 12


def heading_candidate(paragraph: Paragraph, text: str) -> float | None:
    bold, points = run_points(paragraph)
    if bold and points >= GROUP_MIN_PT and len(text.split()) <= HEADING_MAX_WORDS:
        return points
    return None


TOP_NUMBERED = re.compile(r"^\d+[\.)]\s+\S")
TOP_MIN_PT = 17.0


class HeadingPlan:
    """How a source marks its outline. Most of Hikma's files number their
    main sections ("3. INTRODUCTION") but vary the point size between them,
    so when a file numbers its sections the number decides the top level and
    size only separates the levels beneath it. Files without numbered
    sections fall back to ranking bold heading sizes."""

    def __init__(self, document: Document, title: str):
        counts: dict[float, int] = {}
        numbered = 0
        index = 0
        for paragraph in document.paragraphs:
            text = fix_text(paragraph.text)
            if not text:
                continue
            index += 1
            if is_banner(text, title, index):
                continue
            points = heading_candidate(paragraph, text)
            if points is None:
                continue
            counts[points] = counts.get(points, 0) + 1
            if points >= TOP_MIN_PT and TOP_NUMBERED.match(text):
                numbered += 1
        self.numbered = numbered >= 3
        frequent = sorted((size for size, count in counts.items() if count >= 2), reverse=True)
        self.levels = {size: min(rank + 1, 3) for rank, size in enumerate(frequent)}
        for size in counts:
            if size not in self.levels:
                below = [self.levels[s] for s in frequent if s < size]
                self.levels[size] = below[0] if below else min(len(frequent) + 1, 3)
        self.big_heading_in_section = False

    def level(self, text: str, points: float) -> int:
        if not self.numbered:
            return self.levels[points]
        if points >= TOP_MIN_PT and TOP_NUMBERED.match(text):
            self.big_heading_in_section = False
            return 1
        if points >= TOP_MIN_PT:
            self.big_heading_in_section = True
            return 2
        return 3 if self.big_heading_in_section else 2


def style_level(style: str) -> int | None:
    match = re.match(r"Heading (\d)", style)
    if not match:
        return None
    return {1: 1, 2: 1, 3: 2}.get(int(match.group(1)), 3)


def add_heading(builder: ChapterBuilder, text: str, level: int) -> None:
    if level == 2 and builder.awaiting_group_content():
        builder.add_paragraph(f"**{text}**")
        return
    if level == 1:
        builder.start_subsection(text)
    elif level == 2:
        builder.start_group(text)
    else:
        builder.add_paragraph(f"**{text}**", "heading")


def add_body(builder: ChapterBuilder, paragraph: Paragraph, numbering: Numbering,
             mark: tuple[int, str | None] | None, style: str) -> None:
    text = rich_text(paragraph)
    if not text:
        return
    bullet = re.match(r"^(\*\*)?[•●▪◦\-–]\s+", text)
    if mark is None and (bullet or "List" in style):
        if bullet:
            text = (bullet.group(1) or "") + text[bullet.end():]
        mark = (0, None)
    if mark is not None:
        builder.add_list_item(text, mark[0], mark[1])
        return
    builder.add_paragraph(text, "quote" if is_spoken(text) else None)


def feed_document(builder: ChapterBuilder, document: Document, sink: ImageSink,
                  title: str, first: bool) -> None:
    index = 0
    numbering = Numbering(document)
    plan = HeadingPlan(document, title)
    if not first:
        builder.start_subsection(title)
    for kind, item in iter_block_items(document):
        if kind == "table":
            builder.add_block(table_block(item))
            continue
        paragraph = item
        mark = numbering.item(paragraph)
        text = fix_text(paragraph.text)
        images = sink.asset_paths(document, paragraph)
        if images:
            short = bool(text) and len(text.split()) <= 18
            if text and not short:
                builder.add_paragraph(rich_text(paragraph))
            builder.add_images(images, text if short else None)
            continue
        if not text:
            continue
        index += 1
        if is_banner(text, title, index):
            continue
        if text.strip().isdigit():
            continue
        style = paragraph.style.name if paragraph.style else "Normal"
        level = style_level(style)
        if level == 1 and plan.numbered and not TOP_NUMBERED.match(text):
            # In a file whose main sections are numbered, an unnumbered
            # Word heading ("A. Motor system", "Case 1") sits inside the
            # numbered section above it rather than starting a new one.
            level = 2
        if level is None:
            points = heading_candidate(paragraph, text)
            if points is not None and is_spoken(text):
                builder.add_paragraph(f"**{fix_text(text)}**", "quote")
                continue
            level = plan.level(text, points) if points is not None else None
        if level is not None:
            heading = heading_text(text)
            if mark and mark[1]:
                heading = f"{mark[1]} {heading}"
            if heading:
                add_heading(builder, heading, level)
            continue
        add_body(builder, paragraph, numbering, mark, style)


def write_json(slug: str, payload: dict) -> None:
    target = RESOURCE_DATA_DIR / f"{slug}.json"
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8", newline="\r\n")


def build_topic(card: str, topic: dict, source_dir: Path) -> tuple[str | None, ImageSink | None]:
    sources = [source_dir / f"{s['id']}.docx" for s in topic["sources"]]
    if not sources or not all(path.exists() for path in sources):
        return None, None
    slug = slug_for(topic["id"])
    for old in (RESOURCE_ASSET_DIR / card).glob(f"{slug}_[0-9]*.webp"):
        old.unlink()
    builder = ChapterBuilder(slug, topic["title"])
    sink = ImageSink(card, slug)
    for index, path in enumerate(sources):
        feed_document(builder, Document(str(path)), sink, topic["title"], index == 0)
    write_json(slug, builder.payload(None))
    return f"assets/data/resources/{slug}.json", sink


def sound_slug(title: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")


def build_sounds(manifest: dict, source_dir: Path) -> dict[str, dict]:
    if SOUND_DIR.exists():
        shutil.rmtree(SOUND_DIR)
    SOUND_DIR.mkdir(parents=True)
    sounds = {}
    for sound in manifest["sounds"]:
        slug = sound_slug(sound["title"])
        tracks = []
        for number, file_id in enumerate(sound["tracks"], start=1):
            source = source_dir / f"{file_id}.mp3"
            if not source.exists():
                continue
            name = f"{slug}_{number}.mp3"
            shutil.copyfile(source, SOUND_DIR / name)
            normalize(SOUND_DIR / name)
            tracks.append(f"assets/audio/sounds/{name}")
        sounds[norm(sound["title"])] = {"type": "audio", "title": sound["title"], "tracks": tracks}
    return sounds


def build_quick_revision(manifest: dict, source_dir: Path) -> list[dict]:
    spec = manifest["quick_revision"]
    source = source_dir / f"{spec['source']['id']}.docx"
    document = Document(str(source))
    sounds = build_sounds(manifest, source_dir)
    for old in (RESOURCE_ASSET_DIR / "quick_revision").glob("*.webp"):
        old.unlink()
    parts: list[dict] = []
    builder: ChapterBuilder | None = None
    sink: ImageSink | None = None
    emitted: set[str] = set()
    in_sounds = False
    numbering = Numbering(document)

    def finish() -> None:
        nonlocal in_sounds
        if builder is None:
            return
        if in_sounds:
            builder.flush_list()
            for key, block in sounds.items():
                if key not in emitted:
                    builder.blocks.append(block)
                    emitted.add(key)
        write_json(builder.slug, builder.payload(None))
        in_sounds = False

    for kind, item in iter_block_items(document):
        if kind == "table":
            if builder:
                builder.add_block(table_block(item))
            continue
        paragraph = item
        mark = numbering.item(paragraph)
        text = fix_text(paragraph.text)
        style = paragraph.style.name if paragraph.style else "Normal"
        part = re.match(r"^PART\s*(\d+)\s*:\s*(.+)$", text, re.IGNORECASE)
        if style.startswith("Heading 1") and part:
            finish()
            number = len(parts) + 1
            label = part.group(2).strip().capitalize()
            topic_id = f"quick-revision-part-{number}"
            parts.append({"id": topic_id, "title": f"Part {part.group(1)}: {label}"})
            builder = ChapterBuilder(slug_for(topic_id), parts[-1]["title"])
            sink = ImageSink("quick_revision", slug_for(topic_id))
            continue
        if builder is None or sink is None:
            continue
        images = sink.asset_paths(document, paragraph)
        if images:
            builder.add_images(images, text if text and len(text.split()) <= 18 else None)
            continue
        if not text:
            continue
        if style.startswith("Heading 2"):
            in_sounds = False
            builder.start_subsection(heading_text(text))
            continue
        if style.startswith("Heading 3"):
            if norm(text) == "sounds":
                in_sounds = True
                builder.start_subsection("Sounds")
            else:
                builder.start_group(heading_text(text))
            continue
        if style.startswith("Heading"):
            builder.add_paragraph(f"**{heading_text(text)}**", "heading")
            continue
        if in_sounds and LISTEN_SUFFIX.search(text):
            name = norm(LISTEN_SUFFIX.sub("", text))
            name = SOUND_RENAMES.get(name, name)
            if name in sounds and name not in emitted:
                builder.add_block(sounds[name])
                emitted.add(name)
            continue
        add_body(builder, paragraph, numbering, mark, style)
    finish()
    for part in parts:
        part["asset"] = f"assets/data/resources/{slug_for(part['id'])}.json"
    return parts


CHAPTER_LINE = re.compile(r"^chapter\s*(\d+)\s*[:.]\s*(.+)$", re.IGNORECASE)
MNEMONIC_SUB_PT = 17.0
MNEMONIC_GROUP_PT = 13.0
MNEMONIC_NUMBERED = re.compile(r"^\d+(\.\d+)*[\.)]?\s+\S")


def mnemonic_slug(number: int) -> str:
    return f"mnemonics_chapter_{number}"


def is_chapter_line(paragraph: Paragraph, text: str, style: str) -> re.Match | None:
    chapter = CHAPTER_LINE.match(text)
    if chapter and (style.startswith("Heading 1") or run_points(paragraph)[1] >= 20):
        return chapter
    return None


def mnemonic_modes(document: Document) -> dict[int, str]:
    """The handbook's chapters mark their items three ways: Word headings
    (Heading 2 item, Heading 3 mnemonic), bold 18pt numbered items with
    13.5pt mnemonics under them, or 13.5pt numbered items under an 18pt
    section banner. Work out which one each chapter uses."""
    counts: dict[int, dict[str, int]] = {}
    current = None
    for paragraph in document.paragraphs:
        text = fix_text(paragraph.text)
        style = paragraph.style.name if paragraph.style else "Normal"
        chapter = is_chapter_line(paragraph, text, style)
        if chapter:
            current = int(chapter.group(1))
            counts[current] = {"styles": 0, "big": 0}
            continue
        if current is None or not text:
            continue
        if style.startswith("Heading 2"):
            counts[current]["styles"] += 1
        bold, points = run_points(paragraph)
        if bold and points >= MNEMONIC_SUB_PT and MNEMONIC_NUMBERED.match(text):
            counts[current]["big"] += 1
    modes = {}
    for number, count in counts.items():
        if count["styles"] >= 3:
            modes[number] = "styles"
        elif count["big"] >= 3:
            modes[number] = "big"
        else:
            modes[number] = "small"
    return modes


def mnemonic_level(paragraph: Paragraph, text: str, style: str, mode: str) -> int | None:
    """Subsection (1), group (2) or bold line (3) for a heading, None for
    body text, 0 for a section banner that is dropped because its items
    become the subsections."""
    match = re.match(r"Heading (\d)", style)
    if match:
        return {1: 1, 2: 1, 3: 2}.get(int(match.group(1)), 3)
    bold, points = run_points(paragraph)
    if not bold or len(text.split()) > HEADING_MAX_WORDS:
        return None
    if len(text.strip()) <= 2:
        # Chapter 5 spells FAST out in single 24pt letters.
        return None
    if points < MNEMONIC_GROUP_PT:
        return None
    if mode == "styles":
        return 2
    if mode == "big":
        return 1 if points >= MNEMONIC_SUB_PT else 2
    return 0 if points >= MNEMONIC_SUB_PT else 1


def build_mnemonics(manifest: dict, source_dir: Path) -> list[dict]:
    spec = manifest["mnemonics"]
    source = source_dir / f"{spec['source']['id']}.docx"
    document = Document(str(source))
    for old in (RESOURCE_ASSET_DIR / "mnemonics").glob("*.webp"):
        old.unlink()
    for old in RESOURCE_DATA_DIR.glob("mnemonics_chapter_*.json"):
        old.unlink()
    chapters: list[dict] = []
    builder: ChapterBuilder | None = None
    sink: ImageSink | None = None
    numbering = Numbering(document)
    modes = mnemonic_modes(document)
    mode = "styles"

    def finish() -> None:
        if builder is not None:
            write_json(builder.slug, builder.payload(None))

    for kind, item in iter_block_items(document):
        if kind == "table":
            if builder:
                builder.add_block(table_block(item))
            continue
        paragraph = item
        mark = numbering.item(paragraph)
        text = fix_text(paragraph.text)
        style = paragraph.style.name if paragraph.style else "Normal"
        chapter = is_chapter_line(paragraph, text, style)
        if chapter:
            finish()
            number = int(chapter.group(1))
            title = heading_text(chapter.group(2)).capitalize()
            chapters.append({"number": number, "title": title})
            mode = modes.get(number, "styles")
            builder = ChapterBuilder(mnemonic_slug(number), title)
            sink = ImageSink("mnemonics", mnemonic_slug(number))
            continue
        if builder is None or sink is None:
            continue
        images = sink.asset_paths(document, paragraph)
        level = mnemonic_level(paragraph, text, style, mode) if text else None
        if level:
            heading = heading_text(text)
            if mark and mark[1]:
                heading = f"{mark[1]} {heading}"
            add_heading(builder, heading, level)
            if images:
                builder.add_images(images, None)
            continue
        if level == 0:
            if images:
                builder.add_images(images, None)
            continue
        if images:
            short = bool(text) and len(text.split()) <= 18
            if text and not short:
                builder.add_paragraph(rich_text(paragraph))
            builder.add_images(images, text if short else None)
            continue
        if not text:
            continue
        add_body(builder, paragraph, numbering, mark, style)
    finish()
    return chapters


def mnemonic_topics(manifest: dict) -> list[dict]:
    groups = {}
    for group in manifest["mnemonics"]["groups"]:
        for number in group["chapters"]:
            groups[number] = group["title"]
    topics = []
    for path in sorted(RESOURCE_DATA_DIR.glob("mnemonics_chapter_*.json"),
                       key=lambda p: int(p.stem.rsplit("_", 1)[1])):
        number = int(path.stem.rsplit("_", 1)[1])
        data = json.loads(path.read_text(encoding="utf-8"))
        topics.append({
            "id": f"mnemonics-chapter-{number}",
            "title": data["chapter_metadata"]["chapter_title"],
            "group": groups.get(number),
            "dataAssetPath": f"assets/data/resources/{path.name}",
        })
    return topics


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def write_catalog(manifest: dict, assets: dict[str, str | None], quick_parts: list[dict]) -> None:
    lines = [
        "// Generated by scripts/generate_osce_content.py from scripts/osce_manifest.json.",
        "// Edit the manifest and regenerate rather than editing this file.",
        "",
        "import '../models/resource_topic.dart';",
        "",
    ]

    def emit(name: str, category: str, hero: str, topics: list[dict]) -> None:
        lines.append(f"const List<ResourceTopic> {name} = [")
        for topic in topics:
            lines.append("  ResourceTopic(")
            lines.append(f"    id: {dart_string(topic['id'])},")
            lines.append(f"    title: {dart_string(topic['title'])},")
            lines.append(f"    categoryTitle: {dart_string(category)},")
            lines.append(f"    heroAssetPath: {dart_string(hero)},")
            asset = topic.get("dataAssetPath")
            if asset:
                lines.append(f"    dataAssetPath: {dart_string(asset)},")
            if topic.get("group"):
                lines.append(f"    group: {dart_string(topic['group'])},")
            lines.append("  ),")
        lines.append("];")
        lines.append("")

    for card in manifest["cards"]:
        topics = []
        for topic in card["topics"]:
            topics.append({**topic, "dataAssetPath": topic.get("asset") or assets.get(topic["id"])})
        emit(card["dart_name"], card["category_title"], card["hero_asset"], topics)
    spec = manifest["quick_revision"]
    emit(spec["dart_name"], spec["category_title"], spec["hero_asset"],
         [{**part, "dataAssetPath": part.get("asset")} for part in quick_parts])
    spec = manifest["mnemonics"]
    emit(spec["dart_name"], spec["category_title"], spec["hero_asset"], mnemonic_topics(manifest))
    CATALOG_TARGET.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_TARGET.write_text("\n".join(lines), encoding="utf-8")


def existing_assets(manifest: dict) -> tuple[dict[str, str | None], list[dict]]:
    assets: dict[str, str | None] = {}
    for card in manifest["cards"]:
        for topic in card["topics"]:
            path = RESOURCE_DATA_DIR / f"{slug_for(topic['id'])}.json"
            assets[topic["id"]] = f"assets/data/resources/{path.name}" if path.exists() else None
    parts = []
    for path in sorted(RESOURCE_DATA_DIR.glob("quick_revision_part_*.json"),
                       key=lambda p: int(p.stem.rsplit("_", 1)[1])):
        data = json.loads(path.read_text(encoding="utf-8"))
        parts.append({
            "id": path.stem.replace("_", "-"),
            "title": data["chapter_metadata"]["chapter_title"],
            "asset": f"assets/data/resources/{path.name}",
        })
    return assets, parts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path)
    parser.add_argument("--card", action="append", dest="cards", metavar="KEY")
    parser.add_argument("--catalog-only", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.catalog_only:
        assets, parts = existing_assets(manifest)
        write_catalog(manifest, assets, parts)
        print(f"Wrote {CATALOG_TARGET.relative_to(APP_DIR)}.")
        return
    if args.source_dir is None:
        raise SystemExit("--source-dir is required unless --catalog-only is set")
    RESOURCE_DATA_DIR.mkdir(parents=True, exist_ok=True)
    wanted = set(args.cards or [])
    total_images = 0
    skipped = 0
    for card in manifest["cards"]:
        if wanted and card["key"] not in wanted:
            continue
        missing = []
        for topic in card["topics"]:
            if topic.get("asset"):
                continue
            path, sink = build_topic(card["key"], topic, args.source_dir)
            if path is None:
                missing.append(topic["title"])
                continue
            total_images += sink.bytes_written
            skipped += sink.skipped
        print(f"{card['key']}: {len(card['topics']) - len(missing)} topics built"
              + (f", waiting on files for: {', '.join(missing)}" if missing else ""))
    if not wanted or "quick_revision" in wanted:
        parts = build_quick_revision(manifest, args.source_dir)
        print(f"quick_revision: {len(parts)} parts built")
    if not wanted or "mnemonics" in wanted:
        chapters = build_mnemonics(manifest, args.source_dir)
        print(f"mnemonics: {len(chapters)} chapters built")
    assets, parts = existing_assets(manifest)
    write_catalog(manifest, assets, parts)
    print(f"Images written: {total_images / 1e6:.1f} MB, {skipped} unsupported images skipped.")


if __name__ == "__main__":
    main()
