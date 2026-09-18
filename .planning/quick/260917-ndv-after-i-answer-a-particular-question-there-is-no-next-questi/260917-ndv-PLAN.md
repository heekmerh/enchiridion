---
phase: quick-260917-ndv
plan: 01
type: execute
wave: 1
quick_id: 260917-ndv
depends_on:
  - 260917-ndr
  - 260917-ndu
files_modified:
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/test/screens/question_screen_test.dart
autonomous: true
requirements:
  - 260917-ndv

estimate:
  tokens: 48000
  raw_tokens: 48000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "After submitting an answer in the practice flow, a 'Next question' control is visible, and tapping it renders a different, unanswered question without leaving the screen."
    - "If the user does nothing after submitting, the screen advances to the next question on its own after a brief answer-feedback pause."
    - "The user can cancel the pending auto-advance and stay on the answered question to read the explanation and OSCE tip."
    - "When the selector has no further question to serve, the screen says so instead of advancing into a blank or duplicate state."
    - "Opening a question from a question list or a notification tap behaves exactly as before: no next-question control, no auto-advance, 'Back to question list' still works."
    - "Advancing question-to-question does not grow the navigation stack — one Back press returns to the launching screen, not through every question answered in the run."
  artifacts:
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/lib/screens/exam_prep_home_screen.dart
    - enchiridion/test/screens/question_screen_test.dart
  key_links:
    - "QuestionScreen.onRequestNext <- ExamPrepHomeScreen._serveNextQuestion <- NextQuestionSelector.next — the single serve-decision point; advancing must not add a second independent call to next()."
    - "_serveNextQuestion awaits the in-flight answer write before reading the pending question; without that ordering the user is handed back the question they just answered."
    - "Auto-advance Timer lifecycle — cancelled in dispose(), on manual advance, and on user cancel; a live timer after pop calls setState on an unmounted State."
---

<objective>
After a user answers a question in the practice flow there is no way forward: the
post-submit footer offers only "Back to question list", so the run dead-ends on
every single question. This plan gives `QuestionScreen` an explicit **Next
question** control *and* an automatic advance after a short answer-feedback
pause, both driven by the existing `NextQuestionSelector`.

Purpose: turn "practice" from a one-question-per-tap dead end into a continuous
session the user can stay inside.

Output: `QuestionScreen` can replace its question in place when the caller
supplies a next-question loader; `ExamPrepHomeScreen` supplies one; widget tests
cover manual advance, auto-advance, cancel, exhausted-queue, and the unchanged
legacy (loader-absent) path.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@enchiridion/lib/screens/question_screen.dart
@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/services/next_question_selector.dart
@enchiridion/test/screens/question_screen_test.dart
</context>

<interface_context>
Existing signatures the executor must build against — do not change them except
where a task says so:

```
// lib/screens/question_screen.dart
QuestionScreen({ required Question question, required String bookId,
                 required void Function(UserAnswer) onAnswered,
                 UserAnswer? previousAnswer, bool trackDailyStudyStats = false,
                 bool readOnly = false, int? optionSeed })

// lib/services/next_question_selector.dart
Future<Question?> NextQuestionSelector.next({ required List<Question> bank,
                 required bool hasAccess, String scope, DateTime? now })
// NOTE: next() writes the serve log. Calling it is a side effect — call it once
// per question actually shown.

// lib/screens/exam_prep_home_screen.dart (private state)
Future<void> _handleStudyCardAnswer(UserAnswer answer)   // records + re-picks _randomQuestion
int _optionSeedFor(StorageService storage, Question? question)
Question? _randomQuestion;  int _randomQuestionOptionSeed;
```

The four `QuestionScreen` call sites:
- `lib/screens/exam_prep_home_screen.dart:232` — the practice entry point (THIS plan wires it)
- `lib/screens/exam_prep_question_list_screen.dart:104` — list/review context (leave as-is)
- `lib/screens/question_list_screen.dart:97` — per-book list context (leave as-is)
- `lib/widgets/exam_prep/in_app_study_prompt_host.dart:95` — notification tap (leave as-is)
</interface_context>

<scope_boundaries>
Out of scope for this item — these belong to sibling batch items and MUST NOT be
touched here:

- Do NOT modify `lib/services/next_question_selector.dart` (owned by 260917-ndw
  randomization and 260917-ndy 24h requeue). Consume its public `next()` API only.
- Do NOT add any question number, question index, "N of M", progress bar, or bank
  total to the advancing UI. 260917-ndq and 260917-ndt require that the user
  cannot infer how many questions exist. The advance UI is count-free.
- Do NOT touch the Access card / "Browse Full Bank" button (260917-ndx) or the
  Daily Performance metric pills (260917-nds).
- Do NOT change how points or stats are computed (260917-ndu). This plan only
  ensures the existing stats refresh still fires once per answer while advancing.
- Do NOT add a per-session question cap or freemium gating here (260917-ndz).
</scope_boundaries>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: End-to-end in-place advance — answer, tap Next, get a new question</name>
  <files>enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/test/screens/question_screen_test.dart</files>
  <read_first>enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/exam_prep_home_screen.dart</read_first>
  <behavior>
    - Given a QuestionScreen built WITHOUT a next-question loader: post-submit footer is unchanged — "Back to question list" is present and no next-question control exists.
    - Given a QuestionScreen built WITH a loader: before submitting, no next-question control is shown.
    - After submitting, a "Next question" control is shown alongside the explanation.
    - Tapping "Next question" renders the second question's stem, clears the selection, re-enables the options, and hides the result banner and explanation.
    - Tapping "Next question" pushes no route: the Navigator stack depth is the same before and after the advance.
    - The loader is invoked exactly once per advance.
  </behavior>
  <action>
    Add an optional next-question loader to `QuestionScreen` and make the screen able
    to swap its question in place rather than pushing a new route.

    In `lib/screens/question_screen.dart`:
    - Declare a top-level typedef for the loader returning a nullable record of the
      next question plus its option seed, e.g. a `Future` of an optional
      `({Question question, int optionSeed})`. Add it as an optional named
      constructor field on `QuestionScreen` (name it `onRequestNext`). Absent loader
      must preserve today's behaviour exactly — this is what keeps the three list /
      notification call sites unchanged.
    - Move the currently-immutable per-question state into mutable State fields: the
      question being displayed, its option seed, and the shuffled option order
      (today `_optionOrder` is `late final` and is seeded once in `initState`).
      Extract the seeding into a private method that both `initState` and the
      advance path call, so ordering rules stay in one place. Every read of
      `widget.question` inside `build`, `_submit`, `_isCorrect` and `_flagQuestion`
      must move to the State field.
    - Add a private advance method: it calls the loader, and on a non-null result
      does a single `setState` that installs the new question and seed, clears the
      selected option, clears the submitted flag, and reseeds the option order.
      Guard it against re-entrancy (an in-flight advance must ignore a second
      request) and against `mounted == false` after the await.
    - Give the body `ListView` a `ScrollController` and jump it back to offset 0 on
      advance, so the new stem is not rendered scrolled to the previous question's
      explanation. Dispose the controller.
    - In the `if (_submitted)` footer: when a loader is present and the screen is not
      `readOnly`, render a primary "Next question" `FilledButton` that triggers the
      advance, keeping "Back to question list" as the secondary action beneath it.
      When no loader is present, render exactly today's footer. Do not render any
      question number, index, or bank total in this footer (see scope_boundaries).

    In `lib/screens/exam_prep_home_screen.dart`:
    - Store the future returned by the existing `_handleStudyCardAnswer` work in a
      State field (e.g. `_pendingAnswerWrite`) when it is kicked off from the
      `onAnswered` callback, because `onAnswered` is a `void` callback and the record
      + re-pick runs unawaited today.
    - Add `_serveNextQuestion`: await `_pendingAnswerWrite` (null-safe), then read the
      already-re-picked `_randomQuestion` / `_randomQuestionOptionSeed` and return
      them as the record; return null when `_randomQuestion` is null. Do NOT call
      `NextQuestionSelector.next()` again here — `_handleStudyCardAnswer` already made
      the one serve-logged pick for this advance, and a second call would burn an
      extra serve and skip a question.
    - Pass `onRequestNext: _serveNextQuestion` on the `QuestionScreen` built by the
      "Practice one now" button only.

    In `test/screens/question_screen_test.dart`: add the behaviors above. Reuse the
    existing `_buildSubject` helper, extending it with an optional loader and a
    second `Question` const so a test can assert the stem actually changed.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/question_screen_test.dart</automated>
  </verify>
  <done>A user who answers from "Practice one now" sees a "Next question" button, taps it, and is on a fresh unanswered question on the same route; a user who opened the question from a list sees the unchanged footer.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Auto-advance after a feedback pause, with cancel and exhausted-queue states</name>
  <files>enchiridion/lib/screens/question_screen.dart, enchiridion/test/screens/question_screen_test.dart</files>
  <read_first>enchiridion/lib/screens/question_screen.dart</read_first>
  <behavior>
    - After a submit on a loader-backed screen, a visible countdown appears and the screen advances on its own once the pause elapses, with no user tap.
    - The countdown starts only after the submit's storage write, follow-up scheduling, and stats recording have completed — never while that work is still in flight.
    - A visible cancel control ("Stay on this question") stops the pending advance; after cancelling, pumping well past the pause leaves the same question on screen and the "Next question" button still available.
    - Tapping "Next question" manually cancels the pending timer so the screen advances exactly once, not twice.
    - When the loader returns null, the screen shows an all-caught-up message, keeps the explanation and "Back to question list" visible, and does not advance.
    - Popping the screen while a countdown is pending produces no setState-after-dispose error.
  </behavior>
  <action>
    Layer automatic advance on top of Task 1's manual advance, in
    `lib/screens/question_screen.dart` only.

    - Define a private const feedback pause as a named constant on the State class so
      it is tunable in one place; use 6 seconds. That is long enough to read a short
      explanation and reach the cancel control, short enough that an idle user is
      served the next question rather than stranded.
    - At the very end of `_submit`, after all existing awaits resolve and only when a
      loader is present and the screen is not `readOnly`, start a periodic 1-second
      `Timer` that decrements a remaining-seconds State field; when it reaches zero,
      cancel the timer and call Task 1's advance method.
    - Render the remaining seconds in the footer next to the "Next question" button
      (wording such as "Next question in Ns"), and render a `TextButton` labelled
      "Stay on this question" that cancels the timer and clears the countdown state.
      Once cancelled, the countdown does not restart for the current question.
    - Cancel the timer and null the field in: the advance method (before awaiting the
      loader), the cancel button handler, and `dispose()`. After the loader await in
      the advance method, return early if `!mounted`.
    - When the loader resolves null, set an exhausted flag in State. While that flag
      is set, hide the "Next question" button and the countdown and render a short
      message telling the user there is nothing more queued right now, leaving the
      explanation, OSCE tip, and "Back to question list" in place. Do not word this
      message in terms of a remaining count or a bank total.
    - Add the behaviors above to `test/screens/question_screen_test.dart`, driving
      time with `tester.pump(const Duration(...))` rather than `pumpAndSettle` (a
      periodic timer never settles). For the dispose case, pump the screen behind a
      route, submit, pop, then pump past the pause and assert no exception.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/question_screen_test.dart</automated>
  </verify>
  <done>An idle user is carried to the next question ~6s after answering; a reading user can press "Stay on this question" and is not moved; a user who has exhausted the queue is told so rather than left on a stuck screen.</done>
