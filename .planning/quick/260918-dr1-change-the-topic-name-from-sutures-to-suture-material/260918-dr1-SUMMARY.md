---
phase: quick-260918-dr1
plan: 01
quick_id: 260918-dr1
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, dart, resource-topics, surgical-instrumentation, rename]

requires:
  - phase: 260918-dr0
    provides: "85-entry kSurgicalInstrumentationTopics catalog with the sutures entry at index 0"
provides:
  - "Surgical Instrumentation topic id 'sutures' displays as 'Suture Material' on every surface (list row, detail AppBar, detail page header, RELATED TOPICS chip, first section heading)"
  - "resource_topic_test.dart: rename + prose/id-preservation + real-catalog-widget guard"
affects: []

actuals:
  tokens: 1231
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Surgical, field-scoped Edit calls on a shared JSON content asset instead of a stream-editor rename, with an occurrence-count guard test pinning the split between renamed field values and untouched clinical prose"

key-files:
  created:
    - enchiridion/test/models/resource_topic_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/assets/data/resources/sutures.json

key-decisions:
  - "Task 2's guard widget test was written into resource_topic_list_screen_test.dart first (an option the task text explicitly allowed) but relocated into resource_topic_test.dart in a follow-up commit so the plan's own <verification> clause ('git diff --stat shows exactly three files touched') holds against the frontmatter's files_modified list."

requirements-completed: [260918-dr1]

coverage:
  - id: D1
    description: "Surgical Instrumentation list row, detail AppBar, detail page header, RELATED TOPICS chip, and first in-body section heading all read 'Suture Material' instead of 'Sutures'"
    requirement: "260918-dr1"
    verification:
      - kind: unit
        ref: "test/models/resource_topic_test.dart#Suture Material rename catalog entry keeps id sutures but displays as Suture Material"
        status: pass
      - kind: unit
        ref: "test/models/resource_topic_test.dart#Suture Material rename content asset display fields read Suture Material; ids unchanged"
        status: pass
      - kind: automated_ui
        ref: "test/models/resource_topic_test.dart#real Surgical Instrumentation catalog card list renders Suture Material, never the bare old name Sutures"
        status: pass
    human_judgment: false
  - id: D2
    description: "No identifier, asset path, or image path moved; the topic still loads its full content, and the seven legitimate clinical uses of 'Sutures' in body prose survive verbatim"
    requirement: "260918-dr1"
    verification:
      - kind: unit
        ref: "test/models/resource_topic_test.dart#Suture Material rename content asset display fields read Suture Material; ids unchanged (chapter_id/section_id assertions + 7-occurrence count + three-prose-string containment)"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-09-19
status: complete
---

# Phase quick-260918-dr1 Plan 01: Rename Sutures to Suture Material Summary

Renamed the Surgical Instrumentation topic's four display surfaces from "Sutures" to "Suture Material" via three surgical field edits, leaving every id, path, and clinical-prose sentence byte-identical.

## Performance

- **Duration:** 7 min
- **Started:** 2026-09-19T07:59:19Z
- **Completed:** 2026-09-19T08:06:02Z
- **Tasks:** 2 completed
- **Files modified:** 3 (2 modified, 1 created)

## Accomplishments
- `kSurgicalInstrumentationTopics`'s `sutures` entry now has `title: 'Suture Material'`; `id`, `categoryTitle`, `heroAssetPath`, `dataAssetPath`, and `description` are untouched.
- `sutures.json`'s `chapter_metadata.chapter_title`, `chapter_metadata.tags[0]`, and `sections[0].section_title` all changed to `Suture Material`; `chapter_id`, `section_id`, every `subsection_id`/`group_id`, and all seven legitimate prose uses of "Sutures" (the group title, two subsection titles, four technique labels) are byte-identical to before.
- Confirmed no Dart source under `enchiridion/lib` hardcodes the old standalone topic name — all three consuming screens already render `topic.title`.
- Added `test/models/resource_topic_test.dart`: asserts the catalog entry's title/id split, title uniqueness across the catalog, the content asset's three renamed fields plus its two untouched persistence ids, verbatim survival of the three representative prose strings, an exact occurrence count of 7 (down from 10), and — pumping the real `kSurgicalInstrumentationTopics` catalog inside a `MaterialApp` — that the card list renders the exact text "Suture Material" and never the bare text "Sutures".

## Task Commits

Each task was committed atomically:

1. **Task 1: Rename the topic's display name across catalog and content, guarded by a test** - `cd45613` (feat)
2. **Task 2: Prove no surface still shows the old name and nothing regressed** - `0e40fd9` (test)
3. **Correction: relocate the Task 2 guard widget test into resource_topic_test.dart** - `0b087c2` (test)

**Plan metadata:** pending (this SUMMARY commit, made by the orchestrator per this leaf's constraints)

## Files Created/Modified
- `enchiridion/lib/models/resource_topic.dart` - `sutures` entry's `title` field changed to `'Suture Material'`; nothing else touched
- `enchiridion/assets/data/resources/sutures.json` - three field values renamed (`chapter_title`, `tags[0]`, `sections[0].section_title`); all ids and prose unchanged
- `enchiridion/test/models/resource_topic_test.dart` (new) - rename guard: catalog title/id, title uniqueness, content-asset field values, id preservation, prose preservation + occurrence count, and a widget test against the real catalog

## Decisions Made
- Sibling `260918-dr0` had already landed on `main` with the full 85-entry catalog (this worktree was fast-forwarded to pick it up — see "Worktree infrastructure catch-up" below), so this plan renamed dr0's actual landed `sutures` entry rather than a stand-in.
- Task 2 offered a choice of which test file should host the real-catalog widget assertion. It was first added to `resource_topic_list_screen_test.dart`, then moved to `resource_topic_test.dart` in a follow-up commit once it was noticed the plan's `<verification>` section requires the diff to touch exactly the three `files_modified` files. Moving it keeps that check literally true without changing any assertion's behavior.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues were encountered; both plan tasks executed as specified.

### Worktree infrastructure catch-up (not a plan deviation, execution-environment note)

This worktree was branched before sibling `260918-dr0` (which this plan `depends_on`) had landed on `main` — `git merge-base HEAD main` equaled the worktree's own HEAD with zero unique commits, meaning the branch was a strict ancestor of `main`. Before starting Task 1, the worktree branch was fast-forwarded to `main`'s tip (`b806ba7`) via `git merge --ff-only main` — a pure fast-forward, no local divergent commits, no conflicts — per this plan's own constraints. No plan file was altered by this step; it only brought the already-landed, already-reviewed dr0 catalog expansion into the isolated worktree so this plan could rename the real 85-entry catalog's `sutures` entry rather than a stale single-entry snapshot.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** None. Plan executed exactly as written (one file-placement self-correction between Task 2's two allowed options, no behavior change).

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Siblings `260918-dr2`, `dr3`, and `dr5` can land on top of this without rework: only display strings changed, every id/key/path is exactly where `dr0` left it.
- Any pinned note a user already saved in this topic still resolves, since `chapter_id` (`sutures`) and `section_id` (`sutures_section_1`) are unchanged.

## Self-Check: PASSED

- FOUND: enchiridion/lib/models/resource_topic.dart
- FOUND: enchiridion/assets/data/resources/sutures.json
- FOUND: enchiridion/test/models/resource_topic_test.dart
- FOUND commit cd45613 (Task 1)
- FOUND commit 0e40fd9 (Task 2)
- FOUND commit 0b087c2 (file-placement correction)

---
*Phase: quick-260918-dr1*
*Completed: 2026-09-19*
