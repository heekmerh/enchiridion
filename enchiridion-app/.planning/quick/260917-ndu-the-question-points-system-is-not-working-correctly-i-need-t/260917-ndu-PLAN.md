---
phase: quick-260917-ndu
plan: 01
type: execute
wave: 1
quick_id: 260917-ndu
depends_on: []
files_modified:
  - enchiridion/lib/services/study_stats_service.dart
  - enchiridion/lib/services/storage_service.dart
  - enchiridion/lib/models/study_day_stats.dart
  - enchiridion/lib/providers/study_stats_provider.dart
  - enchiridion/lib/main.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/screens/exam_prep_question_list_screen.dart
  - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
  - enchiridion/lib/widgets/exam_prep/in_app_study_prompt_host.dart
  - enchiridion/test/services/study_stats_service_test.dart
  - enchiridion/test/providers/study_stats_provider_test.dart
  - enchiridion/test/screens/exam_prep_home_screen_stats_test.dart
autonomous: true
requirements: [NDU-01, NDU-02, NDU-03, NDU-04]

estimate:
  tokens: 96000
  raw_tokens: 96000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Answering a question updates Answered / Correct / Wrong / Points on the Exam Prep dashboard in the same frame the answer is saved locally, with no network wait."
    - "Dashboard numbers are identical whether the device is online, offline, or signed out — Supabase availability never changes what the user sees."
    - "One answer increments Answered by exactly 1 and Points by exactly 10 (correct) or 0 (wrong) — never double."
    - "Points and answer counts accumulate across days instead of resetting to zero at local midnight."
    - "Answering from any entry point (Quick Check card, question list, notification tap, ambient prompt) is reflected on the dashboard without an app restart."
  artifacts:
    - enchiridion/lib/providers/study_stats_provider.dart
    - enchiridion/test/services/study_stats_service_test.dart
    - enchiridion/test/providers/study_stats_provider_test.dart
    - enchiridion/test/screens/exam_prep_home_screen_stats_test.dart
  key_links:
    - "StudyStatsProvider is registered in main.dart MultiProvider and watched by ExamPrepHomeScreen"
    - "Every answer entry point records through StudyStatsProvider exactly once (no call site both passes trackDailyStudyStats and records in its own onAnswered)"
    - "StudyStatsService local write completes and returns before the Supabase upsert is started"
---

<objective>
Fix the exam-prep points/stats system so the dashboard shows correct, accumulated, instantly-updating numbers.

Purpose: The user reports wrong points and a delay before stats appear. Investigation found four
distinct defects in the current write/read path (all confirmed by reading the source):

1. **The remote push blocks the local read-back (the reported lag).**
   `StudyStatsService.recordAnswer` (lib/services/study_stats_service.dart:44-46) performs the local
   `saveDailyStudyStats` and then `await _sync(updated)` — a Supabase upsert — *before* returning the
   value the dashboard renders. The local write already finished; the user still waits on a network
   round-trip (or its full client timeout when offline/flaky). The same pattern blocks the answer flow
   at exam_prep_home_screen.dart:101 and question_screen.dart:90, which `await` a
   `QuestionReviewSyncService.push` before the `setState` that repaints the metrics. This is exactly
   the user's own diagnosis: local-first should be immediate, the push should be background.

2. **Double-record race producing wrong point totals.**
   In exam_prep_home_screen.dart the Quick Check route passes BOTH `trackDailyStudyStats: true`
   (line 237) AND an `onAnswered` callback (lines 239-241) that runs the whole record pipeline itself
   (`_handleStudyCardAnswer`, lines 83-118). `QuestionScreen._submit` invokes `widget.onAnswered(answer)`
   without awaiting it (question_screen.dart:81) and then runs its *own* `storage.recordAnswer` (line 84)
   and `StudyStatsService.recordAnswer` (line 93). Two concurrent read-modify-write cycles over the same
   SharedPreferences keys, with no serialization. When both read `attempts == 0` they both compute
   `isFirstAttempt == true` and one answer is scored twice (20 points, +2 answered); when they serialize,
   the spaced-repetition ladder is advanced twice instead — the precise hazard `StorageService.recordAnswer`
   warns about in its own docstring (storage_service.dart:408-418). Nondeterministically wrong either way.

