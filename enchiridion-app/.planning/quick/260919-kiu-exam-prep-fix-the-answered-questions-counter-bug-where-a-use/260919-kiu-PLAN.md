---
phase: quick-260919-kiu
plan: 01
type: execute
wave: 2
quick_id: 260919-kiu
batch_id: 260919-kir
depends_on: ["260919-kis"]
files_modified:
  - enchiridion/lib/services/study_stats_service.dart
  - enchiridion/lib/providers/study_stats_provider.dart
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
  - enchiridion/lib/screens/answered_questions_screen.dart
  - enchiridion/test/screens/question_screen_test.dart
  - enchiridion/test/providers/study_stats_provider_test.dart
  - enchiridion/test/services/study_stats_service_test.dart
  - enchiridion/test/screens/exam_prep_home_screen_stats_test.dart
autonomous: true
requirements: [260919-kiu]

estimate:
  tokens: 18000
  raw_tokens: 18000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Answering four Exam Prep questions in a sitting moves the dashboard's Answered tile from 0 to 4, whether those four were brand-new questions, spaced-repetition re-serves, or a mix."
    - "Correct, Wrong and Points move on the same answer events as Answered, so the four tiles stay internally consistent: four answers with three correct render Answered 4, Correct 3, Wrong 1, Points 30."
    - "Retrying a previously wrong question from the Answered drill-down registers on the dashboard instead of silently recording nothing."
    - "One submission still counts exactly once — submitting a single answer never moves Answered by 2 or Points by 20."
    - "Lifetime totals still accumulate across days and are still written locally first, with the Supabase push still unawaited: a hanging network must not delay or block a counted answer."
  artifacts:
    - "enchiridion/lib/services/study_stats_service.dart (recordAnswer counts every answer event; the first-attempt suppression and its parameter are gone)"
    - "enchiridion/lib/providers/study_stats_provider.dart (recordAnswer passes through without the suppression flag)"
    - "enchiridion/lib/screens/question_screen.dart (_submit's stats call updated to the new signature)"
    - "enchiridion/lib/widgets/exam_prep/quick_check_card.dart (_submit's stats call updated to the new signature)"
    - "enchiridion/test/screens/question_screen_test.dart (end-to-end regression: two submissions of the same question count twice)"
    - "enchiridion/test/providers/study_stats_provider_test.dart (the test that asserted a repeat 'changes nothing' is inverted to assert it counts)"
  key_links:
    - "QuestionScreen._submit -> StudyStatsProvider.recordAnswer -> StudyStatsService.recordAnswer -> StorageService.saveDailyStudyStats -> getLifetimeTotals -> the Answered tile in exam_prep_home_screen.dart. The suppression sits in the middle hop of that chain; every surface above it is already correct and must not be changed to compensate."
    - "QuestionReview.attempts must stop being an input to the stats path at all. Reviews merged from Supabase (StorageService.mergeQuestionReviews) or derived from pre-spaced-repetition answers (_reviewsFromLegacyAnswers) arrive with attempts already >= 1, so on a second device or an upgraded install the attempts check also zeroed genuinely-first answers. Removing the parameter — rather than loosening the comparison — closes that second failure mode for free."
    - "The real protection against double-counting is structural and already in place: exactly one recordAnswer call per submission, documented at question_screen.dart's _submit ('This is the sole place StudyDayStats are recorded for this answer'). That invariant, not the attempts check, is what Task 1's and Task 2's guards must hold."
    - "NextQuestionSelector alternates due reviews with unseen questions, so once a user has any review backlog roughly half of what they are served is a repeat. That is why the reported ratio is 4 answered -> 2 counted rather than an occasional off-by-one."
---

<objective>
Make the Exam Prep dashboard count every answer the user actually gives, instead of only the first
answer to each distinct question.

