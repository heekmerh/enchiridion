---
quick_id: 260917-ndr
batch: 260917-ndp
type: execute
wave: 1
depends_on: []
autonomous: true
files_modified:
  - scripts/generate_resource_content.py
  - scripts/tests/test_generate_questions.py
  - enchiridion/assets/data/exam_prep_questions.json
  - enchiridion/test/services/exam_prep_repository_test.dart
  - enchiridion/lib/widgets/exam_prep/explanation_text.dart
  - enchiridion/lib/screens/question_screen.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
  - enchiridion/test/widgets/explanation_text_test.dart
  - enchiridion/lib/models/question.dart
  - enchiridion/lib/services/notification_service.dart
  - enchiridion/test/models/question_test.dart
  - enchiridion/test/services/notification_service_test.dart

estimate:
  tokens: 96000
  raw_tokens: 48000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "A student reading an explanation sees the original paragraph breaks and bulleted 'Key Clues' lines as separate lines, not one run-on block."
    - "All 493 bundled explanations carry real line breaks after regeneration."
    - "Regenerating the asset changes only whitespace — no question, option, answer, or explanation wording drifts."
    - "Question-list rows and notification teasers still render on a single line."
    - "The DOCX-sourced resource topic JSON is byte-identical after the change."
  artifacts:
    - scripts/generate_resource_content.py
    - enchiridion/assets/data/exam_prep_questions.json
    - enchiridion/lib/widgets/exam_prep/explanation_text.dart
    - scripts/tests/test_generate_questions.py
    - enchiridion/test/widgets/explanation_text_test.dart
  key_links:
    - "fix_block_text() -> normalize_questions() -> exam_prep_questions.json (newlines survive generation)"
    - "exam_prep_questions.json -> ExamPrepRepository.parseNormalizedJson -> Question.explanation (newlines survive load)"
    - "Question.explanation -> ExplanationText -> all three answer surfaces (newlines survive render)"
    - "Question.previewText() / notificationTeaser() flatten newlines (single-line surfaces stay single-line)"
---

<objective>
Restore the newline structure that the question/answer content loses during asset
generation, then render it.

Root cause (verified against the repo, not assumed): `fix_text()` in
`scripts/generate_resource_content.py:87` ends with `re.sub(r"\s+", " ", text)`.
`\s` matches `\n`, so every newline in the source content is collapsed to a space
at generation time. The source `scripts/content/question.json` has the structure
intact — all 493 `explanation` values contain real newlines (verified) — and the
bundled `enchiridion/assets/data/exam_prep_questions.json` contains exactly zero,
real or escaped (verified). Flutter's `Text` widget honours `\n` already, so the
widgets are not the origin of the bug; they are handed pre-flattened strings.

A second, latent defect blocks the fix: `normalize_questions()` calls
`split_json_objects(raw[1:])`, dropping the source's leading `{`. The source is a
bare concatenation of 493 top-level objects, so stripping that brace makes the
scanner emit the 493 nested `options` maps instead of the questions (verified —
the parsed objects come back with keys `A`–`E`). The generator cannot currently
run against its own source; `raw` must be passed whole.

Purpose: the explanations are the teaching content — "Why?", "Key Clues in the
Question:", then a bulleted list, then "Classic Exam Association:". Flattened into
one paragraph they are close to unreadable, which is the reported symptom.
Output: a newline-preserving generator, a regenerated asset, and a shared
explanation renderer used by all three answer surfaces.

Scope note for the batch orchestrator: this plan edits `question_screen.dart`,
`exam_prep_home_screen.dart`, and `quick_check_card.dart`, which sibling items
`260917-ndt` (remove question numbers) and `260917-ndq` / `260917-ndx` (hide the
full bank) also touch. There is no logical dependency in either direction — the
overlap is declared in `files_modified` so waves serialise on files.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

@scripts/generate_resource_content.py
@enchiridion/lib/services/exam_prep_repository.dart
@enchiridion/lib/models/question.dart
@enchiridion/lib/screens/question_screen.dart
@enchiridion/lib/widgets/exam_prep/quick_check_card.dart
@enchiridion/lib/services/notification_service.dart
</context>

