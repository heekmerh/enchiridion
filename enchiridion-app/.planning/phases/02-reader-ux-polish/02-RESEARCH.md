# Phase 2: Reader UX Polish — Research

**Researched:** 2026-05-23
**Domain:** Flutter reader UI — table layout, SliverAppBar, animated drawer, GlobalKey scroll anchors, ScrollController listener
**Confidence:** HIGH (all findings verified directly from codebase source files)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Table Overflow Fix**
- D-01: Replace `SingleChildScrollView(Axis.horizontal)` with a wrapping layout. Cell text wraps vertically — no horizontal scroll.
- D-02: Equal column widths — divide `MediaQuery` screen width evenly across all columns. No first-column bias.
- D-03: Header row color must come from the chapter/book color defined in `book.json`, not hardcoded to pink (`AppColors.brandPink`). The planner must find how `chapterColor` or equivalent is exposed in the data model and use it for the table header tint.

**App Bar & Navbar Visibility**
- D-04: Set `SliverAppBar(floating: false)` — the top app bar stays visible at all times.
- D-05: Remove the 3-second auto-hide timer from the floating back+TOC pill. The pill stays permanently visible.
- D-06: Bottom navigation keeps current behavior unchanged.

**TOC Tree Structure**
- D-07: Tree depth: Chapter → Section → Subsection (3 levels).
- D-08: Default expand state when TOC drawer opens: all collapsed.
- D-09: Existing Search and Bookmarks sections kept exactly as-is; tree added below them.

**Jump-To Navigation**
- D-10: GlobalKey map keyed on subsection/section ID, maintained by BlockRenderer.
- D-11: Scroll position tracking to highlight current section in TOC.
- D-12: Tapping TOC item closes drawer + jumps to content (extends `_navigateToChapter()` pattern).

### Claude's Discretion

None — all decisions were locked in discussion.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

---

## Summary

Phase 2 targets three independent change areas in the reader: table layout, app bar behavior, and the TOC drawer. All changes are within the Flutter app (`enchiridion/` directory). No new packages are required — every needed capability is present in Flutter 3.41.6 (stable, Dart 3.11.4) and the existing codebase.

**Critical finding for D-03:** `chapterColor` does NOT exist in the data model or book.json. The `Chapter`, `Book`, and `chapter_metadata` JSON structures have no color field. The `Book` model has only `id`, `title`, `author`, `coverUrl`, `chapters`. The `chapter_metadata` JSON has only `chapter_id`, `chapter_title`, `chapter_icon`, `description`, `position_in_book`, `tags`. The decision requires a design resolution: either add a color field to the data model and JSON, or fall back to a computed color derived from `chapter.id`/`chapter.order`, or use a fixed per-index color palette. The planner must address this gap.

**Critical finding for D-10/D-11:** `BlockRenderer` is a `StatelessWidget`. `GlobalKey` registration and scroll tracking require a `StatefulWidget` wrapper. The current `_ChapterView` is also stateless. Anchor key storage must live in a `StatefulWidget` that persists across renders — either convert `BlockRenderer` to stateful, or introduce a thin stateful wrapper.

**Primary recommendation:** Implement the three areas in this order — (1) table fix (isolated, no dependencies), (2) app bar fix (single-line change), (3) TOC tree + jump-to (most complex, depends on GlobalKey infrastructure).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Table cell layout | Widget (TableBlockWidget) | — | Layout-only change, no data or state involved |
| Table header color | Widget (TableBlockWidget) | Data model (Chapter) | Color must be passed down from caller context |
| SliverAppBar behavior | Widget (ReaderAppBar) | — | Single property change on the sliver |
| Back+TOC pill auto-hide | Screen state (_ReaderShellState) | — | Timer logic lives entirely in _ReaderShellState |
| TOC tree expand/collapse | Drawer Widget (TocDrawerContent) | — | Local UI state, no provider needed |
| TOC active highlight | Drawer Widget (TocDrawerContent) | Screen state (_ReaderShellState) | currentSectionId passed as prop from shell |
| GlobalKey anchor map | BlockRenderer (new StatefulWidget) | — | Keys must be registered when subsection widgets are built |
| Scroll position tracking | Screen state (_ReaderShellState) | — | _scrollController already lives here |
| Jump-to navigation | Screen state (_ReaderShellState) | BlockRenderer key map | Requires offset lookup then scroll |

---

## Standard Stack

No new packages required. All capabilities use Flutter SDK built-ins.

### Core (existing)
| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| flutter/material.dart | 3.41.6 | Table, SliverAppBar, GlobalKey, ScrollController | Already in project |
| provider | ^6.1.1 | State management for passing currentSectionId | Already in project |