</task>

<task type="auto">
  <name>Task 3: Regression sweep across the four QuestionScreen call sites</name>
  <files>enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/exam_prep_home_screen.dart</files>
  <action>
    Confirm the new optional parameter did not disturb the three call sites that must
    keep today's behaviour, and that nothing in the repo still assumes the old
    immutable-question State.

    - Run `flutter analyze` over the two modified files and resolve every error and
      warning this plan introduces. Measured baseline before this plan: exactly ONE
      finding, `unused_element_parameter` on the unused `key` of the dead `_StudyCard`
      widget at `exam_prep_home_screen.dart:342`. That widget is declared but never
      instantiated; it is pre-existing dead code and is NOT this item's to delete
      (`exam_prep_home_screen.dart` is also being edited by 260917-ndu and 260917-nds,
      and a 150-line deletion there would collide). Leave it and note it in the
      summary. Any finding beyond that single baseline one is a regression to fix.
    - Run the full `flutter test` suite. Measured baseline before this plan: 61 tests,
      all passing, exit 0. The count must go UP (new tests from Tasks 1-2) and
      everything must still pass.
    - Grep for `QuestionScreen(` across `lib/` and confirm exactly one call site
      passes the loader (the "Practice one now" button in `exam_prep_home_screen.dart`)
      and the other three — `exam_prep_question_list_screen.dart`,
      `question_list_screen.dart`, `in_app_study_prompt_host.dart` — do not. Use a
      comment-stripped count so doc comments mentioning the widget are not counted:
      `grep -rn "QuestionScreen(" lib/ --include=*.dart | grep -v "^[^:]*:[0-9]*: *//"`.
    - Confirm no question number, index, or bank-size string was introduced into the
      advance footer by reviewing the diff of the post-submit block.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/screens/question_screen.dart lib/screens/exam_prep_home_screen.dart --no-fatal-infos --no-fatal-warnings && flutter test</automated>
  </verify>
  <done>`flutter analyze` on the two modified files reports only the known baseline `_StudyCard` warning, the full test suite passes with more tests than the 61-test baseline, and only the practice entry point supplies a next-question loader.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Question bank content -> rendered UI | Question stems and explanations come from Supabase / bundled assets and are rendered as Flutter `Text`; already non-executing, unchanged by this plan. |