<interface_context>
Facts established by inspection — treat as given, do not re-derive:

- Source `scripts/content/question.json`: 493 concatenated top-level JSON objects,
  no wrapping array, first character `{`. Each object has exactly the keys
  `question`, `options`, `answer`, `explanation`. There is no `osce_tip` key and no
  `topic` key in the source; every asset row already carries `"osce_tip": null` and
  `"topic": null`, so regeneration cannot lose them.
- Newlines in the source: `explanation` 493/493 contain `\n`; `question` 0/493;
  option values 0/493. No `\r`. No run of 3+ consecutive newlines. Therefore only
  the explanation actually changes shape in this fix.
- `split_json_objects(raw)` (full string, no leading-character strip) returns the
  493 question-shaped objects. `split_json_objects(raw[1:])` returns 493 options maps.
- `fix_text()` is shared with the DOCX resource pipeline via `clean_heading()`,
  `paragraph_block()`, `table_block()`, and `checklist_block()`. Those callers want
  the current single-line collapse; their output must not change.
- The Dart `ExamPrepRepository.normalizeLegacySource()` is NOT on the runtime path
  (`loadQuestions()` uses `parseNormalizedJson`). Its `substring(1)` matches the
  `{{` sentinel used by its existing test. Leave it alone.
- Explanation render sites: `question_screen.dart:225`, `quick_check_card.dart:192`,
  `exam_prep_home_screen.dart:484` — all bare `Text(...)`.
- Single-line consumers of `questionText`: `Question.previewText()`
  (`question_list_screen.dart:189`, `exam_prep_question_list_screen.dart:226`) and
  `notificationTeaser()` (`notification_service.dart:138`, `bubble_alarm_callback.dart:65`).
- `flutter_markdown: ^0.7.4` is already a dependency, but the content carries no
  markdown emphasis markers (0/493 contain `**` or `##`). Do not route clinical text
  through a markdown parser — stray `*` or `_` in drug or formula names would be
  silently eaten. Plain text plus explicit paragraph/bullet layout is the correct
  renderer here.
- Test conventions: Python tests are `unittest` under `scripts/tests/`; Flutter
  tests live under `enchiridion/test/<layer>/` and run from `enchiridion/`.
</interface_context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Preserve newlines end-to-end — generator to regenerated asset to loaded Question</name>
  <files>scripts/generate_resource_content.py, scripts/tests/test_generate_questions.py, enchiridion/assets/data/exam_prep_questions.json, enchiridion/test/services/exam_prep_repository_test.dart</files>
  <behavior>
    Python — `fix_block_text(value)`:
    - Input `"Why?\n\nKey Clues:\n- High fever\n- Hypotension"` returns the same string unchanged.
    - Input `"Line  one\t\tstill  one\nLine   two"` returns `"Line one still one\nLine two"` (horizontal runs collapse per line, the line break survives).
    - Input `"a\r\nb\rc"` returns `"a\nb\nc"`.
    - Input `"a\n\n\n\n\nb"` returns `"a\n\nb"` (at most one blank line).
    - Input `"  \n  padded  \n  "` returns `"padded"`.
    - Input `"\xa0"` returns `""`.
    Python — `fix_text(value)`:
    - For every one of the four inputs above, returns exactly what today's
      implementation returns (a single line, all whitespace collapsed). This is the
      DOCX-pipeline guard and must be asserted, not assumed.
    Python — source parsing:
    - Parsing `scripts/content/question.json` yields 493 objects, and every one has
      all four of `question`, `options`, `answer`, `explanation`.
    - An object missing any of those keys raises a ValueError naming the index and
      the missing key, rather than surfacing as a bare KeyError.
    Python — regenerated asset invariants:
    - 493 rows; ids `exam-0001`..`exam-0493`; `osce_tip` and `topic` null on all rows.
    - Every `explanation` contains at least one `\n`; at least 400 contain `\n\n`.
    - For every row, whitespace-collapsing the regenerated `question_text`,
      `explanation`, and each option value reproduces the corresponding value from
      the pre-change asset exactly — zero wording drift.
    Dart — bundled asset:
    - `ExamPrepRepository.parseNormalizedJson` over the real asset file read from
      disk returns a non-empty list in which every `explanation` contains `\n`.
  </behavior>
  <action>
