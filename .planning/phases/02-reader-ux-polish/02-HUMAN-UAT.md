---
status: partial
phase: 02-reader-ux-polish
source: [02-VERIFICATION.md]
started: 2026-05-23T00:00:00Z
updated: 2026-05-23T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. App bar stays visible during scroll
expected: SliverAppBar remains visible at all scroll positions — does not hide when scrolling down or up through chapter content
result: [pending]

### 2. Table readability after wrapping
expected: Medical table content wraps vertically on narrow columns; text is legible at all screen widths (320px, 375px, 414px); no content clipped
result: [pending]

### 3. Section and subsection tap navigation
expected: Tapping a section or subsection in the TOC drawer closes the drawer and scrolls the reader to that content anchor; Scrollable.ensureVisible fires correctly with live GlobalKey contexts
result: [pending]

### 4. Active subsection highlight updates during scroll
expected: As user scrolls through the chapter, the currently-visible subsection becomes highlighted in neonTeal in the TOC; highlight updates smoothly as scroll position changes
result: [pending]

### 5. TOC resets to collapsed on every open
expected: Each time the TOC drawer is opened, all chapter ExpansionTiles are collapsed (not preserving prior expansion state); ValueKey(_drawerOpenCount) lifecycle reset works correctly
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