### Flutter APIs used in this phase
| API | Purpose | Notes |
|-----|---------|-------|
| `Table` + `FixedColumnWidth` | Wrapping table without horizontal scroll | Replaces `IntrinsicColumnWidth` |
| `SliverAppBar(floating: false)` | Always-visible app bar | Remove `snap: true` as well |
| `GlobalKey` | Attach to subsection `Widget` for coordinate lookup | Standard Flutter key |
| `BuildContext.findRenderObject()` | Get `RenderBox` from GlobalKey context | Used to calculate scroll offset |
| `ScrollController.animateTo()` | Scroll to computed offset | Already in use in `_navigateToChapter()` |
| `ScrollController.addListener()` | Track scroll position for active section | `_scrollController` already has a listener (`_onScroll`) |
| `Scrollable.ensureVisible()` | Alternative scroll-to method | Less precise for overlapping sticky headers |
| `ExpansionTile` | Expand/collapse tree nodes in TOC | Built-in Material widget |

**Installation:** No `flutter pub get` changes needed.

---

## Package Legitimacy Audit

> No new packages are installed in this phase. All changes use Flutter SDK built-ins and packages already in `pubspec.yaml`.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
User scrolls reader
        │
        ▼
_ReaderShellState._scrollController (listener: _onScroll)
        │
        ├──► _onScroll() ─► compare offset vs _sectionOffsets map
        │                          │
        │                          ▼
        │                   setState(_currentSectionId)
        │                          │
        │                          ▼
        │              TocDrawerContent(currentSectionId:)
        │                   highlights active tree node
        │
        └──► _scrollController.offset > anchor?
                   (anchor from GlobalKey.currentContext.renderBox.localToGlobal)

User taps TOC item
        │
        ▼
TocDrawerContent.onSectionSelected(sectionId)
        │
        ▼
_ReaderShellState._navigateToSection(sectionId)
        │
        ├──► setState(_isMenuOpen = false)
        └──► _scrollController.animateTo(
               _sectionOffsets[sectionId],
               duration: 300ms, curve: easeOut)
```

### Data Flow for GlobalKey Anchors

```
Chapter JSON loaded
        │
        ▼
BlockRenderer (StatefulWidget) builds _ChapterView
        │
        ▼
_ChapterView iterates section.subsections
        │  for each subsection:
        ▼
GlobalKey key = _keys[subsection.id] ?? GlobalKey()
_keys[subsection.id] = key
        │
        ▼
_SubsectionHeader(key: key, ...)   ← key attached here
        │
        ▼
After first frame (WidgetsBinding.addPostFrameCallback):
  RenderBox box = key.currentContext.findRenderObject()
  offset = box.localToGlobal(Offset.zero).dy + scrollController.offset
  _offsets[subsection.id] = offset
        │
        ▼
Passed up to _ReaderShellState via callback or via InheritedWidget
```

### Recommended Project Structure (changes only)

```
enchiridion/lib/
├── widgets/
│   ├── blocks/
│   │   ├── block_renderer.dart          # Convert to StatefulWidget; add GlobalKey map
│   │   └── table_block.dart             # Replace SingleChildScrollView + IntrinsicColumnWidth
│   └── drawer/
│       └── toc_drawer.dart              # Replace _ChapterItem list with ExpansionTile tree
├── screens/
│   └── reader_screen.dart               # Remove auto-hide timer; add _currentSectionId;
│                                        # add _navigateToSection(); pass currentSectionId to drawer
└── widgets/reader/
    └── reader_app_bar.dart              # floating: false, remove snap: true
