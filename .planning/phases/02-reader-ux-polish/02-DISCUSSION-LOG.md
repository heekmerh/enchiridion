# Phase 2: Reader UX Polish — Discussion Log

**Date:** 2026-05-23
**Areas discussed:** Table overflow fix, Navbar visibility, TOC tree structure, Jump-to navigation

---

## Area 1: Table Overflow Fix

**Q1: How should table columns behave when too wide for screen?**
Options: Wrap text in cells / Keep horizontal scroll with cap / Flexible proportional columns
**Selected:** Wrap text in cells
Notes: Cell text wraps vertically, no horizontal scroll. Best for multi-column medical tables.

**Q2: Equal column widths or first column wider?**
Options: Equal column widths (simpler) / First column wider / You decide
**Selected:** Equal column widths (simpler)
Notes: Screen width divided evenly across all columns.

**Q3: Should header row styling be preserved exactly?**
Options: Keep exactly as-is / Minor improvements OK / Redesign header too
**Selected:** (User clarified) Table header color should come from book.json chapter color, not hardcoded pink.
Notes: This is an important data model dependency — researcher must locate `chapterColor` field.

---

## Area 2: Navbar / App Bar Visibility

**Q1: What should the SliverAppBar do on scroll?**
Options: Always visible / Show on up-hide on down / Remove entirely
**Selected:** Always visible — never hide
Notes: Set `floating: false`. App bar always at top.

**Q2: Should the floating back+TOC pill also always stay visible?**
Options: Always visible too / Keep auto-hide for pill / Show only when app bar not visible
**Selected:** Always visible too
Notes: Remove the 3-second `_showControls` auto-hide timer from `_ReaderShellState`.

**Q3: Bottom navigation and progress bar?**
Options: Always visible (consistent) / Keep current behavior / You decide
**Selected:** Keep current behavior for bottom
Notes: Only top components are changed this phase. Bottom nav/progress bar unchanged.

---

## Area 3: TOC Tree Structure

**Q1: How deep should the tree go?**
Options: Chapter → Section (2 levels) / Chapter → Section → Subsection (3 levels) / Chapter only
**Selected:** Chapter → Section → Subsection (3 levels)
Notes: Full tree matching the data model hierarchy.

**Q2: Default expand state when drawer opens?**
Options: Current chapter expanded, rest collapsed / All collapsed / All expanded
**Selected:** All collapsed
Notes: User must tap to expand. Clean, minimal opening state.

**Q3: Keep existing Search and Bookmarks sections?**
Options: Keep both exactly as-is / Keep search, remove bookmarks / You decide
**Selected:** Keep both exactly as-is
Notes: Search and bookmarks stay at top. Tree structure added below.

---

## Area 4: Jump-To Navigation

**Q1: How precise should the jump-to be?**
Options: Section-level jump / Chapter-level only / Subsection-level jump
**Selected:** Subsection-level jump
Notes: Requires `GlobalKey` map across the full section/subsection tree in `BlockRenderer`.

**Q2: Current position highlighting while reading?**
Options: Highlight current chapter only / Highlight current section as scrolling / No highlight
**Selected:** Highlight current section as user scrolls
Notes: Scroll-position tracking against section anchors. Active section highlighted in open TOC tree.

**Q3: Should drawer close when tapping a TOC item?**
Options: Close drawer and jump / Keep drawer open
**Selected:** Close drawer and jump
Notes: Consistent with current chapter-tap behavior.

---

## Claude's Discretion Items

None — all gray areas were directly answered by the user.

---

*Log written: 2026-05-23*
