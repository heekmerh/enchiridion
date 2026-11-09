---
phase: quick-260917-ndq
plan: 01
type: execute
wave: 1
quick_id: 260917-ndq
depends_on: ["260917-ndx"]
files_modified:
  - enchiridion/lib/services/question_visibility.dart
  - enchiridion/lib/screens/question_list_screen.dart
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/lib/screens/exam_prep_question_list_screen.dart
  - enchiridion/test/services/question_visibility_test.dart
  - enchiridion/test/screens/library_screen_test.dart
  - enchiridion/test/guards/bank_disclosure_guard_test.dart
autonomous: true
requirements: ["260917-ndq"]

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "No screen renders the total number of questions in a book bank or in the exam prep bank."
    - "The library book options sheet no longer opens an enumerated list of every question in a book."
    - "A user who has answered nothing in a book sees no question-browsing entry for that book."
    - "The exam prep Access card states entitlement without naming a bank total or an ordinal question range."
    - "An automated guard fails the test suite if a future change reintroduces a bank-size disclosure anywhere in lib/."
  artifacts:
    - enchiridion/lib/services/question_visibility.dart
    - enchiridion/test/services/question_visibility_test.dart
    - enchiridion/test/guards/bank_disclosure_guard_test.dart
  key_links:
    - "QuestionListScreen list body and progress banner read the question_visibility helpers instead of the loaded bank."
    - "LibraryScreen book options sheet gates its review entry on hasReviewableQuestions()."
    - "The guard test scans lib/ only, never test/, so its own pattern literals cannot satisfy or trip it."
---

<objective>
Stop every user-facing surface from disclosing how many questions exist, and stop the
question bank from being browsable as an enumerated list.

Purpose: the user does not want the bank size known, and does not want the bank itself
browsable "for now". Questions are meant to arrive one at a time (practice-now and study
notifications), not as a catalogue the user can scroll and count.

Output:
- A pure `question_visibility` helper that decides what is browsable and produces
  count-free progress copy.
- `QuestionListScreen` reduced from "every question in the book" to "questions you have
  already answered", with no bank total in its banner.
- The library book options sheet no longer offering a full-bank browse.
- The exam prep Access card copy rewritten without a total or an ordinal question range.
- A guard test that fails the suite if a bank total is reintroduced anywhere in `lib/`.

Scope boundaries with sibling batch items:
- `260917-ndx` owns the exam prep "Browse Full Bank" button and its destination screen.
  This plan does not touch that button. It only sweeps a leftover count disclosure in that
  destination file if `ndx` leaves the file in the tree (Task 3, conditional).
- `260917-ndt` owns question-number labels (`Q12.`, `Question 12`). This plan does not
  remove any question-number label.
- `260917-nds` will later wire dashboard stat tiles to a browse-what-I-answered surface.
  Task 1 deliberately leaves `QuestionListScreen` alive and answered-only so `nds` has a
  surface to point at rather than a deleted screen.

Dependency rationale (why this is not independent): this plan edits the same
`_ExamMetricCard` widget in `exam_prep_home_screen.dart` that `260917-ndx` edits, so this
plan runs after `260917-ndx`.

Coordinator note (cycle resolution): this plan also edits the same
`question_list_screen.dart` list body that `260917-ndt` edits, but `260917-ndt`'s own plan
declares `depends_on: [260917-ndq, ...]` and is explicitly designed to run LAST as a
cleanup sweep that re-locates its grep targets dynamically (via its own Task 3 gate
output) rather than relying on fixed line numbers from this plan. Declaring both directions
created a dependency cycle; the coordinator resolved it by dropping `260917-ndt` from this
plan's `depends_on` (kept only `260917-ndx`). `260917-ndt` remains authoritative for
ordering — it runs after this plan lands, not before.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

The Flutter app lives in `enchiridion/`, not at the repo root. All `flutter` commands run
from `enchiridion/`. All paths in `files_modified` are repo-relative and therefore start
with `enchiridion/`.

Current disclosure inventory (verified by grep at planning time):

| Location | What leaks |
|---|---|
| `lib/screens/exam_prep_home_screen.dart:186` | Access card states the unlocked bank total |
| `lib/screens/exam_prep_home_screen.dart:187` | Access card states an ordinal free range and "full bank" |
| `lib/screens/question_list_screen.dart:169` | Progress banner states the book bank total |
| `lib/screens/question_list_screen.dart` list body | Lists every question including locked placeholders, so the total is countable by scrolling |
| `lib/screens/library_screen.dart` book options sheet | Opens that enumerated list |
| `lib/screens/exam_prep_question_list_screen.dart:158` | Header states the exam prep bank total (owned by `260917-ndx`) |

