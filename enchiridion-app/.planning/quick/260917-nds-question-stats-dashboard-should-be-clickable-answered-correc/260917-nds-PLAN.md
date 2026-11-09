---
quick_id: 260917-nds
type: execute
depends_on: []
files_modified:
  - enchiridion/lib/models/answered_question_filter.dart
  - enchiridion/lib/screens/answered_questions_screen.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/test/models/answered_question_filter_test.dart
  - enchiridion/test/screens/answered_questions_screen_test.dart
autonomous: true

must_haves:
  truths:
    - "Tapping the Wrong tile on the Exam Prep dashboard opens a list of the questions the user has answered incorrectly."
    - "From that list the user can retry a missed question, answer it, and see the row move out of the Wrong filter."
    - "Tapping Answered, Correct, and Points each opens the same browse screen pre-filtered to that status."
    - "The browse screen never shows a question the user has not already answered."
  artifacts:
    - enchiridion/lib/models/answered_question_filter.dart
    - enchiridion/lib/screens/answered_questions_screen.dart
    - enchiridion/test/models/answered_question_filter_test.dart
    - enchiridion/test/screens/answered_questions_screen_test.dart
  key_links:
    - "ExamPrepHomeScreen metric pills -> AnsweredQuestionsScreen(initialFilter:)"
    - "AnsweredQuestionsScreen row -> QuestionScreen(readOnly: false) for wrong answers (retry path)"
    - "StorageService.getAnswers(kStandaloneExamPrepScope) -> the list contents, re-read after each pop"
---

<objective>
Make the four Exam Prep dashboard metric tiles (Answered, Correct, Wrong, Points) tappable, each opening a browse screen filtered to that status, from which the user can retry a question they got wrong.

Purpose: the dashboard currently reports four numbers with no way to act on them. The single highest-value action behind those numbers — "show me what I missed and let me try it again" — has no entry point in the app today.
Output: one new filter model, one new browse screen, the dashboard wired to it, and tests covering the filter partition and the end-to-end retry.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/screens/exam_prep_question_list_screen.dart
@enchiridion/lib/screens/question_screen.dart
@enchiridion/lib/models/question.dart
@enchiridion/lib/models/question_review.dart
@enchiridion/lib/services/storage_service.dart
@enchiridion/lib/services/study_stats_service.dart
@enchiridion/test/screens/question_screen_test.dart
</context>

<interfaces>
Facts the executor must build against — all verified in the current tree, do not re-derive:

- `kStandaloneExamPrepScope` (`'exam_prep'`) is declared in `lib/models/resource_topic.dart`, not in a config file.
- `StorageService.getAnswers(scope)` returns `Map<String, UserAnswer>` keyed by question id — the latest answer per question, all-time. `UserAnswer` carries `questionId`, `selectedOption`, `isCorrect`, `answeredAt`.
- `StorageService.getQuestionReviews(scope)` returns `Map<String, QuestionReview>`; `QuestionReview.attempts` is what existing callers hash with the question id to seed option order (`Object.hash(question.id, review?.attempts ?? 0)`), so a retry does not re-present the correct answer in the same visual slot.
- `QuestionScreen` already supports retake: non-`readOnly` mode starts fresh even when `previousAnswer` is supplied, and `readOnly: true` renders the prior answer plus explanation with answering disabled.
- `StudyStatsService.recordAnswer` is a deliberate no-op when `isFirstAttempt` is false (commit `d0a90f6`). A retry therefore does NOT move the daily Answered/Correct/Points counters. This is existing intended behaviour — see the note in `<constraints>`.
- `Question.previewText()` produces the list-row preview used by the existing question list.
- Provider wiring in tests: `Provider<StorageService>.value(value: storage)` over a `MaterialApp`, with `SharedPreferences.setMockInitialValues({})` in `setUp` — see `test/screens/question_screen_test.dart`.

All Flutter commands run from the `enchiridion/` subdirectory, never the repo root (CLAUDE.md).
</interfaces>

