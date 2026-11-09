---
phase: quick-260919-kis
plan: 01
type: execute
wave: 1
quick_id: 260919-kis
depends_on: []
files_modified:
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/test/screens/question_screen_test.dart
autonomous: true
requirements:
  - 260919-kis

must_haves:
  truths:
    - "After submitting an answer in the practice flow, the answered question, its correct/incorrect banner, its explanation and its OSCE tip stay on screen indefinitely — an idle user is never carried forward."
    - "The only way forward from an answered question is an explicit user action: tapping 'Next question' (loader-backed entry points) or 'Back to question list'."
    - "No countdown text and no 'Stay on this question' cancel control are ever rendered, because there is nothing left to count down or cancel."
    - "Tapping 'Next question' still swaps the question in place — new stem, cleared selection, re-enabled options, hidden explanation — and still pushes no new route."
    - "When the loader has nothing left to serve, tapping 'Next question' shows the caught-up message while the just-answered question's explanation stays visible."
    - "Answer recording is untouched: storage write, daily stats, notification follow-up and the remote review push all still fire exactly once per submit."
  artifacts:
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/test/screens/question_screen_test.dart
  key_links:
    - "QuestionScreen._submit -> (previously) countdown start — severing this link is the whole change; the storage/stats/notification calls above it must survive untouched."
    - "QuestionScreen._advance <- the 'Next question' FilledButton — after this change the button is the sole caller of _advance, so any regression in it dead-ends the run again."
    - "QuestionScreen.dispose -> _scrollController.dispose() — the timer cancel disappears from dispose, but the controller disposal must stay."
---

<objective>
`QuestionScreen` currently starts a six-second countdown the moment an answer is
recorded and then advances to the next question on its own, so the explanation
and OSCE tip the user is reading are yanked away mid-sentence. This plan removes
the timed advance entirely: an answered question stays on screen until the user
explicitly taps **Next question** (or leaves).

Purpose: give the user unlimited time to read the feedback for the question they
just answered — the whole learning value of the practice flow.

Output: `QuestionScreen` with no timer, no countdown label and no cancel control;
its widget tests rewritten so the absence of a timed advance is a guarded
regression rather than an accident.

Scope guard: this item changes the *advance trigger* only. Scoring, answer
recording and answered-count tracking are explicitly out of scope — sibling item
`260919-kiu` owns the answered-counter bug.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

The Flutter app lives in the nested `enchiridion/` directory — every path below
is repo-relative, and every command below `cd enchiridion` first.

@enchiridion/lib/screens/question_screen.dart
@enchiridion/test/screens/question_screen_test.dart

Current state (verified at planning time, 2026-09-19):

- The timed advance lives entirely in `enchiridion/lib/screens/question_screen.dart`.
  A repo-wide search for `Timer` in `enchiridion/lib` returns hits in only three
  files: this screen, `confirm_email_screen.dart` (resend cooldown) and
  `splash_screen.dart` (splash delay). Neither of the latter two is part of the
  exam flow; do not touch them.
- `QuickCheckCard` (`enchiridion/lib/widgets/exam_prep/quick_check_card.dart`)
  already requires an explicit "Close" tap and runs no timer — nothing to change
  there.
- `onRequestNext` has exactly one supplier: `ExamPrepHomeScreen._serveNextQuestion`
  ("Practice one now"). Entry points that pass no loader (question list,
  answered-questions list, notification tap) already show only "Back to question
  list" and are unaffected.
- Baseline is green: `flutter analyze` reports no issues on the two target files,
  and `flutter test test/screens/question_screen_test.dart` passes 12/12.