Relevant existing code:
- `lib/screens/question_list_screen.dart` loads the book bank from Supabase in `_loadData`
  and renders `_buildProgressBanner` + `_buildList`.
- `lib/screens/library_screen.dart` `_showBookOptions` is opened by long-pressing a book
  card and currently has two entries: read the book, and open the question list.
- `lib/services/storage_service.dart` exposes `getAnswers(scope)` returning
  `Map<String, UserAnswer>`.
- `test/screens/library_screen_test.dart` already initialises a stub Supabase and a mocked
  `SharedPreferences`-backed `StorageService`, and pumps `LibraryScreen`. Reuse that
  harness rather than building a new one.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: End-to-end — library review entry serves only already-answered questions</name>
  <files>enchiridion/lib/services/question_visibility.dart, enchiridion/lib/screens/question_list_screen.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/test/services/question_visibility_test.dart, enchiridion/test/screens/library_screen_test.dart</files>
  <precondition>The Flutter SDK is on PATH and `flutter pub get` has already been run in `enchiridion/` (the existing test suite runs).</precondition>
  <reversibility rating="reversible">Pure UI/navigation scoping change; restoring the previous list body and sheet entry is a revert of three files.</reversibility>
  <read_first>
    - enchiridion/lib/screens/question_list_screen.dart (whole file, ~233 lines)
    - enchiridion/lib/screens/library_screen.dart lines 105-170 (`_openBook`, `_showBookOptions`)
    - enchiridion/test/screens/library_screen_test.dart lines 100-135 (`_makeStorage`, `setUpAll`)
  </read_first>
  <behavior>
    Unit behaviours for `question_visibility.dart` (write these tests first, watch them fail):
    - `reviewableQuestions` given a bank of 25 questions and an answered-id set containing
      the ids of the 3rd and 7th returns exactly those two, in bank order.
    - `reviewableQuestions` given an empty answered-id set returns an empty list.
    - `reviewableQuestions` given an answered id that is absent from the bank ignores it and
      does not throw.
    - `hasReviewableQuestions` is `false` for an empty answer map and `true` for a non-empty one.
    - `answeredProgressLabel(answered: 2, correct: 1)` returns exactly `'2 answered — 1 correct'`.
    - `answeredProgressLabel(answered: 0, correct: 0)` returns exactly `'0 answered — 0 correct'`.
    - For a bank of any size, the string returned by `answeredProgressLabel` does not contain
      the bank size: assert `answeredProgressLabel(answered: 2, correct: 1).contains('25')` is
      `false` when the bank holds 25 questions.

    Widget behaviour appended to the existing `library_screen_test.dart`:
    - Pumping `LibraryScreen` with the existing mocked storage (which records no answers),
      then long-pressing the first book card, shows the sheet's read entry and shows no
      entry that opens the question list. Assert the read entry is found and that a
      `find.byIcon(Icons.quiz_outlined)` inside the sheet finds nothing.
  </behavior>
  <action>
    Create `enchiridion/lib/services/question_visibility.dart` as pure Dart with no Flutter
    imports, exporting three top-level functions:

    1. `List&lt;Question&gt; reviewableQuestions({required List&lt;Question&gt; bank, required Set&lt;String&gt; answeredIds})`
       — returns the bank entries whose `id` is in `answeredIds`, preserving bank order.
       Unanswered entries are never returned. This is the single rule that keeps unseen
       questions off every list surface.
    2. `bool hasReviewableQuestions(Map&lt;String, UserAnswer&gt; answers)` — returns
       `answers.isNotEmpty`.
    3. `String answeredProgressLabel({required int answered, required int correct})` —
       builds the progress copy from the user's own two counters only. It must not accept,
       reference, or receive any bank-size value; its signature takes no bank and no list.

    Then rewire `question_list_screen.dart`:
    - `_buildProgressBanner` renders `answeredProgressLabel(answered: _answeredCount, correct: _correctCount)`.
      Delete the old banner expression entirely; do not keep it commented out.
    - `_buildList` iterates the result of `reviewableQuestions(bank: _questions, answeredIds: _answers.keys.toSet())`,
      computing `itemCount` from that filtered list. Leave the per-tile title text exactly as
      `260917-ndt` left it — this task changes which rows exist, never their labels.
    - Keep the `_isLocked` guard in `_openQuestion` as defence in depth even though an
      answered question is by definition openable.
    - Replace the empty-state copy in `_buildEmpty` with a review-shaped message telling the
      user they have not answered anything in this book yet, and show that empty state when
      the filtered list is empty (not only when the loaded bank is empty). The message must
      not mention how many questions exist or are waiting.
    - Change the AppBar title from the questions wording to a review wording so the screen's
      name matches its new contents. No number in the title.

    Then rewire `library_screen.dart` `_showBookOptions`:
    - Keep the read-the-book entry unchanged.
    - Replace the question-list entry with a review entry whose label says the user is
      reviewing what they have already answered, still navigating to `QuestionListScreen`
      with the same `bookId`.
    - Render that review entry only when `hasReviewableQuestions(context.read&lt;StorageService&gt;().getAnswers(book.id))`
      is true, so a user who has answered nothing sees no question surface at all for that book.
    - Keep the `QuestionListScreen` import; the screen stays reachable and is not deleted.

    Follow the repo's existing style: `const` where the analyzer wants it, no new lints.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/services/question_visibility_test.dart test/screens/library_screen_test.dart && flutter analyze lib/services/question_visibility.dart lib/screens/question_list_screen.dart lib/screens/library_screen.dart</automated>
  </verify>
  <done>
    `question_visibility.dart` exists with the three functions and all behaviours above pass.
    `flutter test test/services/question_visibility_test.dart test/screens/library_screen_test.dart`
    is green, including the new long-press assertion that the sheet offers no question-list
    entry for a user with no recorded answers. `flutter analyze` reports no issues on the
    three changed lib files. A grep of `lib/screens/question_list_screen.dart` with comment
    lines stripped yields zero matches for `\$\{[^}]*uestions\.length`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Exam prep Access card states entitlement without a total or an ordinal range</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart</files>
  <read_first>
    - enchiridion/lib/screens/exam_prep_home_screen.dart lines 180-220 (the Access `_ExamMetricCard`, as left by `260917-ndx`)
  </read_first>
  <action>
    Edit only the `subtitle:` argument of the Access `_ExamMetricCard`. Do not touch its
    `child:` — that Row belongs to `260917-ndx` and must be left exactly as that task left it,
    whether or not it still holds a button. Do not touch the Daily Performance card (that Row
    belongs to `260917-nds`) or the Quick Check card.

    New subtitle behaviour:
    - When `_hasAccess` is true, state that full access is active. No inventory figure, no
      collection-length interpolation of any kind.
    - When `_hasAccess` is false, state the free practice allowance using the
      `kFreeQuestionCount` constant and invite unlocking for unlimited practice. Phrase the
      allowance as a quantity of free practice questions, never as a numbered position or a
      span of positions within an ordered bank, and drop the "full bank" phrasing that
      implied a browsable catalogue.

    The distinction that matters: the free allowance is an entitlement the user is entitled
    to know; the size of the bank is not. Keeping `kFreeQuestionCount` in the copy is correct,
    reintroducing an inventory figure is not.

    Delete the two replaced expressions outright rather than commenting them out — a commented
    copy of the old string still discloses the same fact to anyone reading the source and will
    trip the Task 3 guard once comment stripping is tightened.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/screens/exam_prep_home_screen.dart && test "$(grep -vE '^[[:space:]]*//' lib/screens/exam_prep_home_screen.dart | grep -cE '\$\{[^}]*uestions\.length|[Qq]uestions?[[:space:]]+[0-9]+[[:space:]]*-')" = "0" && grep -q 'kFreeQuestionCount' lib/screens/exam_prep_home_screen.dart</automated>
  </verify>
  <done>
    `flutter analyze lib/screens/exam_prep_home_screen.dart` reports no issues. With comment
    lines stripped, the file yields zero matches for both the collection-length interpolation
    pattern and the ordinal-range copy pattern. `kFreeQuestionCount` is still referenced, so
    the free allowance is still communicated. The Access card's `child:` Row is byte-identical
    to what `260917-ndx` left behind.
  </done>
