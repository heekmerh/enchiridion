---
phase: 02-reader-ux-polish
plan: "03"
subsystem: reader-ui
tags: [stateful-widget, global-keys, scroll-anchors, callback-wiring]
dependency_graph:
  requires:
    - 02-01 (Chapter model with section/subsection IDs)
    - 02-02 (block_renderer.dart _AgeReferenceWidget FixedColumnWidth)
  provides:
    - stable-global-keys-on-section-headers
    - stable-global-keys-on-subsection-headers
    - offset-ready-callback-infrastructure
    - keys-ready-callback-infrastructure
  affects:
    - block_renderer.dart (BlockRenderer class, _ChapterView, _SectionHeader, _SubsectionHeader)
    - reader_content.dart (ReaderContent)
tech_stack:
  added: []
  patterns:
    - GlobalKey maps built in initState/_buildKeys, never in build()
    - addPostFrameCallback for post-layout offset measurement
    - didUpdateWidget with chapter.id comparison for chapter-change key rebuild
    - Nullable callback parameters for backward-compatible API extension
key_files:
  created: []
  modified:
    - lib/widgets/blocks/block_renderer.dart
    - lib/widgets/reader/reader_content.dart
decisions:
  - "GlobalKeys passed as key: parameter directly to _SectionHeader and _SubsectionHeader widgets (StatelessWidget key: param) rather than wrapping with KeyedSubtree — simpler and equivalent"
  - "RenderBox null-check and hasSize guard in _calculateOffsets to prevent crashes during rapid chapter switches"
  - "reader_screen.dart does not exist in this codebase; plan acceptance criteria adjusted to analyze reader_content.dart only"
metrics:
  duration: "~3 minutes"
  completed: "2026-05-23"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 2 Plan 03: BlockRenderer StatefulWidget Anchor Infrastructure Summary

**One-liner:** Converted BlockRenderer to StatefulWidget with stable GlobalKey maps built in initState; offset measurement fires via addPostFrameCallback; ReaderContent forwards both callbacks to BlockRenderer as optional parameters.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Convert BlockRenderer to StatefulWidget with GlobalKey map | d74f805 | lib/widgets/blocks/block_renderer.dart |
| 2 | Wire callbacks through ReaderContent | d3c7d29 | lib/widgets/reader/reader_content.dart |

## What Was Built

### Task 1 — BlockRenderer StatefulWidget conversion

**`lib/widgets/blocks/block_renderer.dart`:**

- `class BlockRenderer extends StatefulWidget` with two new optional callbacks:
  - `onKeysReady: void Function(Map<String, GlobalKey> sectionKeys, Map<String, GlobalKey> subsectionKeys)?`
  - `onOffsetsReady: void Function(Map<String, double> offsets)?`
- `_BlockRendererState` with `Map<String, GlobalKey> _sectionKeys` and `Map<String, GlobalKey> _subsectionKeys` fields
- `_buildKeys()`: clears both maps, iterates `widget.chapter.sections` building one key per section and one per subsection, then calls `onKeysReady`
- `initState()`: calls `_buildKeys()` then schedules `_calculateOffsets()` via `addPostFrameCallback`
- `didUpdateWidget()`: detects chapter change via `old.chapter.id != widget.chapter.id`, rebuilds keys and reschedules offset calculation
- `_calculateOffsets()`: measures each keyed widget's global Y position via `RenderBox.localToGlobal`, guards against null context and box, calls `onOffsetsReady`
- `_ChapterView` extended with `sectionKeys` and `subsectionKeys` parameters; keys passed as `key:` parameter to `_SectionHeader` and `_SubsectionHeader` widgets (both updated to accept `super.key`)
- No `GlobalKey()` creation inside any `build()` method

### Task 2 — ReaderContent callback plumbing

**`lib/widgets/reader/reader_content.dart`:**

- Added `onKeysReady` and `onOffsetsReady` optional nullable parameters to `ReaderContent`
- Updated `BlockRenderer(...)` instantiation in `build()` to forward both callbacks
- Existing callers without these parameters continue to compile and run (both are optional/null-default)

## Verification Results

- `flutter analyze lib/widgets/blocks/block_renderer.dart` — No issues found
- `flutter analyze lib/widgets/reader/reader_content.dart` — No issues found
- `flutter analyze lib/widgets/blocks/block_renderer.dart lib/widgets/reader/reader_content.dart` — No issues found
- `flutter test` — 4/4 tests pass (table_block_test.dart from plan 02-02)
- `block_renderer.dart` contains `StatefulWidget`, `Map<String, GlobalKey>`, `initState`, `addPostFrameCallback`, `didUpdateWidget`
- `block_renderer.dart` does NOT contain `GlobalKey()` inside any `build(` method
- `reader_content.dart` contains `onKeysReady`, `onOffsetsReady`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Implementation Detail] Direct key: parameter instead of KeyedSubtree wrapper**
- **Found during:** Task 1
- **Issue:** The plan spec said "wrap the existing Padding widget with `KeyedSubtree(key: anchorKey, child: ...)` when anchorKey is non-null, or pass the key directly to the Padding widget". Since `_SectionHeader` and `_SubsectionHeader` are `StatelessWidget` subclasses, passing the GlobalKey as `super.key` (the widget's own key) is equivalent and cleaner — no `KeyedSubtree` wrapper needed.
- **Fix:** Added `super.key` to both `_SectionHeader` and `_SubsectionHeader` constructors; caller passes `key: sectionKeys[section.id]` directly in `_ChapterView.build()`.
- **Files modified:** lib/widgets/blocks/block_renderer.dart
- **Commit:** d74f805

**2. [Rule 3 - Missing file] reader_screen.dart does not exist in this codebase**
- **Found during:** Task 2 verification
- **Issue:** The plan's `<verify>` step includes `flutter analyze lib/screens/reader_screen.dart`. That file does not exist in the worktree. The reader shell is structured differently from what the plan anticipated.
- **Fix:** Ran `flutter analyze lib/widgets/reader/reader_content.dart` (the file that was actually modified) — no issues found. ReaderContent is not yet used by any screen in this worktree, so backward compatibility could not break any callers.
- **Impact:** None — the analyze check confirms the changed file is clean.

## Known Stubs

None — all callbacks in BlockRenderer and ReaderContent are properly typed and wired. No hardcoded values or placeholder data.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Changes are purely widget-tree infrastructure (GlobalKey management and callback delegation).

## Self-Check: PASSED

- [x] `lib/widgets/blocks/block_renderer.dart` — contains `StatefulWidget`, `Map<String, GlobalKey>`, `initState`, `addPostFrameCallback`, `didUpdateWidget`, `onKeysReady`, `onOffsetsReady`
- [x] `lib/widgets/blocks/block_renderer.dart` — no `GlobalKey()` inside any `build(` method
- [x] `lib/widgets/reader/reader_content.dart` — contains `onKeysReady`, `onOffsetsReady`, forwards to BlockRenderer
- [x] Commit d74f805 — exists (Task 1)
- [x] Commit d3c7d29 — exists (Task 2)
- [x] `flutter test` — 4/4 pass
