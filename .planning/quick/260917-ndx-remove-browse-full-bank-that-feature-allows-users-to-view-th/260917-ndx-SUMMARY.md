---
phase: 260917-ndx
plan: 01
subsystem: ui
tags: [flutter, exam-prep, freemium, widget-test]

requires: []
provides:
  - "Exam Prep home screen with no route into the full question bank"
  - "Widget regression guard for the Exam Prep Access card (free vs paid)"
affects: [260917-ndq, 260917-ndt, 260917-nds]

actuals:
  tokens: 6889
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Widget-test injection seam (testQuestions) mirroring ReaderScreen.testBookProvider"
    - "Nullable Widget? child on a shared card widget to avoid empty Row/spacer when there is no trailing action"

key-files:
  created:
    - enchiridion/test/screens/exam_prep_home_screen_test.dart
  modified:
    - enchiridion/lib/screens/exam_prep_home_screen.dart
    - TESTING_REPORT.md

key-decisions:
  - "Removed the FilledButton.icon 'Browse Full Bank' entirely rather than gating it, per the product decision that users do not get to see the bank"
  - "Made _ExamMetricCard.child nullable instead of leaving an empty Row + spacer for paid users on the Access card"
  - "Extended the TESTING_REPORT.md fix beyond the single named section: 4 other bullets outside the target section also cited the deleted file's path by name, and the plan's own automated verify gate (`! grep -q 'exam_prep_question_list_screen' TESTING_REPORT.md`) checks the whole file, not just the target section — left those bullets' claims and positions unchanged, only replacing the dangling path citations with descriptive text"

requirements-completed: [260917-ndx]

coverage:
  - id: D1
    description: "The whole-bank list screen (exam_prep_question_list_screen.dart) is deleted and no longer reachable from the Exam Prep home screen"
    requirement: "260917-ndx"
    verification:
      - kind: unit
        ref: "test/screens/exam_prep_home_screen_test.dart#free user sees the three cards, an Unlock button, and no bank-browsing affordance"
        status: pass
      - kind: other
        ref: "test ! -e enchiridion/lib/screens/exam_prep_question_list_screen.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Free users still see the Access card's Unlock path; paid users see no Unlock button; both still see Daily Performance, Access, and Quick Check card titles"
    requirement: "260917-ndx"
    verification:
      - kind: unit
        ref: "test/screens/exam_prep_home_screen_test.dart#free user sees the three cards, an Unlock button, and no bank-browsing affordance"
        status: pass
      - kind: unit
        ref: "test/screens/exam_prep_home_screen_test.dart#paid user sees the three cards, no Unlock button, and no bank-browsing affordance"
        status: pass
    human_judgment: false
  - id: D3
    description: "The app compiles with zero analyzer errors after the screen deletion, and the full flutter test suite passes with no new failures"
    requirement: "260917-ndx"
    verification:
      - kind: other
        ref: "flutter analyze lib (0 error-severity issues, 8 total matching pre-existing baseline)"
        status: pass
      - kind: other
        ref: "flutter test (63 tests, all passed)"
        status: pass
    human_judgment: false

duration: ~25min active (interrupted by a monthly spend-limit reset between Task 1 and Task 2/3; wall-clock span was longer)
completed: 2026-09-17
status: complete
---

# Phase 260917-ndx Plan 01: Remove Browse Full Bank Summary

**Deleted the Exam Prep whole-bank list screen and its home-screen entry point; free/paid users now see only Daily Performance, Access (with Unlock for free users), and Quick Check, backed by a new widget regression test.**

## Performance

- **Duration:** ~25 min active work (session was interrupted by a monthly spend-limit reset between Task 1 and Tasks 2/3, so wall-clock elapsed time is not representative)
- **Started:** 2026-09-17 (Task 1 committed 17:25:55+01:00)
- **Completed:** 2026-09-17T22:59:16+01:00
- **Tasks:** 3/3
- **Files modified:** 4 (1 deleted, 3 modified/created)

## Accomplishments
- Deleted `enchiridion/lib/screens/exam_prep_question_list_screen.dart` — the whole-bank question list that showed every question (including locked ones with a truncated text preview) to every user
- Removed the "Browse Full Bank" button and its import from the Exam Prep home screen's Access card; made `_ExamMetricCard.child` nullable so the card renders cleanly (title + subtitle, plus an Unlock button only for free users) instead of an empty Row
- Added `ExamPrepHomeScreen.testQuestions` (a `@visibleForTesting` seam mirroring `ReaderScreen.testBookProvider`) and a new widget test file covering free-user and paid-user rendering, proving the card titles still render, Unlock still works for free users, and no affordance (button text or `Icons.list_alt_outlined`) opens the full bank
- Corrected 5 dangling references to the deleted file across `TESTING_REPORT.md` (the target section plus 4 others that cited its path), leaving the still-open Access-card-subtitle count-disclosure item recorded for sibling batch items 260917-ndq/260917-ndt

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove the bank-browsing entry point end to end** - `66b6a80` (feat)
2. **Task 2: Add a test hook and a widget regression guard** - `591d105` (test)
3. **Task 3: Correct the now-dangling TESTING_REPORT.md references** - `63f0f71` (docs)