</task>

<task type="auto">
  <name>Task 3: Repo-wide guard test that fails on any reintroduced bank-size disclosure</name>
  <files>enchiridion/test/guards/bank_disclosure_guard_test.dart, enchiridion/lib/screens/exam_prep_question_list_screen.dart</files>
  <read_first>
    - enchiridion/test/config/freemium_config_test.dart (plain `flutter_test` style, no widget harness)
  </read_first>
  <behavior>
    - Scanning `lib/` finds zero source lines matching `RegExp(r'\$\{[^}]*uestions\.length')`.
    - Scanning `lib/` finds zero source lines matching `RegExp(r'[Qq]uestions?\s+\d+\s*[-–]')`.
    - The scan walks `lib/` recursively and reads only files ending in `.dart`.
    - Lines whose trimmed form starts with `//` are excluded before matching, so prose in a
      comment cannot fail the gate.
    - Failure output names the offending file and line so a future regression is actionable.
  </behavior>
  <action>
    Create `enchiridion/test/guards/bank_disclosure_guard_test.dart` using `dart:io` and
    `flutter_test`. Resolve the scan root as `Directory('lib')` — `flutter test` runs with the
    package root as the working directory, which is `enchiridion/`.

    Scan `lib/` only. Never scan `test/`: the guard's own pattern literals live in the test
    file, and scanning itself would make the gate permanently red for the wrong reason.

    Use the two regexes given in `&lt;behavior&gt;` verbatim. The first one deliberately requires a
    dollar-brace interpolation, so a legitimate non-display use such as a list length passed to
    `itemCount` does not match — only a figure rendered into a user-visible string does. The
    second one catches copy that walks the bank by ordinal position.

    Collect every violation across all files before asserting, then assert the collected list
    is empty with a `reason` that prints each `file:line` and the matched text. One assertion,
    complete report.

    Run the guard. If it reports a remaining violation in
    `lib/screens/exam_prep_question_list_screen.dart`, that file survived `260917-ndx` and
    still carries its header disclosure: fix it in place by rebuilding that header from the
    `answeredProgressLabel` helper created in Task 1, exactly as `question_list_screen.dart`
    was rebuilt. If `260917-ndx` deleted the file, there is nothing to fix — do not recreate
    it, and drop it from the summary's touched-files list.

    Do not widen the guard to phrases owned by sibling tasks (the browse-feature wording, or
    question-number labels). This gate asserts one invariant only: no inventory figure reaches
    the user.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/guards/bank_disclosure_guard_test.dart && flutter test</automated>
  </verify>
  <done>
    `flutter test test/guards/bank_disclosure_guard_test.dart` passes against the current tree,
    and the full `flutter test` suite is green. Manually reintroducing a bank-total
    interpolation into any `lib/` file makes the guard fail with that file and line named
    (spot-check this once, then revert the temporary edit before committing).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| app UI → end user | Rendered copy and list contents disclose proprietary content-inventory facts (how much material exists) to anyone holding the app |
