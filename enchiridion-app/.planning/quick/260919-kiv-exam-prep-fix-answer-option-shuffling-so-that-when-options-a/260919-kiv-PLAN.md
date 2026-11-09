---
phase: quick-260919-kiv
plan: 01
type: execute
wave: 2
depends_on: ['260919-kis', '260919-kiu']
files_modified:
  - enchiridion/lib/models/question.dart
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
  - enchiridion/test/models/question_test.dart
  - enchiridion/test/screens/question_screen_test.dart
  - enchiridion/test/widgets/quick_check_card_test.dart
  - enchiridion/test/guards/option_label_position_guard_test.dart
autonomous: true
requirements: ['260919-kiv']

estimate:
  tokens: 78000
  raw_tokens: 39000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "On the practice question screen, after the option order is scrambled the on-screen letters still read A, B, C (…) from top to bottom — the letter belongs to the slot, not to the option text."
    - "The same holds in the bubble Quick Check card, whose option order is scrambled from a review-attempt seed."
    - "Tapping a row records that row's underlying option key, so a correct pick is still scored correct and a wrong pick still scored wrong after the shuffle."
    - "Reopening an already-answered question read-only still highlights the row the user originally picked, and still marks the correct row green."
  artifacts:
    - enchiridion/lib/models/question.dart
    - enchiridion/test/guards/option_label_position_guard_test.dart
  key_links:
    - "rendered row index -> Question.displayLabel(index) -> the avatar letter widget (the only source of a displayed letter)"
    - "tapped row -> underlying option key -> UserAnswer.selectedOption and the correctOption comparison (unchanged, key-based, position-independent)"
---

<objective>
Answer options are scrambled, but each option's letter travels with it, so the scramble
changes nothing a user would notice: a memorised "the answer is C" still points at the same
text. Reassign A/B/C/D from the final rendered position instead.

Purpose: make option shuffling do the one thing it exists to do — break position/letter
memorisation of repeated questions — without disturbing how correctness is scored.
Output: a shared position-to-letter helper on `Question`, both shuffling surfaces wired to it,
behaviour tests on each surface, and a repo guard that keeps the letter tied to the slot.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

The Flutter app is the nested `enchiridion/` directory of this repo root. Every path below is
repo-relative, so library code lives under `enchiridion/lib/` and every Flutter command runs as
`cd enchiridion && flutter …`.

@enchiridion/lib/models/question.dart
@enchiridion/lib/screens/question_screen.dart
@enchiridion/lib/widgets/exam_prep/quick_check_card.dart
</context>

<diagnosis>
Read this before touching code — it is the result of tracing all three option-rendering
surfaces, and it decides what is in scope.

Both shuffling surfaces shuffle a list of option **keys** and then render each key's own
letter as that row's label:

- `enchiridion/lib/screens/question_screen.dart:145-148` seeds `_optionOrder` by shuffling
  `_question.optionKeys`; line 307-316 maps that order into `_OptionTile(option: opt, …)`; the
  tile at line 503-514 renders the key it was handed as the avatar letter.
- `enchiridion/lib/widgets/exam_prep/quick_check_card.dart:47` shuffles the same way; line
  126-179 renders the key as the avatar letter at line 170.

So a shuffle of `[a, b, c, d]` into `[c, a, d, b]` renders rows reading "C …", "A …", "D …",
"B …": each letter followed the text it started with. Two consequences — the shuffle is
defeated exactly as reported, and the visible letter column is out of order, which reads as
broken on its own.

**The coupled second bug the brief asks about does not exist, and this plan must keep it that
way.** Correctness is computed against the underlying key everywhere, never against a letter
or a position: `question_screen.dart:151` and `:312`, `quick_check_card.dart:51` and `:128`
all compare an option key to `question.correctOption` (itself lower-cased at
`question.dart:48`). `UserAnswer.selectedOption` likewise stores the key, and read-only
restore at `question_screen.dart:105` compares keys. Nothing keys off a fixed letter-to-answer
mapping, so scoring is already position-independent. The work here is display-only, and Task 2
adds the assertions that pin that property down rather than leaving it assumed. Record this
finding in the SUMMARY — the brief explicitly asked for the check.

