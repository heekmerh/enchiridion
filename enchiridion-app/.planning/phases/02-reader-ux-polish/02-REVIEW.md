---
phase: 02-reader-ux-polish
reviewed: 2026-05-23T07:53:18Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - lib/models/chapter.dart
  - lib/screens/reader_screen.dart
  - lib/screens/unlock_screen.dart
  - lib/widgets/blocks/block_renderer.dart
  - lib/widgets/blocks/table_block.dart
  - lib/widgets/drawer/toc_drawer.dart
  - lib/widgets/reader/reader_app_bar.dart
  - lib/widgets/reader/reader_content.dart
  - test/screens/reader_screen_test.dart
  - test/widgets/table_block_test.dart
  - test/widgets/toc_drawer_test.dart
findings:
  critical: 4
  warning: 7
  info: 4
  total: 15
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-23T07:53:18Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed 11 Flutter/Dart source files from Phase 2 (Reader UX Polish). The
phase goal was: fix table overflow, keep the app bar always visible, add a TOC
tree with jump-to navigation, and add active-section highlighting.

The UX features are present and the architecture is reasonable. However, four
critical defects were found: (1) the active-section offset calculation uses raw
`localToGlobal` viewport coordinates instead of scroll offsets, making the
entire jump-to and highlighting system unreliable after any scroll; (2) tables
and the `_AgeReferenceWidget` overflow or break on narrow screens and wide
content because column widths are computed from `MediaQuery` but applied as
fixed widths that do not account for padding already consumed by parent
widgets; (3) a null-safety crash on `bookProvider.currentChapter!` and
`bookProvider.currentChapterId!` is reachable if the provider reports
`BookStatus.loaded` while either field is somehow null; and (4) the TOC
`ExpansionTile` always fires `onChapterSelected` on both expand AND collapse,
meaning collapsing a chapter tile navigates away from the current chapter.

Seven warnings cover: a missing `_scrollController.removeListener` in
`dispose`; stale `_sectionOffsets` not being cleared on chapter change; the
`_LockedChapterOverlay` spawning a second headless `ReaderContent` whose
`BlockRenderer` will fire `onOffsetsReady` and overwrite the live offsets map;
the `_ReaderShellState._showControls` field being set but never read to guard
anything meaningful; a dead `_chapterHeaderTintColor` method called only from
one hot path but not the equivalent `_AgeReferenceWidget`; the TOC section
`ExpansionTile` ignoring its `onExpansionChanged` callback (always `(_) {}`),
preventing section-level tree expansion from working at all without a tap; and
`DraggableScrollableSheet` being wrapped in a `Padding(viewInsets)` outside
the sheet, which double-applies insets when the keyboard is open.

---

## Critical Issues

### CR-01: Active-section offset uses viewport coordinates, not scroll offsets

**File:** `lib/widgets/blocks/block_renderer.dart:77`

**Issue:** `_calculateOffsets` calls `box.localToGlobal(Offset.zero).dy` to
record each section's position. `localToGlobal` returns the widget's
**current on-screen pixel position**, not its offset within the scrollable
content. As a result:

- On first load (scroll position = 0) the values are roughly correct.
- After the user scrolls, the stored offsets become stale — they still reflect
  the initial viewport positions. The section that "should" be active
  according to `_updateActiveSection` in `reader_screen.dart` is therefore
  wrong for any scroll position except 0.
- Jump-to navigation (`Scrollable.ensureVisible`) is unaffected, but the
  active-section highlight in the TOC will be incorrect as soon as the user
  scrolls.

The root cause is that `localToGlobal` is viewport-relative.
`RenderBox.localToGlobal` must be converted to scroll-relative by subtracting
the `ScrollController.offset` at measurement time, or the measurement must
walk `RenderObject.getTransformTo(null)` relative to the scroll viewport
ancestor.

**Fix:**
```dart
// In _calculateOffsets(), capture the scroll baseline at measurement time
// and store positions relative to the content start, not the viewport.

void _calculateOffsets() {
  // Find the enclosing Scrollable's render object as the reference frame.
  final scrollable = Scrollable.of(context);
  final scrollRenderObject = scrollable.context.findRenderObject();

  final offsets = <String, double>{};
  for (final entry in _sectionKeys.entries) {
    final ctx = entry.value.currentContext;
    if (ctx == null) continue;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) continue;
    // Convert position relative to the scroll viewport instead of the screen.
    final localPos = box.localToGlobal(
      Offset.zero,
      ancestor: scrollRenderObject as RenderObject?,
    );
    offsets[entry.key] = localPos.dy;
  }
  // ... same for subsectionKeys
  widget.onOffsetsReady?.call(offsets);
}
```

