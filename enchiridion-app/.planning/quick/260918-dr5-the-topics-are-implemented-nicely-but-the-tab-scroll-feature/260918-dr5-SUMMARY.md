---
quick_id: 260918-dr5
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, tabbar, tabbarview, osce, resource-topics, subtopic-grouping]

# Dependency graph
requires: ["260918-dr2"]
provides:
  - "isOsceSubtopicHeading (enchiridion/lib/utils/osce_subtopics.dart) — the OSCE-specific ALL-CAPS-heading detector"
  - "subtopicTabsFor's additive isSectionHeading parameter (enchiridion/lib/widgets/common/subtopic_tabs.dart) — heading-grouping override for the '1 section, 2+ subsections' branch"
  - "OsceScreen.testChapterLoader test-injection hook, mirroring ExamPrepHomeScreen.testQuestions/ReaderScreen.testBookProvider"
affects: ["260918-dr6"]

actuals:
  tokens: 5563
  tasks: 2
  commits: 2
  plan_head_before: b806ba76553d955194f9d59aa9299f55e26cda5a

tech-stack:
  added: []
  patterns:
    - "isSectionHeading is an additive, optional parameter on the shared subtopicTabsFor — every caller that omits it (Sutures, IV Cannula) keeps dr2's original one-tab-per-subsection behaviour byte-for-byte; only OSCE's call site supplies it"
    - "Grouping preserves every original ChapterSubsection object (id, content_groups) inside its group's slice rather than merging/flattening subsections, so blockAnchorId-keyed note anchors never move"

key-files:
  created:
    - enchiridion/lib/utils/osce_subtopics.dart
    - enchiridion/test/utils/osce_subtopics_test.dart
  modified:
    - enchiridion/lib/widgets/common/subtopic_tabs.dart
    - enchiridion/lib/screens/osce_screen.dart
    - enchiridion/test/screens/osce_screen_test.dart

key-decisions:
  - "Worktree was a strict ancestor of main with no unique commits at spawn time (created before 260918-dr2 landed); fast-forwarded via `git merge --ff-only main` before starting, per this plan's constraints, so all work builds on dr2's actual landed osce_screen.dart / subtopic_tabs.dart rather than a stale pre-dr2 snapshot."
  - "dr2's SUMMARY explicitly claims dr5 'is fully delivered' — this is TRUE for the topic-vs-sub-topic axis correction (the primary user complaint) but FALSE for the Abdominal Examination heading-inference requirement: dr2's '1 section, 2+ subsections' branch emits one raw tab per subsection, which for the real 69-subsection Abdominal JSON means 69 tabs including sentence-case continuations ('Light palpation', 'What is guarding?', 26 individual viva questions) as their own tabs. Verified this gap directly against the real asset before writing any code (see 'Verification performed' below)."
  - "Closed the gap by EXTENDING dr2's shared subtopicTabsFor with an additive, backward-compatible isSectionHeading parameter, rather than duplicating its TabBar/TabBarView mechanism with a separate derivation+widget (which the plan's sibling_ordering section explicitly warned against). The parameter only changes behaviour when supplied; every non-OSCE caller is unaffected."
  - "Did NOT touch lib/models/resource_topic.dart, matching this plan's verification requirement that siblings dr0/dr1/dr3/dr6 merge without conflict."
  - "isOsceSubtopicHeading strips a leading single-letter enumerator ('A. ', 'B. ') then keeps only letters; returns true when the surviving letters are empty or all-uppercase. This is the exact predicate the plan's context section describes, and running it against the real abdominal_examination.json (via python, then confirmed via the Dart test) yields exactly 33 groups from 69 subsections, first titled 'INTRODUCTION (OSCE OPENING)' — matching the plan's own pre-computed numbers."
  - "Grouping groups whole original ChapterSubsection objects (not merged/flattened content) so every block's blockAnchorId(section.id, subsection.id, group.id, index) is byte-for-byte unchanged from dr2's un-grouped slices — clip/pin note anchors for any subsection that already has notes stay valid."

