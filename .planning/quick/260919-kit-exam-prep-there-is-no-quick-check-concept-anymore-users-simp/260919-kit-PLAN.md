---
quick_id: 260919-kit
batch: 260919-kir
phase: quick-260919-kit
plan: 01
type: execute
wave: 2
depends_on: [260919-kiu, 260919-kiv]
files_modified:
  - enchiridion/lib/screens/exam_prep_home_screen.dart
  - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
  - enchiridion/lib/services/notification_service.dart
  - enchiridion/lib/services/bubble_alarm_callback.dart
  - enchiridion/test/screens/exam_prep_home_screen_test.dart
  - enchiridion/test/guards/retired_quick_check_copy_guard_test.dart
autonomous: true
requirements: [260919-kit]

estimate:
  tokens: 45000
  raw_tokens: 30000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - Exam Prep home shows a card titled "Mock Exam" whose primary action reads "Start Mock Exam"; the retired label appears nowhere on that screen.
    - The ambient single-question surfaces (bubble card, scheduled notification, bubble alarm payload) name themselves accurately as a practice question — not as a mock exam and not with the retired label.
    - No non-comment Dart line under `lib/` contains the retired label outside the two retained internal identifiers.
    - The existing exam-prep widget tests pass against the new copy rather than asserting the retired label.
  artifacts:
    - enchiridion/lib/screens/exam_prep_home_screen.dart
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
    - enchiridion/lib/services/notification_service.dart
    - enchiridion/lib/services/bubble_alarm_callback.dart
    - enchiridion/test/guards/retired_quick_check_copy_guard_test.dart
  key_links:
    - Home screen card title -> the two `find.text` assertions in exam_prep_home_screen_test.dart (they break if the title changes without the test).
    - Guard test -> scans `lib/` only, skipping comment lines and the retained `QuickCheckCard` / `quick_check_card` identifiers, so it cannot self-invalidate.
---

<objective>
Retire the "Quick Check" concept from user-facing exam-prep copy. The Exam Prep home
card is the mock-exam entry point and must say so; the ambient one-question surfaces
must stop using the retired label while still describing themselves truthfully.

Purpose: The product no longer has a "Quick Check" concept — users take a mock exam.
Stale copy misdescribes the feature.
Output: Updated copy in four `lib/` files, an updated widget test, and a repo-wide
guard test registering the invariant.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@enchiridion/lib/screens/exam_prep_home_screen.dart
@enchiridion/lib/widgets/exam_prep/quick_check_card.dart
@enchiridion/test/guards/bank_disclosure_guard_test.dart

**Repo layout:** the Flutter app is the NESTED `enchiridion/` directory inside this
repo root. Every path in this plan is repo-root-relative. All Flutter commands run
from `enchiridion/`.

**Two distinct surfaces — do not give them the same copy:**

1. *Mock exam entry point* — the Exam Prep home card. Its button pushes a
   `QuestionScreen` wired with `onRequestNext`, so the user answers question after
   question. This genuinely IS the mock exam. It gets mock-exam copy.
2. *Ambient one-question surfaces* — the Android bubble card, the scheduled
   follow-up notification, and the bubble alarm payload. These serve exactly ONE
   question. Calling them a mock exam would be false copy. They get accurate
   single-question copy instead.

**Retained internal identifiers (do NOT rename — out of scope per the task
constraint, which limits changes to user-visible strings):** the `QuickCheckCard`
class, the `quick_check_card.dart` filename and its import in `lib/bubble_main.dart`,
`NOTIFICATION_CHANNEL_ID`, and `UNIQUE_WORK_NAME`.

**Sibling-owned, do NOT touch:** answer counting/tracking logic (item 260919-kiu),
the post-answer auto-advance timer and Next affordance (item 260919-kis), and
option-shuffle label assignment (item 260919-kiv). This plan changes copy only.
</context>

<tasks>

<!-- planner-discipline-allow: Quick Check -->
<!-- The task description itself names the retired label, so the string is
     unavoidable in this plan. Both gates below exempt comment lines and the two
     retained identifiers, so no gate is self-invalidating. -->

