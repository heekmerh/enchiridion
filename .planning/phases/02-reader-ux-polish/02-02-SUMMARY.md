---
phase: 02-reader-ux-polish
plan: "02"
subsystem: reader-ui
tags: [table-layout, fixed-column-width, tdd, overflow-fix]
dependency_graph:
  requires:
    - 02-01 (chapterColor field in Chapter model)
  provides:
    - fixed-column-width-tables
    - header-tint-color-parameter
  affects:
    - block_renderer.dart (_AgeReferenceWidget)
    - table_block.dart (TableBlockWidget)
tech_stack:
  added: []
  patterns:
    - FixedColumnWidth(screenWidth - 48 / colCount) for equal-width table columns
    - Color? headerTintColor optional parameter for chapter-color tinting
    - TableRow.decoration inspection in widget tests (not DecoratedBox widget tree)
key_files:
  created:
    - test/widgets/table_block_test.dart
    - assets/icon/logo.png (stub)
    - assets/books/*.png/*.jpeg (stubs)
    - assets/background/bg*.png (stubs)
    - assets/resources/.gitkeep
  modified:
    - lib/widgets/blocks/table_block.dart
    - lib/widgets/blocks/block_renderer.dart
decisions:
  - "FixedColumnWidth formula: (screenWidth - 48) / colCount; 48px accounts for ReaderContent horizontal padding"
  - "headerTintColor alpha: 0.15 in light mode, 0.25 in dark mode for readable header tint"
  - "Test 3/4 inspect TableRow.decoration directly — Flutter does not expose TableRow decoration as DecoratedBox in widget tree"
  - "Stub asset files created to unblock flutter test (pubspec.yaml referenced missing assets)"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-23"
  tasks_completed: 2
  tasks_total: 2
  files_created: 16
  files_modified: 3
---

# Phase 2 Plan 02: Table Overflow Fix Summary

**One-liner:** Replaced SingleChildScrollView+IntrinsicColumnWidth with FixedColumnWidth in both TableBlockWidget and _AgeReferenceWidget, adding Color? headerTintColor to TableBlockWidget for chapter-color header tinting; 4 widget tests pass.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create table widget tests (RED) | 32baae3 | test/widgets/table_block_test.dart, lib/widgets/blocks/table_block.dart (stub field), assets/* |
| 2 | Fix TableBlockWidget and _AgeReferenceWidget (GREEN) | 697f2a0 | lib/widgets/blocks/table_block.dart, lib/widgets/blocks/block_renderer.dart, test/widgets/table_block_test.dart |

## What Was Built

### Task 1 — Failing widget tests (RED)

Created `test/widgets/table_block_test.dart` with 4 behavior tests:

1. No horizontal `SingleChildScrollView` in `TableBlockWidget` tree
2. 3-column table on 375px screen assigns each column `(375-48)/3 ≈ 109px` via `FixedColumnWidth`
3. `headerTintColor: Colors.red` causes header `TableRow` to have a red-tinted background
4. `headerTintColor: null` does not use full-opacity brandPink `#FF66A3`

Added `headerTintColor` field declaration stub to `TableBlockWidget` so the test file compiles — required for RED state (failures at runtime, not compile time).

Also added stub PNG/JPEG asset files (`assets/icon/logo.png`, book covers, backgrounds) to unblock `flutter test` which failed with "No file or variants found for asset" errors.

### Task 2 — Implementation (GREEN)

**`lib/widgets/blocks/table_block.dart`:**
- Added `final Color? headerTintColor` field and constructor parameter
- Replaced `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Table(defaultColumnWidth: IntrinsicColumnWidth()))` with `Table(columnWidths: { for i in colCount: i: FixedColumnWidth(colWidth) })`
- `colWidth = (MediaQuery.of(context).size.width - 48) / colCount`
- `headerColor` derived from `headerTintColor` (alpha 0.15 light / 0.25 dark) or fallback (`inkCharcoal` dark / `brandPink.withValues(alpha: 0.08)` light)

**`lib/widgets/blocks/block_renderer.dart` (`_AgeReferenceWidget`):**
- Replaced `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Table(defaultColumnWidth: IntrinsicColumnWidth()))` with `Table(columnWidths: { for i in colCount: i: FixedColumnWidth(colWidth) })`
- `colCount = 1 + block.rows.first.keys.where((k) => k != 'age').length` (age column + value columns)
- No `headerTintColor` parameter added (age reference tables use hardcoded brandPink fallback per plan spec)

**Test corrections:** Tests 3 and 4 updated to inspect `TableRow.decoration` directly on the `Table` widget's `children` list, rather than searching for `DecoratedBox` in the widget tree (Flutter applies `TableRow.decoration` at the render level, not as a discoverable widget node).

## Verification Results

- `flutter test test/widgets/table_block_test.dart` — 4/4 tests pass
- `flutter analyze lib/widgets/blocks/` — No issues found
- `table_block.dart` contains `FixedColumnWidth` (1 match), `headerTintColor` (5 matches)
- `table_block.dart` contains NO `SingleChildScrollView` (0 matches)
- `block_renderer.dart` `_AgeReferenceWidget` section contains `FixedColumnWidth`, NO `SingleChildScrollView`

## TDD Gate Compliance

- RED gate: `test(02-02)` commit `32baae3` — 3 tests failing (compile succeeded, runtime failures confirmed)
- GREEN gate: `feat(02-02)` commit `697f2a0` — all 4 tests passing

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stub asset files created to unblock flutter test**
- **Found during:** Task 1
- **Issue:** `pubspec.yaml` references `assets/icon/logo.png`, book cover images, and background images that did not exist in the worktree. `flutter test` failed with "No file or variants found for asset" before any compilation occurred.
- **Fix:** Created minimal 1x1 valid PNG stub files for all 14 missing image assets and an `assets/resources/.gitkeep` for the directory entry. Assets are inert (not displayed in tests) but satisfy Flutter's asset bundling requirement.
- **Files created:** `assets/icon/logo.png`, `assets/books/[8 files]`, `assets/background/[5 files]`, `assets/resources/.gitkeep`
- **Commit:** 32baae3 (included in Task 1 commit)

**2. [Rule 1 - Bug] Test 3/4 approach corrected: TableRow.decoration not exposed as DecoratedBox**
- **Found during:** Task 2 (GREEN phase)
- **Issue:** The original Test 3 and Test 4 searched for `DecoratedBox` widgets as descendants of `Table` to find the header row background color. Flutter applies `TableRow.decoration` at the render/paint level — no `DecoratedBox` widget is inserted into the widget tree for TableRow decoration.
- **Fix:** Changed both tests to inspect `table.children` (the `List<TableRow>`) and read `row.decoration` directly. This is the correct approach for verifying `TableRow` decoration in Flutter widget tests.
- **Files modified:** `test/widgets/table_block_test.dart`
- **Commit:** 697f2a0

## Known Stubs

The asset stub files (PNG images) do not affect app functionality — they are never rendered in the app code being tested. Real asset files will need to be restored from the source `enchiridion/` directory when the worktree is merged. These stubs are test-infrastructure only.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. Table layout changes are purely presentational.

## Self-Check: PASSED

- [x] `test/widgets/table_block_test.dart` — exists and all 4 tests pass
- [x] `lib/widgets/blocks/table_block.dart` — contains `FixedColumnWidth`, `headerTintColor`, no `SingleChildScrollView`
- [x] `lib/widgets/blocks/block_renderer.dart` — `_AgeReferenceWidget` contains `FixedColumnWidth`, no `SingleChildScrollView`
- [x] Commit 32baae3 — exists (Task 1 RED)
- [x] Commit 697f2a0 — exists (Task 2 GREEN)