Purpose: a user who answers four questions sees "Answered: 2". Investigation traced this to a
deliberate suppression added by commit `d0a90f6` ("fix: don't double-count repeat answers in daily
study stats"): `StudyStatsService.recordAnswer` returns the day's stats **unchanged** whenever the
caller's `QuestionReview.attempts` is not exactly 1. Spaced repetition exists to re-serve questions,
and `NextQuestionSelector` alternates due reviews with unseen questions — so about half of a normal
sitting is re-serves, every one of which is dropped by that early return. That over-corrected: the
genuine risk it was written against (one submission recorded twice by two different surfaces) is
already prevented structurally, because `QuestionScreen._submit` is now the single place a submission
records stats. The attempts check no longer protects anything; it only deletes real work from the
user's counter — along with their Correct, Wrong and Points, which sit behind the same early return.

Output: `questionsAnswered`, `correctAnswers` and `performancePoints` increment once per answer
event on every surface; the suppression flag is removed from the service, the provider, and both
production call sites; a regression test reproduces the reported scenario end to end; and the three
existing stats suites are realigned to the corrected semantic.
</objective>

<root_cause>
Established by reading the code — do not re-derive:

- `enchiridion/lib/services/study_stats_service.dart:47` is the defect: `if (!isFirstAttempt) return current;`
  short-circuits before the `copyWith` that raises `questionsAnswered`, `correctAnswers` and
  `performancePoints`. Nothing is written and nothing is pushed; the answer simply vanishes.
- The flag is computed identically at both production call sites as `review.attempts == 1`, where
  `review` is the `QuestionReview` returned by `StorageService.recordAnswer`:
  `enchiridion/lib/screens/question_screen.dart:214` and
  `enchiridion/lib/widgets/exam_prep/quick_check_card.dart:74`.
  `QuestionReview.applyAnswer` increments `attempts` on every answer, so the flag is true exactly once
  per question, ever — not once per answer.
- The dashboard tile reads `statsProvider.totals.questionsAnswered`
  (`enchiridion/lib/screens/exam_prep_home_screen.dart:191`), folded from stored days by
  `StudyStatsService.getLifetimeTotals`. That fold is correct; it is faithfully summing days that were
  never incremented.
- Two compounding variants of the same root cause, both closed by removing the flag rather than by
  extra work: `StorageService.mergeQuestionReviews` can install a remote review with `attempts >= 1`
  for a question this device has never answered, and `_reviewsFromLegacyAnswers` derives
  `attempts == 1` for every pre-spaced-repetition answer. In both cases the next local answer computes
  `attempts == 2` and is dropped even though it is the first answer on this device.
- Ruled out by inspection, so do not go looking there: scope routing is sound (all three
  stats-tracking `QuestionScreen` call sites resolve to `kStandaloneExamPrepScope` — the home screen
  passes it literally, `InAppStudyPromptHost` filters to it at line 76, and the drill-down passes it
  literally), there is no divisor or dedupe in the fold (`StudyStatsTotals.fold` is a plain sum), and
  the write path is already synchronous-then-unawaited so no race drops alternate answers.
</root_cause>

<semantic_decision>
The corrected meaning of the four dashboard tiles is **answers given**, not **distinct questions
touched**:

- Answered = how many questions the user has answered, counting a re-served question again each time
  they answer it. This is what the user means by "I answered 4".
- Correct / Wrong = the same events split by outcome, so accuracy (`correctAnswers / questionsAnswered`,
  already computed that way in `StudyDayStats` and `StudyStatsTotals`) stays truthful. Leaving Correct
  and Points on first-attempts-only while Answered counts events would produce an accuracy figure that
  is wrong in a *new* way — these three fields sit behind one shared early return and must move
  together. That is the whole of the "shared broken code path" exception; nothing else changes.
- Points = 10 per correct answer event. A user who re-earns a question after a lapse has genuinely
  done the work; `QuestionReview`'s ladder (a 90-minute cross-surface cooldown in
  `NextQuestionSelector`, a one-day floor after a miss) is what rate-limits this, and it is unchanged
  by this plan.

The Answered drill-down (`answered_questions_screen.dart`) keeps listing **distinct questions** — it
is a browse-and-retry surface and one row per question is correct there. Task 2 adjusts only its two
copy lines so the difference reads as intentional rather than as a second bug.
</semantic_decision>

