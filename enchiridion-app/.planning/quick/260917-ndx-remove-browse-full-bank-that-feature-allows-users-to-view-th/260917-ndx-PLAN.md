---
phase: 260917-ndx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/test/screens/exam_prep_home_screen_test.dart
  - TESTING_REPORT.md
files_deleted:
  - enchiridion/lib/screens/exam_prep_question_list_screen.dart
autonomous: true
requirements: [260917-ndx]

estimate:
  tokens: 46000
  raw_tokens: 23000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - A user on the Exam Prep home screen has no affordance that opens a list of the whole question bank.
    - A free user still sees the Access card and its Unlock path.
    - A user can still start a question from the Quick Check "Practice one now" affordance.
    - The app still compiles with zero analyzer errors after the screen is deleted.
  artifacts:
    - enchiridion/lib/screens/exam_prep_home_screen.dart (Access card with no bank-browsing button)
    - enchiridion/test/screens/exam_prep_home_screen_test.dart (regression guard)
  key_links:
    - ExamPrepHomeScreen is the ONLY caller of the deleted list screen — deleting the import and the button orphans the file completely.
    - library_screen.dart -> ExamPrepHomeScreen remains the single entry into Exam Prep and must keep working.
---

<objective>
Remove the "Browse Full Bank" capability from Exam Prep: delete the button on the Exam Prep
home screen and delete the now-orphaned whole-bank list screen it opened. A user must no
longer have any route that pages through the entire question bank.

Purpose: the whole-bank list exposed every question row (including locked ones, with a
truncated preview of the question text) to every user. Product decision: users do not get to
see the bank.
Output: one deleted screen file, a restructured Access card, a widget regression guard, and a
corrected TESTING_REPORT.md reference.
</objective>

<scope_boundary>
**IN scope — delete these:**
- `enchiridion/lib/screens/exam_prep_question_list_screen.dart` (the whole-bank list: search box,
  "Due for review" filter, one row per question, locked rows included)
- The `FilledButton.icon` on the Exam Prep home Access card that pushes it, plus its import.

**OUT of scope — do NOT touch:**
- `enchiridion/lib/screens/question_list_screen.dart` — a DIFFERENT, book-scoped screen reached
  from `library_screen.dart:159` for an individual book. It is not the exam-prep bank browser.
  Leave it alone.
- The Quick Check / "Practice one now" flow, `NextQuestionSelector`, `QuestionScreen`,
  `StudyStatsService`, and the notification/bubble paths. Session-based question serving stays
  exactly as it is.
- The Access card **subtitle** text (`'All N questions are unlocked.'` /
  `'Questions 1-N are free...'`). It leaks the bank size, but that is sibling batch item
  **260917-ndq / 260917-ndt**'s job. Changing it here creates a pointless merge conflict.
- The `_StudyCard` / `_StudyCardState` dead code at the bottom of the home screen file. It is
  unreferenced and carries a pre-existing `unused_element_parameter` warning, but sibling items
  260917-ndv and 260917-ne0 are reworking this screen. Leave it; the verify gate ignores
  warnings and checks analyzer **errors** only.

**Do NOT confuse this removal with sibling item 260917-nds.**
Item 260917-nds asks for a *filtered* review view reached by tapping Answered / Correct / Wrong
on the stats dashboard — questions the user has **already answered**, so they can retry the ones
they failed. That is a narrower, different feature: it is scoped to the user's own answer
history, never shows unanswered or locked questions, and is reached only from the stats tiles.
Removing the full-bank browser here does **not** forbid that. Whoever executes 260917-nds must
build a new history-filtered screen and must NOT restore the deleted
`ExamPrepQuestionListScreen` to do it.
</scope_boundary>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/screens/exam_prep_question_list_screen.dart
@enchiridion/test/screens/question_screen_test.dart
@enchiridion/test/screens/reader_screen_test.dart
</context>

<interface_context>
Facts established by reading the code — the executor should not need to rediscover these:

