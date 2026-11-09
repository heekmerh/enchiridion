---
phase: quick-260919-kiu
plan: 01
subsystem: exam-prep-stats
tags: [flutter, provider, study-stats, spaced-repetition, dashboard]

requires:
  - phase: quick-260919-kis
    provides: question_screen.dart's post-auto-advance _submit shape, which this plan's stats-call edit lands on top of
provides:
  - Every submitted Exam Prep answer (new or a spaced-repetition re-serve) now increments the dashboard's Answered/Correct/Wrong/Points tiles once
  - Removal of the isFirstAttempt/attempts==1 suppression from StudyStatsService.recordAnswer, StudyStatsProvider.recordAnswer, and both production call sites
  - Regression coverage at the widget level (question_screen_test.dart) and the service level (study_stats_service_test.dart) pinning the reported "answered 4, counted 2" scenario
  - Reworded Answered-drill-down copy explaining why its distinct-question count differs from the dashboard's answers-given count
affects: [exam-prep-dashboard, spaced-repetition, study-stats-provider]

actuals:
  tokens: 4982
  tasks: 3
  commits: 2
  plan_head_before: 717307945f38fd268a8b238fb3f36e47ee9999f2

tech-stack:
  added: []
  patterns:
    - "StudyStatsService.recordAnswer counts every call once; the caller (exactly one per submission: QuestionScreen._submit or QuickCheckCard._submit) is the sole protection against double-counting, not an inspection of review/attempt state."

key-files:
  created: []
  modified:
    - enchiridion/lib/services/study_stats_service.dart
    - enchiridion/lib/providers/study_stats_provider.dart
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
    - enchiridion/lib/screens/answered_questions_screen.dart
    - enchiridion/test/screens/question_screen_test.dart
    - enchiridion/test/providers/study_stats_provider_test.dart
    - enchiridion/test/services/study_stats_service_test.dart
    - enchiridion/test/screens/exam_prep_home_screen_stats_test.dart

key-decisions:
  - "Removed the isFirstAttempt parameter entirely (rather than loosening the attempts==1 comparison) so a review merged from another device or derived from a pre-spaced-repetition answer can no longer suppress a genuinely-new local answer either."
  - "Answered/Correct/Wrong/Points now mean 'answers given', not 'distinct questions touched'; the Answered drill-down keeps counting distinct questions and its copy now says so explicitly instead of silently disagreeing with the dashboard."
  - "Reached the widget-level repeat-submission test by pumping two distinct-keyed QuestionScreen instances over one shared StorageService/StudyStatsProvider, since Flutter reuses State across a keyless re-pump of a structurally identical tree — that would have kept the first submission's _submitted=true and made a real second tap impossible."

patterns-established: []

requirements-completed: [260919-kiu]

coverage:
  - id: D1
    description: "Two submissions of the same question through the real QuestionScreen move the shared provider's totals from one answer/10 points to two answers/20 points"
    requirement: "260919-kiu"
    verification:
      - kind: unit
        ref: "enchiridion/test/screens/question_screen_test.dart#daily stats tracking a repeat answer to the same question counts as a second answer, not a no-op — reproduces the reported \"answered 4, counted 2\" bug"
        status: pass
    human_judgment: false
  - id: D2
    description: "A wrong second submission after a correct first leaves answered 2, correct 1, wrong 1"
    requirement: "260919-kiu"
    verification:
      - kind: unit
        ref: "enchiridion/test/screens/question_screen_test.dart#daily stats tracking a wrong second submission after a correct first leaves answered 2, correct 1, wrong 1"
        status: pass
    human_judgment: false
  - id: D3
    description: "Four recorded answers with two repeats fold to four answered / three correct / one wrong / thirty points at the service level"
    requirement: "260919-kiu"
    verification:
      - kind: unit
        ref: "enchiridion/test/services/study_stats_service_test.dart#StudyStatsService.getLifetimeTotals four recorded answers, two of them repeats of already-answered questions, fold to four answered — reproduces the reported \"answered 4, counted 2\" bug at the service level"
        status: pass
    human_judgment: false
  - id: D4
    description: "A single submission still counts exactly once (double-count guard) and the remote push is still unawaited"
    requirement: "260919-kiu"
    verification:
      - kind: unit
        ref: "enchiridion/test/screens/exam_prep_home_screen_stats_test.dart#one recorded correct answer moves Points by exactly 10 and Answered by exactly 1 — the double-count guard"
        status: pass
      - kind: unit
        ref: "enchiridion/test/screens/exam_prep_home_screen_stats_test.dart#dashboard repaints with updated stats within a single frame while the remote push never resolves"
        status: pass
    human_judgment: false
  - id: D5
    description: "Answered drill-down copy explains the distinct-questions vs. answers-given distinction instead of contradicting the dashboard"
    verification: []
    human_judgment: true
    rationale: "Copy wording is a readability/UX judgment call, not something a unit test can validate — flutter analyze and the existing widget suite confirm it renders without error, but whether the phrasing reads clearly needs a human."