**Plan metadata:** committed by the orchestrator after this dispatch round, per ADR-1239 single-writer invariant (this executor does not commit STATE.md/ROADMAP.md/BATCH.json).

## Files Created/Modified
- `enchiridion/lib/screens/exam_prep_home_screen.dart` - removed the "Browse Full Bank" button/import, made `_ExamMetricCard.child` nullable, added the `testQuestions` widget-test seam
- `enchiridion/lib/screens/exam_prep_question_list_screen.dart` - deleted (whole-bank list screen)
- `enchiridion/test/screens/exam_prep_home_screen_test.dart` - new widget regression test (free/paid access, no bank-browsing affordance)
- `TESTING_REPORT.md` - corrected 5 dangling citations to the deleted file across 4 sections

## Decisions Made
- Kept the Access card's subtitle text byte-for-byte unchanged (still discloses the total question count) — that is explicitly sibling batch items 260917-ndq/260917-ndt's job, not this one's
- Left `_StudyCard`/`_StudyCardState` dead code untouched per the plan's scope boundary (owned by sibling items 260917-ndv/260917-ne0)
- See `key-decisions` in frontmatter for the TESTING_REPORT.md scope decision

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed 4 additional dangling `exam_prep_question_list_screen` citations in TESTING_REPORT.md outside the plan's named target section**
- **Found during:** Task 3
- **Issue:** The plan's action text said to rewrite only the "Exam prep should not show the full question bank to free users" section's bullets and "not touch any other section." However, the plan's own automated verify command (`! grep -q 'exam_prep_question_list_screen' TESTING_REPORT.md`) checks the entire file. Four other bullets — in the "✅ RESOLVED" section (2 bullets), "Device navigation bar overlapping bottom content," and "Unlock button should take user to subscribe for full access" — also cited the now-deleted file by path, which would have failed the verify gate and left the document contradicting itself (referencing line numbers and CTAs in a file that no longer exists).
- **Fix:** Replaced only the dangling path citations in those 4 bullets with descriptive text ("the Exam Prep whole-bank list screen, removed under 260917-ndx"), without reordering, renumbering, or otherwise rewording the surrounding sentences or any other section.
- **Files modified:** TESTING_REPORT.md
- **Verification:** `! grep -q 'exam_prep_question_list_screen' TESTING_REPORT.md` passes; `git diff TESTING_REPORT.md` confirms only the 5 dangling-citation bullets changed, nothing else reordered.
- **Committed in:** 63f0f71 (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — plan's own verify gate required a broader fix than the action text's "one section" scope)
**Impact on plan:** Necessary to satisfy the plan's own automated verification; no scope creep beyond dangling-citation cleanup, and no unrelated section content was altered.

## Issues Encountered
- Execution was interrupted mid-Task-2 by a monthly account spend limit; resumed cleanly from the prior worktree state (Task 1 already committed, Task 2's in-progress file edits still on disk) once the limit reset, with no rework needed.
- No other issues — analyzer, the new widget test, and the full test suite (63 tests) all passed on first run after each task's edits.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The Exam Prep home screen has no route into the full question bank; free users retain the Unlock path and the Quick Check "Practice one now" flow is untouched.
- Sibling batch items 260917-ndq and 260917-ndt still need to address the Access card subtitle's question-count disclosure — tracked as the open item in TESTING_REPORT.md's "Exam prep should not show the full question bank" section.
- Sibling item 260917-nds (answered-question review view) is unaffected: it must build a new history-filtered screen and must not resurrect `ExamPrepQuestionListScreen`.

---
*Phase: 260917-ndx*
*Completed: 2026-09-17*

## Self-Check: PASSED

All claimed files and commits verified present:
- `enchiridion/test/screens/exam_prep_home_screen_test.dart` — FOUND
- `enchiridion/lib/screens/exam_prep_question_list_screen.dart` — confirmed deleted (absent)
- `.planning/quick/260917-ndx-.../260917-ndx-SUMMARY.md` — FOUND (this file)
- Commit `66b6a80` — FOUND
- Commit `591d105` — FOUND
- Commit `63f0f71` — FOUND