Additionally, `_ReaderShellState._updateActiveSection` must add the current
`_scrollController.offset` when comparing, because the stored offsets are now
relative to the viewport top of the scroll area (dy = 0 at content start):

```dart
void _updateActiveSection() {
  if (_sectionOffsets.isEmpty) return;
  final scrollOffset =
      _scrollController.hasClients ? _scrollController.offset : 0.0;
  String? activeId;
  double bestOffset = double.negativeInfinity;
  for (final entry in _sectionOffsets.entries) {
    // entry.value is now content-relative; compare directly against scrollOffset
    if (entry.value <= scrollOffset + 100 && entry.value > bestOffset) {
      bestOffset = entry.value;
      activeId = entry.key;
    }
  }
  if (activeId != _currentSectionId) {
    setState(() => _currentSectionId = activeId);
  }
}
```

---

### CR-02: Null-safety crash: `currentChapter!` and `currentChapterId!` called after status check

**File:** `lib/screens/reader_screen.dart:193-209`

**Issue:**
```dart
final chapter = bookProvider.currentChapter!;   // line 193 — force-unwrap
// ...
currentChapterId: bookProvider.currentChapterId!,   // line 209
```
The code falls through to this point only when
`bookProvider.status != loading && bookProvider.status != error`. If the
provider ever has a third status (e.g. `BookStatus.initial` or any future
state) where `currentChapter` is `null`, both force-unwraps crash with a
`Null check operator used on a null value` exception at runtime with no
user-visible recovery.

Even within the current two-path logic the `!` is unsafe: if `status ==
BookStatus.loaded` but `currentChapter` is `null` due to a bug in
`BookProvider.navigateToChapter`, the crash is uncatchable.

**Fix:**
```dart
final chapter = bookProvider.currentChapter;
final chapterId = bookProvider.currentChapterId;

if (chapter == null || chapterId == null) {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
// Use chapter and chapterId (non-nullable) below.
```

---

### CR-03: TOC `onExpansionChanged` always navigates — collapse triggers unwanted chapter navigation

**File:** `lib/widgets/drawer/toc_drawer.dart:218-229`

**Issue:** The chapter `ExpansionTile.onExpansionChanged` unconditionally calls
`widget.onChapterSelected(chapter.id)` on both `expanded == true` and
`expanded == false`:

```dart
onExpansionChanged: (expanded) {
  widget.onChapterSelected(chapter.id);   // fires on collapse too
  setState(() {
    if (expanded) {
      _expandedChapters.add(chapter.id);
    } else {
      _expandedChapters.remove(chapter.id);
    }
  });
},
```

Collapsing a chapter tile navigates the reader to that chapter even if the
user is already reading it (redundant scroll-to-top) or is trying to collapse
a different chapter (navigates away unintentionally). This also means every
tree node tap fires two chapter navigations if two chapters are expanded.

**Fix:** Only navigate on expand (tap to open), not on collapse:
```dart
onExpansionChanged: (expanded) {
  if (expanded) {
    widget.onChapterSelected(chapter.id);
  }
  setState(() {
    if (expanded) {
      _expandedChapters.add(chapter.id);
    } else {
      _expandedChapters.remove(chapter.id);
    }
  });
},
```

---

### CR-04: `_LockedChapterOverlay` spawns a second live `ReaderContent` that overwrites scroll offsets

**File:** `lib/screens/reader_screen.dart:535`

**Issue:** The locked-chapter overlay renders a full `ReaderContent` (with
no `bookId` and no callbacks) as a blurred background:

```dart
IgnorePointer(
  child: ReaderContent(chapter: chapter, bookId: bookId),
),
```

`ReaderContent` instantiates `BlockRenderer`, which in `initState` calls
`_buildKeys()` and schedules `_calculateOffsets()` via
`WidgetsBinding.instance.addPostFrameCallback`. Because `onKeysReady` and
`onOffsetsReady` are `null` here, the keys are not clobbered — but
`BlockRenderer` still allocates independent `GlobalKey` objects for every
section. Since `GlobalKey`s must be unique across the widget tree, having two
`BlockRenderer` instances for the same chapter will throw a duplicate
`GlobalKey` exception at runtime if the chapter's section keys from the live
`ReaderContent` are already registered.