<scope_boundaries>
This is one item in quick batch `260919-kir`. Stay inside the counting path:

- **Do not touch the spaced-repetition ladder.** `enchiridion/lib/models/question_review.dart`,
  `enchiridion/lib/services/next_question_selector.dart` and `StorageService`'s review/serve-log
  methods are correct as written and are not in `files_modified`. Re-serving a question is the feature,
  not the bug.
- **Do not change scope routing, the Supabase table, or `scripts/sql/`.** `_sync` upserts the same
  columns to `daily_study_stats`; the `get_leaderboard` RPC aggregates that table server-side and needs
  no migration.
- **Do not change streaks, accuracy formulas, or the fold.** `StudyStatsTotals.fold` and the
  `accuracy` getters already do the right arithmetic over whatever they are given.
- **260919-kis owns the auto-advance removal in `question_screen.dart`.** This plan depends on it and
  edits only the `statsProvider.recordAnswer(...)` argument list inside `_submit`. Do not touch the
  advance/Next-button behavior kis leaves behind, and do not reintroduce a countdown.
- **260919-kit owns the "Quick Check" copy retirement** (including in
  `widgets/exam_prep/quick_check_card.dart`) and **260919-kiv owns option-label shuffling** in both
  `question_screen.dart` and the bubble card. Both declare themselves *after* this item, so this
  plan's diff lands first. Change no user-facing "Quick Check" string and no option-label logic here.
  If either has nonetheless already landed in this worktree's base — the card widget renamed, its copy
  reworded, or `optionSeed`/label handling restructured — adapt to what is on disk and never revert it;
  the only edit this plan makes in that file is to the stats call inside its `_submit`.

Ordering note: `depends_on` lists only `260919-kis` on purpose. `kit` already declares a dependency on
this item, so naming `kit` (or `kiv`, which depends on `kit`) back would close a dependency cycle.
`kis` is the one overlapping item with no inbound edge from here, and sequencing after it means this
plan edits `_submit` in its final post-auto-advance shape.
</scope_boundaries>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

The defect and its call sites:
@enchiridion/lib/services/study_stats_service.dart
@enchiridion/lib/providers/study_stats_provider.dart

The surface that reads the counter (READ ONLY — this plan does not edit it):
@enchiridion/lib/screens/exam_prep_home_screen.dart

The sibling plan this one is sequenced after:
@.planning/quick/260919-kis-exam-prep-after-a-user-answers-a-question-remove-the-automat/260919-kis-PLAN.md
</context>

<interface_notes>
Facts established by investigation — do not re-derive:

- Current signature:
  `Future<StudyDayStats> recordAnswer({String scope = kStandaloneExamPrepScope, required bool isCorrect, required bool isFirstAttempt, DateTime? answeredAt})`
  on both `StudyStatsService` (study_stats_service.dart:38) and `StudyStatsProvider`
  (study_stats_provider.dart:44). The provider is a thin pass-through that then refreshes `_today` and
  `_totals` and calls `notifyListeners()` synchronously — that behavior is correct and stays.
- The suppression parameter is required and positional-by-name at three call sites in `lib/`
  (the two production `_submit` methods and the provider pass-through) and at nine call sites across
  three test files. Because it is `required`, dropping it from the signature makes every stale caller a
  compile error — which is the executor's checklist: the analyzer will name each one.
- `StudyDayStats.copyWith` is what performs the increment; the day is keyed by
  `StudyStatsService.dateKeyFor(timestamp)` and persisted through
  `StorageService.saveDailyStudyStats`, which merges into a per-scope map of days.
- `StudyStatsService` takes a `syncOverride` test seam whose whole purpose is proving the remote push
  is never awaited. Tests pass `(_) => Completer<void>().future`. Keep that seam and keep `unawaited`.
- `test/screens/question_screen_test.dart` already has a `_buildSubject(...)` helper that wires
  `Provider<StorageService>.value` plus `ChangeNotifierProvider<StudyStatsProvider>(create: ...)` and
  accepts `trackDailyStudyStats`. It constructs the provider internally, so a test cannot currently
  read the totals back — Task 1 adds an optional injection parameter for that.