<constraints>
Read before writing any code — these keep this item from colliding with its sibling batch items.

1. **Do not change how points or daily stats are counted.** Sibling item `260917-ndu` owns the points system. This plan only reads `StudyDayStats`; it must not edit `StudyStatsService`, `StudyDayStats`, or the `isFirstAttempt` guard. A retry legitimately leaves the daily counters unchanged.
2. **Do not touch the question-serving or selection path.** `NextQuestionSelector`, `ServeLog`, and the notification scheduling belong to siblings `260917-ndv` and `260917-ndw`. The retry path here reuses `QuestionScreen` directly.
3. **Do not expose unanswered bank content.** The new screen is built strictly from the keys of `getAnswers(...)`, so it can only ever list questions the user has already seen. Do not add a total-bank count, a "x of N" line, or any locked-question row — siblings `260917-ndq` and `260917-ndx` are removing exactly those affordances elsewhere.
4. **Do not introduce new ordinal-number UI.** The new screen identifies rows by preview text only. Sibling `260917-ndt` is stripping ordinals from the UI; this plan must not add a fresh one for it to clean up. Leave `QuestionScreen`'s existing app-bar title alone — that is `260917-ndt`'s to change, not this item's.
5. **Do not edit `exam_prep_question_list_screen.dart`.** It is the full-bank browser and sibling `260917-ndx` is removing its entry point. The new screen is a separate file.
</constraints>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: End-to-end "browse what I got wrong and retry it" — the Wrong tile only</name>
  <files>enchiridion/test/screens/answered_questions_screen_test.dart, enchiridion/lib/models/answered_question_filter.dart, enchiridion/lib/screens/answered_questions_screen.dart, enchiridion/lib/screens/exam_prep_home_screen.dart</files>
  <read_first>
    - `enchiridion/test/screens/question_screen_test.dart` — copy its provider + mock-prefs harness verbatim.
    - `enchiridion/lib/screens/exam_prep_question_list_screen.dart` lines 91-126 — the existing push-then-refresh-on-pop idiom (`.then((_) { ... re-read storage ... })`). Reuse it; do not invent a new one.
  </read_first>
  <behavior>
    Write these as failing widget tests first, in `test/screens/answered_questions_screen_test.dart`:
    - Given three stored answers (two wrong, one correct) seeded via `storage.recordAnswer(...)`, opening the screen with the wrong filter lists exactly the two missed questions and none of the correct one.
    - Every listed row is identifiable by its question preview text.
    - Tapping a missed row pushes `QuestionScreen` with answering enabled (a Submit control is present, i.e. not the read-only view).
    - Answering that retried question correctly and popping back leaves the wrong-filtered list showing only one row, and `storage.getAnswers('exam_prep')[id].isCorrect` is now true.
    - A filter whose set is empty renders an empty-state message rather than a blank list.
  </behavior>
  <action>
    Build the one vertical path from dashboard tile to retry and back. This is the whole stack for this feature; the remaining tasks widen it, they do not deepen it.

    Create `lib/models/answered_question_filter.dart` with an enum `AnsweredQuestionFilter` whose values are `answered`, `correct`, `wrong`, `points`. Give it a `label` getter (the dashboard tile caption), a `title` getter (the browse-screen app-bar heading — use "Missed questions" for `wrong` and "Questions that earned points" for `points`), and `bool matches(UserAnswer answer)` returning: `answered` -> always true; `correct` -> `answer.isCorrect`; `wrong` -> `!answer.isCorrect`; `points` -> `answer.isCorrect`. `points` shares the correct predicate on purpose: points are awarded only for correct answers, so the set of point-earning questions is the set of correct ones. Keep this file free of Flutter widget imports so it stays unit-testable — it may import the question model only.

    Create `lib/screens/answered_questions_screen.dart` with a stateful `AnsweredQuestionsScreen` taking `required List<Question> questions` and `required AnsweredQuestionFilter initialFilter`. Resolve rows by intersecting the passed-in bank with `context.read<StorageService>().getAnswers(kStandaloneExamPrepScope)` — a question with no stored answer is never a row — then keep the ones the active filter `matches`, sorted by `answeredAt` newest first. Hold the active filter in state so later tasks can add a switcher; initialise it from `initialFilter`.

    Each row shows a green check or red cross leading icon driven by `isCorrect`, and the row's preview text as its title. Identify rows by preview text alone; the screen must not render the question's ordinal field anywhere (see constraint 4). A row whose stored answer was wrong carries an explicit retry affordance and opens `QuestionScreen` with `readOnly: false`, `trackDailyStudyStats: true`, `previousAnswer` set to the stored answer, and `optionSeed` computed with the same `Object.hash(question.id, review?.attempts ?? 0)` expression the dashboard already uses. A row whose stored answer was correct opens `QuestionScreen` with `readOnly: true` so reviewing an explanation cannot silently lapse a correct answer off the spaced-repetition ladder. After the pushed route pops, re-read answers and reviews from storage and `setState`, so a retried question moves between filters immediately.

    Render an empty-state message when the filtered set has no rows.

    In `lib/screens/exam_prep_home_screen.dart`, add the missing Wrong metric to the Daily Performance card, computed as `questionsAnswered - correctAnswers` from `_todayStats`, and make that one tile tappable: it pushes `AnsweredQuestionsScreen` with the wrong filter and the already-loaded `_questions`, and calls the existing `_load()` when the route pops so the card reflects any change. Give `_MetricPill` an optional tap callback — wrap its container so the tap produces a visible ripple and exposes a button to the semantics tree rather than a bare gesture detector. Leave the other three tiles non-tappable in this task; Task 2 wires them.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/answered_questions_screen_test.dart</automated>
    <automated>cd enchiridion && flutter analyze lib/models/answered_question_filter.dart lib/screens/answered_questions_screen.dart lib/screens/exam_prep_home_screen.dart</automated>
  </verify>
  <done>The widget test passes from a red start, analyze reports no issues on the three files, and tapping Wrong on the dashboard reaches a list of missed questions that can be retried.</done>