Work in `scripts/generate_resource_content.py` first.

Add `fix_block_text(value: str) -> str` holding the encoding-repair logic that
`fix_text` has today (the `\xa0` swap, the mojibake latin-1/utf-8 round trip
guarded by the `Â`/`â`/`ð` marker check, and the punctuation `replacements` map),
but ending with line-structure-preserving normalisation instead of the global
collapse: normalise `\r\n` and `\r` to `\n`, collapse horizontal whitespace runs
within each line to one space, strip each line, cap runs of three or more
newlines at two, then strip the whole string. Keep the existing empty-input early
return.

Redefine `fix_text(value)` to delegate: return the global-whitespace collapse of
`fix_block_text(value)`. This keeps the DOCX callers (`clean_heading`,
`paragraph_block`, `table_block`, `checklist_block`) producing byte-identical
output while the new function becomes the structure-aware variant. Do not change
any DOCX call site.

In `normalize_questions()`, switch `question_text`, `explanation`, and `osce_tip`
to `fix_block_text` and leave option values on `fix_text` — option labels are
single-line chips inside a Row and have no newlines in the source anyway.

Fix the source scan in the same function: pass the whole `raw` to
`split_json_objects` rather than `raw[1:]`. The source is a bare concatenation
whose first character is the first question's opening brace, so stripping it
desynchronises the depth counter and yields the nested options maps. After
parsing, validate each object has `question`, `options`, `answer`, and
`explanation`, raising a ValueError naming the offending index and key, so this
class of mis-parse fails loudly instead of producing a plausible-looking wrong asset.

Add a `--questions-only` argument to `main()` (argparse) that runs
`normalize_questions()` and skips the `TOPICS` loop. The DOCX-derived resource
JSON is out of scope for this item and must not be rewritten; regenerating it
would churn files another quick item already stabilised.

Before regenerating, snapshot the current asset for the drift comparison, e.g.
`git show HEAD:enchiridion/assets/data/exam_prep_questions.json` written to the
scratchpad. Then regenerate with `python3 scripts/generate_resource_content.py --questions-only`.

Write `scripts/tests/test_generate_questions.py` as a `unittest` module following
the `sys.path.insert(0, str(Path(__file__).resolve().parents[1]))` import style
already used by `scripts/tests/test_audit_paediatrics_toc.py`. Cover every Python
bullet in the behavior block. For the drift assertion, read the pre-change asset
from `git show HEAD:...` via `subprocess` so the test is self-contained and does
not depend on a scratchpad file surviving.

Finally, extend `enchiridion/test/services/exam_prep_repository_test.dart` with a
second test that reads `assets/data/exam_prep_questions.json` from disk with
`dart:io` `File` (flutter test runs with the package root as cwd), feeds it to
`ExamPrepRepository.parseNormalizedJson`, and asserts the list is non-empty and
that every `explanation` contains a line break. Keep the existing
`normalizeLegacySource` test untouched.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion && python3 -m unittest discover -s scripts/tests -p 'test_generate_questions.py' -v && python3 -m unittest discover -s scripts/tests -p 'test_*.py' && cd enchiridion && flutter test test/services/exam_prep_repository_test.dart</automated>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion && git diff --stat -- enchiridion/assets/data/resources/ | tee /dev/stderr | wc -l | grep -qx 0 && echo "resource topic JSON untouched"</automated>
  </verify>
  <done>`fix_block_text` preserves line structure and `fix_text` still collapses it; the generator parses its own source into 493 question-shaped objects; the regenerated asset has 493 rows whose explanations all contain `\n` and whose whitespace-collapsed text matches the pre-change asset exactly; the Dart repository test proves the newlines survive loading; `assets/data/resources/` shows no diff.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Render explanations as structured paragraphs and bullets across all three answer surfaces</name>
  <files>enchiridion/lib/widgets/exam_prep/explanation_text.dart, enchiridion/test/widgets/explanation_text_test.dart, enchiridion/lib/screens/question_screen.dart, enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/widgets/exam_prep/quick_check_card.dart</files>
  <behavior>
    - Given `"Why?\n\nThis is the reason."`, renders two separate paragraph Text
      widgets, with vertical spacing between them.
    - Given `"Key Clues:\n- High fever\n- Hypotension"`, renders the heading line
      plus two bullet rows; each bullet's text excludes the leading `- ` marker and
      the bullet glyph is a separate widget from the text, so wrapped bullet text
      hangs under the text and not under the glyph.
    - Given a single-line string with no newline, renders exactly one Text and no
      bullet rows.
    - Given `""`, renders nothing (a zero-size widget), not an empty spaced block.
    - A paragraph mixing a lead-in line and bullets keeps the lead-in as a plain
      line above the bullets rather than folding it into the first bullet.
    - Bullet detection accepts `- `, `• `, and `– ` prefixes after leading spaces.
    - Passing a `style` applies it to paragraph and bullet text alike.
  </behavior>
  <action>
