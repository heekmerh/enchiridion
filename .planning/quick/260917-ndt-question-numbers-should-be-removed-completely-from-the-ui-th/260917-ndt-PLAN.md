---
phase: quick-260917-ndt
quick_id: 260917-ndt
plan: 01
type: execute
wave: 2
depends_on: [260917-ndq, 260917-ndx, 260917-nds]
files_modified:
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/lib/screens/question_list_screen.dart
  - enchiridion/lib/screens/exam_prep_question_list_screen.dart
  - enchiridion/test/screens/question_screen_test.dart
autonomous: true
requirements: [QB-260917-NDT]

estimate:
  tokens: 30000
  raw_tokens: 30000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - A user practising a question sees no ordinal ("Question N" / "QN.") anywhere on screen.
    - No app surface states or implies how many questions the bank holds.
    - A user still sees their own progress (answered / correct counts) with no denominator.
    - Locked questions still read as locked without exposing an ordinal.
  artifacts:
    - enchiridion/lib/screens/question_screen.dart (neutral app bar title)
    - enchiridion/test/screens/question_screen_test.dart (regression test asserting ordinal absence)
  key_links:
    - Question.questionNumber stays intact on the model and in access gating (next_question_selector, _isLocked) — only its rendering is removed.
    - Every QuestionScreen entry point (list tap, Quick Check card, notification tap) shares one app bar, so the title fix covers all of them.
---

<objective>
Remove every question ordinal and bank-size figure from the Flutter UI so a user
cannot tell what number a question is, nor how many questions exist in total.

Purpose: the question bank size is commercially sensitive (siblings 260917-ndq and
260917-ndx remove bank browsing for the same reason). Ordinals leak it indirectly —
seeing "Q412." tells the user the bank has at least 412 questions.
Output: ordinal-free question surfaces, a regression test, and two grep gates that
keep new leaks out.

Scope boundary: this is a rendering change only. `Question.questionNumber` remains on
the model, in `exam_prep_repository.dart`, in `next_question_selector.dart`, and in the
`_isLocked` free-tier comparisons — the free/paid gate depends on it. Deleting the field
would break access control.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
</execution_context>

<context>
@enchiridion/lib/screens/question_screen.dart
@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/screens/question_list_screen.dart
@enchiridion/lib/screens/exam_prep_question_list_screen.dart
@enchiridion/test/screens/question_screen_test.dart

The Flutter app lives in `enchiridion/` under the repo root (see CLAUDE.md). All
`flutter` commands run from that directory; all paths above are repo-relative.

Baseline leak inventory measured on the pre-sibling tree (8 sites):
- ordinal rendered: question_screen.dart:136, exam_prep_home_screen.dart:390,
  question_list_screen.dart:189, exam_prep_question_list_screen.dart:225 and :226
- bank size rendered: exam_prep_home_screen.dart:186,
  question_list_screen.dart:169, exam_prep_question_list_screen.dart:158
- numbered free-tier range: exam_prep_home_screen.dart:187