- `test/providers/study_stats_provider_test.dart:79-90` is the one test that asserts the *defect* as
  intended behavior ("recording the same question a second time (not first attempt) changes nothing").
  Every other `isFirstAttempt: true` occurrence in the three test suites is a plain argument removal
  with no expectation change.
- `test/screens/exam_prep_home_screen_stats_test.dart` asserts against rendered tile text
  (`find.text('10')`, `find.text('1')`), including a test explicitly named the double-count guard.
  Those expectations stay exactly as they are: one recorded answer still renders 10 and 1.
- The Flutter app lives in `enchiridion/`, not at the repo root. Commands below assume the executor's
  working directory is the repo root and use a relative `cd enchiridion` so they stay correct inside a
  git worktree.
</interface_notes>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: A repeat answer counts — end to end from a real submission to the dashboard totals</name>
  <precondition>`enchiridion/lib/screens/question_screen.dart` still contains a `statsProvider.recordAnswer(...)` call inside `_submit`, and `enchiridion/lib/widgets/exam_prep/quick_check_card.dart` (or the path sibling 260919-kit renamed it to) still contains its own `statsProvider.recordAnswer(...)` call. If either stats call is absent, halt and report which surface lost it rather than re-adding one.</precondition>
  <files>enchiridion/lib/services/study_stats_service.dart, enchiridion/lib/providers/study_stats_provider.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/test/screens/question_screen_test.dart</files>
  <read_first>enchiridion/lib/services/study_stats_service.dart (the whole file — the early return at line 47, its doc comment, and the unawaited push), enchiridion/lib/providers/study_stats_provider.dart (the whole file), enchiridion/lib/screens/question_screen.dart (_submit, in whatever shape sibling 260919-kis left it), enchiridion/lib/widgets/exam_prep/quick_check_card.dart (_submit), enchiridion/test/screens/question_screen_test.dart (the _buildSubject helper and one existing submit-flow test, for the tap sequence and finder idioms this suite uses)</read_first>
  <behavior>
    - Submitting an answer to the same question twice through `QuestionScreen` with daily-stats tracking on leaves the shared provider reporting two answers, not one.
    - Two correct submissions of the same question leave lifetime points at 20 and correct at 2.
    - A second submission that is wrong after a first that was correct leaves answered at 2, correct at 1, wrong at 1.
    - A single submission still leaves answered at 1 and points at 10 — the double-count guard holds.
    - The service still returns without awaiting the remote push: a recorded answer completes even when the push future never resolves.
  </behavior>
  <action>
    Remove the suppression from the whole chain, proving it with a test that fails first for the
    reported reason.

    Start with the test, in `enchiridion/test/screens/question_screen_test.dart`. Extend the existing
    `_buildSubject` helper with one optional named parameter that accepts an externally constructed
    `StudyStatsProvider`; when supplied, provide it with `ChangeNotifierProvider.value`, and when
    omitted keep today's `create:` behavior byte-for-byte so no existing test in that suite changes.
    Then add a test that pumps the subject with tracking enabled and a provider the test holds a
    reference to, taps the correct option, taps Submit, settles, and asserts the provider's lifetime
    totals read one answer. Then drive a second submission of the same question and assert the totals
    read two answers and twenty points. Reach the second submission the way the screen actually allows
    it — re-pumping a fresh subject over the same `StorageService` and the same provider instance is
    the cheapest honest route, since a real user reaches a repeat by being re-served the question in a
    later session. Do not fake the review state to force `attempts` back to 1; the point of the test is
    that `attempts` is irrelevant. Run it and confirm it fails asserting two but finding one — if it
    fails any other way, stop and report before changing production code.

    Then in `enchiridion/lib/services/study_stats_service.dart`, delete the early return that skips the
    update, and delete the suppression parameter from the signature so no caller can reintroduce it.
    Rewrite the method's doc comment to state the corrected contract in the file's existing voice:
    every submitted answer counts once, a re-served question counts again each time it is answered
    because the user genuinely answered it again, and the protection against recording one submission
    twice is that exactly one surface records each submission — not an inspection of review state.
    Note in that comment why review state is deliberately not consulted: a review merged from another
    device, or derived from a pre-spaced-repetition answer, carries a non-zero attempt count that has
    nothing to do with whether this answer is new. Leave the local-write-then-unawaited-push structure,
    the `syncOverride` seam, and `dateKeyFor` exactly as they are.

    In `enchiridion/lib/providers/study_stats_provider.dart`, drop the same parameter from
    `recordAnswer` and from the inner service call. Change nothing else — the synchronous
    `_today`/`_totals` refresh and the single `notifyListeners()` per recorded answer are the behavior
    sibling item 260917-ndu established and several tests assert.

    At both production call sites — `_submit` in `enchiridion/lib/screens/question_screen.dart` and
    `_submit` in `enchiridion/lib/widgets/exam_prep/quick_check_card.dart` — remove only the argument
    line that threads the review's attempt count into the stats call. Keep the surrounding structure
    untouched: the local `storage.recordAnswer` write still comes first and is still awaited, the
    review it returns is still used for the notification scheduling and the remote review push below,
    and the ordering comments there remain accurate. Resist deleting the now-possibly-unused local
    variable without checking — the review is still needed by the calls that follow.

    Re-run the new test and confirm it passes.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/screens/question_screen_test.dart</automated>
  </verify>
  <done>A second answer to the same question, submitted through the real screen, moves the shared provider's totals from one to two answers and from ten to twenty points; the suppression parameter no longer exists on the service, the provider, or either call site; a single submission still counts exactly once.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Realign the three stats suites to the corrected semantic and fix the drill-down copy</name>
  <files>enchiridion/test/providers/study_stats_provider_test.dart, enchiridion/test/services/study_stats_service_test.dart, enchiridion/test/screens/exam_prep_home_screen_stats_test.dart, enchiridion/lib/screens/answered_questions_screen.dart</files>
  <read_first>enchiridion/test/providers/study_stats_provider_test.dart (the whole file — especially the repeat-answer test at lines 79-90), enchiridion/test/services/study_stats_service_test.dart (the getLifetimeTotals group around lines 94-125), enchiridion/test/screens/exam_prep_home_screen_stats_test.dart (all three widget tests and their rendered-text expectations), enchiridion/lib/screens/answered_questions_screen.dart (the kCorrectAnswerPoints declaration and doc comment at lines 11-18, the all-time counter getters and their comment at lines 93-104, and the two rendered copy lines at 146-161)</read_first>
  <behavior>
    - Recording the same question a second time raises answered to 2 and points to 20 — the suite asserts the corrected behavior, under a name that describes it.
    - The reported scenario is locked: four recorded answers, of which two are repeats of already-answered questions, fold to lifetime totals of four answered.
    - Three correct out of those four leave correct at 3, wrong at 1 and points at 30, so accuracy reads 0.75.
    - Lifetime totals still accumulate across a day boundary, and the rendered dashboard still shows 30 points for a stored prior day of 20 plus one correct answer today.
    - The dashboard still repaints within a single frame while the remote push never resolves.
    - Every stats suite compiles against the new signature with no suppression argument anywhere.
  </behavior>
  <action>
    Bring the tests that encoded the old contract onto the new one, and stop the drill-down copy from
    contradicting the corrected tiles.

    In `enchiridion/test/providers/study_stats_provider_test.dart`, invert the test that currently
    asserts a repeat changes nothing: rename it to describe a repeat as counted work, and assert the
    second recorded answer reads two answered and twenty points. Remove the suppression argument from
    every other call in the file; those tests keep their existing expectations unchanged, because a
    first answer counted before and still counts now.

    In `enchiridion/test/services/study_stats_service_test.dart`, remove the suppression argument from
    the `getLifetimeTotals` test and add a regression test named for the reported bug: record four
    answers through the service where two of them are repeats of questions already answered in the same
    run, then assert lifetime totals read four answered. Make three of the four correct and assert
    correct 3, wrong 1, points 30, so the fix is pinned across all four tiles rather than on the
    headline count alone. Drive it through `StudyStatsService.recordAnswer` over a real
    `StorageService` on mock `SharedPreferences`, matching how the rest of that file is set up, and
    pass the `syncOverride` seam so the test never reaches the network.

    In `enchiridion/test/screens/exam_prep_home_screen_stats_test.dart`, remove the suppression
    argument from the three provider calls. Leave every rendered-text expectation exactly as written,
    including the test named as the double-count guard — one recorded answer must still render 10
    points and 1 answered, and that suite is the proof this change did not turn one submission into
    two.

    In `enchiridion/lib/screens/answered_questions_screen.dart`, make three small copy and comment
    corrections and nothing else. The points line rendered under the points filter must stop saying a
    *first* correct answer is the one worth points — every correct answer now is. The `kCorrectAnswerPoints`
    doc comment must drop its stale note that a sibling item forbids editing the stats service (this
    plan edits it) while keeping the reminder that the value is duplicated here and must stay in sync.
    The all-time summary line and the comment above its getters should say plainly that this screen
    counts distinct questions while the dashboard tiles count answers given, so the two figures
    differing is legible rather than alarming. Do not change the row list, the filters, the retry
    behavior, or the read-only guard on correct rows.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/providers/study_stats_provider_test.dart test/services/study_stats_service_test.dart test/screens/exam_prep_home_screen_stats_test.dart test/screens/answered_questions_screen_test.dart</automated>
  </verify>
  <done>All four suites pass against the new signature; the provider suite asserts a repeat counts; a service-level regression test reproduces four-answers-with-two-repeats folding to four; the drill-down copy no longer claims only a first correct answer scores.</done>