Create `ExplanationText` in `enchiridion/lib/widgets/exam_prep/explanation_text.dart`
as a `StatelessWidget` taking a required `String text` and an optional
`TextStyle? style`.

Split the text into paragraphs on runs of two or more newlines, then split each
paragraph into lines on single newlines. Emit a `Column` with
`crossAxisAlignment: CrossAxisAlignment.start` and `mainAxisSize: MainAxisSize.min`.
Render a run of consecutive non-bullet lines as one `Text` (the embedded single
newlines render as line breaks, which is what the source intended), and render each
bullet line as a `Row` with `crossAxisAlignment: CrossAxisAlignment.start`
containing a narrow bullet glyph followed by an `Expanded` `Text` of the remaining
content — this is what gives wrapped bullets a hanging indent, which a single
`Text` cannot do. Put deliberate vertical spacing between paragraphs and a smaller
gap between bullet rows. Return a `SizedBox.shrink()` when the trimmed input is empty.

Add a short doc comment recording why this widget exists: the content arrives as
plain text with meaningful line breaks, and the alternative of feeding it to
`flutter_markdown` would let stray emphasis characters in drug names and formulas
silently disappear.

Then swap the three bare render sites to use it, preserving each site's current
text style:
- `question_screen.dart:225` — replace `Text(q.explanation, style: theme.textTheme.bodyMedium)`.
- `exam_prep_home_screen.dart:484` — replace `Text(widget.question.explanation)`.
- `quick_check_card.dart:192` — replace `Text(widget.question.explanation)`.

Leave the OSCE tip block in `question_screen.dart` on its current `Text`: every
`osce_tip` in the bundled data is null, so there is no structured content to render
and changing it would be untested churn.

Write `enchiridion/test/widgets/explanation_text_test.dart` covering the behavior
bullets. Create the `test/widgets/` directory — it does not exist yet. Pump the
widget inside a `MaterialApp`/`Scaffold` and assert on widget counts and on
`find.textContaining` for the de-marked bullet content.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/enchiridion && flutter test test/widgets/explanation_text_test.dart test/screens/question_screen_test.dart</automated>
  </verify>
  <done>`ExplanationText` renders paragraphs and hanging-indent bullets per the behavior list; all three answer surfaces route `Question.explanation` through it; the new widget test and the existing question screen test pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Keep list previews and notification teasers single-line</name>
  <files>enchiridion/lib/models/question.dart, enchiridion/lib/services/notification_service.dart, enchiridion/test/models/question_test.dart, enchiridion/test/services/notification_service_test.dart</files>
  <behavior>
    - `Question.previewText()` on a stem containing `"A 5 year old boy.\nWhat is the\n\nnext step?"` returns a string with no line break in it.
    - `previewText` still returns short single-line stems unchanged, still takes the
      tail for long stems, and still prefixes the ellipsis — the three existing
      tests in `test/models/question_test.dart` continue to pass unmodified.
    - The `maxLength` budget is measured after flattening, so a stem whose newlines
      inflate its length is not truncated differently than its rendered form.
    - `notificationTeaser()` on a multi-line stem returns a single-line string.
    - `notificationTeaser()` still caps at 160 characters and appends the ellipsis
      beyond that, and returns shorter input unchanged.
  </behavior>
  <action>
