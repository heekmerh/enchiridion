---
quick_id: 260919-kiw
batch_id: 260919-kir
subsystem: ui
tags: [flutter, scrollspy, tabbar, autoscrollcontroller, osce, instrumentation]

# Dependency graph
requires: ["260918-dr2", "260918-dr5"]
provides:
  - "SubtopicTabsView (enchiridion/lib/widgets/common/subtopic_tabs.dart) now renders one continuous CustomScrollView per topic, driven by a shared AutoScrollController, instead of a TabBarView pager — the single mechanism behind Surgical Instrumentation, Medical Instrumentation, and OSCE detail screens"
  - "SubtopicTab.anchorId — an additive getter resolving a tab's scroll-anchor id from its existing slice, with no change to subtopicTabsFor's derivation or its 8 pinned unit tests"
  - "Scrollspy: the tab strip auto-advances to whichever sub-topic is currently under the top of the content area, driven by AutoScrollController.tagMap and an activation line derived from the scroll view's own RenderBox (not a fixed screen offset)"
  - "The sideways swipe affordance from 260918-dr2 restored as a GestureDetector.onHorizontalDragEnd fling on the one scroll view, rather than TabBarView's own paging gesture"
affects: ["260919-kiy"]

actuals:
  tokens: 8324
  tasks: 3
  commits: 2
  plan_head_before: 7662dc01adfba2888d81a523430da220f1262f8e

tech-stack:
  added: []
  patterns:
    - "One shared CustomScrollView + AutoScrollController per topic-shaped screen, mirroring reader_screen.dart's existing chapter-reading pattern (scrollToIndex / tagMap-based scrollspy), rather than a bespoke mechanism for resource topics"
    - "subtopicTabsFor's slices are now read-only metadata (tab labels + scroll anchors) — the content-backed render path always draws the ORIGINAL, unsliced chapter exactly once via ReaderContent(asSliver: true), never the per-tab slices, to avoid repeating the source section header once per sub-topic"
    - "TickerProviderStateMixin (not SingleTickerProviderStateMixin) for any State that may rebuild its own TabController mid-life — a chapter arriving asynchronously from null to non-null changes the tab count, which disposes and recreates the TabController; SingleTickerProviderStateMixin permits creating exactly one ticker for the State's entire lifetime and crashes on the second, even though the first was already disposed"

key-files:
  created: []
  modified:
    - enchiridion/lib/widgets/common/subtopic_tabs.dart
    - enchiridion/test/widgets/subtopic_tabs_test.dart
    - enchiridion/test/screens/osce_screen_test.dart

key-decisions:
  - "Split the rewrite into two commits matching the plan's tracer/expansion task boundary: Task 1 shipped the content-backed continuous-scroll + scrollspy slice only, with the outline-only (no content JSON yet) multi-tab path temporarily still paging through the old TabBarView; Task 2 then unified that last path onto the same CustomScrollView design and restored the sideways fling. This let the tracer feedback gate (re-running Task 1's own <verify> end-to-end) prove the core mechanism before expanding, per this plan's `type=\"tracer\"` task."
  - "SubtopicTab.anchorId resolves as the first subsection id of the tab's slice's single section, falling back to the section id, null when the tab has no content — covers all three content branches of subtopicTabsFor (multi-section, one-section-many-subsections, whole-chapter) with no new fields and no change to that function's derivation, so its 8 pinned unit tests and test/utils/osce_subtopics_test.dart's real-Abdominal-content test stay valid unmodified."
  - "For the outline-only (no content JSON) path, each tab's own AutoScrollTag index equals its tab position directly — no need to route through BlockRenderer's onItemIndexesReady map at all, since there is no BlockRenderer on that path. This keeps the tap/scrollspy code identical across both content shapes, branching only in how the anchor index is resolved (see _anchorIndexFor)."
  - "Scrollspy's activation line is `scroll view's own RenderBox top + 16px`, not reader_screen.dart's fixed screen-relative `100`, because ResourceTopicDetailScreen stacks a 16:9 hero image, a category label, and this tab strip above the scroll view — a fixed screen offset would sit above the viewport and always resolve to the wrong sub-topic (documented in the plan's context block and mirrored as an inline comment)."
  - "Deleted the now-dead _SubtopicBody widget (the per-tab ListView body) entirely rather than keeping it in a reduced form — the content-backed path never renders per-tab slices anymore (it draws the original chapter once), and the outline-only path's ComingSoonSubtopicBody was converted directly to a non-scrolling Column, so no caller remained."
  - "Converted _ComingSoonSubtopicBody from a self-scrolling ListView to a plain, non-scrolling Column — it is now an item inside the shared outer scroll view (either directly in a sliver, or, during Task 1's interim state, inside the old TabBarView's bounded-viewport page), so a nested Scrollable would have reintroduced the very content boundary this plan removes."