<task type="tracer" tdd="true">
  <name>Task 1: Exam Prep home card becomes the Mock Exam entry point</name>
  <files>enchiridion/lib/screens/exam_prep_home_screen.dart, enchiridion/test/screens/exam_prep_home_screen_test.dart</files>
  <behavior>
    - The Exam Prep home screen renders a card titled "Mock Exam"; a search for the retired title finds nothing.
    - The card's primary action is labelled "Start Mock Exam".
    - Both the free-user and paid-user widget tests still find exactly one card title and still assert no bank-browsing affordance.
  </behavior>
  <read_first>
    enchiridion/lib/screens/exam_prep_home_screen.dart — the `_ExamMetricCard` at the
    third position in the `ListView` (title/subtitle/child around lines 257-291), the
    `_serveNextQuestion` doc comment (around line 124), and the unreferenced
    `_StudyCard` / `_StudyCardState` classes (around lines 392-545).

    enchiridion/test/screens/exam_prep_home_screen_test.dart — the two `find.text`
    card-title assertions (around lines 77 and 97) and the file header comment.
  </read_first>
  <action>
    Update the third `_ExamMetricCard` on the Exam Prep home screen so it describes a
    mock exam:

    - `title:` becomes `Mock Exam`.
    - `subtitle:` becomes: Take a mock exam drawn from your unlocked questions. Your answers feed the performance stats above.
      (Drop the old sentence about short prompts appearing at random study intervals —
      that described the ambient surface, not this card.)
    - The null-question empty state becomes: No unlocked questions are available yet.
      (It must no longer contain the hyphenated lowercase form of the retired label.)
    - The `OutlinedButton.icon` label becomes `Start Mock Exam`, and its `icon:`
      changes from `Icons.bolt_outlined` to `Icons.quiz_outlined` — the bolt glyph
      reads as "quick/instant", which is the framing being retired.

    Delete the `_StudyCard` and `_StudyCardState` classes entirely. They are
    unreferenced dead code (nothing in `lib/` or `test/` constructs `_StudyCard`; only
    its own declaration sites match) and they carry a second copy of the retired
    label. Before deleting, confirm non-reference by searching the repo for
    `_StudyCard`; if anything outside those declaration sites references it, do NOT
    delete — update its label string to `Mock Exam` instead and say so in the summary.
    After deletion `flutter analyze` must stay clean, which also proves the class was
    unused.

    Update the `_serveNextQuestion` doc comment, which cross-references the old button
    label in quotes, to name the new button label instead — otherwise it points at a
    label that no longer exists. Leave every other comment and identifier in this file
    alone.

    In the widget test, change both card-title assertions to match the new title, and
    refresh the file header comment that lists the three cards. Do not alter the
    assertions about the Unlock button or the absent bank-browsing affordance.

    Do NOT modify the metric pills, `StudyStatsProvider` usage, `_handleStudyCardAnswer`,
    or `NextQuestionSelector` wiring — counting is sibling item 260919-kiu's and
    advancing is 260919-kis's.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/screens/exam_prep_home_screen.dart && flutter test test/screens/exam_prep_home_screen_test.dart test/screens/exam_prep_home_screen_stats_test.dart</automated>
  </verify>
  <done>Both exam-prep home widget test files pass; the home screen card reads Mock Exam with a Start Mock Exam action; `_StudyCard` is gone and analyze is clean.</done>
</task>

