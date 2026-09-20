---
phase: quick-260919-kiy
plan: 01
subsystem: ui
tags: [flutter, dart, resource-topics, medical-instrumentation, list, dense]

# Dependency graph
requires:
  - phase: quick-260918-dr0
    provides: "The shared `dense` flag and `_buildDenseList`/`_buildCardList` builders on `ResourceTopicListScreen`"
  - phase: quick-260918-dr4
    provides: "`kMedicalInstrumentationTopicsInDisplayOrder`, the available-first ordered catalog with IV Cannula leading"
provides:
  - "Medical Instrumentation call site opts into the existing dense (ListTile) presentation, matching Surgical Instrumentation"
  - "End-to-end test proving the Library carousel -> Medical Instrumentation tap renders ListTile rows with zero Image widgets"
  - "Two pre-existing widget tests realigned from asserting the retired card presentation to asserting the shipped dense presentation"
affects: [library_screen, resource_topic_list_screen]

actuals:
  tokens: 1832
  tasks: 2
  commits: 3
plan_head_before: 7662dc01adfba2888d81a523430da220f1262f8e

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart
    - enchiridion/test/screens/library_screen_test.dart
    - enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
    - enchiridion/test/models/medical_instrumentation_display_order_test.dart

key-decisions:
  - "Reused the existing dense flag verbatim (from 260918-dr0) rather than building any new list/row widget — the entire behavioral delta is one call-site flag."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "Medical Instrumentation renders as OSCE/Surgical-style single-line rows instead of hero-image cards, with IV Cannula still leading and coming-soon topics still dimmed with their badge"
    verification:
      - kind: e2e
        ref: "enchiridion/test/screens/library_screen_test.dart#tapping Medical Instrumentation card navigates to a dense ResourceTopicListScreen"
        status: pass
    human_judgment: false
  - id: D2
    description: "Surgical Instrumentation's presentation is byte-for-byte unchanged"
    verification:
      - kind: unit
        ref: "git diff scope check — resource_topic_list_screen.dart shows only doc-comment lines changed, library_screen.dart shows exactly one added line"
        status: pass
    human_judgment: false
  - id: D3
    description: "The two pre-existing widget tests that pumped the Medical Instrumentation catalog in card mode are realigned to assert the dense presentation instead of silently passing against a retired UI"
    verification:
      - kind: integration
        ref: "enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart#the real kMedicalInstrumentationTopics catalog opens on the Diagnostic and Monitoring Equipment header with IV Cannula first"
        status: pass
      - kind: integration
        ref: "enchiridion/test/models/medical_instrumentation_display_order_test.dart#IV Cannula renders strictly above every other Medical Instrumentation topic tile in the first viewport"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-19
status: complete
---

# Quick 260919-kiy: Medical Instrumentation Dense List Summary

**Medical Instrumentation now opts into the shared `dense` (ListTile) presentation on `ResourceTopicListScreen`, matching Surgical Instrumentation, via a single added `dense: true` argument at the call site.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-19T15:01:00Z
- **Completed:** 2026-09-19T15:26:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Medical Instrumentation renders single-line `ListTile` rows (circle icon, title, trailing chevron/badge) instead of full-bleed hero-image cards.
- Proven end-to-end from the Library Resources carousel: a new widget test taps through Resources -> Medical Instrumentation and asserts `ListTile` rows are present, zero `Image` widgets render inside the pushed screen, and `IV Cannula` still appears.
- The two pre-existing widget tests that pumped the real Medical Instrumentation catalog in card mode (and would have silently gone stale) are realigned onto the dense presentation.

## Task Commits

Each task was committed atomically (TDD RED/GREEN split for Task 1):

1. **Task 1 (RED): add end-to-end test for dense Medical Instrumentation list** - `73f00c3` (test)
2. **Task 1 (GREEN): Medical Instrumentation opts into dense list presentation** - `90a2d8e` (feat)
3. **Task 2: realign Medical Instrumentation tests onto dense presentation** - `3745386` (test)

**Plan metadata:** committed by orchestrator after this dispatch round (per quick-batch constraints, this executor does not commit docs artifacts).

## Files Created/Modified
- `enchiridion/lib/screens/library_screen.dart` - Added `dense: true` to the Medical Instrumentation `ResourceTopicListScreen(...)` call site.
- `enchiridion/lib/screens/resource_topic_list_screen.dart` - Updated the `dense` field doc comment to describe the default generically (Medical Instrumentation is no longer a card-mode holdout).
- `enchiridion/test/screens/library_screen_test.dart` - Added an end-to-end test tapping through the Resources carousel to Medical Instrumentation and asserting the dense presentation.
- `enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart` - Realigned the Medical Instrumentation grouping test onto `dense: true` and a `ListTile` finder (was `Ink`, a card-only widget).
- `enchiridion/test/models/medical_instrumentation_display_order_test.dart` - Realigned the display-order widget test onto `dense: true` and rewrote the enlarged-viewport comment to describe dense-mode rationale.

## Decisions Made
- None beyond the plan's own directive — reused 260918-dr0's shared `dense` presentation verbatim; no new widget, row, or ordering logic was introduced.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- No blockers. The full `flutter test` suite (250 tests, baseline 249 + 1 new) and `flutter analyze lib/ test/` both pass; the 9 pre-existing analyze issues surfaced by the full-repo scan are all in files this plan did not touch (login_screen.dart, profile_screen.dart, register_screen.dart, exam_prep_repository.dart, toc_drawer.dart, reader_notes_test.dart, reader_screen_test.dart) and are out of this plan's scope per its `<threat_model>`/scope boundary.
- Verification scope check confirmed: `git diff --name-only` against the pre-plan base lists exactly the five `files_modified` paths; no ordering/availability files (`resource_topic.dart`, `content_availability.dart`, `resource_topic_detail_screen.dart`) were touched.

---
*Phase: quick-260919-kiy*
*Completed: 2026-09-19*

## Self-Check: PASSED

All 5 modified source/test files and the SUMMARY.md itself found on disk; all 3 task commits (`73f00c3`, `90a2d8e`, `3745386`) found in `git log`.
