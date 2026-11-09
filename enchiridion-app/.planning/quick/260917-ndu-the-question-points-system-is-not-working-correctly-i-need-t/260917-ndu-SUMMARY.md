---
quick_id: 260917-ndu
subsystem: exam-prep
tags: [flutter, provider, study-stats, points, supabase, tdd]
requires: []
provides:
  - StudyStatsProvider (ChangeNotifier) as the single owner of exam-prep points/stats state
  - Local-first, non-blocking StudyStatsService.recordAnswer (background Supabase push, syncOverride test seam)
  - Lifetime-accumulated Answered/Correct/Wrong/Points headline metrics on the Exam Prep dashboard
  - Single-record-path fix across all four answer entry points (Quick Check, question list, notification tap, ambient prompt)
affects: [exam-prep-dashboard, question-screen, quick-check-card, study-stats]
tech-stack:
  added: []
  patterns:
    - "ChangeNotifier provider owning local-first state, notifying synchronously before an unawaited background network push (matches QuestionReviewSyncService's swallow-all-failures contract)"
    - "@visibleForTesting screen-level test seam (ExamPrepHomeScreen.testQuestions) to bypass rootBundle asset loading in widget tests, mirroring the existing ReaderScreen.testBookProvider pattern"
key-files:
  created:
    - enchiridion/lib/providers/study_stats_provider.dart
    - enchiridion/test/providers/study_stats_provider_test.dart
    - enchiridion/test/services/study_stats_service_test.dart
    - enchiridion/test/screens/exam_prep_home_screen_stats_test.dart
  modified:
    - enchiridion/lib/services/study_stats_service.dart
    - enchiridion/lib/models/study_day_stats.dart
    - enchiridion/lib/services/storage_service.dart
    - enchiridion/lib/main.dart
    - enchiridion/lib/screens/exam_prep_home_screen.dart
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
key-decisions:
  - "Split work into 3 task commits: (1) StudyStatsProvider + single-record path fix on the Quick Check route, (2) lifetime totals accumulation + routing Quick Check's bubble card through the provider, (3) the widget-test regression guard — deliberately mirroring the plan's own task boundaries rather than one combined commit."
  - "StudyStatsService.recordAnswer no longer awaits the Supabase upsert; it starts the push via `unawaited()` after the local write completes and returns immediately, with an injectable syncOverride for tests to prove non-blocking behavior against a never-completing Future."
  - "ExamPrepHomeScreen headline metrics now render StudyStatsProvider.totals (lifetime, folded via StudyStatsTotals.fold across every stored day) instead of a single day's stats; today's daily figure is kept as secondary context text underneath."
actuals:
  tokens: 10003
  tasks: 3
  commits: 3
requirements-completed: [NDU-01, NDU-02, NDU-03, NDU-04]
status: complete
completed: 2026-09-17
---

# Quick 260917-ndu: Exam Prep Points System Fix Summary

Introduced a `StudyStatsProvider` ChangeNotifier as the single, local-first owner of exam-prep points/stats, fixing an uncaught-double-record race on the Quick Check path, an always-awaited Supabase push that caused the reported lag, and a dashboard that never accumulated points across days.

## Root Causes Fixed

1. **Reported lag** — `StudyStatsService.recordAnswer` awaited the Supabase upsert before returning; the dashboard now gets its updated value the instant the local `SharedPreferences` write completes, with the push started via `unawaited()` afterward.
2. **Wrong/doubled points** — the Quick Check route passed `trackDailyStudyStats: true` to `QuestionScreen` *and* ran its own full record pipeline in `onAnswered`, racing two read-modify-write cycles over the same storage keys. `QuestionScreen` is now the sole recorder on that route.
3. **Dead dashboard snapshot** — `ExamPrepHomeScreen` held stats in local `State`, so answers recorded from the question list, notification taps, or the Quick Check bubble card never appeared until an app restart. The screen now `context.watch`es `StudyStatsProvider`, which every entry point records through.
4. **No accumulation, no Wrong metric** — the dashboard read only `getTodayStats()`, resetting to zero at local midnight. `StorageService.getAllDailyStudyStats` + `StudyStatsTotals.fold` now sum every stored day; Wrong (`questionsAnswered - correctAnswers`, floored at zero) is a new fourth headline metric alongside Answered/Correct/Points.