```

### Pattern 1: Fixed-Width Wrapping Table (D-01, D-02)

**What:** Replace `SingleChildScrollView(Axis.horizontal)` + `IntrinsicColumnWidth` with a non-scrolling `Table` using `FixedColumnWidth` based on available screen width.

**When to use:** All `TableBlockWidget` renders.

```dart
// Source: verified from enchiridion/lib/widgets/blocks/table_block.dart (current) +
//         Flutter Table docs [ASSUMED: exact API usage pattern]
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final screenWidth = MediaQuery.of(context).size.width;
  final contentWidth = screenWidth - 48; // 24px horizontal padding each side
  final colCount = block.columns.isNotEmpty ? block.columns.length : 1;
  final colWidth = contentWidth / colCount;

  // D-03: header color — see chapterColor gap in Pitfalls
  final headerColor = headerTintColor ?? (isDark
      ? AppColors.inkCharcoal
      : AppColors.brandPink.withValues(alpha: 0.08));

  return Container(
    margin: EdgeInsets.only(bottom: fontSize * 1.5),
    decoration: BoxDecoration(
      border: Border.all(color: theme.dividerColor),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Table(
      columnWidths: {
        for (int i = 0; i < colCount; i++)
          i: FixedColumnWidth(colWidth),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: theme.dividerColor),
        verticalInside: BorderSide(color: theme.dividerColor),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        if (block.columns.isNotEmpty)
          TableRow(
            decoration: BoxDecoration(color: headerColor),
            children: block.columns
                .map((col) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Text(col,
                          style: TextStyle(
                            fontSize: fontSize * 0.85,
                            fontWeight: FontWeight.bold,
                          )),
                    ))
                .toList(),
          ),
        ...block.rows.map((row) => TableRow(
              children: row
                  .map((cell) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Text(cell,
                            style: TextStyle(
                              fontSize: fontSize * 0.9,
                              height: lineHeight,
                            )),
                      ))
                  .toList(),
            )),
      ],
    ),
  );
}
```

**Note on `AgeReferenceBlock`:** `_AgeReferenceWidget` in `block_renderer.dart` has the IDENTICAL `SingleChildScrollView(Axis.horizontal)` + `IntrinsicColumnWidth` pattern (lines 443-503 of `block_renderer.dart`). It must receive the same fix. This is a second change target in the same file.

### Pattern 2: SliverAppBar Fix (D-04)

**What:** Change `floating: true, snap: true` to `floating: false` and remove `snap`.

**File:** `enchiridion/lib/widgets/reader/reader_app_bar.dart`, line 23-25.

```dart
// Before (verified from reader_app_bar.dart lines 23-25):
return SliverAppBar(
  floating: true,
  snap: true,

// After:
return SliverAppBar(
  floating: false,
  // snap is only valid when floating: true; remove it
```

**Note:** `snap: true` is only valid when `floating: true`. Leaving `snap: true` with `floating: false` generates a Flutter assertion error at runtime. Remove both properties or set both to false.

### Pattern 3: Remove Auto-Hide Timer (D-05)

**What:** `_ReaderShellState` in `reader_screen.dart` has a `Timer? _hideControlsTimer` and methods `_resetHideControlsTimer()` and `_onScroll()` that implement the 3-second auto-hide. Remove these; set `_showControls` permanently to `true`.

**Exact current code (verified from reader_screen.dart):**

```dart
// Current — lines 51, 54, 77-91, 99, 103
bool _showControls = true;           // field
Timer? _hideControlsTimer;           // field

void _onScroll() {
  if (!_showControls) setState(() => _showControls = true);
  _resetHideControlsTimer();         // ← call to remove
}

void _resetHideControlsTimer() {     // ← entire method to remove
  _hideControlsTimer?.cancel();
  if (_scrollController.hasClients &&
      _scrollController.offset > 100 &&
      !_isMenuOpen &&
      !_isSettingsOpen) {
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isMenuOpen && !_isSettingsOpen) {
        setState(() => _showControls = false);
      }
    });
  }
}
```

**After D-05:** Remove `_hideControlsTimer` field, remove `_resetHideControlsTimer()` entirely, simplify `_onScroll()` to nothing (or remove listener if not needed for D-11), remove `_hideControlsTimer?.cancel()` from `dispose()`, remove all `_resetHideControlsTimer()` call sites (lines 99, 103, in `_onScroll`, in `onTap` GestureDetector). The `_showControls` field can be removed entirely or left as `final bool _showControls = true` if the `if (_showControls)` at line 310 is kept for the progress bar.

**Interaction with D-11:** `_onScroll()` will still be needed as the scroll listener for active-section tracking. It should remain but without the timer call.

### Pattern 4: GlobalKey Anchor Map (D-10)

**What:** Convert `BlockRenderer` to a `StatefulWidget`. Maintain a `Map<String, GlobalKey>` for every subsection and section rendered. After each build, calculate offsets from the keys and store them for use by the scroll-jump and active-highlight logic.

**Key decisions:**
- Keys must be created in `State.initState()` or `State.didUpdateWidget()`, not in `build()`. Creating `GlobalKey()` in `build()` causes key churn (new key each build = lost render objects).
- Offset calculation must happen after layout: use `WidgetsBinding.instance.addPostFrameCallback`.
- Offsets must be re-calculated when the chapter changes (user navigates to a different chapter).

```dart
// Source: Flutter GlobalKey docs [ASSUMED: exact pattern]
class BlockRenderer extends StatefulWidget {
  final Chapter chapter;
  final String bookId;
  final void Function(Map<String, double>)? onOffsetsReady;

  const BlockRenderer({
    super.key,
    required this.chapter,
    this.bookId = '',
    this.onOffsetsReady,
  });

  @override
  State<BlockRenderer> createState() => _BlockRendererState();
}

class _BlockRendererState extends State<BlockRenderer> {
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _subsectionKeys = {};

  @override
  void initState() {
    super.initState();
    _buildKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
  }

