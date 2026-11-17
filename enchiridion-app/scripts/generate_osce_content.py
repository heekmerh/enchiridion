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
from docx.text.paragraph import Paragraph
from PIL import Image, UnidentifiedImageError

from generate_resource_content import (
    APP_DIR,
    RESOURCE_ASSET_DIR,
    RESOURCE_DATA_DIR,
    checklist_block,
    checklist_candidate,
    fix_text,
    iter_block_items,
    paragraph_block,
    table_block,
)

SCRIPTS_DIR = Path(__file__).resolve().parent
MANIFEST = SCRIPTS_DIR / "osce_manifest.json"
SOUND_DIR = APP_DIR / "assets" / "audio" / "sounds"
CATALOG_TARGET = APP_DIR / "lib" / "data" / "resource_catalog.dart"
IMAGE_MAX_WIDTH = 900
IMAGE_QUALITY = 70
SUBSECTION_MIN_PT = 22.0
NUMBERED_SUBSECTION_MIN_PT = 17.0
GROUP_MIN_PT = 12.5
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


def clean_title(text: str) -> str:
    text = re.sub(r"^\d+(\.\d+)*[\.)]?\s*", "", fix_text(text))
    return text.strip(" :-")


class ChapterBuilder:
    def __init__(self, slug: str, title: str):
        self.slug = slug
        self.title = title
        self.subsections: list[dict] = []
        self.sub_title = "Overview"
        self.groups: list[dict] = []
        self.group_title = ""
        self.blocks: list[dict] = []
        self.pending: list[str] = []

    def flush_checklist(self) -> None:
        if self.pending:
            self.blocks.append(checklist_block(self.pending))
            self.pending = []

    def flush_group(self) -> None:
        self.flush_checklist()
        if self.blocks:
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
        if self.groups:
            self.subsections.append({
                "subsection_id": f"{self.slug}_subsection_{len(self.subsections) + 1}",
                "subsection_title": self.sub_title,
                "subsection_icon": None,
                "content_groups": self.groups,
            })
        self.groups = []

    def start_subsection(self, title: str) -> None:
        self.flush_subsection()
        self.sub_title = title

    def start_group(self, title: str) -> None:
        self.flush_group()
        self.group_title = title

    def add_text(self, text: str, list_style: bool) -> None:
        if list_style or checklist_candidate(text, ""):
            self.pending.append(text)
            return
        self.flush_checklist()
        self.blocks.append(paragraph_block(text))

    def add_block(self, block: dict) -> None:
        self.flush_checklist()
        self.blocks.append(block)

    def add_images(self, paths: list[str], caption: str | None) -> None:
        self.flush_checklist()
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
    plain = norm(text)
    if not plain or plain.isdigit():
        return True
    if "osce" in plain.split() and len(plain.split()) <= 3:
        return True
    return plain == norm(title) or norm(title) in plain and len(plain) <= len(norm(title)) + 12


def feed_document(builder: ChapterBuilder, document: Document, sink: ImageSink,
                  title: str, first: bool) -> None:
    index = 0
    if not first:
        builder.start_subsection(title)
    for kind, item in iter_block_items(document):
        if kind == "table":
            builder.add_block(table_block(item))
            continue
        paragraph = item
        text = fix_text(paragraph.text)
        images = sink.asset_paths(document, paragraph)
        if images:
            short = bool(text) and len(text.split()) <= 18
            if text and not short:
                builder.add_block(paragraph_block(text))
            builder.add_images(images, text if short else None)
            continue
        if not text:
            builder.flush_checklist()
            continue
        index += 1
        if is_banner(text, title, index):
            continue
        if text.strip().isdigit():
            continue
        bold, points = run_points(paragraph)
        style = paragraph.style.name if paragraph.style else "Normal"
        numbered = bool(re.match(r"^\d+(\.\d+)*[\.)]\s+\S", text))
        if style.startswith("Heading 1") or style.startswith("Heading 2") or (
            bold and (points >= SUBSECTION_MIN_PT or (numbered and points >= NUMBERED_SUBSECTION_MIN_PT))
        ):
            heading = clean_title(text)
            if heading:
                builder.start_subsection(heading)
            continue
        if style.startswith("Heading") or (bold and points >= GROUP_MIN_PT and len(text.split()) <= 14):
            builder.start_group(fix_text(text).rstrip(":"))
            continue
        builder.add_text(text, "List" in style or text.startswith(("•", "-", "–")))


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

    def finish() -> None:
        nonlocal in_sounds
        if builder is None:
            return
        if in_sounds:
            builder.flush_checklist()
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
            builder.flush_checklist()
            continue
        if style.startswith("Heading 2"):
            in_sounds = False
            builder.start_subsection(clean_title(text))
            continue
        if style.startswith("Heading 3"):
            if norm(text) == "sounds":
                in_sounds = True
                builder.start_subsection("Sounds")
            else:
                builder.start_group(clean_title(text))
            continue
        if in_sounds and LISTEN_SUFFIX.search(text):
            name = norm(LISTEN_SUFFIX.sub("", text))
            name = SOUND_RENAMES.get(name, name)
            if name in sounds and name not in emitted:
                builder.add_block(sounds[name])
                emitted.add(name)
            continue
        builder.add_text(text, "List" in style or text.startswith(("•", "-", "–")))
    finish()
    for part in parts:
        part["asset"] = f"assets/data/resources/{slug_for(part['id'])}.json"
    return parts


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
    assets, parts = existing_assets(manifest)
    write_catalog(manifest, assets, parts)
    print(f"Images written: {total_images / 1e6:.1f} MB, {skipped} unsupported images skipped.")


if __name__ == "__main__":
    main()