<task type="auto">
  <name>Task 2: Ambient one-question surfaces drop the retired label</name>
  <files>enchiridion/lib/widgets/exam_prep/quick_check_card.dart, enchiridion/lib/services/notification_service.dart, enchiridion/lib/services/bubble_alarm_callback.dart</files>
  <action>
    Replace the retired label in the three ambient single-question surfaces with
    `Practice Question`. These surfaces each serve exactly one question, so they must
    NOT be relabelled as a mock exam — that would be inaccurate copy.

    - `quick_check_card.dart`: the heading `Text` near the top of the `Scaffold` body
      (around line 106). Leave the sentence beneath it ("Answer one short question,
      then get back to what you were doing.") unchanged — it is already accurate and
      does not name the retired concept.
    - `notification_service.dart`: the `title:` argument passed to
      `_plugin.zonedSchedule` inside `scheduleFollowUp` (around line 143). Do not touch
      `_channelId`, `_channelName`, or `_channelDescription` — those are already
      neutral ("Exam prep reviews") and the channel id is an internal identifier.
    - `bubble_alarm_callback.dart`: the `title` entry in the map passed to the
      `showBubble` platform-channel invocation (around line 93).

    Leave the `QuickCheckCard` class name, the filename, and the import in
    `lib/bubble_main.dart` untouched — the task constraint scopes this item to
    user-visible strings, not identifiers.

    Do NOT touch the option-order shuffle (`_optionOrder`, the `Random(seed)` call) or
    the option letter avatar in `quick_check_card.dart` — that is sibling item
    260919-kiv's territory.

    Android native strings are deliberately OUT OF SCOPE for this item: the task
    constraint scopes the search to the nested `enchiridion/lib/` tree, the
    `BubblePlugin.kt` title is only a fallback that Dart always overrides, and the
    notification-channel display name is guarded by an early return when the channel
    already exists, so renaming it would reach fresh installs only and is a channel
    migration decision rather than a copy tweak. Record this in the summary as a
    follow-up candidate — do not silently omit it.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/widgets/exam_prep/quick_check_card.dart lib/services/notification_service.dart lib/services/bubble_alarm_callback.dart && flutter test test/services/notification_service_test.dart test/android/bubble_entrypoint_wiring_test.dart</automated>
  </verify>
  <done>All three ambient surfaces read Practice Question; the notification-service and bubble-wiring tests pass; analyze is clean.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Register a repo-wide guard for the retired label</name>
  <files>enchiridion/test/guards/retired_quick_check_copy_guard_test.dart</files>
  <behavior>
    - The guard reports zero violations against the tree as left by Tasks 1 and 2.
    - The guard would report a violation if the retired label were reintroduced into a non-comment `lib/` Dart line.
    - The guard tolerates the retained `QuickCheckCard` identifier and the `quick_check_card.dart` import in `lib/bubble_main.dart`.
  </behavior>
  <read_first>
    enchiridion/test/guards/bank_disclosure_guard_test.dart — mirror its structure
    exactly: the `_Violation` value class with a `path:line — "match"` `toString`, the
    `_scanLib()` helper walking `Directory('lib').listSync(recursive: true)` filtered to
    `.dart` files, the `line.trim().startsWith('//')` skip, and the single `test(...)`
    asserting `violations` `isEmpty` with a joined-violations `reason`.
  </read_first>
  <action>
    Create a new guard following the `bank_disclosure_guard_test.dart` pattern, asserting
    one invariant: no non-comment line under `lib/` carries the retired exam-prep label.

    Detection: a case-insensitive `RegExp` matching the word quick followed by an
    optional single space, hyphen, or underscore, then the word check.

    Exemptions, applied per line before matching:
    - Skip lines whose trimmed form starts with `//` (the analog's rule — needed
      because several retained doc comments still narrate the feature's history).
    - Skip lines containing the retained class identifier `QuickCheckCard`.
    - Skip lines containing the retained filename fragment `quick_check_card`.

    Scope the scan to `lib/` only, never `test/` — the detection literals live in this
    very file, so scanning `test/` would make the gate permanently fail for the wrong
    reason. Carry that rationale in the file header comment, as the analog does.

    Verify the guard has teeth before finishing: temporarily reintroduce the label into
    a non-comment `lib/` line, confirm the guard fails and names that path and line,
    then revert the temporary edit and confirm it passes again.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/guards/retired_quick_check_copy_guard_test.dart && flutter analyze && flutter test</automated>
  </verify>
  <done>The new guard passes, the full suite passes, and analyze is clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | Copy-only change. No new input crosses any boundary; no parsing, network, storage, or auth path is modified. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kit-01 | Information Disclosure | New user-facing copy strings | low | mitigate | Replacement copy states no question-bank totals or counts; the existing `bank_disclosure_guard_test.dart` runs in the full suite (Task 3) and fails if it does. |
| T-kit-02 | Tampering | Dependencies | low | accept | No package-manager install occurs in this plan; no new or changed dependency. |
</threat_model>

<verification>
Run from the repo root — the negative gate that proves the label is gone from the app
tree. It filters comment lines and the two retained identifiers, so it matches only
live code. It reports 5 before this plan and must report 0 after:

```
grep -rniE "quick.?check" enchiridion/lib/ --include="*.dart" \
  | grep -vE "^[^:]+:[0-9]+:[[:space:]]*(//|///|\*)" \
  | grep -v "QuickCheckCard" \
  | grep -v "quick_check_card" \
  | wc -l
```

Then, from `enchiridion/`: `flutter analyze` clean and `flutter test` green.
</verification>

<success_criteria>
- The repo-root gate above reports 0.
- `cd enchiridion && flutter analyze` reports no issues.
- `cd enchiridion && flutter test` passes, including the new guard.
- Exam Prep home reads "Mock Exam" / "Start Mock Exam"; the three ambient surfaces read "Practice Question".
- No change to counting logic, auto-advance behavior, or option-shuffle labelling.
- The summary records the deliberately-deferred Android native strings.
</success_criteria>

<output>
Create `.planning/quick/260919-kit-exam-prep-there-is-no-quick-check-concept-anymore-users-simp/260919-kit-SUMMARY.md` when done.
</output>
