---
phase: 02-reader-ux-polish
plan: "05"
subsystem: toc-drawer
tags: [toc, expansion-tile, navigation, scroll-to-anchor, active-section, chapter-color]
dependency_graph:
  requires:
    - 02-04 (reader_screen.dart _currentSectionId, _sectionKeys, _subsectionKeys from BlockRenderer callbacks)
    - 02-03 (BlockRenderer StatefulWidget with GlobalKey maps and onKeysReady/onOffsetsReady)
  provides:
    - toc-expansion-tile-tree
    - navigate-to-section-scroll
    - active-subsection-highlighting
    - table-header-chapter-color
  affects:
    - lib/widgets/drawer/toc_drawer.dart (ExpansionTile tree, new props, removed _ChapterItem)
    - lib/screens/reader_screen.dart (_navigateToSection, _drawerOpenCount, updated call site)
    - lib/widgets/blocks/block_renderer.dart (headerTintColor wired from chapter.chapterColor)
    - test/widgets/toc_drawer_test.dart (4 new widget tests)
tech_stack:
  added: []
  patterns:
    - ExpansionTile with onExpansionChanged for chapter navigation + tree expansion
    - Set<String> _expandedChapters for controlled expansion state
    - ValueKey(_drawerOpenCount) to reset expansion state on drawer open (D-08)
    - Scrollable.ensureVisible for scroll-to-anchor navigation
    - Color.parse from chapter.chapterColor hex string for TableBlockWidget headerTintColor
key_files:
  created:
    - test/widgets/toc_drawer_test.dart
  modified:
    - lib/widgets/drawer/toc_drawer.dart
    - lib/screens/reader_screen.dart
    - lib/widgets/blocks/block_renderer.dart
decisions:
  - "Chapter tap triggers both onChapterSelected navigation AND ExpansionTile expansion via onExpansionChanged (not GestureDetector in title — GestureDetector absorbs taps and prevents ExpansionTile expansion)"
  - "D-08 collapse-on-open implemented via ValueKey(_drawerOpenCount) on TocDrawerContent, forcing Flutter to destroy and recreate the StatefulWidget on each drawer open"
  - "Section-level ExpansionTile uses onExpansionChanged: (_) {} (no-op) — section navigation happens via subsection ListTile taps"
  - "Pre-existing lib/ analyze errors in library_screen.dart and login_screen.dart are out-of-scope worktree gaps; only changed files analyze clean"
metrics:
  duration: "~25 minutes"
  completed: "2026-05-23"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 3
---

# Phase 2 Plan 05: TOC Tree + Active-Section Navigation Summary

**One-liner:** Replaced flat _ChapterItem list in TocDrawerContent with a 3-level ExpansionTile tree (chapter/section/subsection); added _navigateToSection using Scrollable.ensureVisible; active subsection highlighted in neonTeal; table headers now use chapter color via headerTintColor.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write TOC drawer widget tests (RED + prop stubs) | b21ae9f | test/widgets/toc_drawer_test.dart, lib/widgets/drawer/toc_drawer.dart, lib/screens/reader_screen.dart |
| 2 | Implement TOC tree + _navigateToSection + headerTintColor (GREEN) | 1cd6582 | lib/widgets/drawer/toc_drawer.dart, lib/screens/reader_screen.dart, lib/widgets/blocks/block_renderer.dart, test/widgets/toc_drawer_test.dart |

## What Was Built

### Task 1 — RED test stubs

**`test/widgets/toc_drawer_test.dart`:**

- REQ-2.3a: Asserts `ExpansionTile` renders for each chapter
- REQ-2.3b: Asserts subsection hidden initially; visible after expanding chapter + section
- REQ-2.3c: Asserts tapping subsection ListTile fires `onSectionSelected(sectionId, subsectionId)`
- REQ-2.3d: Asserts active subsection (currentSectionId match) has `AppColors.neonTeal` text color

Added stub props (`currentSectionId`, `onSectionSelected`) to `TocDrawerContent` so the test compiles. Added stub call site update to `reader_screen.dart`.

### Task 2 — GREEN implementation

**`lib/widgets/drawer/toc_drawer.dart`:**

- New props: `currentSectionId: String?` and `onSectionSelected: Function(String, String)`
- New state: `final Set<String> _expandedChapters = {}`
- Chapter list section replaced with `ExpansionTile` per chapter; `onExpansionChanged` calls both `onChapterSelected` and updates `_expandedChapters`
- Each chapter's children: section-level `ExpansionTile` nodes; each section's children: subsection `ListTile` nodes
- Subsection `ListTile.onTap` calls `onSectionSelected(section.id, sub.id)`
- Active subsection (id == currentSectionId) uses `AppColors.neonTeal` color and `FontWeight.w600`
- Removed `_ChapterItem` class entirely