**Third surface, deliberately out of scope:** `_StudyCard` in
`enchiridion/lib/screens/exam_prep_home_screen.dart:459` renders `optionKeys` in sorted order
with no shuffle at all, so its letters already match their rendered positions and it has
nothing to fix. Leave its behaviour and its file untouched — sibling item `260919-kit` is
editing that same file's copy, and this plan must not collide with it.
</diagnosis>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Letter follows the slot — one helper, wired end-to-end through the practice screen</name>
  <files>enchiridion/lib/models/question.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/test/models/question_test.dart, enchiridion/test/screens/question_screen_test.dart</files>
  <read_first>
    - enchiridion/lib/models/question.dart:56-63 (`optionText`, `optionKeys`)
    - enchiridion/lib/screens/question_screen.dart:145-148 (`_seedOptionOrder`), :307-316 (option map), :451-514 (`_OptionTile` and its avatar)
    - enchiridion/test/screens/question_screen_test.dart:11-27 and :41-71 (the fixture questions and `_buildSubject` harness this test file already uses — reuse both, do not build a new harness)
  </read_first>
  <behavior>
    - `Question.displayLabel(0)` is `'A'`, `(1)` is `'B'`, `(2)` is `'C'`, `(3)` is `'D'`; it depends only on the position passed in and never on any option key.
    - A negative position, or one past the letters available, is a programming error rather than a silently wrong letter: assert on it.
    - Rendering `_question` (`{'a': '3', 'b': '4', 'c': '5'}`) under a seed that genuinely permutes the key order shows the option texts in that permuted order while the avatar letters still read A, B, C top to bottom.
    - The row carrying text `'4'` is still the one scored correct after that permutation (`correctOption` is `'b'`), whatever letter its slot gives it.
  </behavior>
  <action>
    Add a static `displayLabel(int position)` to `Question` in
    `enchiridion/lib/models/question.dart`, returning the position-th capital letter
    (`String.fromCharCode(0x41 + position)`), with an `assert` restricting position to
    `0 <= position < 26`. Document in its doc comment that the letter belongs to the rendered
    slot, not to the option — which is the entire point of shuffling a repeated question.

    In `enchiridion/lib/screens/question_screen.dart`, give `_OptionTile` a new required
    `String label` field alongside its existing `option` field, and render `label` as the
    avatar's text (line ~507) instead of deriving the letter from `option`. Keep `option`
    on the tile: the tap callback, the selected comparison and the correctness comparison all
    still run on the underlying key and must not change. Then change the option map at
    line ~307 to walk positions as well as keys — `options.asMap().entries.map((entry) => …)`
    — passing `label: Question.displayLabel(entry.key)` and `option: entry.value`.

    Do not restate the removed letter-derivation expression in a comment inside either
    `question_screen.dart` or `quick_check_card.dart`: Task 3 adds a guard that reads those
    two files' source, and a comment quoting the old expression would trip it.

    Tests. In `enchiridion/test/models/question_test.dart`, cover `displayLabel` for the first
    four positions and its out-of-range assertion. In
    `enchiridion/test/screens/question_screen_test.dart`, add a widget test that pumps
    `_buildSubject(storageService, readOnly: false)` with an explicit `optionSeed`. Derive the
    expected key order inside the test with the same `['a','b','c']..shuffle(Random(seed))`
    the screen uses, and first `expect` that derived order is NOT `['a','b','c']` — with a
    reason saying a seed that leaves the order untouched makes the test vacuous. If the seed
    you pick fails that guard, bump it until it permutes. Then assert two things: the option
    texts appear top to bottom in the derived order, and the avatar letters appear top to
    bottom as A, B, C. Read rendered order by collecting the relevant `Text` widgets in tree
    order (`tester.widgetList&lt;Text&gt;(find.descendant(of: find.byType(CircleAvatar), matching: find.byType(Text)))`
    for the letters) rather than by index-guessing individual finders.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/models/question_test.dart test/screens/question_screen_test.dart</automated>
  </verify>
  <done>Both test files pass, including the pre-existing cases in `question_screen_test.dart`, which find options by their text (`'4'`, `'6'`) and so must not have needed edits. The new widget test proves a permuted text order renders alongside letters reading A, B, C.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Same fix in the bubble Quick Check card, plus the scoring-coupling assertions</name>
  <files>enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/test/widgets/quick_check_card_test.dart</files>
  <read_first>
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart:40-51 (`initState` seeding, `_isCorrect`), :126-179 (option rows and avatar)
    - enchiridion/test/screens/question_screen_test.dart:111-118 (the `SharedPreferences.setMockInitialValues` + `StorageService` setUp this widget needs, since the card reads `StorageService` from the tree)
  </read_first>
  <behavior>
    - Whatever order `_optionOrder` lands in, the card's avatar letters read A, B, C, D top to bottom.
    - Tapping the row whose text is the correct option's text and submitting reports the correct result, no matter which letter that row was given.
    - Tapping a row whose text is a wrong option and submitting reports the wrong result, likewise letter-independent.
  </behavior>
  <action>
    Apply the Task 1 helper to `enchiridion/lib/widgets/exam_prep/quick_check_card.dart`: change
    the option map at line ~126 from `_optionOrder.map((option) {…})` to walk positions too
    (`_optionOrder.asMap().entries.map((entry) {…})`, with `final option = entry.value;` as the
    first line of the body so the rest of the closure — selected, isCorrect, onTap, and
    `optionText(option)` — is untouched), and render `Question.displayLabel(entry.key)` as the
    avatar's text at line ~170. Leave the seeding at line 47 exactly as it is: the seed derives
    from the review attempt count on purpose, so a repeated question lands in a different order,
    and that is the behaviour this fix finally makes visible.

    Create `enchiridion/test/widgets/quick_check_card_test.dart`. Wrap the card in a
    `MaterialApp` under a `MultiProvider` supplying `StorageService` and `StudyStatsProvider`,
    mirroring `_buildSubject` in `test/screens/question_screen_test.dart`, with
    `SharedPreferences.setMockInitialValues({})` in `setUp`. Use a four-option fixture question
    so the letter sequence is worth asserting. Assert the avatar letters read A, B, C, D in
    tree order — that assertion is seed-independent and holds for every order the card can
    produce, so this test needs no control over the seed.

    Then add the two scoring assertions the brief asked for, which are the ones that would
    catch a regression into letter-keyed scoring: find the row by its option *text*, tap it,
    tap Submit, pump, and expect the card's verdict text — `'Correct'` for the text belonging
    to `correctOption`, `'Not quite'` for a wrong one (see line ~189). Give each a reason
    stating that the verdict follows the option key, never the letter the shuffle handed the
    row.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/widgets/quick_check_card_test.dart</automated>
  </verify>
  <done>The new test file passes: letters read A, B, C, D in tree order, the correct-text row scores correct, and a wrong-text row scores wrong.</done>