In practice this crashes as soon as a locked chapter is displayed if the live
`ReaderContent` is also in the tree (it is — `SliverToBoxAdapter` renders one
of the two). The locked overlay takes the `_LockedChapterOverlay` path but it
still calls `ReaderContent(chapter: chapter, bookId: bookId)` which triggers
`BlockRenderer._buildKeys()` and registers the same `GlobalKey` values already
held by the outer `ReaderContent`'s `BlockRenderer` (if the user navigated
back to a free chapter then a locked one). Even where keys don't clash, it
wastes layout budget building an invisible full-content tree.

**Fix:** Strip `BlockRenderer`/`ReaderContent` from the locked overlay
background. Use a simpler placeholder, or pass `onKeysReady`/`onOffsetsReady`
as null *and* give `BlockRenderer` a `key` that prevents it from sharing
`GlobalKey` namespace with the live instance — but the cleanest fix is to not
render full content at all in the blurred background:

```dart
// Replace the IgnorePointer > ReaderContent with an empty container or a
// simple shimmer placeholder that doesn't build GlobalKeys.
IgnorePointer(
  child: Container(color: theme.colorScheme.surface),
),
```

---

## Warnings

### WR-01: `ScrollController` listener never removed in `dispose`

**File:** `lib/screens/reader_screen.dart:64,74`

**Issue:** `_scrollController.addListener(_onScroll)` is called in `initState`
but `_scrollController.removeListener(_onScroll)` is never called in
`dispose`. The `ScrollController.dispose()` call on line 76 disposes the
controller, which does remove all listeners internally, but only **after** the
controller fires any pending notifications during the dispose lifecycle. The
missing `removeListener` is not a crash risk here because `dispose()` is
called immediately after, but it is a code-quality issue: if the listener is
added more than once (e.g. via hot-reload) the listener fires twice per
scroll event and `setState` is called multiple times unnecessarily.

**Fix:**
```dart
@override
void dispose() {
  _scrollController.removeListener(_onScroll);  // add this line
  _scrollController.dispose();
  super.dispose();
}
```

---

### WR-02: Stale `_sectionOffsets` not cleared when chapter changes

**File:** `lib/screens/reader_screen.dart:114-116`

**Issue:** `_onOffsetsReady` replaces `_sectionOffsets` when the new chapter's
offsets are measured. However, between a chapter navigation event and the
`addPostFrameCallback` firing, the old stale offsets from the previous chapter
are still present in `_sectionOffsets`. During this brief window,
`_updateActiveSection` runs on every scroll event and compares current scroll
positions against keys that belong to the now-gone chapter, potentially
activating a section ID that does not exist in the new chapter's TOC and
keeping the stale highlight visible.

**Fix:** Clear `_sectionOffsets` in `_navigateToChapter` before the new
chapter content is loaded:
```dart
void _navigateToChapter(String chapterId) {
  setState(() {
    _sectionOffsets = {};          // clear immediately
    _currentSectionId = null;      // reset highlight
    _isMenuOpen = false;
    _showControls = true;
  });
  context.read<BookProvider>().navigateToChapter(chapterId);
  _scrollController.animateTo(0,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
}
```

---

### WR-03: Table and `_AgeReferenceWidget` column widths ignore parent padding

**File:** `lib/widgets/blocks/table_block.dart:24-27`
**File:** `lib/widgets/blocks/block_renderer.dart:527-531`

**Issue:** Both `TableBlockWidget` and `_AgeReferenceWidget` compute column
widths as:
```dart
final contentWidth = screenWidth - 48;
final colWidth = contentWidth / colCount;
```
The magic constant `48` assumes a specific horizontal padding on the content
area. `ReaderContent` wraps content in `EdgeInsets.symmetric(horizontal: 24)`
(= 48 total), so the intent is correct for that specific parent. However:

1. The table blocks are also rendered inside `_LockedChapterOverlay` (via the
   headless `ReaderContent`) and potentially in other contexts where the
   parent padding may differ.
2. Wide cells with long text that cannot wrap (e.g. medical abbreviations,
   numbers) will still overflow the fixed column width because `FixedColumnWidth`
   does not grow to fit content — it clips or overflows. There is no
   `overflow: TextOverflow.ellipsis` or soft-wrap enforcement per column.
3. On a device with a non-standard screen width or when the app is run on a
   tablet, the `screenWidth - 48` calculation remains the full tablet width
   divided by the number of columns, which can produce extremely wide columns
   and overshoots the visual content area.