</task>

<task type="auto">
  <name>Task 3: Analyzer, full-suite regression, and blast-radius check</name>
  <files>enchiridion/lib/services/study_stats_service.dart, enchiridion/lib/providers/study_stats_provider.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/screens/answered_questions_screen.dart</files>
  <read_first>enchiridion/test/services/storage_service_test.dart (the review/day-stats persistence suite most exposed to this change), enchiridion/test/models/question_review_test.dart (the ladder suite, which must pass completely untouched — if it does not, the ladder was modified and that must be reverted)</read_first>
  <action>
    Confirm nothing outside the counting path moved.

    Run the analyzer over the five changed library files, then the entire test suite. Because the
    suppression parameter was `required`, any caller this plan missed is a compile error the analyzer
    names outright — fix those call sites rather than restoring the parameter.

    The most exposed suites are `test/services/storage_service_test.dart`,
    `test/models/question_review_test.dart` (ladder behavior — must be green with zero edits),
    `test/screens/question_screen_test.dart` in whatever shape sibling 260919-kis left it, and
    `test/services/next_question_selector_test.dart`. Fix production code rather than loosening any
    assertion, with one exception: if a suite asserts the old first-attempt-only counting that this
    plan deliberately changed, update that expectation and call it out explicitly in the summary,
    naming the file, the old expectation and the new one.

    Resolve only analyzer findings this plan introduced — an unused import or an unused local left
    behind by the removed argument. Leave pre-existing findings in untouched files alone.

    Finally confirm the blast radius: `git diff --name-only` must list exactly the nine paths in this
    plan's `files_modified` and nothing more. In particular
    `enchiridion/lib/models/question_review.dart`,
    `enchiridion/lib/services/next_question_selector.dart`,
    `enchiridion/lib/services/storage_service.dart`,
    `enchiridion/lib/screens/exam_prep_home_screen.dart` and anything under `scripts/sql/` must be
    absent from that list.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/services/study_stats_service.dart lib/providers/study_stats_provider.dart lib/screens/question_screen.dart lib/widgets/exam_prep/quick_check_card.dart lib/screens/answered_questions_screen.dart &amp;&amp; flutter test</automated>
  </verify>
  <done>The analyzer reports no issues for the five changed library files, the full `flutter test` suite is green, and the changed-file list matches `files_modified` exactly.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user submission -> local stats store | A tap becomes a `SharedPreferences` write through `StudyStatsService` -> `StorageService.saveDailyStudyStats`. This plan changes when that write happens, never what is written or where. |