</task>

<task type="auto">
  <name>Task 3: Repo guard against the letter re-attaching to the option, then full-suite sweep</name>
  <files>enchiridion/test/guards/option_label_position_guard_test.dart</files>
  <read_first>
    - enchiridion/test/guards/available_before_coming_soon_guard_test.dart:1-27 (the house style for a repo-wide guard: a leading comment block stating the one invariant, then a small table of subjects)
  </read_first>
  <action>
    <!-- planner-discipline-allow: toUpperCase -->
    The token below is the guard's own subject, so it has to be named here to be implementable.
    It is safe: the guard reads only the two `lib/` files, never this plan and never the test
    file itself, and Tasks 1 and 2 already forbid restating it in those two files' comments.

    Create `enchiridion/test/guards/option_label_position_guard_test.dart`, a source-reading
    guard over exactly the two surfaces that shuffle option order:
    `lib/screens/question_screen.dart` and `lib/widgets/exam_prep/quick_check_card.dart`
    (resolve each with `File('lib/…')`, since `flutter test` runs with the app directory as
    its working directory). For each file, strip whole-line `//` comments, then assert the
    remaining source contains `Question.displayLabel(` and contains no occurrence of
    `toUpperCase` — after this change neither file has any other use of it, so its return is
    the signal that a letter is being derived from an option key again.

    Head the file with a comment stating the invariant in one sentence: in a surface that
    shuffles option order, the displayed letter is a function of the rendered position and of
    nothing else. Name each failing file in the `reason:` so a future failure explains itself.

    `exam_prep_home_screen.dart` is deliberately absent from the subject list — it renders
    sorted keys and never shuffles. Say so in the header comment so nobody "completes" the
    list later and breaks a file another batch item owns.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/guards/option_label_position_guard_test.dart &amp;&amp; flutter analyze lib/models/question.dart lib/screens/question_screen.dart lib/widgets/exam_prep/quick_check_card.dart &amp;&amp; flutter test</automated>
  </verify>
  <done>The guard passes, the analyzer reports no issues for the three changed library files, and the full `flutter test` suite is green — including `test/screens/exam_prep_home_screen_test.dart` and `test/screens/answered_questions_screen_test.dart`, neither of which needed edits.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| stored answer -> local review state | `UserAnswer.selectedOption` is persisted and later replayed to restore a read-only view; this change must not alter what is written there. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kiv-01 | Tampering | `UserAnswer.selectedOption` persisted by `question_screen.dart` / `quick_check_card.dart` | low | mitigate | Change is display-only; the value written stays the underlying option key. Task 2's two scoring assertions and the untouched read-only case in `question_screen_test.dart` pin this down. |