## Task Commits

1. **Task 1 — instant single-record stats path via StudyStatsProvider**: `8fc79b0` (`feat`)
   - `StudyStatsService`: `unawaited()` background push + `syncOverride` test seam; also fixed a latent bug where `AuthService.currentUser` was read outside the swallow-all-failures `try` block (uncaught assertion whenever Supabase isn't initialized — every test, and briefly at cold start).
   - New `StudyStatsProvider` (ChangeNotifier), registered in `main.dart`'s `MultiProvider`.
   - `ExamPrepHomeScreen`: removed the local `_todayStats` field; `_handleStudyCardAnswer` reduced to next-question selection and the local answers map only (no more duplicate storage/stats/notification/sync calls).
   - `QuestionScreen._submit`: records through `StorageService` then `StudyStatsProvider`, backgrounds notification scheduling and the remote review push via `unawaited()`.
   - Also laid the `StudyStatsTotals` model / `StorageService.getAllDailyStudyStats` / `StudyStatsService.getLifetimeTotals` foundation Task 2 wires into the UI.
2. **Task 2 — accumulate lifetime totals and route Quick Check through the provider**: `547ec2e` (`feat`)
   - `ExamPrepHomeScreen` dashboard now renders lifetime Answered/Correct/Wrong/Points as the headline metrics, with today's figure as secondary text; subtitle no longer implies a Supabase dependency.
   - `quick_check_card.dart` now records through `StudyStatsProvider` instead of constructing `StudyStatsService` directly, and backgrounds its notification/sync calls so clearing "Saving…" never waits on the network.
   - Verified the question-list and ambient-notification entry points already recorded exactly once through `QuestionScreen`'s `trackDailyStudyStats` flag — no changes needed there.
3. **Task 3 — regression guard widget tests**: `f8f244e` (`test`)
   - New `test/screens/exam_prep_home_screen_stats_test.dart` pinning: (a) a single `pump` (not `pumpAndSettle`) shows updated Points/Answered while the remote push is held open by a never-completing Future; (b) one recorded correct answer moves Points by exactly 10 and Answered by exactly 1, read from rendered text; (c) a prior day's stored stats plus today sum correctly across a day boundary.

**Plan metadata:** commit pending (this SUMMARY + state updates are committed separately by the orchestrator).

## Files Created/Modified

- `enchiridion/lib/providers/study_stats_provider.dart` — new ChangeNotifier owning `today`/`totals`, `recordAnswer`, `refresh`.
- `enchiridion/lib/services/study_stats_service.dart` — non-blocking push, `syncOverride` seam, `getLifetimeTotals`, `_sync` try-block bugfix.
- `enchiridion/lib/models/study_day_stats.dart` — new `StudyStatsTotals` (fold, wrongAnswers floor, accuracy).
- `enchiridion/lib/services/storage_service.dart` — new `getAllDailyStudyStats` reader.
- `enchiridion/lib/main.dart` — registers `StudyStatsProvider` in `MultiProvider`.
- `enchiridion/lib/screens/exam_prep_home_screen.dart` — watches the provider, renders 4-pill lifetime headline + daily secondary line, `testQuestions` seam for widget tests.
- `enchiridion/lib/screens/question_screen.dart` — records through the provider; backgrounds notification/sync.
- `enchiridion/lib/widgets/exam_prep/quick_check_card.dart` — records through the provider; backgrounds notification/sync.
- `enchiridion/test/providers/study_stats_provider_test.dart`, `enchiridion/test/services/study_stats_service_test.dart`, `enchiridion/test/screens/exam_prep_home_screen_stats_test.dart` — new test coverage (17 new tests total).

## Decisions Made

- See `key-decisions` in frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `StudyStatsService._sync` read `AuthService.currentUser` outside its `try` block**
- **Found during:** Task 1, first `flutter test` run — every test recording an answer without `syncOverride` threw an uncaught `AssertionError` from `Supabase.instance` (not initialized in tests), because the `currentUser` read happened before the `try`.
- **Issue:** Violated the project's own documented contract (see `QuestionReviewSyncService.push`'s docstring: "the whole body — including the `currentUser` read — is inside the try block on purpose"). The push is supposed to swallow every failure, including this one.
- **Fix:** Moved `final user = AuthService.currentUser;` inside the `try`, matching `QuestionReviewSyncService`.
- **Files modified:** `enchiridion/lib/services/study_stats_service.dart`
- **Committed in:** `8fc79b0` (Task 1 commit)

