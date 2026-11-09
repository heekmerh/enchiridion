---
quick_id: 260918-dr6
batch_id: 260918-dqw
subsystem: testing
tags: [flutter, osce, resource-topics, regression-guard]

# Dependency graph
requires:
  - phase: 260918-dr5
    provides: "OSCE detail route in its final sub-topic-tab shape (station name in the AppBar, never as a tab)"
provides:
  - "test/guards/osce_station_titles_guard_test.dart — identity-anchored (by id, not position) guard pinning the Abdominal Examination station's title/dataAssetPath and rejecting the bare organ short form on any OSCE station"
affects: []

actuals:
  tokens: 1733
  tasks: 2
  commits: 2
  plan_head_before: 9fedcc661ad5ced941c4ad503a3f444ee2aaca26

tech-stack:
  added: []
  patterns:
    - "Regression guard selects the target entity by stable id (kOsceTopics.firstWhere(t.id == ...)) rather than list position or tab index, so it survives sibling reordering/restructuring work"
    - "Detail-route assertions target rendered text (findsWidgets against the string) rather than tab/TabBar structure, so the guard is agnostic to the specific tab-layout implementation in place at any given time"

key-files:
  created:
    - enchiridion/test/guards/osce_station_titles_guard_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart

key-decisions:
  - "Trusted the plan's pre-flight finding only after independently re-verifying it against the current (post-fast-forward) codebase: read lib/models/resource_topic.dart and confirmed title: 'Abdominal Examination' was already present at HEAD."
  - "Worktree was a strict ancestor of main with zero unique commits at spawn time (created before both 260918-dr5 and 260918-dr3 landed); fast-forwarded via `git merge --ff-only main` before starting, per this plan's constraints, so the guard and comment edit build on dr5's actual landed osce_screen.dart (post-restructure tab shape) rather than a stale pre-dr5 snapshot."
  - "Wrote the guard as a new file (test/guards/osce_station_titles_guard_test.dart), not as additions to test/screens/osce_screen_test.dart, exactly as instructed — dr5 already modified that file in the same batch, and a shared file would risk a merge conflict on the batch merge."
  - "Test 4 (detail-route render) supplies a synthetic Chapter via OsceScreen.testChapterLoader (the hook dr5 added) rather than exercising the real rootBundle asset load path, matching the established pattern in the pre-existing osce_screen_test.dart and avoiding the documented indefinite-hang risk of real asset loading in this project's widget-test environment."
  - "Test 4 asserts with find.text(...) findsWidgets against the AppBar/body text rather than reading (tabBar.tabs.first as Tab).text, so it stays valid whether the station label lives in a tab or the app bar — satisfying the plan's explicit post-dr5/pre-dr5 dual-compatibility requirement even though only the post-dr5 shape is reachable today."

requirements-completed: ["260918-dr6"]

coverage:
  - id: D1
    description: "The OSCE station backed by abdominal_examination.json is labelled exactly 'Abdominal Examination' in kOsceTopics, selected by id (not position)"
    requirement: "260918-dr6"
    verification:
      - kind: unit
        ref: "enchiridion/test/guards/osce_station_titles_guard_test.dart#kOsceTopics entry selected by id abdominal-examination has title exactly \"Abdominal Examination\""
        status: pass
    human_judgment: false
  - id: D2
    description: "The rename did not drag the station's dataAssetPath along with it"
    requirement: "260918-dr6"
    verification:
      - kind: unit
        ref: "enchiridion/test/guards/osce_station_titles_guard_test.dart#the abdominal-examination entry keeps its dataAssetPath unchanged"
        status: pass
    human_judgment: false
  - id: D3
    description: "The OSCE station list renders a ListTile titled exactly 'Abdominal Examination', resolved by text rather than list position"
    requirement: "260918-dr6"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/guards/osce_station_titles_guard_test.dart#OsceScreen renders a ListTile whose title reads exactly \"Abdominal Examination\", resolved by that text rather than by list position"
        status: pass
    human_judgment: false
  - id: D4
    description: "Opening the Abdominal Examination station's detail route still shows the label 'Abdominal Examination' on screen, regardless of tab-vs-appbar layout"
    requirement: "260918-dr6"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/guards/osce_station_titles_guard_test.dart#tapping the Abdominal Examination tile pushes the detail route, which still shows \"Abdominal Examination\" somewhere on screen"
        status: pass
    human_judgment: false
  - id: D5
    description: "No station in kOsceTopics carries the bare single-word organ short form as its title"
    requirement: "260918-dr6"
    verification:
      - kind: unit
        ref: "enchiridion/test/guards/osce_station_titles_guard_test.dart#no station in kOsceTopics carries the bare single-word organ short form as its title"
        status: pass
    human_judgment: false
  - id: D6
    description: "The stale short-form reference in the kOsceTopics block comment is corrected to the station's real display title, with no other change to the file"
    requirement: "260918-dr6"
    verification:
      - kind: other
        ref: "grep -E '^[[:space:]]*//' lib/models/resource_topic.dart | grep -c 'Abdominal Examination' (>=1) plus flutter analyze lib/models/resource_topic.dart"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-19
status: complete
---

# Quick Item 260918-dr6: Rename Abdominal -> Abdominal Examination Summary

**Pre-flight finding confirmed: the user-visible station title was already correct ("Abdominal Examination") at HEAD before this plan started — no rename shipped here. This plan instead delivered the missing regression guard (identity-anchored by station id, layout-agnostic on the detail route) plus a one-line correction to a stale short-form reference left in a source comment.**