  @override
  void didUpdateWidget(BlockRenderer old) {
    super.didUpdateWidget(old);
    if (old.chapter.id != widget.chapter.id) {
      _sectionKeys.clear();
      _subsectionKeys.clear();
      _buildKeys();
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateOffsets());
    }
  }

  void _buildKeys() {
    for (final section in widget.chapter.sections) {
      _sectionKeys[section.id] = GlobalKey();
      for (final sub in section.subsections) {
        _subsectionKeys[sub.id] = GlobalKey();
      }
    }
  }

  void _calculateOffsets() {
    final offsets = <String, double>{};
    void measure(String id, GlobalKey key) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      // dy relative to the CustomScrollView viewport origin
      final pos = box.localToGlobal(Offset.zero);
      offsets[id] = pos.dy;
    }
    _sectionKeys.forEach(measure);
    _subsectionKeys.forEach(measure);
    widget.onOffsetsReady?.call(offsets);
  }

  @override
  Widget build(BuildContext context) {
    // ... forward to _ChapterView, passing keys
  }
}
```

**Important offset caveat:** `localToGlobal(Offset.zero).dy` returns the position relative to the screen, NOT relative to the scroll viewport origin. To get the scroll target offset, the implementation must add `_scrollController.offset` to the `dy` value at the time `_calculateOffsets` is called, OR use `Scrollable.ensureVisible` which handles this automatically. See Pitfall 3 below.

**Recommended approach for jump-to:** Use `Scrollable.ensureVisible(key.currentContext!, duration: ..., curve: ...)` instead of manual offset math. It is simpler and handles nested scrollables correctly. The tradeoff is less control over alignment (it scrolls to make the widget visible, not necessarily to the top of screen).

**Alternative for precise top-align:** Use `_scrollController.animateTo(offset - appBarHeight)` where offset is derived from `RenderBox.localToGlobal` + current scroll position. This requires knowing the app bar height (available from `SliverAppBar` expanded height, or by storing a key on the SliverAppBar).

### Pattern 5: Scroll Tracking for Active Section (D-11)

**What:** In `_onScroll()`, compare `_scrollController.offset` against the stored anchor offsets and set `_currentSectionId`/`_currentSubsectionId` to the highest anchor whose offset is <= current scroll position.

```dart
// Source: [ASSUMED — standard ScrollController listener pattern]
String? _currentSectionId;

void _onScroll() {
  _updateActiveSection();
  // (timer call removed per D-05)
}