Line numbers are pre-sibling. 260917-ndq and 260917-ndx may have already rewritten or
deleted the two list screens, and 260917-ndx/260917-nds may have moved code inside
exam_prep_home_screen.dart. Re-locate every site with the Task 3 gate commands rather
than trusting these numbers.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Neutral app bar on the shared question screen, with a regression test</name>
  <files>enchiridion/lib/screens/question_screen.dart, enchiridion/test/screens/question_screen_test.dart</files>
  <read_first>enchiridion/test/screens/question_screen_test.dart (reuse its existing `_question` fixture and `_buildSubject` helper — the fixture is already numbered 1)</read_first>
  <behavior>
    - Pumping QuestionScreen with a numbered fixture renders no text containing that ordinal.
    - The app bar still renders a title, so the screen keeps a heading and a working back affordance.
    - The existing two tests in the file (readOnly reuse, answer recording) still pass unchanged.
  </behavior>
  <action>
    Add a widget test to enchiridion/test/screens/question_screen_test.dart that pumps
    `_buildSubject(storageService, readOnly: false)` and asserts, via
    `find.textContaining('Question 1')` and `find.textContaining('Q1')`, that both are
    `findsNothing`, and that `find.text('Practice Question')` is `findsOneWidget`. Run it
    and watch it fail on the current title (RED).

    Then change the AppBar title at enchiridion/lib/screens/question_screen.dart:136 to the
    constant string `Practice Question`, dropping the interpolation of the model's ordinal
    field. Keep the rest of the AppBar (surface background, zero elevation, the flag action)
    untouched. Re-run the test (GREEN).

    This is the tracer: QuestionScreen is the single screen every practice path lands on
    (list tap, the Quick Check card's "Review fully", and notification taps via
    in_app_study_prompt_host), so proving the ordinal is gone here proves the primary
    end-to-end path before the sweep in Task 2 widens it.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/question_screen_test.dart</automated>
  </verify>
  <done>All three tests in test/screens/question_screen_test.dart pass, and `grep -nE '\$\{?[A-Za-z_.]*[Qq]uestion[Nn]umber' enchiridion/lib/screens/question_screen.dart` returns no lines.</done>
</task>

<task type="auto">
  <name>Task 2: Sweep the remaining ordinal and bank-size surfaces</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/screens/question_list_screen.dart, enchiridion/lib/screens/exam_prep_question_list_screen.dart</files>
  <read_first>The Task 3 gate command output — run both gates first to get the live, post-sibling list of offending lines.</read_first>
  <action>
    Fix every line the two gates report, plus the numbered free-tier subtitle described below.
    If a sibling plan already deleted one of the list screens, skip it — a missing file is a
    satisfied gate, not a failure.

    On the exam prep home screen (`_StudyCard`, around line 390): replace the coloured eyebrow
    label that interpolates the model's ordinal field with the constant string `Quick Check`,
    matching the branding already used by widgets/exam_prep/quick_check_card.dart. Keep the
    `labelLarge` + primary-colour + `w700` styling so the visual hierarchy is unchanged.

    On the exam prep home screen Access card (around lines 186-187): rewrite both branches of
    the subtitle so neither states a bank total nor a numbered range. Unlocked branch: state
    that full access is active. Locked branch: state the free allowance as a plain count of
    practice questions the user gets — `$kFreeQuestionCount practice questions` — and invite an
    unlock. The allowance is the user's own quota and is fine to show; what must go is the
    total and any phrasing that positions questions as an ordered, numbered series.

    On both list screens' progress banners (question_list_screen.dart around line 169 and
    exam_prep_question_list_screen.dart around line 158): drop the denominator. Show only the
    user's own totals — answered count and correct count — with no bank total in the string.

    On both list screens' tiles (question_list_screen.dart around line 189 and
    exam_prep_question_list_screen.dart around lines 225-226): drop the `Q`-prefix ordinal from
    the title and show only `previewText()`. For the locked branch in the exam prep list, use
    the constant string `Locked question` — do not substitute preview text there, because that
    branch deliberately withholds question text from users without access (see the comment at
    exam_prep_question_list_screen.dart:85). Leave the leading status icon, the trailing
    lock/chevron icon, the styles, and `onTap` exactly as they are.

    Do not touch `Question.questionNumber` in enchiridion/lib/models/question.dart,
    exam_prep_repository.dart, next_question_selector.dart, or the `_isLocked` comparisons —
    those are access control, not rendering.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/screens/exam_prep_home_screen.dart lib/screens/question_list_screen.dart lib/screens/exam_prep_question_list_screen.dart</automated>
  </verify>
  <done>`flutter analyze` on the three screens reports no errors, and both Task 3 gates return zero hits across enchiridion/lib.</done>
</task>