| Local device storage (`StorageService` / SharedPreferences) -> serve decisions | The serve log and review ladder drive which question is served next; a caller that double-calls the selector corrupts the schedule. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndv-01 | Tampering | `ExamPrepHomeScreen._serveNextQuestion` -> `NextQuestionSelector.next` | medium | mitigate | Advance reuses the single pick already made by `_handleStudyCardAnswer`; Task 1 forbids a second `next()` call, so the serve log and spaced-repetition ladder record one serve per question actually shown. |
| T-ndv-02 | Information disclosure | Advance footer in `question_screen.dart` | medium | mitigate | The footer is count-free by construction (scope_boundaries + Task 3 diff review): no question number, index, "N of M", or bank total, so auto-advance cannot leak bank size that 260917-ndq/ndt exist to hide. |
| T-ndv-03 | Denial of service | Auto-advance `Timer` in `_QuestionScreenState` | low | mitigate | Timer cancelled in `dispose()`, on manual advance, and on user cancel; advance guards on `mounted` after the loader await and is re-entrancy guarded, so no orphaned periodic timer or setState-after-dispose crash loop. |
| T-ndv-04 | Elevation of privilege | Freemium gating on the advanced-to question | low | accept | Advancing consumes the same `NextQuestionSelector.next(hasAccess:)` result the home card already used; the loader introduces no new bank access path, and per-session caps are 260917-ndz's scope. |
| T-ndv-SC | Tampering | npm/pip/cargo installs | low | accept | No new dependencies are introduced — this plan uses only `dart:async` and existing app code, so no package legitimacy gate applies. |
</threat_model>

<verification>
- `cd enchiridion && flutter test test/screens/question_screen_test.dart` passes, covering: loader-absent footer unchanged, manual advance, auto-advance, cancel, exhausted queue, and dispose-with-pending-timer.
- `cd enchiridion && flutter test` — full suite green, no regressions (baseline 61 passing).
- `cd enchiridion && flutter analyze lib/screens/question_screen.dart lib/screens/exam_prep_home_screen.dart --no-fatal-infos --no-fatal-warnings` — exits 0 with only the known baseline `_StudyCard` `unused_element_parameter` warning.
- Diff review: the post-submit footer contains no question number, index, or bank total.
- Diff review: `lib/services/next_question_selector.dart` is untouched.
</verification>

<success_criteria>
- Answering from "Practice one now" yields both an explicit "Next question" control and an unattended advance after the feedback pause.
- The advance replaces the question in place; one Back press returns to Exam Prep regardless of how many questions were answered in the run.
- The user can stop the auto-advance to read the explanation.
- An empty queue produces a clear message, not a stuck or blank screen.
- List-opened and notification-opened questions behave exactly as they did before this change.
</success_criteria>

<output>
Create `.planning/quick/260917-ndv-after-i-answer-a-particular-question-there-is-no-next-questi/260917-ndv-SUMMARY.md` when done.
</output>
