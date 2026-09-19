---
quick_id: 260918-dr2
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, tabbar, tabbarview, osce, resource-topics, reader]

# Dependency graph
provides:
  - "SubtopicTabsView + subtopicTabsFor() in enchiridion/lib/widgets/common/subtopic_tabs.dart — the shared 'a topic opens into its own sub-topics' surface"
  - "OSCE station detail screen rewired onto per-station sub-topic tabs (no more all-stations TabBar)"
  - "ResourceTopicDetailScreen (Sutures, IV Cannula) rewired onto the same shared sub-topic tabs"
affects: ["260918-dr0", "260918-dr4", "260918-dr5"]

actuals:
  tokens: 8908
  tasks: 2
  commits: 2
  plan_head_before: 67181dbdc3030cf295d675dc8f09649058048488

tech-stack:
  added: []
  patterns:
    - "subtopicTabsFor(topic, chapter) is the single pure derivation for 'what are this topic's sub-topics' — content-backed topics slice by section/subsection, content-less topics use their authored outline"
    - "SubtopicTabsView is the shared stateful tab-strip widget every topic detail screen should render through, rather than inventing its own TabController"

key-files:
  created:
    - enchiridion/lib/widgets/common/subtopic_tabs.dart
    - enchiridion/test/widgets/subtopic_tabs_test.dart
  modified:
    - enchiridion/lib/screens/osce_screen.dart
    - enchiridion/lib/screens/resource_topic_detail_screen.dart
    - enchiridion/test/screens/osce_screen_test.dart

key-decisions:
  - "subtopicTabsFor precedence: chapter with 2+ sections -> one tab per section; chapter with exactly 1 section holding 2+ subsections -> one tab per subsection (the branch all three real topic JSONs take); chapter with 0-1 subsections -> a single unchanged-chapter tab; null chapter with a non-empty topic.outline -> one tab per outline entry (no content slice); null chapter with no outline -> a single tab titled with the topic title."
  - "Every content slice reuses the original ChapterSection/ChapterSubsection id/title/order/color verbatim (the section/subsection objects themselves are reused by reference where the original is copied whole) so blockAnchorId-keyed pinned/margin notes keep resolving after the split."
  - "SubtopicTabsView renders no TabBar at all when derivation yields <= 1 tab, so a one-sub-topic topic never shows a lone stub tab."
  - "TabBarView physics is left unset everywhere (no GestureDetector wrapping it either) so Flutter's default horizontal drag/swipe is what moves between sub-topics — this is the literal feature the user asked for."
  - "topic.description renders once, on the first tab only, inside SubtopicTabsView — not repeated per sub-topic, and no longer duplicated as a separate headlineSmall block in ResourceTopicDetailScreen's header (the AppBar already shows the topic title)."
  - "260918-dr5 ('the tab scroll feature is not for the topics, it is for the sub-topics within each topic') is fully delivered by this plan and needs no separate implementation — see 'For dr5' below."

requirements-completed: []

coverage:
  - id: D1
    description: "subtopicTabsFor derives subsection-based tabs for a content-backed topic (69/36/28-subsection JSONs) and outline-based tabs for a content-less topic, preserving section/subsection ids in every slice, with a non-empty fallback label for blank titles"
    verification:
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#subtopicTabsFor (pure derivation)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Opening an OSCE station shows only that station's own sub-topics as tabs (never other stations), and a horizontal drag on the content area advances/returns the tab index by one"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#dragging the content area sideways advances the tab controller by one, and dragging back returns it"
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#OSCE list has no TabBar; opening a content-less station shows its own outline as tabs"
    human_judgment: false
  - id: D3
    description: "Sutures / IV Cannula (ResourceTopicDetailScreen) render through the same SubtopicTabsView, with the loading/error branches and list-screen contract byte-for-byte unchanged"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView a topic with no content and a 4-entry outline shows a TabBar with 4 labels, swipeable by drag"
      - kind: automated_ui
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart#SubtopicTabsView a topic whose derivation yields a single entry renders no TabBar"
      - kind: automated_ui
        ref: "enchiridion/test/screens/resource_topic_list_screen_test.dart#tapping the available card pushes the detail screen"
    human_judgment: false

duration: 45min
completed: 2026-09-19
status: complete
---

# Quick Item 260918-dr2: Sub-Topic Tabs Summary

**A shared `SubtopicTabsView`/`subtopicTabsFor()` module now drives per-topic swipeable sub-topic tabs across OSCE stations and Surgical/Medical Instrumentation detail screens, replacing OSCE's old all-stations tab strip.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-09-19T07:10:00Z (approx.)
- **Completed:** 2026-09-19T07:54:58Z
- **Tasks:** 2/2
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- New `enchiridion/lib/widgets/common/subtopic_tabs.dart`: pure `subtopicTabsFor({topic, chapter})` derivation plus `SubtopicTabsView` stateful widget — the single place the app now decides what a topic's sub-topics are.
- `osce_screen.dart` rewired end-to-end: `OsceScreen` pushes the tapped `ResourceTopic` itself (not an index into all stations); `_OsceDetailScreen` loads only that one topic's chapter and renders `SubtopicTabsView` — the old all-stations `TabBar`/`TabBarView`, `_OsceTabBody`, and `_OutlinePlaceholder` are gone.
- `resource_topic_detail_screen.dart` (Sutures, IV Cannula) rewired onto the same `SubtopicTabsView`, so every topic in the app — not just OSCE — opens into swipeable sub-topic tabs. Loading/error branches and the list-screen's error-path test contract are unchanged.
- A horizontal drag on the content area moves to the adjacent sub-topic and back, proven by automated `tester.drag` + `pumpAndSettle` assertions in both `osce_screen_test.dart` and `subtopic_tabs_test.dart` (not just code inspection).
- A topic whose derivation yields exactly one sub-topic renders no tab strip at all (verified for both the outline-only and content-slicing code paths).