| Supabase `questions` table → client | The client still fetches the full book bank to resolve which questions were answered; the payload reaches the device regardless of what the UI draws |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndq-01 | Information Disclosure | `question_list_screen.dart` progress banner and list body | medium | mitigate | Render only already-answered questions via `reviewableQuestions`, and build the banner from `answeredProgressLabel`, which structurally cannot receive a bank size (Task 1) |
| T-ndq-02 | Information Disclosure | `exam_prep_home_screen.dart` Access card copy | medium | mitigate | Replace the total and the ordinal free range with entitlement-only copy; keep the allowance constant, drop the inventory figure (Task 2) |
| T-ndq-03 | Information Disclosure | Any future `lib/` UI copy | low | mitigate | `test/guards/bank_disclosure_guard_test.dart` fails the suite on any reintroduced inventory interpolation or ordinal-range copy (Task 3) |
| T-ndq-04 | Information Disclosure | Supabase `questions` read path in `question_list_screen.dart` `_loadData` | high | accept | Hiding the bank in the UI does not hide it from a client that reads the network response or local cache. A determined user can still count rows. Proper containment needs server-side row limiting / RLS on the `questions` table, which is out of scope for a quick UI task — recorded here as the follow-up this change does not deliver |

No package-manager installs occur in this plan, so no supply-chain (`T-ndq-SC`) row applies
and no package-legitimacy checkpoint is required.
</threat_model>

<verification>
1. `cd enchiridion && flutter analyze` — no new issues.
2. `cd enchiridion && flutter test` — full suite green, including the three new/extended test files.
3. `cd enchiridion && grep -rnE '\$\{[^}]*uestions\.length' --include=*.dart lib` — no output.
4. `cd enchiridion && grep -rnE '[Qq]uestions?[[:space:]]+[0-9]+[[:space:]]*-' --include=*.dart lib` — no output.
5. Manual read-through of the touched screens confirms no remaining sentence tells the user
   how many questions exist, in total or remaining.
</verification>

<success_criteria>
- No `lib/` surface renders a question-bank total; both grep gates above return nothing.
- The library book options sheet offers no full-bank browse, and offers a review entry only
  to a user who has answered at least one question in that book.
- `QuestionListScreen` shows only already-answered questions and a count-free progress label.
- The exam prep Access card communicates the free allowance and unlock path with no total and
  no ordinal question range.
- `flutter analyze` and `flutter test` both pass from `enchiridion/`.
- No file owned by `260917-ndx` or `260917-ndt` is edited except the single conditional sweep
  described in Task 3.
</success_criteria>

<output>
Create `.planning/quick/260917-ndq-users-should-not-be-able-to-see-the-full-question-bank-for-n/260917-ndq-SUMMARY.md` when done.

The summary must record, under a clearly named heading, that T-ndq-04 was accepted rather
than mitigated: the client still downloads the full book bank, so bank size remains
recoverable from the network layer. That is the honest limit of this change and the user
should see it stated rather than inferred.
</output>