</task>

<task type="auto">
  <name>Task 2: Wire the remaining three tiles and lay out four pills without overflow</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/screens/answered_questions_screen.dart</files>
  <action>
    Make Answered, Correct, and Points tappable the same way the Wrong tile already is, each pushing `AnsweredQuestionsScreen` with its matching `AnsweredQuestionFilter` value and refreshing via `_load()` on pop.

    Four pills will not fit one `Row` on a narrow phone. Replace the single row in the Daily Performance card with two rows of two `Expanded` pills — Answered and Correct on the first, Wrong and Points on the second — with the existing spacing between and above them. Do not use a horizontal scroll or let a pill shrink below readability.

    In `AnsweredQuestionsScreen`, add a three-option segmented control above the list (Answered / Correct / Wrong) so the user can switch status without going back to the dashboard. When the screen was opened on the points filter, show the correct option as the selected segment — the two describe the same set — while the app-bar heading still reflects the points framing. Selecting a segment sets the active filter to that segment's value.

    Add a summary line above the list reading the all-time counts of answered, correct, and wrong, and qualify it with the words "all time". This is load-bearing: the dashboard tiles are *today's* numbers while this list is the user's whole answer history, so the two will legitimately disagree and the screen must say which one it is showing. When the screen was opened on the points filter, add one further line stating how many points a first correct answer is worth, taking the value from the constant already applied in `StudyStatsService.recordAnswer` rather than restating a number that can drift.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/answered_questions_screen_test.dart</automated>
    <automated>cd enchiridion && flutter analyze lib/screens/exam_prep_home_screen.dart lib/screens/answered_questions_screen.dart</automated>
    <automated>cd enchiridion && test "$(grep -v '^\s*//' lib/screens/exam_prep_home_screen.dart | grep -c 'AnsweredQuestionFilter\.')" -ge 4</automated>
  </verify>
  <done>All four tiles navigate to the browse screen with their own filter, the card renders two rows of two pills with no overflow warning, and the list header states the all-time counts.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Unit-test the filter partition and gate the no-ordinal rule</name>
  <files>enchiridion/test/models/answered_question_filter_test.dart</files>
  <behavior>
    - `correct` and `wrong` partition a set of answers: every answer matches exactly one of the two, and their match counts sum to the total.
    - `answered` matches every answer, correct or wrong.
    - `points` matches exactly the same answers as `correct`.
    - Each enum value exposes a non-empty `label` and a non-empty `title`.
  </behavior>
  <action>
    Create `test/models/answered_question_filter_test.dart` as a plain `flutter test` file with no widget pumping — the filter model has no Flutter dependency, so this must run as fast unit assertions over a handful of hand-built `UserAnswer` instances covering both outcomes.

    Assert the partition property directly rather than checking individual cases one at a time: build a mixed list, then assert that for every answer exactly one of the correct/wrong predicates holds, and that the two match counts sum to the list length. That form keeps catching regressions if a fifth filter value is added later.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/models/answered_question_filter_test.dart</automated>
    <automated>cd enchiridion && test "$(grep -v '^\s*//' lib/screens/answered_questions_screen.dart | grep -c 'questionNumber')" -eq 0</automated>
    <automated>cd enchiridion && flutter test test/models/ test/screens/</automated>
  </verify>
  <done>The unit test passes, the new screen's non-comment source contains no ordinal-field reference, and the existing model and screen test suites still pass.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| free user -> paid question bank | The freemium gate decides which question content a user may read. A new browse surface is a new place that gate can leak through. |