## Task Commits

Each task was committed atomically:

1. **Task 1: Sub-topic tab derivation + swipeable tabs, wired end to end through OSCE** - `b82a2c2` (feat)
2. **Task 2: Give the Sutures / IV Cannula topic detail screen the same swipeable sub-topic tabs** - `6ff0a81` (feat)

_Both tasks were TDD: tests for the derivation, the swipe drag, and the new screen contracts were written alongside/immediately verified against the implementation before each commit; `flutter test`/`flutter analyze` were run and green before every commit._

## Files Created/Modified

- `enchiridion/lib/widgets/common/subtopic_tabs.dart` - **New.** `SubtopicTab`, `subtopicTabsFor()`, `SubtopicTabsView` — the shared sub-topic tab derivation and widget every topic surface now consumes.
- `enchiridion/test/widgets/subtopic_tabs_test.dart` - **New.** Pure unit tests over hand-built `Chapter` fixtures for every `subtopicTabsFor` branch (2+ sections, 1 section with 2+ subsections, single-tab fallback, outline-driven, no-outline fallback, blank-title guard), plus `SubtopicTabsView` widget tests (4-entry outline TabBar + drag-to-index-1, single-entry renders no TabBar).
- `enchiridion/lib/screens/osce_screen.dart` - `OsceScreen.onTap` now pushes `_OsceDetailScreen(topic: topic)`; `_OsceDetailScreen` holds `Chapter?`/`Object?` for one topic and renders `SubtopicTabsView`; `_OsceTabBody`/`_OutlinePlaceholder` deleted.
- `enchiridion/test/screens/osce_screen_test.dart` - Rewritten for the new contract: station-scoped `TabBar` labels resolved via `kOsceTopics` lookups (never hardcoded title literals, so `260918-dr1`/`260918-dr6` renames can't break these tests), plus a dedicated drag-swipe test.
- `enchiridion/lib/screens/resource_topic_detail_screen.dart` - Success branch now renders hero image, category label, then `Expanded(child: SubtopicTabsView(...))`; `_chapter` typed `Chapter?`; duplicated `headlineSmall` title block removed (AppBar already shows it); `_load()`/loading/error branches untouched.

## Decisions Made

See `key-decisions` in frontmatter. In short: the derivation precedence is section-count-first, then subsection-count, then outline, then a bare single tab; every slice preserves original ids verbatim for note-anchor safety; the tab strip disappears entirely below 2 tabs; and `TabBarView` is never given custom physics or wrapped in a competing gesture detector, so the default swipe is the mechanism.

## Deviations from Plan

**Worktree was stale relative to `main` at spawn time** (this is infrastructure, not a plan deviation, but is recorded for traceability): this worktree's branch (`worktree-agent-a1fb52e4ff3ad7f91`) was created from a commit that predates the `260918-dqw` batch's planning commits, so `260918-dr2-PLAN.md` did not exist on disk at task start. Verified the worktree branch was a strict ancestor of `main` with no unique commits (`git merge-base --is-ancestor` returned true), then fast-forwarded (`git merge --ff-only main`) to bring in the plan file and all prior sibling work (`260917-*`, `260918-dqx`/`dqy`, etc.) before starting. No destructive git operations were used; this was a pure fast-forward.

Otherwise: None - plan executed exactly as written.

## Issues Encountered

- The first `tester.drag(..., Offset(-400, 0))` attempt on a `TabBarView` in an 800×600 test viewport did not cross the page-snap threshold (exactly half the viewport width). Increased the drag offset to `Offset(-500, 0)` in both `subtopic_tabs_test.dart` and `osce_screen_test.dart`, which reliably advances the `TabController` by one index, confirmed by three separate test runs.
- Could not write outside the worktree's own directory (a hard sandbox boundary for isolated agents), so the `gsd-plan-head-before-260918-dr2` ledger file could not be persisted to `.git/worktrees/<name>/`. The base commit (`67181dbdc3030cf295d675dc8f09649058048488`, i.e. `main`'s `HEAD` immediately after the fast-forward, before any task commit) was instead captured directly and is recorded in `actuals.plan_head_before` above; `commits: 2` was measured via `git rev-list --count 67181db..HEAD`.

## For dr5

Sibling `260918-dr5` ("the tab scroll feature is not for the topics, it is for the sub-topics within each topic") is the same feature request as this item, one message later. It is fully delivered here — no separate implementation is needed. If `260918-dr5` is dispatched with its own tasks against `osce_screen.dart`, it should be collapsed into a no-op confirmation of this plan's behavior rather than re-implementing sub-topic tabs.

## For dr0/dr4

`260918-dr0` (Surgical Instrumentation list) and `260918-dr4` (Medical Instrumentation list) should push their list rows to `ResourceTopicDetailScreen` (already wired to `SubtopicTabsView` by this plan) or, for any new topic-shaped screen, consume `SubtopicTabsView(topic:, chapter:)` directly rather than building a new tab strip. This plan does not touch `resource_topic_list_screen.dart`.

## Next Phase Readiness

- `SubtopicTabsView`/`subtopicTabsFor` are stable, tested, and ready for any future topic surface to consume.
- `flutter analyze lib/ test/` and `flutter test` (full suite, 171 tests) are both green; the only analyzer findings are 9 pre-existing issues in unrelated files (untouched by this plan).

---
*Quick item: 260918-dr2 (batch 260918-dqw)*
*Completed: 2026-09-19*

## Self-Check: PASSED

All files created/modified confirmed present on disk; both task commits (`b82a2c2`, `6ff0a81`) confirmed present in `git log`.
