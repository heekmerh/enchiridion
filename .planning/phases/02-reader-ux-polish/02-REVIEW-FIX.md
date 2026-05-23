---
phase: 02-reader-ux-polish
fixed_at: 2026-05-23T08:45:00Z
review_path: .planning/phases/02-reader-ux-polish/02-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 11
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-05-23T08:45:00Z
**Source review:** .planning/phases/02-reader-ux-polish/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (CR-01 through CR-04, WR-01 through WR-07)
- Fixed: 11
- Skipped: 0

## Fixed Issues

### CR-01: Active-section offset uses viewport coordinates, not scroll offsets

**Files modified:** `lib/widgets/blocks/block_renderer.dart`
**Commit:** ab2e172
**Applied fix:** Replaced bare `box.localToGlobal(Offset.zero).dy` with `box.localToGlobal(Offset.zero, ancestor: scrollRenderObject)` where `scrollRenderObject` is resolved via `Scrollable.maybeOf(context)`. Stored offsets are now relative to the scroll viewport origin and remain stable across all scroll positions.

---

### CR-02: Null-safety crash: `currentChapter!` and `currentChapterId!`

**Files modified:** `lib/screens/reader_screen.dart`
**Commit:** 4361289
**Applied fix:** Extracted `bookProvider.currentChapter` and `bookProvider.currentChapterId` as nullable locals; added an early-return loading indicator when either is null. Replaced all three remaining `bookProvider.currentChapterId!` call sites with the non-nullable local `chapterId`.

---

### CR-03: TOC `onExpansionChanged` always navigates on both expand and collapse

**Files modified:** `lib/widgets/drawer/toc_drawer.dart`
**Commit:** 7b6cb9f
**Applied fix:** Added `if (expanded)` guard around `widget.onChapterSelected(chapter.id)` so navigation only fires when a tile is expanded (opened), not when it is collapsed.

---

### CR-04: `_LockedChapterOverlay` spawns duplicate `GlobalKey` via second `ReaderContent`

**Files modified:** `lib/screens/reader_screen.dart`
**Commit:** 386ffe9
**Applied fix:** Replaced the `IgnorePointer > ReaderContent(...)` in the locked overlay with a plain `IgnorePointer > Container(color: theme.colorScheme.surface)`. This eliminates the second `BlockRenderer` instance that was registering duplicate GlobalKeys for the same chapter's section anchors.

---

### WR-01: `ScrollController` listener never removed in `dispose`

**Files modified:** `lib/screens/reader_screen.dart`
**Commit:** 885f32a
**Applied fix:** Added `_scrollController.removeListener(_onScroll)` as the first line of `dispose()`, before `_scrollController.dispose()`.

---

### WR-02: Stale `_sectionOffsets` not cleared when chapter changes

**Files modified:** `lib/screens/reader_screen.dart`
**Commit:** 624485e
**Applied fix:** Added `_sectionOffsets = {}` and `_currentSectionId = null` to the `setState` call inside `_navigateToChapter` so stale offsets and the active-section highlight are cleared immediately when chapter navigation begins.

---

### WR-03: Table column widths ignore parent padding (hardcoded 48px)

**Files modified:** `lib/widgets/blocks/table_block.dart`, `test/widgets/table_block_test.dart`
**Commit:** 2b9cf8c (source), 841ddac (test)
**Applied fix:** Wrapped `TableBlockWidget.build` in a `LayoutBuilder` so `colWidth = constraints.maxWidth / colCount` uses the actual available layout width instead of `MediaQuery.size.width - 48`. The corresponding test was updated to assert equal positive widths across columns rather than a specific pixel value tied to the old MediaQuery heuristic.

---

### WR-04: TOC section `ExpansionTile.onExpansionChanged` is a no-op

**Files modified:** `lib/widgets/drawer/toc_drawer.dart`
**Commit:** fcc9f06
**Applied fix:** Removed the dead `onExpansionChanged: (_) {}` callback from section-level `ExpansionTile` widgets. The tile manages its own expansion state internally; the no-op callback was misleading dead code.

---

### WR-05: `DraggableScrollableSheet` double-applies keyboard insets

**Files modified:** `lib/screens/reader_screen.dart`, `lib/widgets/blocks/block_renderer.dart`
**Commit:** a16f745 (plus follow-up brace fix 26955fe)
**Applied fix:** Removed the outer `Padding(EdgeInsets.only(bottom: viewInsets.bottom))` wrapper from both `_NotesBottomSheet` and `_ClipsBottomSheet`. Moved keyboard inset handling inside the sheet builder's own padding. Also fixed a stray closing `)` in `_NotesBottomSheet` that was left from the refactor.

---

### WR-06: `_showControls` field is effectively dead state

**Files modified:** `lib/screens/reader_screen.dart`
**Commit:** 7c305e1
**Applied fix:** Removed the `_showControls` field declaration and all `_showControls = true` assignments. Replaced the `if (_showControls) Positioned(AnimatedOpacity(...))` construct with a plain unconditional `Positioned(child: ReaderProgressBar(...))`.

---

### WR-07: `_AgeReferenceWidget` column count derived from first row only; hardcoded 48px

**Files modified:** `lib/widgets/blocks/block_renderer.dart`
**Commit:** 6132d6e
**Applied fix:** Replaced `block.rows.first.keys` with `block.rows.expand((r) => r.keys).toSet()` to derive `colCount` from the union of all row keys, preventing mismatches when `block.rows` is empty or rows have varying key sets. Also wrapped the widget in `LayoutBuilder` to use `constraints.maxWidth` instead of `MediaQuery.size.width - 48`.

---

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-05-23T08:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