void _updateActiveSection() {
  if (_sectionOffsets.isEmpty) return;
  final scrollOffset = _scrollController.offset;

  String? activeId;
  double bestOffset = double.negativeInfinity;

  for (final entry in _sectionOffsets.entries) {
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

**Storage of offsets:** The `_sectionOffsets` map lives in `_ReaderShellState`. `BlockRenderer` delivers it via the `onOffsetsReady` callback, which is called after each layout pass. `_ReaderShellState` stores the received map.

**Passing to TOC:** `_currentSectionId` is passed as a new prop to `TocDrawerContent`. The TOC uses it to highlight the matching tree item (same pattern as the existing `currentChapterId` prop).

### Pattern 6: TOC Tree with ExpansionTile (D-07, D-08, D-09)

**What:** Replace the flat `_ChapterItem` list in `TocDrawerContent` with a tree using `ExpansionTile` (chapter) containing `ListTile` rows for sections and subsections.

**Existing structure to preserve (D-09):** Search TextField, search results section, bookmarks section. Only the chapter list section at the bottom (currently `...widget.chapters.map((chapter) => _ChapterItem(...))`) is replaced.

**D-08 (all collapsed):** `ExpansionTile` is collapsed by default unless `initiallyExpanded: true`. Do not set `initiallyExpanded`. To force re-collapse when the drawer closes and reopens, use a `key` based on the drawer open state or chapter ID so the `ExpansionTile` widgets are rebuilt.

```dart
// Source: Flutter ExpansionTile docs [ASSUMED: parameter names]
// Replace the _ChapterItem list section:
...widget.chapters.map((chapter) {
  final isActiveChapter = chapter.id == widget.currentChapterId;
  return ExpansionTile(
    key: ValueKey('${chapter.id}_${widget.currentChapterId}'),
    // D-08: not initiallyExpanded; only auto-expand the active chapter if desired
    initiallyExpanded: false,
    leading: isActiveChapter
        ? const Icon(Icons.circle, size: 8, color: AppColors.brandPink)
        : null,
    title: Text(
      chapter.title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: isActiveChapter ? FontWeight.w600 : FontWeight.normal,
        color: isActiveChapter
            ? AppColors.brandPink
            : theme.colorScheme.onSurface,
      ),
    ),
    children: chapter.sections.map((section) {
      return ExpansionTile(
        title: Text(section.title, style: const TextStyle(fontSize: 13)),
        children: section.subsections.map((sub) {
          final isActiveSub = sub.id == widget.currentSectionId;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 48, right: 16),
            title: Text(sub.title,
                style: TextStyle(
                  fontSize: 12,
                  color: isActiveSub
                      ? AppColors.neonTeal
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: isActiveSub ? FontWeight.w600 : null,
                )),
            onTap: () => widget.onSectionSelected(section.id, sub.id),
          );
        }).toList(),
      );
    }).toList(),
  );
}),
```

**New props needed on `TocDrawerContent`:**
- `String? currentSectionId` — highlights active subsection
- `Function(String sectionId, String subsectionId) onSectionSelected` — for jump-to

**New method in `_ReaderShellState`:**
```dart
void _navigateToSection(String sectionId, String subsectionId) {
  setState(() {
    _isMenuOpen = false;
    _showControls = true;
  });
  // Jump to subsection anchor
  final key = _subsectionKeys[subsectionId] ?? _sectionKeys[sectionId];
  if (key?.currentContext != null) {
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      alignment: 0.0, // scroll to top of viewport
    );
  }
}
```

**How to get keys from BlockRenderer to ReaderShellState:** `BlockRenderer` is rendered inside `ReaderContent` which is inside `SliverToBoxAdapter` in `_ReaderShellState`. Options:
1. Pass `onOffsetsReady` callback from `_ReaderShellState` through `ReaderContent` to `BlockRenderer`. Also pass keys (not just offsets) as a separate callback `onKeysReady`.
2. Use an `InheritedWidget` / `Provider`. This is heavier but cleaner at scale.

**Recommendation:** Option 1 — callback chain. Two callbacks: `onKeysReady(Map<String, GlobalKey> sectionKeys, Map<String, GlobalKey> subsectionKeys)` and `onOffsetsReady(Map<String, double>)`. Both are added to `ReaderContent` and forwarded to `BlockRenderer`. `_ReaderShellState` stores the maps in fields.

### Anti-Patterns to Avoid

- **Creating `GlobalKey()` inside `build()`:** Causes a new key on every rebuild, losing the render object reference. Keys must be created once in `initState()`.
- **Using `Scrollable.ensureVisible` from within a timer callback:** The context may be stale. Call it directly from user interaction.
- **Setting `snap: true` without `floating: true`:** Flutter asserts this combination is invalid and will throw at runtime.
- **Using `_scrollController.offset` to calculate anchor position at build time:** The scroll position at build time is 0 (or wherever it is currently). Anchors must be calculated after layout via `addPostFrameCallback`.
- **Keeping `_showControls` conditional check on the progress bar without updating:** After D-05, if `_showControls` is always `true`, the `if (_showControls)` wrapper on `ReaderProgressBar` (line 310 of reader_screen.dart) is a no-op and can be simplified.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Expand/collapse tree nodes | Custom animation widget | `ExpansionTile` | Built-in, accessible, handles state |
| Scroll to widget | Manual offset math + animateTo | `Scrollable.ensureVisible` | Handles nested scrollables, viewport math, alignment |
| Fixed-width table columns | Loop to measure text width | `FixedColumnWidth(screenWidth / n)` | Flutter Table handles cell wrapping natively |
| Detecting current section on scroll | Full content re-scan on each scroll event | Store pre-computed offset map, binary search or linear scan at scroll time | Content scan is O(blocks) per frame; offset map is O(sections) |

---

## Critical Gap: D-03 — `chapterColor` Does Not Exist

**Verified finding:** `book.json` has NO `chapterColor`, `color`, or color-adjacent field in `chapter_metadata`. The `Chapter` Dart model has NO color field. The `Book` model has NO color field.

**Options for the planner to resolve:**

| Option | Effort | Quality |
|--------|--------|---------|
| A. Add `chapter_color` (hex string) to every chapter in `book.json` + add `color?` field to `Chapter` model + parse in `Chapter.fromJson` | High (data + code) | Best: per-chapter control |
| B. Derive color from `chapter.order` using a fixed palette (e.g., `AppColors` cycling list) | Low (code only) | Acceptable: no data changes |
| C. Use `AppColors.brandPink` as-is (ignore D-03) | None | Not acceptable — contradicts locked decision |
| D. Derive from `chapter.id` hash | Low (code only) | Acceptable: deterministic, no data changes |

**Recommendation for planner:** Choose Option B (color palette indexed by `chapter.order % palette.length`). This requires no JSON changes and delivers visual variation. The palette should be defined in `AppColors` as a `static const List<Color>`.

**Propagation path when resolved:** `_ReaderShellState` has the `chapter` object. It passes it to `ReaderContent(chapter: chapter)` → `BlockRenderer(chapter: chapter)` → `_ChapterView`. The `_ChapterView` already builds `TableBlockWidget`. The color can be computed in `_ChapterView` and passed to `TableBlockWidget` as a new optional `Color? headerTintColor` parameter.

---

## Common Pitfalls

### Pitfall 1: `snap: true` assertion failure after removing `floating: true`

**What goes wrong:** `SliverAppBar(floating: false, snap: true)` throws a Flutter assertion: `snap: true requires floating: true`.
**Why it happens:** `snap` is only meaningful when `floating` is true.
**How to avoid:** Remove both `floating: true` and `snap: true` when applying D-04. The final state is `SliverAppBar(floating: false)` with no `snap` property.
**Warning signs:** Red-screen assertion error on any reader open after the change.

### Pitfall 2: GlobalKey churn (keys created in `build()`)

**What goes wrong:** Scroll anchors work the first time but silently fail after any rebuild (font size change, theme change, etc.).
**Why it happens:** `GlobalKey()` creates a new key instance each call. If called in `build()`, Flutter sees a different key object every rebuild and replaces the render object. The old context is garbage-collected.
**How to avoid:** Create all `GlobalKey` instances in `initState()` / `_buildKeys()`, stored in a `Map<String, GlobalKey>` field. Pass the pre-created key to each widget.
**Warning signs:** Jump-to works after hot restart but fails after scrolling or changing settings.

### Pitfall 3: `localToGlobal` offset includes scroll position incorrectly

**What goes wrong:** Jumping to a section scrolls to the wrong position — undershoots or overshoots.
**Why it happens:** `box.localToGlobal(Offset.zero).dy` returns position relative to the current viewport (i.e., screen coordinates), not the document. If the user has already scrolled 500px, a widget at document position 800 reports `dy = 300`. Storing 300 as the scroll target is wrong.
**How to avoid:** Use `Scrollable.ensureVisible()` which internally handles viewport math. If using manual `animateTo`, convert: `scrollTarget = box.localToGlobal(Offset.zero, ancestor: scrollViewRenderBox).dy`.
**Warning signs:** Jump-to accuracy degrades the more the user has already scrolled before tapping a TOC item.

### Pitfall 4: `AgeReferenceBlock` missed in table fix

**What goes wrong:** `TableBlock` tables are fixed but `AgeReferenceBlock` tables still overflow.
**Why it happens:** `_AgeReferenceWidget` in `block_renderer.dart` (lines 420–503) has an identical `SingleChildScrollView(Axis.horizontal)` + `IntrinsicColumnWidth` pattern. It is separate from `TableBlockWidget`.
**How to avoid:** Apply the same `FixedColumnWidth` fix to `_AgeReferenceWidget`. This is in `block_renderer.dart`, not `table_block.dart`.
**Warning signs:** Age reference tables (block type `age_reference`) still scroll horizontally after the fix.

### Pitfall 5: TOC collapsed state resets mid-session

**What goes wrong:** User expands a chapter in the TOC, closes the drawer, reopens it — everything is expanded or collapsed incorrectly.
**Why it happens:** If `ExpansionTile` key is based on chapter ID only, re-open of the drawer reuses the same widget (no rebuild) and preserves the previous expanded state. This may be desired. But if the key includes `_isMenuOpen`, the tree rebuilds on open/close, resetting to all-collapsed (D-08 compliant). Choose the key strategy deliberately.
**How to avoid:** For strict D-08 compliance (always collapsed on open), use `ValueKey('toc_${widget.currentChapterId}_${drawerOpenCount}')` or pass a `drawerKey` that increments each time the drawer opens.
**Warning signs:** User reports that chapters are already expanded when they open the TOC.

### Pitfall 6: `onSectionSelected` callback signature mismatch

**What goes wrong:** `TocDrawerContent` is called with old `onChapterSelected: _navigateToChapter` which takes only a `String chapterId`. The new tree needs a two-argument callback.
**How to avoid:** Add a new `onSectionSelected: _navigateToSection` prop of type `Function(String sectionId, String subsectionId)`. Keep the existing `onChapterSelected` for chapter-level taps. Both callbacks must be wired in `_ReaderShellState.build()` at the `TocDrawerContent` call site.
**Warning signs:** Compile error `'_navigateToChapter' is not a subtype of Function(String, String)`.

---

## File-by-File Change Map

| File | Decision | What Changes |
|------|----------|-------------|
| `lib/widgets/reader/reader_app_bar.dart` | D-04 | `floating: true` → `floating: false`; remove `snap: true` |
| `lib/screens/reader_screen.dart` | D-05 | Remove `Timer? _hideControlsTimer` field; remove `_resetHideControlsTimer()` method; simplify `_onScroll()`; remove timer cancel from `dispose()`; add `String? _currentSectionId` field; add `Map<String, GlobalKey> _sectionKeys`, `_subsectionKeys` fields; add `Map<String, double> _sectionOffsets` field; add `_navigateToSection()` method; add `_updateActiveSection()` call in `_onScroll()`; update `TocDrawerContent` call to pass `currentSectionId` and `onSectionSelected` |
| `lib/widgets/reader/reader_content.dart` | D-10 | Add `onKeysReady` and `onOffsetsReady` callback params; forward to `BlockRenderer` |
| `lib/widgets/blocks/block_renderer.dart` | D-01, D-02, D-10 | Convert `BlockRenderer` to `StatefulWidget`; add `_sectionKeys`, `_subsectionKeys` maps; `_buildKeys()` in `initState()`; `_calculateOffsets()` in `addPostFrameCallback`; pass keys to `_SectionHeader`/`_SubsectionHeader`; fix `_AgeReferenceWidget` table (remove `SingleChildScrollView`, use `FixedColumnWidth`) |
| `lib/widgets/blocks/table_block.dart` | D-01, D-02, D-03 | Remove `SingleChildScrollView`; change `defaultColumnWidth: IntrinsicColumnWidth()` to per-column `FixedColumnWidth`; add optional `Color? headerTintColor` param; use it in `TableRow` decoration |
| `lib/widgets/drawer/toc_drawer.dart` | D-07, D-08, D-09 | Add `String? currentSectionId` and `Function(String, String) onSectionSelected` props; replace flat `_ChapterItem` list with `ExpansionTile` tree; keep search and bookmarks sections unchanged; remove `_ChapterItem` class or repurpose for chapter-level tap |
| `lib/models/chapter.dart` | D-03 (if Option A) | Add `final Color? color;` field; parse `chapter_metadata.chapter_color` |
| `lib/theme/app_colors.dart` | D-03 (if Option B) | Add `static const List<Color> chapterPalette = [...]` |
| `assets/data/book.json` | D-03 (if Option A) | Add `"chapter_color": "#hex"` to every `chapter_metadata` block |

---

## Integration Risks and Ordering Dependencies

1. **Table fix (D-01/D-02/D-03) is independent.** It touches only `table_block.dart` and optionally `block_renderer.dart` (`_AgeReferenceWidget`). No dependency on other changes. Do this first or in parallel.

2. **App bar fix (D-04) is independent.** Single-line change in `reader_app_bar.dart`. Do this first — it is the lowest-risk change.

3. **Timer removal (D-05) modifies the same file as D-11 (scroll tracking).** Plan them together in a single wave to avoid two conflicting edits to `reader_screen.dart`. The `_onScroll()` method is touched by both.

4. **GlobalKey infrastructure (D-10) must be complete before D-11 and D-12 can work.** Without keys, there are no offsets; without offsets, scroll tracking and jump-to have no targets. Order: D-10 → D-11 → D-12.

5. **D-03 color resolution must be decided before implementing `TableBlockWidget`.** The `headerTintColor` parameter shape depends on whether color comes from `chapter.order`, `chapter.color`, or a hash. Decide Option A/B first, then implement.

6. **`TocDrawerContent` signature change (D-07) must be coordinated with `_ReaderShellState`** — both files change at the same time. Adding the new `onSectionSelected` callback before wiring it in the shell would cause a compile error (required param missing).

**Safe implementation order:**
```
Wave 1 (independent, no cross-dependencies):
  - reader_app_bar.dart: D-04 (floating: false)
  - Decide D-03 color resolution strategy

Wave 2 (table fix):
  - table_block.dart: D-01, D-02, D-03
  - block_renderer.dart: D-01 fix for _AgeReferenceWidget

Wave 3 (GlobalKey infrastructure):
  - block_renderer.dart: D-10 (convert to StatefulWidget, key map)
  - reader_content.dart: add callback props

Wave 4 (scroll tracking + timer removal — same file):
  - reader_screen.dart: D-05 (remove timer) + D-11 (scroll tracking) together

Wave 5 (TOC tree + jump-to — coordinated pair):
  - toc_drawer.dart: D-07, D-08, D-09 (tree structure + new props)
  - reader_screen.dart: D-12 (_navigateToSection, wire new TocDrawerContent props)
```

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Scrollable.ensureVisible` takes `alignment: 0.0` to scroll target to top of viewport | Pattern 4, Pattern 6 | Jump-to may center or bottom-align instead of top-align; minor UX issue |
| A2 | `ExpansionTile` parameter names (`initiallyExpanded`, `leading`, `children`) match Flutter 3.41.6 API | Pattern 6 | Compile error; easy to fix by checking Flutter docs |
| A3 | Color palette approach (Option B for D-03) is acceptable to the user | Gap: D-03 | User may require Option A (explicit JSON colors); needs user confirmation |
| A4 | `BlockRenderer`'s `onOffsetsReady` callback pattern will not cause setState-during-build warnings | Pattern 4 | If `addPostFrameCallback` triggers within the same frame, may require a `setState` guard; low risk |
| A5 | `ValueKey` on `ExpansionTile` resets expansion state when key changes | Pattern 6 / Pitfall 5 | If Flutter preserves state across key changes, all-collapsed D-08 may not work; needs testing |

---

## Open Questions (RESOLVED)

1. **D-03: What color value should the table header use?**
   - What we know: No `chapterColor` field exists in book.json or the Dart model.
   - What's unclear: Whether the user wants to add per-chapter colors to book.json (requires editing JSON for all chapters) or is satisfied with computed colors.
   - Recommendation: Present Option A vs B to user in plan notes. Default to Option B (palette by `chapter.order`) as it requires no JSON editing. The planner should add a task that explicitly calls this out.
   - **RESOLVED:** User chose Option A — add `chapter_color` hex string field to book.json for each chapter. Plan 01 Task 2 implements this pipeline (book.json → Chapter model → TableBlockWidget).

2. **Should `_SectionHeader` also get a GlobalKey (for section-level jump) or only `_SubsectionHeader`?**
   - What we know: D-10 says "subsection/section ID" — both levels are tappable per D-07.
   - What's unclear: Whether section-level taps should jump to the section heading or its first subsection.
   - Recommendation: Attach GlobalKeys to both `_SectionHeader` and `_SubsectionHeader`. Section tap → scroll to section key; subsection tap → scroll to subsection key.
   - **RESOLVED:** GlobalKeys attached to both `_SectionHeader` AND `_SubsectionHeader` in Plan 03 Task 1.

3. **Should chapters in the TOC tree be tappable at the chapter level (existing behavior) in addition to section/subsection?**
   - What we know: The existing `_ChapterItem` had chapter-level taps via `onChapterSelected`. D-12 says "tap TOC item → close drawer + jump."
   - What's unclear: Whether chapter-level tap should still navigate (switch chapter) vs. just expand the tree.
   - Recommendation: Keep chapter-level tap to switch chapter (existing behavior). Section/subsection taps trigger scroll-within-chapter.
   - **RESOLVED:** Chapter tap navigates to the chapter AND expands its section list. Plan 05 Task 2 implements this as: call `onChapterSelected` AND toggle `_expandedChapters` set.

---

## Environment Availability

> Step 2.6: All changes are code/config only within the Flutter project. No external tools, services, or CLIs beyond Flutter SDK (already confirmed available).

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All changes | Yes | 3.41.6 (stable) | — |
| Dart SDK | All changes | Yes | 3.11.4 | — |

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in, no separate install) |
| Config file | None (uses default flutter test runner) |
| Quick run command | `cd enchiridion && flutter test test/widgets/ -x` |
| Full suite command | `cd enchiridion && flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-2.1 | TableBlockWidget renders without horizontal scroll | Widget test | `flutter test test/widgets/table_block_test.dart -x` | No — Wave 0 |
| REQ-2.1 | Equal column widths computed from MediaQuery | Widget test | `flutter test test/widgets/table_block_test.dart -x` | No — Wave 0 |
| REQ-2.2 | SliverAppBar floating is false | Widget test | `flutter test test/widgets/reader_app_bar_test.dart -x` | No — Wave 0 |
| REQ-2.3a | TOC renders Chapter→Section→Subsection tree | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3b | TOC all collapsed on open | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3c | Tap subsection → onSectionSelected called | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| REQ-2.3d | Active section highlighted in TOC | Widget test | `flutter test test/widgets/toc_drawer_test.dart -x` | No — Wave 0 |
| D-05 | No auto-hide timer on back+TOC pill | Unit test (logic) | `flutter test test/screens/reader_screen_test.dart -x` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `cd enchiridion && flutter test test/widgets/ -x`
- **Per wave merge:** `cd enchiridion && flutter test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/widgets/table_block_test.dart` — covers REQ-2.1
- [ ] `test/widgets/reader_app_bar_test.dart` — covers REQ-2.2
- [ ] `test/widgets/toc_drawer_test.dart` — covers REQ-2.3a/b/c/d
- [ ] `test/screens/reader_screen_test.dart` — covers D-05 (no timer)

---

## Security Domain

> This phase makes no changes to authentication, session management, data storage, or network calls. All changes are local UI rendering and navigation. Security domain: not applicable.

---

## Sources

### Primary (HIGH confidence — directly read from codebase)

- `enchiridion/lib/screens/reader_screen.dart` — complete `_ReaderShellState` implementation, timer logic, `_navigateToChapter`, scroll controller
- `enchiridion/lib/widgets/reader/reader_app_bar.dart` — exact `SliverAppBar` declaration (`floating: true, snap: true`)
- `enchiridion/lib/widgets/blocks/table_block.dart` — `SingleChildScrollView(Axis.horizontal)` + `IntrinsicColumnWidth` pattern; `AppColors.brandPink` header tint
- `enchiridion/lib/widgets/blocks/block_renderer.dart` — `_AgeReferenceWidget` second table; `_SectionHeader`/`_SubsectionHeader` structure; `StatelessWidget` status of `BlockRenderer`
- `enchiridion/lib/widgets/drawer/toc_drawer.dart` — flat `_ChapterItem` list; existing Search + Bookmarks sections
- `enchiridion/lib/models/chapter.dart` — `Chapter`, `ChapterSection`, `ChapterSubsection` structure; IDs: `section_id`, `subsection_id`
- `enchiridion/lib/models/book.dart` — confirmed: no `chapterColor` field
- `enchiridion/assets/data/book.json` — confirmed: no `color` or `chapter_color` in `chapter_metadata`
- `enchiridion/pubspec.yaml` — Flutter 3.41.6, no new packages needed
- `enchiridion/lib/theme/app_colors.dart` — `AppColors.brandPink`, `AppColors.neonTeal`
- `enchiridion/lib/providers/book_provider.dart` — `navigateToChapter`, no scroll position tracking currently

### Secondary (ASSUMED — Flutter SDK patterns from training knowledge)

- `Scrollable.ensureVisible` API shape — [ASSUMED]
- `ExpansionTile` parameter names — [ASSUMED]
- `GlobalKey` + `addPostFrameCallback` offset pattern — [ASSUMED]
- `FixedColumnWidth` Table behavior — [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Current implementation details: HIGH — all verified by direct file reads
- chapterColor gap: HIGH — confirmed absent from both JSON and Dart models
- Flutter API patterns (GlobalKey, ScrollController, ExpansionTile): MEDIUM — training knowledge, not verified via Context7 this session
- Integration risk ordering: HIGH — derived from file dependency analysis

**Research date:** 2026-05-23
**Valid until:** 2026-06-23 (stable Flutter APIs; book.json structure unlikely to change)