requirements-completed: []

coverage:
  - id: D1
    description: "A content-backed topic (chapter with multiple sub-topics) scrolls continuously from the first sub-topic straight into the last with no tab tap, and the source section header renders exactly once rather than once per tab"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll a content-backed topic renders one Scrollable in the content area with no per-tab pager"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll scrolling down without tapping a tab eventually reaches the fourth sub-topic heading"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll the source section title is rendered exactly once, not once per tab"
        status: pass
    human_judgment: false
  - id: D2
    description: "As the reader scrolls a content-backed topic, the tab strip's selected tab follows along to name whichever sub-topic is currently under the top of the content area, with no tab ever tapped"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll scrolling the third sub-topic to the top of the content area moves the tab controller to index 2 with no tap"
        status: pass
    human_judgment: false
  - id: D3
    description: "Tapping a tab scrolls the one content view to that sub-topic instead of swapping the content out, and the previously-open sub-topic's content is no longer on screen"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll tapping the fourth tab settles with that sub-topic visible and the controller index at 3"
        status: pass
    human_judgment: false
  - id: D4
    description: "A sideways fling still moves one sub-topic forward or back (both on synthetic content-backed and outline-only topics, and on the real OSCE Cardiovascular System station), a vertical drag is unaffected, and the async chapter arrival (null -> 4-subtopic chapter) rebuilds the TabController without a ticker crash"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView outline-only continuous scroll and fling a leftward fling advances the controller index by one and settles with the next entry in view"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView outline-only continuous scroll and fling a rightward fling returns to the previous entry, index and content together"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView outline-only continuous scroll and fling a vertical drag still scrolls the content and leaves the fling handler inert"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView content-backed continuous scroll rebuilding from a null chapter to a 4-subtopic chapter swaps the outline view for content and scrollspy keeps working"
        status: pass
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#flinging the content area sideways advances the tab controller by one, and flinging back returns it"
        status: pass
    human_judgment: false
  - id: D5
    description: "A topic with no written content still shows one tab per outline entry, and scrolling those coming-soon bodies is continuous (no tab tap needed to reach the last entry) — proven both on a synthetic outline topic and the real OSCE screen's content-less Cardiovascular System station"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView outline-only continuous scroll and fling scrolling down without tapping a tab reaches the fourth outline entry"
        status: pass
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView outline-only continuous scroll and fling scrolling the third outline entry to the top moves the tab controller to index 2 with no tap"
        status: pass
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#opening a content-less station (Cardiovascular System) scrolls continuously through its outline with no tab tap"
        status: pass
    human_judgment: false

duration: 70min
completed: 2026-09-19
status: complete
---

# Quick Item 260919-kiw: Continuous Scroll With Scrollspy Tab Strip Summary

**Rewrote `SubtopicTabsView`'s content area from a `TabBarView` pager into one continuous `CustomScrollView` driven by a shared `AutoScrollController`, with the tab strip demoted to a scrollspy indicator — fixing the "abrupt halt" reported across Surgical Instrumentation, Medical Instrumentation, and OSCE.**

## Accomplishments

- Module content in every topic-shaped screen (Surgical Instrumentation, Medical Instrumentation,
  OSCE) now scrolls continuously from the first sub-topic straight through to the last, on both
  content-backed topics (Abdominal Examination, Sutures, IV Cannula shape) and outline-only
  (coming-soon) topics — no tab tap required anywhere in between.