| T-kiv-02 | Information Disclosure | option letter rendering | low | accept | Letters label options already fully visible on screen; reassigning them by position reveals nothing new. |

No package-manager installs in this plan, so the supply-chain gate (`T-…-SC`) does not apply.
</threat_model>

<verification>
1. `cd enchiridion && flutter test test/models/question_test.dart test/screens/question_screen_test.dart` — passes.
2. `cd enchiridion && flutter test test/widgets/quick_check_card_test.dart` — passes.
3. `cd enchiridion && flutter test test/guards/option_label_position_guard_test.dart` — passes.
4. `cd enchiridion && flutter analyze lib/models/question.dart lib/screens/question_screen.dart lib/widgets/exam_prep/quick_check_card.dart` — clean.
5. `cd enchiridion && flutter test` — full suite green, with no edits to `exam_prep_home_screen.dart` or its tests.
</verification>

<success_criteria>
- A scrambled option list renders letters A, B, C (…) top to bottom on both the practice
  question screen and the bubble Quick Check card, so the letter no longer identifies the
  option text it started next to.
- Scoring is unchanged and provably key-based: correct picks score correct and wrong picks
  score wrong regardless of the letter the shuffle gave the row.
- A guard test fails the suite if either shuffling surface goes back to deriving a letter from
  an option key.
- The SUMMARY records the brief's coupled-bug check: correctness tracking never assumed a
  fixed letter-to-answer mapping, so there was no second bug to fix — and names the two tests
  that now hold that property.
</success_criteria>

<output>
Create `.planning/quick/260919-kiv-exam-prep-fix-answer-option-shuffling-so-that-when-options-a/260919-kiv-SUMMARY.md` when done
</output>