duration: ~35min
completed: 2026-09-19
status: complete
---

# Phase quick-260919-kiu Plan 01: Fix the Exam Prep answered-questions counter Summary

**Removed the `attempts == 1` suppression from `StudyStatsService.recordAnswer` so every submitted answer — including spaced-repetition re-serves — increments the dashboard's Answered/Correct/Wrong/Points tiles once, instead of only the first answer to each distinct question ever counting.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 3 (2 produced commits; Task 3 was analyzer/full-suite/blast-radius verification only)
- **Files modified:** 9

## Accomplishments
- `StudyStatsService.recordAnswer` no longer takes `isFirstAttempt` and no longer short-circuits on repeat answers — every call raises `questionsAnswered`/`correctAnswers`/`performancePoints` once, with the local write still first and the Supabase push still `unawaited`.
- `StudyStatsProvider.recordAnswer` and both production call sites (`QuestionScreen._submit`, `QuickCheckCard._submit`) updated to the new signature; the `review` variable each derived from `storage.recordAnswer` remains in use for notification scheduling and the remote review push.
- New regression tests reproduce the reported "answered 4, counted 2" bug at both the widget level (two submissions through a real `QuestionScreen`) and the service level (four answers, two repeats, folding to four/three/one/thirty), and both are pinned green.
- The three existing stats suites (`study_stats_provider_test.dart`, `study_stats_service_test.dart`, `exam_prep_home_screen_stats_test.dart`) realigned to the corrected semantic; the provider test that used to assert a repeat "changes nothing" now asserts it counts.
- `answered_questions_screen.dart`'s all-time summary line and points caption reworded so its distinct-questions count reads as intentionally different from the dashboard's answers-given count, and the stale doc-comment note (claiming a sibling item forbade editing the stats service) removed.

## Task Commits

Each task with a code diff was committed atomically:

1. **Task 1: A repeat answer counts — end to end from a real submission to the dashboard totals** - `c090a09` (feat, tdd)
2. **Task 2: Realign the three stats suites to the corrected semantic and fix the drill-down copy** - `935af68` (test, tdd)
3. **Task 3: Analyzer, full-suite regression, and blast-radius check** - no commit (verification-only; no production or test files changed)

**Plan metadata:** not committed by this executor — per the batch orchestrator's constraints (ADR-1239 single-writer invariant), STATE.md/ROADMAP.md updates and this SUMMARY.md's commit are owned by the orchestrator, not this leaf agent.

_Both code commits carry a RED-then-GREEN TDD cycle: Task 1's new widget test was confirmed failing (`Expected: <2>, Actual: <1>`) before the production fix; Task 2's inverted provider test and new service-level regression test were written and run to pass against the already-fixed production code from Task 1._

## Files Created/Modified
- `enchiridion/lib/services/study_stats_service.dart` - Removed the `isFirstAttempt` parameter and its early return; rewrote the doc comment to state the corrected once-per-answer contract and why review state is deliberately not consulted.
- `enchiridion/lib/providers/study_stats_provider.dart` - Dropped `isFirstAttempt` from the pass-through signature and inner service call.
- `enchiridion/lib/screens/question_screen.dart` - Removed the `isFirstAttempt: review.attempts == 1` argument from `_submit`'s stats call; `review` remains used below for notification scheduling and the remote push.
- `enchiridion/lib/widgets/exam_prep/quick_check_card.dart` - Same argument removal in its own `_submit`.
- `enchiridion/lib/screens/answered_questions_screen.dart` - Reworded the all-time summary line, the points-filter caption, and the `kCorrectAnswerPoints`/all-time-getters doc comments.
- `enchiridion/test/screens/question_screen_test.dart` - Added an optional `statsProvider`/`screenKey` parameter to `_buildSubject`, plus a `'daily stats tracking'` group with two new regression tests.
- `enchiridion/test/providers/study_stats_provider_test.dart` - Removed `isFirstAttempt` from every call; inverted the repeat-answer test to assert counting instead of a no-op.
- `enchiridion/test/services/study_stats_service_test.dart` - Removed `isFirstAttempt`; added the four-answers-two-repeats regression test using an explicit `syncOverride`.
- `enchiridion/test/screens/exam_prep_home_screen_stats_test.dart` - Removed `isFirstAttempt` from the three provider calls; rendered-text expectations unchanged.