<!-- planner-discipline-allow: _autoAdvanceTimer, _secondsRemaining, _feedbackPause, _startAutoAdvanceCountdown, _cancelAutoAdvance, Timer.periodic, Timer -->
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: An answered question stays put until the user taps Next</name>
  <files>enchiridion/test/screens/question_screen_test.dart, enchiridion/lib/screens/question_screen.dart</files>
  <read_first>
    Read `enchiridion/lib/screens/question_screen.dart` in full and the
    `auto-advance` group of `enchiridion/test/screens/question_screen_test.dart`
    before editing either.
  </read_first>
  <behavior>
    Rewrite the test group currently named `auto-advance` as `no timed advance`,
    holding these cases (write them first; they must fail against today's screen):

    - An idle user is never carried forward: answer and submit with a loader that
      counts its calls, then `await tester.pumpAndSettle()` followed by
      `await tester.pump(const Duration(seconds: 30))`. Expect the loader call
      count to be 0, `find.text('What is 2 + 2?')` to still find one widget,
      `find.text('Explanation')` to still find one widget, and
      `find.text('Next question')` to still find one widget.
    - No countdown affordances are rendered after submit: expect
      `find.textContaining('Next question in')` and
      `find.text('Stay on this question')` to each find nothing.
    - Tapping "Next question" advances exactly once and stays advanced: tap it,
      settle, then `await tester.pump(const Duration(seconds: 30))` and expect
      the loader call count to still be 1 and `find.text('What is 3 + 3?')` to
      find one widget.
    - An exhausted queue is only discovered on an explicit tap: with a loader
      returning null, submit, expect `find.textContaining('caught up')` to find
      nothing yet, then tap "Next question" and expect `find.textContaining('caught up')`
      to find one widget, `find.text('Next question')` to find nothing, and
      `find.text('Explanation')` to still find one widget (the just-answered
      question's feedback survives).
    - Leaving an answered screen raises no exception: reuse `_buildPushableSubject`,
      answer, submit, pop, then `await tester.pump(const Duration(seconds: 30))`
      and expect `tester.takeException()` to be null.

    The pre-existing `next-question advance` group and the three tests above it
    keep passing unchanged.
  </behavior>
  <action>
    Work test-first.

    In `enchiridion/test/screens/question_screen_test.dart`: rename the
    `auto-advance` group to `no timed advance` and replace its five tests with the
    cases in `behavior`. Delete the `Stay on this question cancels the pending
    advance` test outright — the control it drives ceases to exist. Because no
    periodic timer runs any more, the workarounds those tests needed are obsolete:
    drop the `tester.drag(find.byType(ListView), ...)` scroll hack and the
    `skipOffstage: false` finder arguments it forced, and use `pumpAndSettle()`
    freely where the old comments warned it would never settle. Keep
    `_buildSubject`, `_buildPushableSubject`, `_PushCounter`, `_question` and
    `_question2` as they are. Run the file and confirm the new cases fail.

    Then in `enchiridion/lib/screens/question_screen.dart` remove the timed
    advance and nothing else:

    - Delete the `_feedbackPause` constant, the `_autoAdvanceTimer` field, the
      `_secondsRemaining` field, and the `_startAutoAdvanceCountdown()` and
      `_cancelAutoAdvance()` methods, together with the comment block above
      `_feedbackPause` that explains the pause.
    - In `_submit()`, delete the trailing block that starts the countdown —
      including the `if (!mounted) return;` immediately above it, which guarded
      only that call. Everything before it (the `UserAnswer`, `storage.recordAnswer`,
      the `StudyStatsProvider.recordAnswer`, `widget.onAnswered(answer)`, the
      `unawaited` follow-up scheduling and review push) is untouched — those are
      sibling item `260919-kiu`'s territory and must not be edited here.
    - In `_advance()`, delete the `_cancelAutoAdvance()` call; keep the
      `_advancing` re-entrancy guard, the null-loader early return, the `mounted`
      check after the await, the `_exhausted` handling and the scroll-to-top.
    - In `dispose()`, delete the timer cancel line and keep
      `_scrollController.dispose()` and `super.dispose()`.
    - In `build()`, delete the conditional countdown `Text` (and the `SizedBox`
      that spaces it) and the `TextButton` cancel control below the `FilledButton`.
      The post-submit footer keeps, in order: the caught-up container when
      exhausted, otherwise the unconditional "Next question" `FilledButton` still
      disabled while `_advancing`, then the "Back to question list"
      `OutlinedButton`.
    - Keep `import 'dart:async';` — `unawaited` in `_submit()` still needs it.

    Re-run the file; all cases must pass.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/question_screen_test.dart</automated>
  </verify>
  <done>
    `flutter test test/screens/question_screen_test.dart` passes with a
    `no timed advance` group; pumping 30 simulated seconds after a submit leaves
    the same question, its explanation and its "Next question" button on screen
    with the loader never called; tapping "Next question" is the only thing that
    advances.
  </done>
</task>

<task type="auto">
  <name>Task 2: Retire the auto-advance promise from the screen's documented contract</name>
  <files>enchiridion/lib/screens/question_screen.dart</files>
  <action>
    The screen's dartdoc still advertises the behaviour just removed, which would
    mislead the next reader and re-invite the regression. Rewrite these comments
    so they describe a purely user-driven advance:

    - The doc on the `NextQuestionLoader` typedef, whose closing sentence
      currently describes the loader-absent path in terms of an unattended
      advance. State instead that an absent loader means no next-question control
      at all, and say plainly that advancing is always user-initiated.
    - The doc on the `QuestionScreen.onRequestNext` field, which currently
      promises an unattended advance "layered on top in a later change". Replace
      that parenthetical: a present loader adds an explicit "Next question"
      control that swaps the question in place; the screen never advances by
      itself, so the user keeps the explanation on screen as long as they want.
    - The comment on the `_advancing` field, which currently qualifies an advance
      as "manual or, in a later change, automatic". Drop the qualifier — there is
      only one kind of advance now.
    - Leave the `readOnly` and `optionSeed` docs alone. In particular, do not
      reword the "ambient Quick Check sheet" reference in the `readOnly` doc —
      sibling item `260919-kit` owns Quick Check wording and edits here would
      collide with it.

    Then prove the removal is complete and nothing else in the screens suite
    depended on the timed advance.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/screens/question_screen.dart test/screens/question_screen_test.dart && test "$(grep -vE '^[[:space:]]*(///|//|\*|/\*)' lib/screens/question_screen.dart | grep -cE '_autoAdvanceTimer|_secondsRemaining|_feedbackPause|Timer')" = 0 && flutter test test/screens/</automated>
  </verify>
  <done>
    The analyzer reports no issues on the screen and its test (no orphaned
    private fields or methods left behind); no executable line of
    `question_screen.dart` references a timer or a countdown remainder any more;
    the whole `test/screens/` suite passes, confirming no other screen test
    relied on the timed advance.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user -> local device storage | The submitted answer is written to `SharedPreferences` via `StorageService.recordAnswer`. This plan does not modify that path. |
| device -> Supabase | `QuestionReviewSyncService.push` mirrors the review remotely, fire-and-forget. This plan does not modify that path. |

No new dependency is added: the change is a net deletion of widget-local timer
code plus test edits, so no package-legitimacy gate applies.

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-260919-kis-01 | Tampering | `QuestionScreen._submit` answer-recording block | medium | mitigate | Task 1's action forbids editing the storage/stats/notification/push sequence; `flutter test test/screens/` (Task 2) re-runs the existing "records the review" and exam-prep stats tests that assert one write per submit. |
| T-260919-kis-02 | Denial of Service | `QuestionScreen` widget lifecycle | low | mitigate | Removing the periodic timer removes the only post-dispose callback source on this screen; the rewritten pop-while-answered test asserts `tester.takeException()` is null after 30 simulated seconds. |
| T-260919-kis-03 | Information Disclosure | post-submit footer copy | low | accept | The footer renders only the question's own explanation and OSCE tip, already shown before this change; no ordinal or bank-size leak is introduced (the existing "never render the question ordinal" test still guards this). |
</threat_model>

<verification>
- `cd enchiridion && flutter test test/screens/question_screen_test.dart` — passes, with a `no timed advance` group replacing `auto-advance`.
- `cd enchiridion && flutter analyze lib/screens/question_screen.dart test/screens/question_screen_test.dart` — no issues (baseline was also clean, so any new issue is this change's).
- `cd enchiridion && flutter test test/screens/` — the full screens suite still passes.
- Manual smoke (optional, not gating): Exam Prep -> "Practice one now" -> answer -> the explanation stays on screen indefinitely; only tapping "Next question" moves on.
</verification>

<success_criteria>
- No timer, countdown label or cancel control remains in `question_screen.dart`.
- An answered question and its explanation stay on screen until the user acts.
- "Next question" still advances in place, pushes no route, and reports the
  caught-up state when the loader is exhausted.
- Answer recording, stats, notification scheduling and the remote push are
  byte-for-byte unchanged.
- Loader-absent entry points (question list, answered list, notification tap)
  behave exactly as before.
</success_criteria>

<output>
Create `.planning/quick/260919-kis-exam-prep-after-a-user-answers-a-question-remove-the-automat/260919-kis-SUMMARY.md` when done
</output>
