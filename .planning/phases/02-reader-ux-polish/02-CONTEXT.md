# Phase 2: Reader UX Polish — Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix three reader experience problems: table cells that overflow horizontally, a `SliverAppBar` that hides on scroll, and a flat TOC that has no sections or subsections. Add subsection-level jump-to navigation with scroll-tracking highlight. No new features — only fixing things that already exist and navigating what's already in the data model.

</domain>

<decisions>
## Implementation Decisions

### Table Overflow Fix

- **D-01:** Replace `SingleChildScrollView(Axis.horizontal)` with a wrapping layout. Cell text wraps vertically — no horizontal scroll.
- **D-02:** Equal column widths — divide `MediaQuery` screen width evenly across all columns. No first-column bias.
- **D-03:** Header row color must come from the chapter/book color defined in `book.json`, not hardcoded to pink (`AppColors.brandPink`). The planner must find how `chapterColor` or equivalent is exposed in the data model and use it for the table header tint.

### App Bar & Navbar Visibility

- **D-04:** Set `SliverAppBar(floating: false)` — the top app bar (title + notes + bookmark + settings) stays visible at all times. Never hides on scroll.
- **D-05:** Remove the 3-second auto-hide timer from the floating back+TOC pill (`_showControls` in `_ReaderShellState`). The pill stays permanently visible.
- **D-06:** Bottom navigation (Previous/Next chapter buttons) and progress bar keep their current behavior unchanged. Only top components are affected by this phase.

### TOC Tree Structure

- **D-07:** Tree depth: Chapter → Section → Subsection (3 levels, matching the full data model depth).
- **D-08:** Default expand state when TOC drawer opens: all collapsed. User must tap to expand any chapter.
- **D-09:** Existing Search and Bookmarks sections at the top of the TOC drawer are kept exactly as-is. Tree structure is added below them.

### Jump-To Navigation

- **D-10:** Subsection-level precision — tapping any TOC item (section OR subsection) scrolls the reader to that exact subsection heading. Requires a `GlobalKey` map keyed on subsection/section ID, maintained by the `BlockRenderer` or a new scroll-anchor layer.
- **D-11:** Current position highlighting — as the user scrolls, the TOC tree highlights the section/subsection they're currently reading. Requires scroll position tracking against section anchor positions.
- **D-12:** Tapping a TOC item closes the drawer and jumps to the content (same pattern as current chapter-level tap behavior in `_navigateToChapter()`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reader Core
- `enchiridion/lib/screens/reader_screen.dart` — `_ReaderShellState._showControls` timer (D-05 target), `_navigateToChapter()` (jump-to pattern to extend in D-12)
- `enchiridion/lib/widgets/reader/reader_app_bar.dart` — `SliverAppBar(floating: true, snap: true)` (D-04 target, line 23)
- `enchiridion/lib/widgets/reader/reader_content.dart` — top-level content widget; entry point into `BlockRenderer`

### Table Rendering
- `enchiridion/lib/widgets/blocks/table_block.dart` — current implementation with `SingleChildScrollView(Axis.horizontal)` and `IntrinsicColumnWidth` (D-01/D-02 target)
- `enchiridion/lib/models/content_block.dart` — `TableBlock` model (columns: List<String>, rows: List<List<String>>)

### TOC Drawer
- `enchiridion/lib/widgets/drawer/toc_drawer.dart` — current flat `_ChapterItem` list; tree replaces the chapter list section (D-07/D-08/D-09 target)

### Data Model (tree structure)
- `enchiridion/lib/models/chapter.dart` — `Chapter` → `ChapterSection` → `ChapterSubsection` hierarchy. IDs available at every level for anchor keys.

### Block Renderer
- `enchiridion/lib/widgets/blocks/block_renderer.dart` — renders sections/subsections; anchor keys (D-10) go here

### Project Context
- `.planning/ROADMAP.md` — Phase 2 task list and success criteria
- `.planning/REQUIREMENTS.md §2` — Reader experience requirements (table wrapping, fixed navbar, tree TOC, jump-to)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CustomDrawer` — slide-in drawer already handles open/close animation and position (left/right). TOC tree replaces only the `TocDrawerContent` child inside it.
- `AppColors.brandPink` / `AppColors.neonTeal` — used for active state highlights in current `_ChapterItem`. New tree active state should follow the same pattern.
- `_navigateToChapter(String chapterId)` in `_ReaderShellState` — existing pattern for closing the drawer + navigating. Jump-to will extend this to accept an optional `sectionId`/`subsectionId`.
- `bookProvider.visitedChapterIds` — already tracks visited chapters. May be extended or paralleled for visited sections if needed.

### Established Patterns
- `Consumer<BookProvider>` wraps the entire reader shell — any scroll-position tracking needed for active-section highlighting should go through `BookProvider` or a new `ReadingPositionProvider`.
- `BlockRenderer` receives `Chapter` and `bookId` — it's the natural place to assign `GlobalKey`s to section headings for anchor-based scrolling.
- `IntrinsicColumnWidth` with `SingleChildScrollView` is the problematic pattern to replace; `FixedColumnWidth` with `MediaQuery.of(context).size.width` division is the replacement direction.

### Integration Points
- Table header color from book.json: researcher must find `chapterColor` field (or equivalent) in the `Chapter` model / JSON schema and confirm it's available at `TableBlockWidget` render time.
- Scroll position → active section: `_scrollController` in `_ReaderShellState` already exists. A `ScrollController` listener can compare `_scrollController.offset` against registered anchor positions to determine the active section.
- TOC active-section callback: `TocDrawerContent` currently receives `currentChapterId`. It will also need `currentSectionId` (new) passed down from `_ReaderShellState`.

</code_context>

<specifics>
## Specific Notes

- Table header color is intentionally NOT hardcoded to pink — it must use the book/chapter color from `book.json`. Researcher should confirm where this color lives in the data model.
- All 3 TOC levels (chapter, section, subsection) should be tappable and produce a jump-to scroll.
- The "all collapsed" default for TOC means no chapter is expanded when the drawer first opens — user expands what they need.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-reader-ux-polish*
*Context gathered: 2026-05-23*