**Fix:** Use `LayoutBuilder` to obtain the actual available width inside
`TableBlockWidget` rather than reading from `MediaQuery`:
```dart
@override
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final colCount = block.columns.isNotEmpty ? block.columns.length : 1;
      final colWidth = constraints.maxWidth / colCount;
      // ... rest of the widget using colWidth
    },
  );
}
```

---

### WR-04: TOC section `ExpansionTile.onExpansionChanged` is a no-op — section tree never expands

**File:** `lib/widgets/drawer/toc_drawer.dart:257`

**Issue:** The nested section-level `ExpansionTile` has:
```dart
onExpansionChanged: (_) {},
```
This is a no-op callback. `ExpansionTile` by default manages its own
expansion state internally, so the subsection children ARE revealed visually.
However, the outer `isExpanded` flag in `_expandedChapters` is only tracked
for chapter-level tiles. For section tiles, there is no state tracking, and
the no-op callback means any future need to record expanded sections (for
auto-expanding the active section, or persisting state) cannot be added without
refactoring. More concretely, the trailing icon (which is controlled by
`isExpanded` from `_expandedChapters`) is only set on the *chapter* tile.
The section tile has no custom `trailing`, so `ExpansionTile`'s default
expand/collapse arrow is used — and it does update automatically. The no-op
callback is therefore harmless to current behavior but is dead, misleading
code that suggests the callback was intended to do something.

**Fix:** If no state tracking is needed, remove the `onExpansionChanged`
callback from section tiles entirely:
```dart
ExpansionTile(
  key: ValueKey('toc_${section.id}'),
  initiallyExpanded: false,
  tilePadding: const EdgeInsets.only(left: 24, right: 16),
  title: Text(section.title, style: const TextStyle(fontSize: 13)),
  // removed: onExpansionChanged: (_) {},
  children: section.subsections.map((sub) { ... }).toList(),
),
```

---

### WR-05: `DraggableScrollableSheet` double-applies keyboard insets

**File:** `lib/screens/reader_screen.dart:440-441`
**File:** `lib/screens/reader_screen.dart:667-668`

**Issue:** Both `_NotesBottomSheet` and `_ClipsBottomSheet` use the same
pattern:
```dart
return Padding(
  padding: EdgeInsets.only(bottom: viewInsets.bottom),
  child: DraggableScrollableSheet(...),
);
```
`showModalBottomSheet` with no `isScrollControlled: false` (the notes sheet
uses `isScrollControlled: true`) already positions the sheet above the
keyboard by default when `useSafeArea` or the route itself respects
`MediaQuery.viewInsets`. Adding a manual `viewInsets.bottom` padding on top of
this can push the sheet partially off-screen on some devices / Flutter
versions. Even where it doesn't clip, the padding shifts the drag handle and
title upward into the keyboard space.

The correct pattern for `DraggableScrollableSheet` inside
`isScrollControlled: true` modal routes is to NOT add the `viewInsets` padding
externally; instead let `DraggableScrollableSheet`'s `builder` use
`MediaQuery.of(context).viewInsets.bottom` as padding on the *content* (not
the sheet itself).

**Fix:** Remove the outer `Padding` wrapper and handle insets inside the sheet
builder if needed:
```dart
@override
Widget build(BuildContext context) {
  return DraggableScrollableSheet(
    initialChildSize: 0.55,
    minChildSize: 0.3,
    maxChildSize: 0.9,
    expand: false,
    builder: (_, __) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16,
        16 + MediaQuery.of(context).viewInsets.bottom,  // insets here
      ),
      child: ...,
    ),
  );
}
```

---

### WR-06: `_showControls` field is effectively dead state

**File:** `lib/screens/reader_screen.dart:50,199,211,268,316,355`

**Issue:** `_showControls` is set to `true` in several places (tap handler,
settings open, TOC open, navigation press) but is **never set to `false`**
anywhere in the codebase. The `AnimatedOpacity` at line 355 is
`opacity: _showControls ? 1.0 : 0.0`, which always evaluates to `1.0`. The
`if (_showControls)` guard at line 355 is also always `true`.

If the original intent was to hide the progress bar when the user is not
interacting (auto-hide), the hiding logic was removed (D-05 removed the timer)
but the `_showControls` field and its assignments were not cleaned up. This
leaves misleading dead state that will confuse future maintainers.

**Fix:** Either remove `_showControls` entirely and render `ReaderProgressBar`
unconditionally, or re-introduce the auto-hide behavior if it is still desired:
```dart
// Option A — remove dead state:
// Replace the guarded Positioned with:
Positioned(
  bottom: 0, left: 0, right: 0,
  child: ReaderProgressBar(progress: bookProvider.progress),
),
```