3. **The dashboard is a dead snapshot.**
   `ExamPrepHomeScreen._todayStats` is populated in `initState` -> `_load()` and only otherwise inside
   `_handleStudyCardAnswer`. Answers recorded through the three other entry points —
   exam_prep_question_list_screen.dart:108, in_app_study_prompt_host.dart:98 (notification taps, which
   pass `onAnswered: (_) {}`), and quick_check_card.dart:75 — write to storage but never notify the home
   screen, which stays mounted beneath the pushed route. Those points only surface after an app restart.

4. **"Accumulated" points do not accumulate.**
   The dashboard reads `getTodayStats()` only (exam_prep_home_screen.dart:51). Every metric silently
   resets to 0 at local midnight even though `storage_service.dart:547-572` retains a per-day map of all
   history. There is also no Wrong metric, only Answered / Correct / Points.

Output: A `StudyStatsProvider` (ChangeNotifier) that owns the stats, writes locally and notifies
listeners synchronously, and pushes to Supabase in the background; a dashboard that watches it; a single
recording owner per answer; lifetime accumulation; and regression tests that fail on today's code.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

Source under change (the Flutter app lives in `enchiridion/`, NOT the repo root):
@enchiridion/lib/services/study_stats_service.dart
@enchiridion/lib/models/study_day_stats.dart
@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/screens/question_screen.dart

Patterns to follow:
- `enchiridion/lib/providers/pinned_notes_provider.dart` — the project's ChangeNotifier + StorageService
  provider shape, and how it is registered in `enchiridion/lib/main.dart` (MultiProvider, lines 71-80).
- `enchiridion/lib/services/question_review_sync_service.dart` — the established "local is authoritative,
  remote push is best-effort and swallows every failure" contract, including why `Supabase.instance` must
  be read *inside* the try block (it asserts rather than throwing when `initialize()` has not run, which
  is the case in every widget test).
- `enchiridion/test/services/storage_service_test.dart` lines 1-18 — the `SharedPreferences.setMockInitialValues({})`
  test setup this project uses.