<task type="auto">
  <name>Task 3: Lock the gates and run the suite</name>
  <files>enchiridion/lib, enchiridion/test</files>
  <action>
    Run both leak gates over the whole app source and confirm zero hits, then run the full
    unit/widget suite and a repo-wide analyze to confirm no other screen or test depended on
    the removed strings. Fix any test that asserted on an ordinal or a bank total by updating
    the expectation to the new ordinal-free text — do not reintroduce the string to make a
    stale test pass.

    Gate A (ordinal rendered into a string) is the regex `\$\{?[A-Za-z_.]*[Qq]uestion[Nn]umber`
    over `--include=*.dart enchiridion/lib`. It matches only Dart string interpolation, so the
    bare field accesses in the model, repository, selector and gating comparisons are correctly
    left alone. Gate B (bank size rendered into a string) is the regex
    `\$\{?[A-Za-z_]*[Qq]uestions\.length`, which likewise ignores non-rendered uses such as
    `itemCount:`. Both measured 5 and 3 hits respectively on the pre-fix tree, so a zero result
    is a real change, not a vacuous pass.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion &amp;&amp; A=$(grep -rnE '\$\{?[A-Za-z_.]*[Qq]uestion[Nn]umber' --include=*.dart enchiridion/lib | wc -l) &amp;&amp; B=$(grep -rnE '\$\{?[A-Za-z_]*[Qq]uestions\.length' --include=*.dart enchiridion/lib | wc -l) &amp;&amp; C=$(grep -rn 'Questions 1-' --include=*.dart enchiridion/lib | wc -l) &amp;&amp; echo "A=$A B=$B C=$C" &amp;&amp; [ "$A" -eq 0 ] &amp;&amp; [ "$B" -eq 0 ] &amp;&amp; [ "$C" -eq 0 ]</automated>
    <automated>cd enchiridion &amp;&amp; flutter test</automated>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib</automated>
  </verify>
  <done>Gate A, Gate B and the numbered-range grep all return 0; `flutter test` passes with no skipped-over failures; `flutter analyze lib` reports no errors.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app UI → end user (incl. unpaid/freemium) | Rendered strings are the only thing an unpaid user can read; anything interpolated into them is disclosed. |
| Supabase question rows → client | The client loads question rows including `question_number`; the client decides what to render. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndt-01 | Information Disclosure | question_screen.dart, exam_prep_home_screen.dart, both list screens | medium | mitigate | Remove ordinal and bank-total interpolations from rendered strings (Tasks 1-2); enforce with Gate A and Gate B (Task 3). |
| T-ndt-02 | Information Disclosure | future UI code added after this change | medium | mitigate | Gate A/Gate B greps in Task 3 verify, plus the QuestionScreen regression test, catch reintroduction. |
| T-ndt-03 | Elevation of Privilege | `_isLocked` / next_question_selector free-tier gate | high | mitigate | Explicitly scope the change to rendering; `Question.questionNumber` and every comparison against `kFreeQuestionCount` stay intact, so the free/paid boundary is unchanged. `flutter test` (Task 3) covers next_question_selector_test.dart. |
| T-ndt-04 | Information Disclosure | Supabase payload still carries `question_number` | low | accept | Out of scope for a UI-text item — hiding it server-side needs a view/RLS change; the client-side gate depends on the field today. Note for 260917-ndq. |

No package-manager installs are introduced by this plan, so no supply-chain legitimacy gate applies.
</threat_model>

<verification>
1. `cd enchiridion && flutter test` — full suite green, including the new ordinal-absence test.
2. `cd enchiridion && flutter analyze lib` — no errors.
3. Gate A, Gate B and the numbered-range grep each return 0 (Task 3 verify block).
4. Manual read-through of the diff: `Question.questionNumber` still present in
   enchiridion/lib/models/question.dart, exam_prep_repository.dart,
   next_question_selector.dart, and the `_isLocked` comparisons.
</verification>

<success_criteria>
- No screen renders a question ordinal or a bank total.
- The user still sees their own answered/correct counts.
- Free-tier messaging still communicates the allowance without a numbered range or total.
- Access gating behaviour is byte-for-byte unchanged in logic.
- Both grep gates return zero and are recorded in the summary for reuse by siblings.
</success_criteria>

<output>
Create `.planning/quick/260917-ndt-question-numbers-should-be-removed-completely-from-the-ui-th/260917-ndt-SUMMARY.md` when done.
</output>