---

### WR-07: `_AgeReferenceWidget` column headers derived from `Map` key iteration order (unstable)

**File:** `lib/widgets/blocks/block_renderer.dart:567-579`

**Issue:** The `_AgeReferenceWidget` header row is built by iterating
`block.rows.first.keys.where((k) => k != 'age')` to derive column names
other than `'age'`. `Map` in Dart preserves insertion order, so this is
deterministic as long as the JSON parser produces keys in original order —
which is true for `dart:convert`'s `jsonDecode`. However:

1. If `block.rows` is empty, the header row still renders only the age-unit
   cell (fine), but `colCount` is `1`, causing all column widths to be set to
   the full `contentWidth`. If any row later has more than 1 key, the table
   layout will have more cells than column-width entries, causing a Flutter
   `Table` assertion or rendering error.
2. The column widths for `_AgeReferenceWidget` use the same `screenWidth - 48`
   magic constant as `TableBlockWidget`, inheriting the same padding-mismatch
   defect described in WR-03.

**Fix:** Compute `colCount` from the maximum number of distinct keys across all
rows, or require the model to carry a `columns` field (consistent with
`TableBlock`):
```dart
final allKeys = block.rows.expand((r) => r.keys).toSet();
final colCount = allKeys.isEmpty ? 1 : allKeys.length;
```

---

## Info

### IN-01: Dead switch expression in `_chapterPlainText`

**File:** `lib/widgets/drawer/toc_drawer.dart:99-101`

**Issue:**
```dart
final blockText = switch (block.runtimeType.toString()) {
  _ => _blockText(block),
};
```
The switch has only a wildcard arm and no other patterns. It always calls
`_blockText(block)` regardless of the block type. The `switch` expression adds
no value and could be replaced with a direct call:
```dart
final blockText = _blockText(block);
```

---

### IN-02: `_chapterHeaderTintColor` is never used for `_AgeReferenceWidget`

**File:** `lib/widgets/blocks/block_renderer.dart:183-191,199,211`

**Issue:** `_chapterHeaderTintColor()` is called only when building a
`TableBlockWidget` (line 199). `_AgeReferenceWidget` (line 211) does not
receive a tint color and always uses the hardcoded fallback (`AppColors.inkCharcoal` /
`AppColors.brandPink.withValues(alpha: 0.08)`). If the intent is visual
consistency (all table-like blocks in a chapter share the chapter accent
color), `_AgeReferenceWidget` should accept and apply `headerTintColor` as
`TableBlockWidget` does.

**Fix:** Pass `headerTintColor` to `_AgeReferenceWidget` or refactor both into
a shared table-rendering helper.

---

### IN-03: `reader_screen_test.dart` tests a stub, not the real implementation

**File:** `test/screens/reader_screen_test.dart:7-43`

**Issue:** The test file defines `_PillAlwaysVisibleStub` — a hand-written
stub that hardcodes `_visible = true` and never hides the pill. The tests
then verify behavior of this stub, not of `_ReaderShellState`. If a future
developer re-introduces an auto-hide timer in `_ReaderShellState`, these tests
will continue to pass because they never exercise the real widget. The tests
provide zero regression coverage for the D-05 requirement.

**Fix:** Replace the stub-based tests with widget tests that pump the real
`_ReaderShell` (or a suitably mocked `_ReaderShellState`) and verify that
after 4 seconds the `Key('pill')` widget is still in the tree. Requires
mocking `BookProvider`, `SettingsProvider`, `BookmarkProvider`, and
`AccessService`, but that is the only way to obtain meaningful coverage.

---

### IN-04: Magic constant `48` duplicated across two files

**File:** `lib/widgets/blocks/table_block.dart:25`
**File:** `lib/widgets/blocks/block_renderer.dart:527`

**Issue:** The literal `48` (representing total horizontal content padding) is
hard-coded in both files independently. Changing the padding in `ReaderContent`
from `24` to something else requires updating both files. Prefer a shared
constant or, better, switch to `LayoutBuilder` (see WR-03) to eliminate the
magic value entirely.

**Fix:** Extract to a named constant or use `LayoutBuilder`:
```dart
// In a shared constants file:
const double kContentHorizontalPadding = 24.0; // per-side
// Usage: screenWidth - kContentHorizontalPadding * 2
```

---

_Reviewed: 2026-05-23T07:53:18Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