| local storage -> screen | `SharedPreferences`-backed answers render directly into the list; no remote input crosses into this screen. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-nds-01 | Information disclosure | `AnsweredQuestionsScreen` row source | medium | mitigate | Rows are built only from the keys of `getAnswers(scope)`, so an unanswered — therefore possibly locked — question can never become a row. No unlock/lock branch is added, so there is no gate to get wrong. |
| T-nds-02 | Information disclosure | list header counts | low | mitigate | The header reports counts of the user's own answers only; constraint 3 forbids a total-bank figure, so the header cannot reveal bank size. |
| T-nds-03 | Tampering | spaced-repetition ladder via retry | medium | mitigate | Correct rows open `QuestionScreen` with `readOnly: true`, so reviewing an explanation cannot overwrite a correct answer and lapse the ladder. Only wrong rows are answerable. |
| T-nds-04 | Tampering | daily points counters | low | accept | A retry routes through the existing `isFirstAttempt` guard, which already refuses to re-count. This plan adds no new write path to the counters. |
| T-nds-SC | Tampering | dependency installs | low | accept | No package-manager install is introduced; the change uses only packages already in `pubspec.yaml`. |
</threat_model>

<verification>
Run from `enchiridion/`:

```
flutter analyze lib/models/answered_question_filter.dart lib/screens/answered_questions_screen.dart lib/screens/exam_prep_home_screen.dart
flutter test test/models/ test/screens/
```

Manual pass on a running app: open Exam Prep, answer a question wrong, tap Wrong, confirm the missed question is listed, retry it, answer correctly, and confirm the row leaves the Wrong filter and appears under Correct. Then tap each of Answered, Correct, and Points and confirm each lands on its own filtered view.
</verification>

<success_criteria>
- All four Daily Performance tiles are tappable and open the browse screen on their own filter.
- A Wrong tile exists on the dashboard where previously only Answered, Correct, and Points were rendered.
- A question the user answered incorrectly can be retried from the browse list, and answering it correctly moves it out of the Wrong filter.
- The browse screen lists only questions the user has already answered, with no bank total and no ordinal numbering.
- `flutter analyze` is clean on the touched files and the model and screen test suites pass.
</success_criteria>

<output>
Create the SUMMARY in this item's quick directory when done.
</output>