- The tab strip auto-advances via scrollspy to name whichever sub-topic is currently under the top
  of the content area, mirroring `reader_screen.dart`'s existing `AutoScrollController.tagMap`
  pattern but with an activation line derived from the scroll view's own on-screen position rather
  than a fixed offset (this screen stacks a hero image and category label above the content, which
  a fixed screen-relative number would have sat above).
- Tapping a tab now scrolls the single content view to that sub-topic (`Scrollable.ensureVisible`,
  falling back to `AutoScrollController.scrollToIndex`) instead of paging a `TabBarView`.
- The sideways-fling affordance shipped by sibling `260918-dr2` survives, re-implemented as a
  `GestureDetector.onHorizontalDragEnd` fling on the one scroll view rather than `TabBarView`'s own
  paging gesture; vertical reading scrolling is unaffected since the horizontal recognizer never
  contends with the vertical scrollable's drag arena.
- `subtopicTabsFor`'s pure derivation (and its 8 pinned unit tests, plus sibling `260918-dr5`'s
  real-Abdominal-content heading-grouping test) is completely untouched — the rewrite only reads
  its output (via one additive `SubtopicTab.anchorId` getter) rather than changing what it computes.
- Fixed a pre-existing, previously-untriggered bug: rebuilding the `TabController` when the tab
  count changes (e.g. a chapter arriving asynchronously) crashed with "SingleTickerProviderStateMixin
  … multiple tickers were created", because that mixin permits creating only one ticker for the
  entire lifetime of the State object even after the first `AnimationController` (and its ticker)
  is disposed. Switched to `TickerProviderStateMixin`.

## Task Commits

Each task was committed atomically:

1. **Task 1: One continuous scroll view with a scrollspy tab strip, proven end-to-end on a content-backed topic** - `8f71951` (feat, tracer)
2. **Task 2: Continuous outline-only topics, and the sideways fling re-pointed at the new scroll** - `0ed9d91` (feat)
3. **Task 3: Regression sweep across all three affected surfaces** - no code changes required; scoped `flutter analyze`, the full `flutter test` suite (261/261), and the plan's grep gates (`AutoScrollController` present, `SubtopicTabsView` still the sole mechanism in both screen files, no `TabBarView(` on any non-comment line) all passed against Task 2's commit with nothing left to fix or commit.

## Files Created/Modified

- `enchiridion/lib/widgets/common/subtopic_tabs.dart` - `SubtopicTab` gains the additive `anchorId`
  getter. `_SubtopicTabsViewState` rewritten to own an `AutoScrollController` alongside its
  `TabController`, render one `CustomScrollView` (content-backed or outline-only, single-tab or
  multi-tab), run the scrollspy listener, resolve tab-tap/fling scrolling, and guard the
  scrollspy against fighting a tap-initiated scroll. `_SubtopicBody` deleted (dead code once the
  content-backed path draws the original chapter directly); `_ComingSoonSubtopicBody` converted
  from a self-scrolling `ListView` to a non-scrolling `Column` suitable for use as a sliver item.
- `enchiridion/test/widgets/subtopic_tabs_test.dart` - Re-pointed the pre-existing outline-topic
  drag test at a fling instead of a `TabBarView` drag. Added two new widget-test groups: one
  proving continuous scroll, scrollspy, tab-tap-scrolls, single-render-of-the-source-section, and
  async chapter-arrival behaviour on a synthetic tall content-backed chapter (wrapped in the
  `StorageService`/`SettingsProvider`/`PinnedNotesProvider` harness `BlockRenderer` requires); one
  proving the same continuity/scrollspy/fling/vertical-scroll-survival behaviours on a
  height-constrained outline-only topic. All 8 pure `subtopicTabsFor` unit tests are untouched.
- `enchiridion/test/screens/osce_screen_test.dart` - Re-pointed the Cardiovascular-station drag
  test at a fling on the new `CustomScrollView`; added a test proving the real content-less
  station's outline scrolls to its last entry with no tab tap. The station-list, coming-soon-badge,
  and Abdominal-Examination heading-grouping tests are untouched and still pass.

## Decisions Made

