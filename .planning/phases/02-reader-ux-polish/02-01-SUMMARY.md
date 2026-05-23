---
phase: 02-reader-ux-polish
plan: "01"
subsystem: reader-ui
tags: [sliver-app-bar, chapter-model, book-json, data-pipeline]
dependency_graph:
  requires: []
  provides:
    - floating-false-app-bar
    - chapter-color-data-pipeline
  affects:
    - 02-02-PLAN.md (chapter_color field for table header tints)
tech_stack:
  added: []
  patterns:
    - SliverAppBar with floating: false (always-visible app bar)
    - Chapter model nullable String? field for JSON-sourced color
key_files:
  created:
    - assets/data/book.json
  modified:
    - lib/widgets/reader/reader_app_bar.dart
    - lib/models/chapter.dart
decisions:
  - "chapter_color assigned by (position_in_book - 1) % 8 cycling 8-color palette"
  - "chapter_color stored as nullable String? to handle legacy JSON without the field"
  - "book.json added as tracked asset (was previously untracked)"
metrics:
  duration: "~3 minutes"
  completed: "2026-05-23"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 2 Plan 01: App Bar Fix and Chapter Color Data Pipeline Summary

**One-liner:** Fixed SliverAppBar to always-visible (floating: false, no snap) and wired chapter_color hex field through book.json and Chapter Dart model for Wave 2 table tinting.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix SliverAppBar — remove floating/snap (D-04) | 08cdaa5 | lib/widgets/reader/reader_app_bar.dart |
| 2 | Add chapter_color to book.json and Chapter model (D-03) | dc00373 | assets/data/book.json, lib/models/chapter.dart |

## What Was Built

### Task 1 — SliverAppBar fix (D-04)

Changed `floating: true` to `floating: false` and removed `snap: true` from the `ReaderAppBar` widget. Flutter asserts that `snap` requires `floating`, so removing snap was mandatory. The app bar now stays visible at all times as the user scrolls.

### Task 2 — chapter_color data pipeline (D-03)

Added `"chapter_color"` hex string to every `chapter_metadata` object in `book.json` (80 chapters). Colors are assigned by cycling an 8-color palette using `(position_in_book - 1) % 8`:

| Index | Color | Name |
|-------|-------|------|
| 0 | #FF66A3 | brandPink |
| 1 | #00D2FF | neonTeal |
| 2 | #FFD166 | gold |
| 3 | #A78BFA | violet |
| 4 | #34D399 | emerald |
| 5 | #F87171 | rose |
| 6 | #60A5FA | sky |
| 7 | #FB923C | amber |

The `Chapter` Dart model now has `final String? chapterColor` with constructor param, `fromJson` parsing `metadata['chapter_color']`, and `toJson` serialization.

## Verification Results

- `flutter analyze lib/widgets/reader/reader_app_bar.dart lib/models/chapter.dart` — No issues found
- `reader_app_bar.dart` contains `floating: false`, no `snap: true`, no `floating: true`
- `chapter.dart` contains `final String? chapterColor`, `chapterColor: metadata['chapter_color']`, `'chapter_color': chapterColor`
- `book.json` contains exactly 80 occurrences of `"chapter_color"`
- Existing `test/models/book_test.dart` — All 2 tests passed

## Deviations from Plan

**1. [Rule 3 - Path] book.json resolved to worktree root, not enchiridion/ subdirectory**
- **Found during:** Task 2
- **Issue:** Plan referenced `enchiridion/assets/data/book.json` but the git repo structure has Flutter files at the worktree root (`lib/`, `pubspec.yaml`). The `assets/` directory was absent from the worktree.
- **Fix:** Created `assets/data/book.json` at the worktree root (matching `pubspec.yaml` asset reference). Sourced original book.json from the untracked `enchiridion/` directory in the parent repo.
- **Files created:** `assets/data/book.json`
- **Commit:** dc00373

No other deviations. Plan executed as designed.

## Known Stubs

None — all fields fully wired.

## Threat Flags

None — book.json is a static read-only asset bundled in the APK, no new network endpoints or trust boundaries introduced.

## Self-Check: PASSED

- [x] `lib/widgets/reader/reader_app_bar.dart` — exists and contains `floating: false`
- [x] `lib/models/chapter.dart` — exists and contains `chapterColor` field
- [x] `assets/data/book.json` — exists with 80 `chapter_color` entries
- [x] Commit 08cdaa5 — exists (Task 1)
- [x] Commit dc00373 — exists (Task 2)