Sibling quick-batch items touch the same two files; this plan does not depend on them, but the batch
merge should be aware: 260917-nds (make the stat tiles clickable) builds directly on the metrics this
plan corrects; 260917-ndx (remove Browse Full Bank) and 260917-ndt (remove question numbers) also edit
`exam_prep_home_screen.dart`, and 260917-ndt / 260917-ndv also edit `question_screen.dart`.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: End-to-end instant stats — one answer, one record, zero network wait</name>
  <files>enchiridion/lib/services/study_stats_service.dart, enchiridion/lib/providers/study_stats_provider.dart, enchiridion/lib/main.dart, enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/test/providers/study_stats_provider_test.dart</files>
  <read_first>
    - enchiridion/lib/services/study_stats_service.dart (whole file, 72 lines)
    - enchiridion/lib/providers/pinned_notes_provider.dart (constructor + notifyListeners shape only)
    - enchiridion/lib/main.dart lines 60-95 (MultiProvider registration block)
    - enchiridion/lib/screens/exam_prep_home_screen.dart lines 28-120 and 159-181
  </read_first>
  <behavior>
    - Recording an answer returns updated stats without ever awaiting the Supabase upsert: a test that
      stubs the remote push with a Future that never completes still gets its updated stats back and
      still sees listeners notified.
    - Recording a correct answer raises performancePoints by exactly 10 and questionsAnswered by exactly 1.
    - Recording a wrong answer raises questionsAnswered by 1 and performancePoints by 0.
    - Recording the same question a second time (isFirstAttempt false) changes nothing.
    - Listeners are notified exactly once per recorded answer.
    - Listeners are notified before the background push resolves.
  </behavior>
  <action>
    Make the single Quick Check path — tap "Practice one now", answer, return — update the dashboard
    metrics immediately, with the Supabase write happening afterwards in the background. Wire it through
    every layer (service, provider, registration, screen) rather than only patching the service.

    In `StudyStatsService`, separate the local commit from the remote push. `recordAnswer` must finish the
    `saveDailyStudyStats` call and return the updated `StudyDayStats` to its caller without the remote
    upsert being part of the awaited chain. Import `dart:async` and start the sync as an unawaited future
    so a slow or hanging Supabase client cannot delay the return. Extract the remote upsert behind a
    protected/injectable seam (a named method or an optional constructor callback defaulting to the real
    upsert) so tests can substitute a never-completing future and prove the return is not gated on it.
    Keep the existing swallow-all-failures contract on the push, and keep the existing `isFirstAttempt`
    no-op guard and its docstring rationale intact.

    Create `enchiridion/lib/providers/study_stats_provider.dart` — a `ChangeNotifier` constructed from
    `StorageService`, following the shape of `PinnedNotesProvider`. It owns the exam-prep stats state,
    exposes the current day's `StudyDayStats` as a getter, exposes a `recordAnswer` method taking
    isCorrect / isFirstAttempt / scope / answeredAt that delegates to `StudyStatsService`, assigns the
    returned value to its field, and calls `notifyListeners()` synchronously on that same turn. Also
    expose a `refresh()` that re-reads from storage and notifies, for callers that recorded elsewhere.
    Load the initial value from storage in the constructor so the first frame is already correct.

    Register it in `main.dart` inside the existing `MultiProvider` list as a `ChangeNotifierProvider`
    built from the same `storageService` instance the neighbouring providers receive.

    In `ExamPrepHomeScreen`, stop holding stats in local `State`. Read them from the provider in `build`
    via a `context.watch` so any notification repaints the metric pills. Remove the `_todayStats` field
    and its assignments in `_load` and `_handleStudyCardAnswer`.

    Fix the double-record on this path: the Quick Check route currently both passes
    `trackDailyStudyStats: true` to `QuestionScreen` and hands it an `onAnswered` that repeats the entire
    record pipeline. Make `QuestionScreen` the sole recorder for this route — keep the flag, and reduce
    the screen's `onAnswered` callback to updating the local answers map and asking the provider to
    refresh. Delete the storage/stats/notification/sync calls that `_handleStudyCardAnswer` duplicates,
    retaining only the next-question selection and answers-map update that are genuinely this screen's job.
    Do not leave a second code path that can record the same answer.

    Add `enchiridion/test/providers/study_stats_provider_test.dart` covering the behaviors above, using
    the `SharedPreferences.setMockInitialValues({})` setup from `test/services/storage_service_test.dart`.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/providers/study_stats_provider_test.dart</automated>
  </verify>
  <done>A correct answer through the Quick Check path raises the dashboard Points by exactly 10 and Answered by exactly 1, visible without waiting on any network call; the provider test passes including the never-completing-push case; only one code path records a given answer.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Accumulate lifetime totals, add Wrong, and route every entry point through the provider</name>
  <files>enchiridion/lib/services/storage_service.dart, enchiridion/lib/models/study_day_stats.dart, enchiridion/lib/services/study_stats_service.dart, enchiridion/lib/providers/study_stats_provider.dart, enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/exam_prep_question_list_screen.dart, enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/widgets/exam_prep/in_app_study_prompt_host.dart, enchiridion/test/services/study_stats_service_test.dart</files>
  <read_first>
    - enchiridion/lib/services/storage_service.dart lines 540-573 (the per-day stats map)
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart lines 51-85
    - enchiridion/lib/screens/exam_prep_question_list_screen.dart lines 95-125
    - enchiridion/lib/widgets/exam_prep/in_app_study_prompt_host.dart lines 75-104
  </read_first>
  <behavior>
    - Folding a stats map holding three separate days returns totals equal to the sum of all three days.
    - Lifetime totals are unchanged by the local clock crossing midnight; a day recorded yesterday still
      contributes to the displayed Points.
    - Wrong equals questionsAnswered minus correctAnswers, and is never negative.
    - An empty stats map folds to zero for every metric rather than throwing.
    - Answering through the question-list route notifies the stats provider.
  </behavior>
  <action>
    Expand the proven slice from Task 1 to the remaining entry points and to lifetime accumulation.

    In `StorageService`, add a reader that returns every stored `StudyDayStats` for a scope by decoding
    the whole per-day map at the `study_stats_` prefix key, tolerating malformed or absent entries the
    same way `getDailyStudyStats` already does (return empty, never throw).

    Add a small immutable totals value holding questionsAnswered, correctAnswers, performancePoints and a
    derived wrong count and accuracy, plus a fold constructor over an iterable of `StudyDayStats`. Put it
    alongside `StudyDayStats` in enchiridion/lib/models/study_day_stats.dart. Guard the derived wrong
    count so it cannot go negative if a stored day is inconsistent.

    Expose the lifetime totals from `StudyStatsService` and surface them on `StudyStatsProvider` as a
    getter refreshed alongside the daily value on every record and refresh.

    On the dashboard, render the accumulated totals as the headline metrics the user asked for — Answered,
    Correct, Wrong, Points — and keep the daily figure as clearly-labelled secondary context rather than
    the primary number. Update the metric card's subtitle so it no longer implies the displayed numbers
    depend on Supabase being reachable. Adjust the metric row layout to hold four pills without overflow.

    Route the other three answer entry points through the provider so the dashboard never shows stale
    numbers. In `QuestionScreen`, have the stats recording go through `StudyStatsProvider` instead of
    constructing `StudyStatsService` directly, and move the `QuestionReviewSyncService.push` and the
    notification scheduling off the awaited path that precedes the caller's UI update, so submitting an
    answer never blocks on the network. In `quick_check_card.dart`, replace its direct
    `StudyStatsService(storage).recordAnswer` with the provider call and likewise stop awaiting the remote
    push before clearing its saving state. In `in_app_study_prompt_host.dart` and
    `exam_prep_question_list_screen.dart`, leave `trackDailyStudyStats: true` as the single recording
    trigger — verify neither one also records in its own `onAnswered` callback, and if it does, remove the
    duplicate so each answer is recorded exactly once.

    Add `enchiridion/test/services/study_stats_service_test.dart` covering the folding behaviors above.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/services/study_stats_service_test.dart test/providers/study_stats_provider_test.dart test/services/storage_service_test.dart</automated>
  </verify>
  <done>The dashboard shows Answered, Correct, Wrong and Points summed over all recorded days; the numbers survive a day boundary; all four answer entry points record exactly once and notify the provider.</done>