See `key-decisions` in frontmatter. In short: split the two-task plan into two matching commits so
the tracer task's own feedback gate could verify the core content-backed mechanism end-to-end
before expanding to the outline-only path and fling gesture; kept `subtopicTabsFor`'s derivation
completely untouched by reading its output through one additive getter; fixed a real, previously-
dormant `SingleTickerProviderStateMixin` bug that this plan's async-chapter-arrival test finally
exercised.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a `SingleTickerProviderStateMixin` crash on async chapter arrival**
- **Found during:** Task 1, while writing the "rebuilding from a null chapter to a 4-subtopic
  chapter" test (a scenario every real caller of `SubtopicTabsView` hits, since `chapter` always
  arrives asynchronously from an asset load).
- **Issue:** `_SubtopicTabsViewState` disposes and recreates its `TabController` whenever the tab
  count changes (pre-existing logic, unchanged by this plan). `SingleTickerProviderStateMixin`
  only permits creating one `Ticker` for the entire lifetime of the `State` object — disposing the
  old `TabController`'s `AnimationController` does not reset the mixin's internal ticker reference,
  so the second `TabController(..., vsync: this)` throws "A SingleTickerProviderStateMixin can
  only be used as a TickerProvider once." This was a real, pre-existing latent bug (present before
  this plan's changes too) that no existing test exercised until this plan's own async-arrival test
  did.
- **Fix:** Switched `_SubtopicTabsViewState` from `SingleTickerProviderStateMixin` to
  `TickerProviderStateMixin`, which supports creating a new ticker each time the old one is
  disposed — exactly Flutter's documented recommendation for this scenario.
- **Files modified:** `enchiridion/lib/widgets/common/subtopic_tabs.dart`
- **Verification:** The async-chapter-arrival test passes; full `flutter test` suite (261/261)
  unaffected.
- **Committed in:** `8f71951` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Necessary for correctness — every real caller of `SubtopicTabsView` loads its
chapter asynchronously, so this crash would have reached production on first use of the rewritten
widget. No scope creep beyond the one-line mixin change.

## Issues Encountered

- Two widget tests (`scrolling the third sub-topic ...` and its outline-only counterpart) initially
  used `tester.scrollUntilVisible`'s internal zero-duration `Scrollable.ensureVisible` jump to
  position a heading for a scrollspy assertion. That jump's scroll-position notification fires
  synchronously, before the resulting layout is built, so the scrollspy read one-frame-stale
  render-box positions and landed on the wrong tab. Replaced with a small helper
  (`_dragUntilTabIndex`) that drives real, frame-synced `tester.drag()` steps and stops once the
  controller reaches the expected index — closer to how a real user scrolls, and not subject to
  the jump-timing artifact. This was a test-harness-only issue; the production scrollspy code
  (which only ever receives real, incremental scroll-position updates) was not affected.
- The synthetic outline-only test fixture's four coming-soon bodies were shorter than the default
  600px test viewport, so there was almost nothing to scroll and the scrollspy could never advance
  past index 0. Constrained the test `Scaffold` body to `SizedBox(height: 220)` for that test group
  so there is genuine scroll distance to exercise.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three reported surfaces (Surgical Instrumentation, Medical Instrumentation, OSCE) now share
  one continuously-scrolling, scrollspy-driven mechanism with no code path left rendering a
  per-tab pager.
- Sibling `260919-kiy` (routing Medical Instrumentation's list screen through
  `ResourceTopicDetailScreen`) inherits this fix automatically, with no coordination needed in
  either merge order, since it changes only the list screen, never `subtopic_tabs.dart`.
- No model, list screen, or content JSON was touched, so siblings `260919-kix`, `260919-kiy`, and
  `260919-kiz` merge without conflict from this item.

## Self-Check: PASSED

All modified files confirmed present on disk with the expected content; both task commits
(`8f71951`, `0ed9d91`) confirmed present in `git log`. Full `flutter test` suite: 261/261 passing.
Scoped `flutter analyze lib/widgets/common/subtopic_tabs.dart test/widgets/subtopic_tabs_test.dart
test/screens/osce_screen_test.dart`: no issues found.

---
*Quick item: 260919-kiw (batch 260919-kir)*
*Completed: 2026-09-19*