## Pre-flight finding, independently re-verified

The plan's objective states the rename was never actually needed because `lib/models/resource_topic.dart:105`
already reads `title: 'Abdominal Examination'`, and has since a commit that predates this
batch. Before trusting that claim, this executor:

1. Fast-forwarded the worktree branch to `main`'s tip first (see Deviations below), then read
   the actual landed `enchiridion/lib/models/resource_topic.dart` and
   `enchiridion/lib/screens/osce_screen.dart`.
2. Confirmed the `abdominal-examination` entry's `title` field reads `'Abdominal Examination'`
   at the post-fast-forward HEAD, with `id: 'abdominal-examination'` and
   `dataAssetPath: 'assets/data/resources/abdominal_examination.json'` both independent,
   hand-written, and untouched.
3. Confirmed `_OsceDetailScreen`'s `AppBar` title is `widget.topic.title` and no station name
   ever appears as a tab (dr5's landed shape) — matching dr5's own SUMMARY note "For dr6".
4. Found exactly one stale reference: the block comment above `const List<ResourceTopic>
   kOsceTopics` still read `// "Abdomen" has full written content today
   (abdominal_examination.json);`, contradicting the title two dozen lines below it.

Conclusion: this plan's value is the guard, not a rename. Both tasks ran and passed on their
first attempt, exactly as the plan anticipated.

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-19T08:29:00Z
- **Completed:** 2026-09-19T08:49:17Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- New `test/guards/osce_station_titles_guard_test.dart` with 5 test cases: two model-layer
  checks (title, dataAssetPath) selecting the station by id; two render-layer checks (list tile
  text, detail-route text after tap) that assert on rendered strings rather than tab/list
  position; one negative check that no station title in `kOsceTopics` ever regresses to the
  bare organ short form.
- All 5 new cases passed on their first run against unmodified product code — the finding the
  plan predicted.
- Corrected the stale `// "Abdomen" has full written content today` comment in
  `lib/models/resource_topic.dart` to `// "Abdominal Examination" has full written content
  today`, with no other line in the file touched.
- Re-ran the full targeted verification suite (`test/guards/`, `test/screens/osce_screen_test.dart`,
  `test/models/content_availability_test.dart`) plus `flutter analyze
  lib/models/resource_topic.dart` after both tasks: all green, no regressions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Identity-anchored guard — station id to rendered label, end to end** - `303d451` (test)
2. **Task 2: Correct the stale short-form reference in the kOsceTopics comment** - `c9672cb` (docs)

## Files Created/Modified
- `enchiridion/test/guards/osce_station_titles_guard_test.dart` - **New.** Identity-anchored
  regression guard: 2 model-layer tests (title, dataAssetPath by id), 2 render-layer widget
  tests (list tile text, post-tap detail-route text), 1 negative test (no station reverts to
  the bare organ short form).
- `enchiridion/lib/models/resource_topic.dart` - One comment line corrected above
  `kOsceTopics`; no other line changed (id, dataAssetPath, description, outline entries, and
  every other station's data untouched).

## Decisions Made
See `key-decisions` in frontmatter. In short: independently re-verified the plan's pre-flight
claim rather than trusting it blindly; kept the new guard in its own file to avoid a merge
conflict with sibling dr5's edits to `osce_screen_test.dart`; asserted on rendered text rather
than tab structure so the guard survives future OSCE detail-route restructures; used the
`testChapterLoader` injection hook (added by dr5) to reach the detail route deterministically
without depending on real asset loading.

## Deviations from Plan

**Worktree was stale relative to `main` at spawn time** (infrastructure, not a plan deviation,
recorded per this plan's constraints): this worktree's branch
(`worktree-agent-ae103dfa5b6f5d18d`) was a strict ancestor of `main` with zero unique commits
(`git merge-base --is-ancestor` true), predating both sibling `260918-dr5` (this plan's direct
dependency) and `260918-dr3` (not a direct dependency, but also restructured the same file's
region). Fast-forwarded (`git merge --ff-only main`) before starting, bringing in dr5's actual
landed `osce_screen.dart` (the final sub-topic-tab shape) and dr3's landed
`kMedicalInstrumentationTopics` additions. No destructive git operations were used.

No other deviations. Both tasks executed exactly as specified; no Rule 1-4 auto-fixes were
needed since the guard passed immediately against unmodified product code and the comment edit
was a single, unambiguous line replacement.

## Issues Encountered

None. The `flutter test` compact reporter's progress counter (`+N`) appeared to jump
non-monotonically per source file when multiple test-file arguments were passed together in one
invocation (a known artifact of flutter_test's concurrent-shard progress printing, not a test
failure) — verified this was cosmetic by re-running `test/guards/` alone (9 tests, all green,
matching the 5 new + 4 pre-existing guard-file tests) and by grepping the full combined-run log
for `failed`/`exception`/`error` (no matches). All runs ended with `All tests passed!` and no
failure output.

## Next Phase Readiness

This was the final planned item touching `lib/models/resource_topic.dart` in this batch
sequence for the OSCE region; sibling `260918-dr4` (Sutures/IV-Cannula region, dispatched after
this item per the batch's stated ordering) can now proceed without a merge conflict risk in this
file's OSCE block. No blockers.

## Self-Check: PASSED

All files created/modified confirmed present on disk (`enchiridion/test/guards/osce_station_titles_guard_test.dart`,
this SUMMARY.md); both task commits (`303d451`, `c9672cb`) confirmed present in `git log`.

---
*Quick item: 260918-dr6 (batch 260918-dqw)*
*Completed: 2026-09-19*