**2. [Rule 1 - Bug] `use_build_context_synchronously` lint on new `context.read<StudyStatsProvider>()` calls**
- **Found during:** Task 1/2, `flutter analyze lib test`.
- **Issue:** Reading `context.read<StudyStatsProvider>()` after an `await` (the local `storage.recordAnswer` call) risks resolving against a stale widget tree.
- **Fix:** Read both `StorageService` and `StudyStatsProvider` before the first `await` in `question_screen.dart` and `quick_check_card.dart`.
- **Files modified:** `enchiridion/lib/screens/question_screen.dart`, `enchiridion/lib/widgets/exam_prep/quick_check_card.dart`
- **Committed in:** `8fc79b0`, `547ec2e`

**3. [Rule 3 - Blocking] `ExamPrepRepository.loadQuestions()` hangs indefinitely in the widget-test environment**
- **Found during:** Task 3 — the first `pumpAndSettle()` after `pumpWidget(ExamPrepHomeScreen())` timed out. A throwaway debug harness confirmed the loading spinner never cleared after 5s of simulated pumps.
- **Issue:** `rootBundle.loadString(...)` bypasses `TestDefaultBinaryMessenger` mocks in this Flutter version — the exact constraint `test/screens/reader_screen_test.dart` already documents for `ReaderScreen`.
- **Fix:** Added `ExamPrepHomeScreen.testQuestions` (`@visibleForTesting`), mirroring the existing `ReaderScreen.testBookProvider` pattern — `_load()` skips only the asset read when a test list is supplied; access checks, storage reads, and next-question selection still run through their normal (test-overridable) paths.
- **Files modified:** `enchiridion/lib/screens/exam_prep_home_screen.dart`
- **Committed in:** `f8f244e` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bugs, 1 Rule 3 blocking issue)
**Impact on plan:** All three were necessary for correctness (deviation 1) or for the plan's own stated verification to run at all (deviations 2, 3). No scope creep — no architectural changes, no new dependencies.

## Issues Encountered

None beyond the deviations above.

## Known Stubs

None.

## Verification

- `cd enchiridion && flutter test` — 78 tests pass (61 pre-existing + 17 new across the three new test files).
- `cd enchiridion && flutter analyze lib test` — 10 issues, all pre-existing and unrelated to this plan's files (verified via `git diff --stat` against files touched); no new issues introduced.
- Manual smoke (airplane-mode Quick Check flow) was not performed — out of scope for this automated pass; the widget-test regression guard (Task 3) exercises the equivalent behavior (never-completing push, single frame) without a physical device.

## Self-Check: PASSED

- `enchiridion/lib/providers/study_stats_provider.dart` — FOUND
- `enchiridion/test/providers/study_stats_provider_test.dart` — FOUND
- `enchiridion/test/services/study_stats_service_test.dart` — FOUND
- `enchiridion/test/screens/exam_prep_home_screen_stats_test.dart` — FOUND
- Commit `8fc79b0` — FOUND
- Commit `547ec2e` — FOUND
- Commit `f8f244e` — FOUND