</task>

<task type="auto">
  <name>Task 3: Regression guard — dashboard repaints instantly with the remote push unavailable</name>
  <files>enchiridion/test/screens/exam_prep_home_screen_stats_test.dart</files>
  <read_first>
    - enchiridion/test/screens/question_screen_test.dart (this project's widget-test harness: how it wraps
      a screen in MultiProvider with a mocked StorageService and pumps)
  </read_first>
  <action>
    Add a widget test that would fail against the pre-fix code, pinning the two defects the user reported.

    Build the Exam Prep dashboard inside the project's usual provider harness with
    `SharedPreferences.setMockInitialValues({})` and a `StudyStatsProvider` whose remote push is
    substituted with a future that never completes — standing in for an offline or degraded network.
    Record a correct answer through the provider, `pump` a single frame (do NOT use `pumpAndSettle`,
    which would mask a pending network wait), and assert the rendered Points and Answered values have
    already changed. Assert the test completes without a pending-timer or unsettled-future failure.

    Add a second case asserting one recorded correct answer moves Points by exactly 10 and Answered by
    exactly 1 — the double-count guard — by recording once through the provider and reading the rendered
    text, not by inspecting internal counters.

    Add a third case seeding the stats map with a prior day plus today and asserting the rendered Points
    equal the sum across both days.

    Then run the full suite and the analyzer to confirm nothing else regressed.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test &amp;&amp; flutter analyze lib test</automated>
  </verify>
  <done>`flutter test` passes across the whole suite including the three new dashboard cases, and `flutter analyze lib test` reports no new issues.</done>
</task>

</tasks>

<verification>
- `cd enchiridion && flutter test` — full suite green, including the three new test files.
- `cd enchiridion && flutter analyze lib test` — no new analyzer issues.
- Manual smoke (optional, device/emulator): with airplane mode ON, answer a Quick Check question and
  confirm Points/Answered change the instant the answer is submitted; re-enable network and confirm the
  row later appears in Supabase `daily_study_stats` without any further user action.
</verification>

<success_criteria>
- Dashboard metrics change in the same frame the answer is committed locally, with no network dependency.
- Displayed numbers are identical online, offline, and signed out.
- One answer moves Answered by exactly 1 and Points by exactly 10 (correct) or 0 (wrong).
- Points and counts accumulate across days rather than resetting at local midnight.
- Answered / Correct / Wrong / Points are all displayed.
- All four answer entry points update the dashboard without an app restart.
</success_criteria>

<output>
Create `.planning/quick/260917-ndu-the-question-points-system-is-not-working-correctly-i-need-t/260917-ndu-SUMMARY.md` when done.
</output>