| local stats store -> Supabase `daily_study_stats` | `_sync` upserts the same columns for the signed-in user; the `get_leaderboard` RPC then aggregates that table across users. Counting repeats raises what a studying user uploads. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260919-kiu-01 | Tampering | `performancePoints` now awarded per correct answer event, feeding the cross-user leaderboard | medium | mitigate | Re-answering is not free: `NextQuestionSelector` enforces a 90-minute cross-surface cooldown and a one-day floor after a miss, and the drill-down opens correct rows read-only so a correct answer cannot be resubmitted for points from there. The rule is uniform across users, so the leaderboard ordering stays meaningful. Task 2 pins the award at 10 per correct answer so a future edit cannot silently multiply it. |
| T-260919-kiu-02 | Tampering | one submission recorded twice by two surfaces | medium | mitigate | The attempts check that incidentally masked this is being removed, so the structural invariant must be held explicitly: exactly one `recordAnswer` per submission, asserted by Task 1's single-submission assertion and by the existing double-count guard test in `exam_prep_home_screen_stats_test.dart`, which Task 2 leaves unchanged. |
| T-260919-kiu-03 | Repudiation | local `SharedPreferences` stats are user-writable on a rooted device | low | accept | Pre-existing and unchanged by this plan: local state was already authoritative and already uploaded. No new trust is placed in the client here. |
| T-260919-kiu-04 | Denial of Service | a hanging Supabase push delaying a counted answer | low | mitigate | The local write stays first and the push stays `unawaited` behind the `syncOverride` seam; Task 1's behavior list keeps the never-resolving-push assertion, and the home-screen suite still proves a single-frame repaint while the push is held open. |
| T-260919-kiu-05 | Tampering | package-manager installs | low | accept | No pub/npm/pip/cargo install occurs — no `pubspec.yaml` change, no new dependency, no new asset. The package-legitimacy gate does not apply. |
</threat_model>