Task 1 routes `question_text` through `fix_block_text`, so a future batch of
content with line breaks in the stem would reach these two single-line surfaces.
Today's 493 stems contain none, so this is defensive, and it is cheap: a list row
is a one-line `Text` and an Android notification body collapses line breaks
unpredictably across launchers, so both want a flattened string regardless of
what the content does later.

In `enchiridion/lib/models/question.dart`, flatten whitespace at the top of
`previewText` before the length check — collapse whitespace runs (including
newlines) to single spaces and trim — then run the existing tail-taking logic
against the flattened string. Do not alter the tail-taking or ellipsis behaviour;
the comment above the method explaining why the tail is taken stays accurate.

In `enchiridion/lib/services/notification_service.dart`, apply the same flattening
inside `notificationTeaser` before the 160-character cap, so both the plugin path
and `bubbleAlarmCallback` (which calls the same helper) get a single-line body.

Extend `test/models/question_test.dart` with the multi-line cases from the
behavior list, added to the existing `Question.previewText` group. Extend
`test/services/notification_service_test.dart` with a `notificationTeaser` group
covering the flattening, the 160-character cap, and the short-input passthrough —
this is a pure function, so it needs none of the platform-channel setup the
existing test in that file works around.
  </action>
  <verify>
    <automated>cd /home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/enchiridion && flutter test test/models/question_test.dart test/services/notification_service_test.dart</automated>
  </verify>
  <done>Both single-line surfaces flatten embedded line breaks while keeping their existing truncation behaviour; new and pre-existing tests in both files pass.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| authored content -> generator -> bundled asset | `scripts/content/question.json` is hand-maintained content parsed by a hand-rolled brace scanner; a malformed object previously produced a silently wrong asset rather than an error |
| bundled asset -> Flutter render | asset strings are rendered verbatim into UI and into Android notification bodies |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndr-01 | Tampering | `normalize_questions()` object scan | medium | mitigate | Task 1 validates every parsed object carries `question`/`options`/`answer`/`explanation` and raises a ValueError naming index and key, replacing the silent mis-parse that let the `raw[1:]` offset yield options maps |
| T-ndr-02 | Information disclosure | regenerated `exam_prep_questions.json` | medium | mitigate | Task 1 asserts zero wording drift against the pre-change asset read from `git show HEAD:...`, so a regeneration cannot quietly substitute or drop clinical content |
| T-ndr-03 | Denial of service | `ExplanationText` layout | low | mitigate | Paragraph/line splitting is linear in string length over ~2 KB strings and the widget short-circuits on empty input; no regex backtracking is introduced |
| T-ndr-04 | Tampering | npm/pip/cargo installs | n/a | accept | No dependency is added or upgraded by this plan; `flutter_markdown` is deliberately not adopted. Package legitimacy gate not applicable |
</threat_model>

<verification>
Run from the repo root after all three tasks:

1. `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` — generator unit
   tests plus the two pre-existing script test modules still pass.
2. `cd enchiridion && flutter test` — the full Flutter suite, confirming no
   regression in the screen tests that construct `Question` fixtures.
3. `cd enchiridion && flutter analyze` — no new analyzer findings.
4. `git diff --stat -- enchiridion/assets/data/resources/` — empty; only the
   question asset was regenerated.
5. Spot-check one regenerated row renders as intended: confirm `exam-0001`'s
   explanation in the asset contains the `Key Clues in the Question:` heading
   followed by `\n\n` and then `- High fever` on its own line.
</verification>

<success_criteria>
- Every bundled explanation carries real line breaks; the asset previously had zero.
- Regeneration is provably whitespace-only — no clinical wording changed.
- The three answer surfaces render paragraphs and bullets with hanging indents
  instead of one contiguous block.
- Question-list rows and notification teasers remain single-line.
- The DOCX resource pipeline's output is unchanged.
- `flutter test`, `flutter analyze`, and the Python unittest suite all pass.
</success_criteria>

<output>
Create `.planning/quick/260917-ndr-the-question-and-answer-rendering-engine-is-not-making-use-o/260917-ndr-SUMMARY.md` when done.
</output>