- The Flutter app root is `<repo root>/enchiridion/`. All `flutter` commands run from there.
- `ExamPrepQuestionListScreen` is referenced from exactly ONE place in the repo:
  `enchiridion/lib/screens/exam_prep_home_screen.dart` (import at line 16, construction at
  line 195). Nothing else in `lib/`, `test/`, or `integration_test/` mentions it.
- `ExamPrepHomeScreen` is reached only from `enchiridion/lib/screens/library_screen.dart:580`
  (the "Exam Prep" resource card).
- `_ExamMetricCard` is a private widget in the home screen file with
  `{required String title, required String subtitle, required Widget child}` and three call
  sites: Daily Performance, Access, Quick Check.
- Test conventions already in this repo:
  - `SharedPreferences.setMockInitialValues({})` then `StorageService(prefs)` and
    `Provider<StorageService>.value(...)` — see `test/screens/question_screen_test.dart`.
  - `AccessService.testAccessOverride` (a `static bool?`) short-circuits
    `hasExamPrepAccess()` — see `lib/services/access_service.dart:15,82`.
  - Widget tests must avoid `rootBundle`; the established pattern is a constructor-injected
    test override, e.g. `ReaderScreen.testBookProvider`
    (`lib/screens/reader_screen.dart:37,45,50`). The header comment of
    `test/screens/reader_screen_test.dart` explains why (`ui.ImmutableBuffer.fromAsset`
    bypasses binary-messenger mocks in Flutter 3.19+).
- `kStandaloneExamPrepScope` is `'exam_prep'`, declared in `lib/models/resource_topic.dart:28`.
- `Question` has a const constructor: `Question(id:, questionText:, options:, correctOption:,
  explanation:, questionNumber:)`.
- `NextQuestionSelector(storage).next({bank:, hasAccess:})` returns `Future<Question?>` and may
  legitimately return `null`.
- `NotificationService.scheduleFollowUp` early-returns when `!_initialized`, so it is inert in
  widget tests.
- Analyzer baseline, measured before this plan: `flutter analyze lib` reports 8 issues, **zero
  of severity `error`**. Two of those warnings live in the files this plan touches
  (`exam_prep_home_screen.dart` `unused_element_parameter`, and two `unnecessary_cast` in
  `exam_prep_repository.dart`). Gates below therefore check for `error` only.
- `flutter test test/screens/question_screen_test.dart` passes today (verified).
</interface_context>

<tasks>

<task type="tracer">
  <name>Task 1: Remove the bank-browsing entry point end to end</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/lib/screens/exam_prep_question_list_screen.dart</files>
  <action>
In `enchiridion/lib/screens/exam_prep_home_screen.dart`:

1. Delete the `import 'exam_prep_question_list_screen.dart';` line.
2. In the "Access" `_ExamMetricCard`, delete the `Expanded(child: FilledButton.icon(...))`
   entry that navigates to the deleted screen, including its `Icons.list_alt_outlined` icon
   and its label. Keep the card's `title` and `subtitle` byte-for-byte unchanged.
3. The Access card's `child` is now a `Row` whose only remaining member is the free-user
   `OutlinedButton` that pushes `UnlockScreen`, and which is empty for a user who already has
   access. Fix that so the card renders cleanly rather than leaving a zero-height Row and its
   preceding spacer:
   - Relax `_ExamMetricCard.child` from `required Widget child` to a nullable `Widget? child`.
   - In `_ExamMetricCard.build`, emit the `SizedBox(height: 14)` spacer and `child` only when
     `child != null`.
   - Pass `child: _hasAccess ? null : OutlinedButton(...)` from the Access card, dropping the
     `Row` and `SizedBox(width: 10)` wrappers — the Unlock button now stands alone.
   - The Daily Performance and Quick Check call sites keep passing a non-null child unchanged.
4. Do not touch `_handleStudyCardAnswer`, `_StudyCard`, `_optionSeedFor`, `_load`, or the
   Quick Check card.

Then delete the file `enchiridion/lib/screens/exam_prep_question_list_screen.dart` with
`git rm`. Nothing else in the repo references it, so no other call site needs repair; any
missed reference will surface as an analyzer error in the gate below.