<verification>
1. `cd enchiridion && flutter test test/screens/question_screen_test.dart` — passes, including the new
   two-submissions regression.
2. `cd enchiridion && flutter test test/providers/study_stats_provider_test.dart test/services/study_stats_service_test.dart test/screens/exam_prep_home_screen_stats_test.dart test/screens/answered_questions_screen_test.dart` — passes.
3. `cd enchiridion && flutter analyze lib/services/study_stats_service.dart lib/providers/study_stats_provider.dart lib/screens/question_screen.dart lib/widgets/exam_prep/quick_check_card.dart lib/screens/answered_questions_screen.dart` — clean.
4. `cd enchiridion && flutter test` — full suite green, with `test/models/question_review_test.dart`
   passing unedited.
5. `git diff --name-only` lists exactly the nine paths in `files_modified`; `question_review.dart`,
   `next_question_selector.dart`, `storage_service.dart`, `exam_prep_home_screen.dart` and
   `scripts/sql/` are absent.
6. Read-back: `StudyStatsService.recordAnswer` has no parameter carrying review state, and its doc
   comment states the corrected once-per-answer contract.
</verification>

<success_criteria>
- A user who answers four Exam Prep questions sees Answered: 4, whether those four were new questions,
  re-served reviews, or a mix.
- Correct, Wrong and Points move with the same answer events, so the four tiles agree with each other
  and accuracy stays truthful.
- Retrying a previously wrong question from the Answered drill-down now registers on the dashboard.
- One submission still counts exactly once — the double-count guard test is unchanged and green.
- The spaced-repetition ladder, question selection, scope routing, the Supabase schema and the
  leaderboard RPC are untouched.
- The drill-down still lists one row per distinct question, and its copy now explains why that figure
  differs from the tiles instead of contradicting them.
</success_criteria>

<output>
Create `.planning/quick/260919-kiu-exam-prep-fix-the-answered-questions-counter-bug-where-a-use/260919-kiu-SUMMARY.md` when done.
</output>