## Decisions Made
- Deleted the `isFirstAttempt` parameter outright rather than loosening the `attempts == 1` check, closing the cross-device/legacy-review variant of the same bug for free (per the plan's `interface_notes`).
- Kept "Answered/Correct/Wrong/Points = answers given" and "Answered drill-down = distinct questions" as two deliberately different metrics, documented in-place rather than reconciled, per the plan's `semantic_decision`.
- Used per-pump `Key`s in the new widget test to force a fresh `QuestionScreen` State on the second submission — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree was forked before dependency 260919-kis was merged to main**
- **Found during:** Task 1, before writing any test — reading `question_screen.dart` and `question_screen_test.dart` showed the pre-kis auto-advance timer (`_startAutoAdvanceCountdown`, the `'auto-advance'` test group) still present, contradicting this plan's `<note>` that the worktree's base already included kis.
- **Issue:** This worktree's HEAD (`7662dc0`) predates kis's two commits on `main` (`dd10f51`, `705425f`). Without them, `question_screen.dart` was in its pre-kis shape, which the plan's task instructions (and scope boundary "do not touch the advance/Next-button behavior kis leaves behind") assume is already gone.
- **Fix:** Verified both kis commits touch only `question_screen.dart` and its test (confirmed via `git show --stat` before acting), then cherry-picked them (`git cherry-pick dd10f51 705425f`) onto this worktree's branch. Both applied cleanly with no conflicts. This is the minimal, surgical fix — bringing in exactly the declared dependency rather than merging all of `main` (which would have also pulled in unrelated, already-landed sibling batch items).
- **Files modified:** `enchiridion/lib/screens/question_screen.dart`, `enchiridion/test/screens/question_screen_test.dart` (via the cherry-picked commits, prior to this plan's own edits).
- **Verification:** `flutter test test/screens/question_screen_test.dart` passed after the cherry-pick and before any of this plan's own changes; the file inspection afterward matched the plan's `read_first`/`interface_notes` expectations exactly.
- **Committed in:** `055467c`, `7173079` (the cherry-picked commits themselves — not new work invented by this executor, but pre-existing, reviewed commits from `main`).

**2. [Rule 3 - Blocking] Flutter widget-test state reuse defeated the plan-suggested "re-pump" repeat-submission technique**
- **Found during:** Task 1, first test run — both new tests failed with `Finder "Submit": []` instead of the expected RED assertion mismatch.
- **Issue:** The plan's action text suggested "re-pumping a fresh subject over the same StorageService and the same provider instance" to simulate a second submission. Flutter's element reconciliation reuses the existing `State` object across a keyless `pumpWidget` call when the new widget tree is structurally identical, so the second pump inherited the first submission's `_submitted = true` state rather than starting fresh — no Submit button was ever shown to tap.
- **Fix:** Added an optional `screenKey` parameter to `_buildSubject`, threaded to `QuestionScreen(key: screenKey, ...)`, and passed distinct `ValueKey`s (`'attempt-1'`, `'attempt-2'`) across the two pumps in each new test — forcing a genuinely fresh `State` per pump, matching how a real re-serve arrives as a new screen instance.
- **Files modified:** `enchiridion/test/screens/question_screen_test.dart`.
- **Verification:** Re-ran the tests; they then failed for the correct reason (`Expected: <2>, Actual: <1>`), confirming RED, before the production fix made them pass.
- **Committed in:** `c090a09` (Task 1 commit).

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking issues that prevented executing the plan as literally written; neither introduced scope beyond what the plan specified).
**Impact on plan:** Both fixes were prerequisites for correctly implementing Task 1 exactly as scoped — no production behavior beyond the plan's stated objective was added, and no files outside `files_modified` (plus the two dependency-commit files, which are already inside `files_modified`) were touched.

## Issues Encountered
See Deviations above — both issues were resolved before any production code changes were made, so no code changes had to be reverted or reworked.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Sibling items 260919-kit (Quick Check copy retirement) and 260919-kiv (option-label shuffling), both declared to run after this item, can proceed against `question_screen.dart`/`quick_check_card.dart` in their post-kiu shape — this plan's only edit to those files was the stats-call argument removal, per its scope boundary.
- No blockers identified. The full `flutter test` suite (252 tests) and `flutter analyze` over the five changed library files are green.

---
*Phase: quick-260919-kir (batch), item 260919-kiu*
*Completed: 2026-09-19*

## Self-Check: PASSED

All 9 modified source/test files and this SUMMARY.md verified present on disk; all 4 referenced commit hashes (`c090a09`, `935af68`, `055467c`, `7173079`) verified present in `git log --oneline --all`.