**`lib/screens/reader_screen.dart`:**

- Added `int _drawerOpenCount = 0` field
- Menu open button increments `_drawerOpenCount` when `_isMenuOpen` becomes true
- `TocDrawerContent` wrapped with `key: ValueKey(_drawerOpenCount)` for D-08 reset
- Added `_navigateToSection(sectionId, subsectionId)`: closes drawer, tries `_subsectionKeys[subsectionId]` then `_sectionKeys[sectionId]`, calls `Scrollable.ensureVisible` on the found context
- Updated call site: `onSectionSelected: _navigateToSection`, `currentSectionId: _currentSectionId`
- Removed `// ignore: unused_field` comments (fields now consumed by `_navigateToSection`)

**`lib/widgets/blocks/block_renderer.dart`:**

- Added `_chapterHeaderTintColor()` helper in `_ChapterView`: parses `chapter.chapterColor` hex string (e.g., `#FF66A3`) to `Color`; returns null on parse failure or null chapterColor
- `TableBlockWidget` call in `_buildBlock` now passes `headerTintColor: _chapterHeaderTintColor()`

## Verification Results

- `flutter test test/widgets/toc_drawer_test.dart` — 4/4 tests pass (GREEN)
- `flutter test` — 10/10 tests pass (full suite)
- `flutter analyze lib/widgets/drawer/toc_drawer.dart lib/screens/reader_screen.dart lib/widgets/blocks/block_renderer.dart` — No issues found
- `toc_drawer.dart`: contains `ExpansionTile`, `onSectionSelected`, `currentSectionId`, `_expandedChapters`
- `toc_drawer.dart`: does NOT contain `_ChapterItem`
- `reader_screen.dart`: contains `_navigateToSection`, `Scrollable.ensureVisible`, `onSectionSelected: _navigateToSection`, `currentSectionId: _currentSectionId`, `_drawerOpenCount`, `ValueKey(_drawerOpenCount)`
- `block_renderer.dart`: contains `headerTintColor` at TableBlockWidget instantiation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] GestureDetector in ExpansionTile title absorbs taps preventing expansion**
- **Found during:** Task 2 — tests REQ-2.3b/c/d failed with "Section One" not found after tapping chapter
- **Issue:** The plan spec suggested wrapping the chapter title Text in a GestureDetector to call `onChapterSelected`. But GestureDetector absorbs all tap events, preventing `ExpansionTile` from receiving the tap and expanding its children.
- **Fix:** Moved both `onChapterSelected` call and `_expandedChapters` state update into `onExpansionChanged` callback. `ExpansionTile` now naturally expands on tap AND triggers chapter navigation simultaneously.
- **Files modified:** lib/widgets/drawer/toc_drawer.dart
- **Commit:** 1cd6582

**2. [Rule 2 - Missing] Test `ensureVisible` needed for off-screen expanded children**
- **Found during:** Task 2 — test taps on "Section One" failed because the section was inside an expanded tile that rendered outside the default test viewport
- **Fix:** Added `tester.ensureVisible(finder)` calls in tests 2/3/4 before tapping expanded children
- **Files modified:** test/widgets/toc_drawer_test.dart
- **Commit:** 1cd6582

## Known Stubs

None — all plan features are fully implemented and wired.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Changes are widget-state, scroll navigation, and color parsing (from bundled chapter metadata) only.

## Self-Check: PASSED

- [x] `lib/widgets/drawer/toc_drawer.dart` — exists, contains ExpansionTile, onSectionSelected, currentSectionId, _expandedChapters
- [x] `lib/widgets/drawer/toc_drawer.dart` — does NOT contain `_ChapterItem`
- [x] `lib/screens/reader_screen.dart` — contains _navigateToSection, Scrollable.ensureVisible, _drawerOpenCount, ValueKey(_drawerOpenCount)
- [x] `lib/widgets/blocks/block_renderer.dart` — contains headerTintColor at TableBlockWidget call
- [x] `test/widgets/toc_drawer_test.dart` — 4 testWidgets calls, all pass
- [x] `flutter test` — 10/10 pass
- [x] Commit b21ae9f — Task 1 (RED tests + prop stubs)
- [x] Commit 1cd6582 — Task 2 (full implementation GREEN)