requirements-completed: []

coverage:
  - id: D1
    description: "isOsceSubtopicHeading correctly classifies ALL-CAPS headings (with/without leading enumerator), short/symbol-joined abbreviations, no-letter titles, and rejects any mixed-case or lowercase title as a heading"
    verification:
      - kind: unit
        ref: "enchiridion/test/utils/osce_subtopics_test.dart#isOsceSubtopicHeading"
        status: pass
    human_judgment: false
  - id: D2
    description: "subtopicTabsFor with isSectionHeading groups the real, shipped 69-subsection Abdominal Examination chapter into heading-bounded sub-topics: first tab titled INTRODUCTION (OSCE OPENING), strictly fewer tabs than subsections, no tab titled a pure continuation ('Light palpation', 'What is guarding?'), and the conservation invariant (concatenating every tab's subsections reproduces the source list exactly) holds"
    verification:
      - kind: unit
        ref: "enchiridion/test/utils/osce_subtopics_test.dart#subtopicTabsFor with isSectionHeading (real Abdominal content) — reads the shipped asset.json with dart:io, skips gracefully if absent"
      - kind: manual
        ref: "python simulation against assets/data/resources/abdominal_examination.json's 69 real subsection titles: 33 groups, first 'INTRODUCTION (OSCE OPENING)', no 'Light palpation' group"
      - status: pass
    human_judgment: false
  - id: D3
    description: "Opening Abdominal Examination through the real OsceScreen tap-to-detail flow (not just the pure derivation) renders the grouped tabs in the actual TabBar, and every non-OSCE caller (Sutures/IV Cannula via ResourceTopicDetailScreen) is provably unaffected since the parameter is optional and they never pass it"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#opening a content-backed station (Abdominal Examination) groups sub-topics by heading, never one tab per raw subsection"
      - kind: unit
        ref: "enchiridion/test/widgets/subtopic_tabs_test.dart (dr2's pre-existing suite, re-run unmodified and still green — proves the default isSectionHeading:null path is untouched)"
    human_judgment: false

duration: 40min
completed: 2026-09-19
status: complete
---

# Quick Item 260918-dr5: OSCE Sub-Topic Heading Grouping Summary

**Extended sibling `260918-dr2`'s already-landed sub-topic tab mechanism with an additive, OSCE-only heading-grouping override, so Abdominal Examination's 69 raw subsections collapse into 33 meaningful sub-topic tabs instead of surfacing every continuation paragraph and viva question as its own tab.**

## Verification performed before writing any code

This item's `sibling_ordering` and required reading pointed to `260918-dr2`'s SUMMARY, which
states dr5 "is fully delivered by this plan and needs no separate implementation." Before
trusting that claim, this executor:

1. Fast-forwarded the worktree branch to `main`'s tip (see Deviations below), then read the
   actual landed `enchiridion/lib/screens/osce_screen.dart` and
   `enchiridion/lib/widgets/common/subtopic_tabs.dart`.
2. Confirmed dr2 does fully deliver the plan's axis correction (must-haves 1, 2, 5): opening a
   station shows only that station's own sub-topics, swipe stays inside the station, the
   station is named once in the app bar, and the station list itself is untouched.