Commit this task on its own so the removal is a single reviewable change.
  </action>
  <verify>
    <automated>test ! -e enchiridion/lib/screens/exam_prep_question_list_screen.dart && cd enchiridion && ! flutter analyze lib 2>&1 | grep -q 'error •'</automated>
  </verify>
  <done>
The whole-bank list screen file no longer exists, `flutter analyze lib` reports zero
`error`-severity issues (warnings/infos unchanged from the 8-issue baseline), and the Exam Prep
home screen's Access card renders title + subtitle, plus an Unlock button for free users only.
  </done>
  <reversibility rating="reversible">Deleting a screen file and a button is a git revert away; no data model, storage key, or persisted state changes.</reversibility>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add a test hook and a widget regression guard</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/test/screens/exam_prep_home_screen_test.dart</files>
  <behavior>
    - Free user (`AccessService.testAccessOverride = false`), injected 25-question bank: the
      Exam Prep home builds and shows the `Exam Prep` app-bar title and the
      `Daily Performance`, `Access`, and `Quick Check` card titles.
    - Free user: an `Unlock` button is present on the Access card.
    - Free user: no affordance that opens the whole bank — the removed button's label finds
      nothing, and `Icons.list_alt_outlined` finds nothing anywhere in the tree.
    - Paid user (`testAccessOverride = true`), same injected bank: the screen still builds and
      shows all three card titles, there is no `Unlock` button, and again no bank-browsing
      affordance.
    - Neither case reaches `rootBundle`, Supabase, or a platform channel.
  </behavior>
  <action>
First, add the test-injection hook to `ExamPrepHomeScreen`, mirroring
`ReaderScreen.testBookProvider`:

- Add a `final List<Question>? testQuestions;` field with a doc comment saying it is a
  widget-test seam and that production always passes null so the bundled asset is loaded.
- Accept it in the const constructor as an optional named parameter; keep
  `const ExamPrepHomeScreen({super.key})` working for the existing `library_screen.dart` call
  site.
- In `_load`, source the bank from the override when present, otherwise from
  `_repository.loadQuestions()` as today. Everything downstream of that line is unchanged.

Then create `enchiridion/test/screens/exam_prep_home_screen_test.dart` implementing the
behaviors above. Use the repo's existing harness shape from
`test/screens/question_screen_test.dart`: `SharedPreferences.setMockInitialValues({})` in
`setUp`, build a `StorageService` from the resulting prefs, wrap the screen in
`MultiProvider(providers: [Provider<StorageService>.value(value: storage)])` inside a
`MaterialApp`, and `await tester.pumpAndSettle()` after pumping (the screen loads
asynchronously and shows a `CircularProgressIndicator` first).

Build the injected bank with the const `Question` constructor — 25 entries with sequential
`questionNumber` values 1..25 so the free/paid split at `kFreeQuestionCount` is actually
exercised.

Set `AccessService.testAccessOverride` per test and reset it to `null` in `tearDown` so the
static does not leak into other test files.

Assert the card titles positively before asserting the absences — an absence-only test would
still pass if the screen failed to build at all. Do not assert on the Quick Check *button*:
`NextQuestionSelector.next()` may return null and the card then renders an explanatory
message instead; assert on the `Quick Check` card title, which is present either way.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/exam_prep_home_screen_test.dart</automated>
  </verify>
  <done>
`flutter test test/screens/exam_prep_home_screen_test.dart` passes with both the free-user and
paid-user cases green, proving the Exam Prep home still renders its three cards and the Unlock
path while offering no route into the full bank.
  </done>
</task>

<task type="auto">
  <name>Task 3: Correct the now-dangling TESTING_REPORT.md references</name>
  <files>TESTING_REPORT.md</files>
  <action>
`TESTING_REPORT.md` has a section headed
`### Exam prep should not show the full question bank to free users` whose three bullets cite
`lib/screens/exam_prep_question_list_screen.dart` at specific line ranges (`207-236`, `76-82`).
That file no longer exists, so those citations are now dangling.