3. Independently counted the real `assets/data/resources/abdominal_examination.json` — one
   section, 69 subsections. Traced dr2's own derivation logic (`sections.length == 1 &&
   subsections.length >= 2` → one tab per subsection) and confirmed it would render **69 raw
   tabs** for Abdominal Examination, including tabs literally titled `Light palpation`, `Deep
   palpation`, `What is guarding?`, and 26 individual viva-question tabs — dr2's own test suite
   (`subtopic_tabs_test.dart`) never exercises the real asset shape, only small synthetic
   fixtures, so this was untested and unnoticed.
4. Simulated this plan's heading-inference algorithm (leading-enumerator strip + all-letters-
   uppercase check) in Python against the real 69 titles: **33 groups**, first
   `INTRODUCTION (OSCE OPENING)`, matching the plan author's own pre-computed numbers exactly.

Conclusion: dr2 delivered the axis fix completely but did **not** deliver the heading-inference
requirement for Abdominal Examination (must-have 3) or Task 1's specific test 8 assertions (`a
sub-topic count strictly smaller than the source subsection count`, `no sub-topic titled
'Light palpation'`). This is a real, verified gap, not a restatement of dr2's work — closed with
a minimal, additive extension rather than a rebuild (see Key Decisions).

## Accomplishments

- New `enchiridion/lib/utils/osce_subtopics.dart`: pure `isOsceSubtopicHeading(String)` predicate,
  no Flutter imports, unit-tested in isolation against every case class from the plan (ALL-CAPS,
  enumerator-prefixed, short abbreviations, symbol-joined abbreviations, no-letter titles,
  sentence-case, mixed-case).
- `subtopicTabsFor` (dr2's shared derivation) gains an additive `isSectionHeading` parameter.
  Supplying it changes ONLY the "1 section, 2+ subsections" branch: instead of one tab per raw
  subsection, it groups subsections in authored order by heading boundary, preserving every
  original `ChapterSubsection` (id + content_groups) inside its group's slice — so
  `blockAnchorId`-keyed note anchors are exactly as stable as dr2's un-grouped slices were.
  Omitting the parameter (every caller except OSCE) is provably unchanged — dr2's own
  `subtopic_tabs_test.dart` suite re-runs green, untouched.
- `OsceScreen` gains a `testChapterLoader` test-injection hook (mirrors
  `ExamPrepHomeScreen.testQuestions` / `ReaderScreen.testBookProvider`) and its detail screen
  now passes `isOsceSubtopicHeading` into `SubtopicTabsView`. A new widget test drives the real
  tap-to-detail flow with a synthetic Abdominal-shaped chapter and asserts the rendered `TabBar`
  shows 3 grouped tabs (`A. INSPECTION`, `B. PALPATION`, `C. PERCUSSION`), not 5 raw-subsection
  tabs, and that neither continuation title ever appears as its own tab.
- A new unit test reads the real, shipped `abdominal_examination.json` off disk with `dart:io`
  (never `rootBundle`, per this project's established widget-test trap) and proves, against the
  actual production content: first tab `INTRODUCTION (OSCE OPENING)`, 33 tabs (strictly fewer
  than 69 subsections), no tab titled `Light palpation` or `What is guarding?`, and the
  conservation invariant — concatenating every tab's subsections reproduces the source
  subsection list exactly (same ids, same order, nothing dropped or duplicated).

## Task Commits

Each task was committed atomically:

1. **Heading-detection utility + isolated predicate tests** - `b779476` (feat)
2. **Wire heading-grouping into subtopicTabsFor + OsceScreen, with real-content and real-flow tests** - `0b514de` (feat)

## Files Created/Modified

- `enchiridion/lib/utils/osce_subtopics.dart` - **New.** `isOsceSubtopicHeading(String title)`,
  pure string logic, no Flutter import.
- `enchiridion/test/utils/osce_subtopics_test.dart` - **New.** Predicate unit tests plus an
  integration-level test proving `subtopicTabsFor(..., isSectionHeading: isOsceSubtopicHeading)`
  groups the real shipped Abdominal JSON correctly (skips gracefully if the asset is absent from
  a sparse checkout).
- `enchiridion/lib/widgets/common/subtopic_tabs.dart` - `subtopicTabsFor` and `SubtopicTabsView`
  both gain an optional, additive `isSectionHeading` parameter; default `null` behaviour is
  byte-for-byte unchanged (dr2's own test suite re-verifies this).
- `enchiridion/lib/screens/osce_screen.dart` - `OsceScreen` gains `testChapterLoader`; detail
  screen's `SubtopicTabsView` call now passes `isSectionHeading: isOsceSubtopicHeading`.
- `enchiridion/test/screens/osce_screen_test.dart` - Added a widget test for the content-backed
  (Abdominal Examination) path through the real tap-to-detail flow, wrapped in the
  `MultiProvider` harness (`StorageService`, `SettingsProvider`, `PinnedNotesProvider`) that
  `ReaderContent`/`BlockRenderer` require, mirroring `block_renderer_test.dart`'s pattern.

## Decisions Made

See `key-decisions` in frontmatter. In short: extend dr2's shared derivation with an additive,
OSCE-only parameter rather than duplicating its widget mechanism; preserve every original
subsection object (not merged) inside a group's slice so note anchors never move; keep the
change fully backward-compatible for every non-OSCE caller.

## Deviations from Plan

**Worktree was stale relative to `main` at spawn time** (infrastructure, not a plan deviation,
recorded per this plan's constraints): this worktree's branch (`worktree-agent-a4ba0804e3b3c53d5`)
was a strict ancestor of `main` with zero unique commits (`git merge-base --is-ancestor` true),
predating sibling `260918-dr2`'s landed commits. Fast-forwarded (`git merge --ff-only main`)
before starting, bringing in `260918-dr2-PLAN.md`/`SUMMARY.md` and its actual landed
`osce_screen.dart`/`subtopic_tabs.dart`. No destructive git operations were used.

**Did not create the plan's originally-specified `osceSubtopicsFor` full derivation function** —
the plan was written before dr2 (which lands in the same batch) built a shared, already-adopted
`subtopicTabsFor`/`SubtopicTabsView` mechanism used by three screens. Building a second, parallel
derivation function plus a second widget-facing tab strip for OSCE alone would have duplicated
dr2's mechanism exactly as this plan's `sibling_ordering` section warned against ("Read the file
as it actually is before editing... After this plan, the sub-topic tab layout is the
authoritative one" — meaning dr2's `SubtopicTabsView`, not a second one). Instead, extended the
existing mechanism with a minimal, backward-compatible parameter. The plan's stated file list
(`lib/utils/osce_subtopics.dart`, `test/utils/osce_subtopics_test.dart`) is honored for the new
files; the plan's other listed files (`osce_screen.dart`, `osce_screen_test.dart`) are also
exactly as specified. `subtopic_tabs.dart` (not in the plan's original `files_modified`, since
the plan predates its existence) is the one file touched beyond the plan's original file list —
necessary because it is the sole entry point into `SubtopicTabsView`'s tab derivation.

Otherwise: task behavior tests were adapted from the plan's original `osceSubtopicsFor`-shaped
spec (Task 1's tests 1-8) to the shape that actually reaches production
(`subtopicTabsFor(..., isSectionHeading: ...)`), preserving every one of the plan's substantive
assertions (heading predicate cases, conservation invariant, real-content grouping, no
continuation-titled tabs) rather than testing a function that no longer exists in the shipped
code path.

## Issues Encountered

None beyond the dr2-completeness gap documented above (found deliberately, not accidentally, by
verifying dr2's claim against the real asset before trusting it).

## For dr6

`260918-dr6` depends on this item and reads this SUMMARY for the final state of station/topic
titles in `osce_screen.dart`. Final state: `_OsceDetailScreen`'s `AppBar` title is
`widget.topic.title` (the station name, shown exactly once); no station name ever appears as a
tab; tab labels are that station's own sub-topics (outline entries for content-less stations,
heading-grouped subsections for Abdominal Examination). `lib/models/resource_topic.dart` was
not touched by this plan, so dr6's rename work has no merge conflict here.

## Self-Check: PASSED

All files created/modified confirmed present on disk; both task commits (`b779476`, `0b514de`)
confirmed present in `git log`.

---
*Quick item: 260918-dr5 (batch 260918-dqw)*
*Completed: 2026-09-19*