Rewrite only that section's bullets to record the current state: the whole-bank browser and its
entry point were removed under batch item 260917-ndx, so there is no longer any UI that lists
the bank. Keep the section heading unchanged. Keep the remaining open product question — that
the Access card subtitle still discloses the total question count — stated as the outstanding
work, since sibling items 260917-ndq and 260917-ndt own it.

**Write the replacement bullets without naming the deleted source file's path or basename.**
Refer to it descriptively ("the Exam Prep whole-bank list screen") and cite only files that
still exist, such as `lib/screens/exam_prep_home_screen.dart`. A dangling path is exactly what
this task exists to remove, and the gate below fails if the old path survives anywhere in the
document — including inside the replacement prose.

Do not reword, reorder, or renumber any other section of the file, and do not touch the
`### Exam Prep` request list further down (that list is the batch's own input, mirrored in
BATCH.json). `TESTING_REPORT.md` already has uncommitted changes and several sibling batch
items will edit it; keeping this diff to one section is what keeps the merge clean.
  </action>
  <verify>
    <automated>! grep -q 'exam_prep_question_list_screen' TESTING_REPORT.md && grep -q '260917-ndx' TESTING_REPORT.md && test ! -e enchiridion/lib/screens/exam_prep_question_list_screen.dart</automated>
  </verify>
  <done>
`TESTING_REPORT.md` no longer cites the deleted file, names 260917-ndx as the change that
removed the browser, and still carries the open count-disclosure item for its sibling tasks.
No other section of the file is modified (confirm with `git diff TESTING_REPORT.md`).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| free user -> bundled question asset | The whole bank ships inside the app asset; the UI is the only thing deciding what a non-paying user is shown. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndx-01 | Information Disclosure | `ExamPrepQuestionListScreen` row builder | medium | mitigate | Task 1 deletes the screen. It listed every question including locked rows, and locked rows rendered a truncated preview of the real question text — a free user could read paid content without answering it. |
| T-ndx-02 | Information Disclosure | Exam Prep Access card subtitle | low | transfer | The subtitle still prints the total bank size. Out of scope here; owned by sibling items 260917-ndq and 260917-ndt and recorded as open in TESTING_REPORT.md by Task 3. |
| T-ndx-03 | Information Disclosure | bundled `assets/data/exam_prep_questions.json` | medium | accept | The full bank is client-side and extractable from the APK regardless of UI. Removing the browser raises the bar for a casual user; a determined one is not stopped. Server-side gating is a separate architectural decision, not a quick-batch item. |

No package-manager installs are performed by this plan, so no supply-chain (`T-ndx-SC`)
legitimacy gate applies.
</threat_model>

<verification>
Run from the repo root:

```
test ! -e enchiridion/lib/screens/exam_prep_question_list_screen.dart
cd enchiridion && flutter analyze lib 2>&1 | grep -c 'error •'   # expect 0
cd enchiridion && flutter test test/screens/exam_prep_home_screen_test.dart
cd enchiridion && flutter test                                    # full suite, no new failures
git diff --stat                                                   # expect only the 4 declared paths
```

Warnings and infos from `flutter analyze` are expected — the measured baseline is 8 issues with
zero errors, and this plan deliberately does not clean up the unrelated ones.
</verification>

<success_criteria>
- No file under `enchiridion/lib/` constructs or imports a whole-bank question list for Exam Prep.
- `enchiridion/lib/screens/exam_prep_question_list_screen.dart` is deleted from the working tree
  and from git.
- `flutter analyze lib` reports zero `error`-severity issues.
- `flutter test` passes, including the new `test/screens/exam_prep_home_screen_test.dart`.
- The Exam Prep home screen still renders Daily Performance, Access, and Quick Check, still
  offers Unlock to free users, and still starts a question from Quick Check.
- `enchiridion/lib/screens/question_list_screen.dart` (the per-book list) is untouched.
- `TESTING_REPORT.md` carries no reference to the deleted file.
</success_criteria>

<output>
Create `.planning/quick/260917-ndx-remove-browse-full-bank-that-feature-allows-users-to-view-th/260917-ndx-SUMMARY.md` when done.
</output>
