---
quick_id: 260917-ndw
type: execute
depends_on: []
files_modified:
  - .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md
  - enchiridion/test/services/next_question_selector_test.dart
  - enchiridion/lib/services/next_question_selector.dart
  - enchiridion/lib/services/storage_service.dart
autonomous: true
must_haves:
  truths:
    - FINDINGS.md states how question selection and randomization actually work today, naming the single selector entry point, its three call sites, and the four layers that currently prevent repeats.
    - A free-tier user who is served questions without answering them keeps receiving different questions instead of the same question forever.
    - A question recorded as served by the headless bubble isolate is not immediately re-served by the foreground app.
    - The six pre-existing NextQuestionSelector tests and the rest of the suite still pass.
  artifacts:
    - .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md
    - enchiridion/test/services/next_question_selector_test.dart
  key_links:
    - NextQuestionSelector.next reads and writes the shared ServeLog through StorageService, and both the foreground screens and the headless bubble isolate must observe the same persisted log.
---

<objective>
Answer how question randomization and repeat-avoidance are implemented, and repair the two repetition defects that trace uncovered.

Purpose: The user asks how repetition is prevented. Selection is already centralized in `NextQuestionSelector`, but planning-time probes proved it degenerates into serving one identical question forever for free-tier users, and that its cross-surface serve log is invisible to the headless bubble isolate.
Output: A FINDINGS.md that answers the question, plus a minimal selector/storage fix with regression tests.
</objective>

<context>
@enchiridion/lib/services/next_question_selector.dart
@enchiridion/lib/models/serve_log.dart
@enchiridion/lib/models/question_review.dart
@enchiridion/lib/services/storage_service.dart
@enchiridion/lib/services/bubble_alarm_callback.dart
@enchiridion/test/services/next_question_selector_test.dart
</context>

<planning_evidence>
Measured at planning time against the current working tree, using a throwaway test that was deleted afterwards. The executor should reproduce these, not trust them blindly, but they are the reason the two fix tasks exist.

- Baseline: `flutter test` is green (61 tests, ~16s) and `flutter analyze` on the three files above reports no issues.
- Defect A probe — free-tier bank of 10, `hasAccess: false`, 30 consecutive `next()` calls, nothing ever answered: the first 10 serves were distinct (shuffled), then `q1` was returned for all 20 remaining serves.
- Defect A boundary probe — bank sizes 10 and 12 collapse to a single repeated id after the first pass; sizes 13 and 20 keep rotating. The cliff is exactly `ServeLog.maxRecent` (12), and the free tier's `kFreeQuestionCount` is 10.
- Defect B probe — with a `StorageService` holding a `SharedPreferences` instance, a serve log written behind that instance read back as `[]`, and as `[q7]` only after `reload()`.
</planning_evidence>

<tasks>

<task type="tracer">
  <name>Task 1: Trace the serving path, write FINDINGS.md, and capture the repetition defect as a failing test</name>
  <files>.planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md, enchiridion/test/services/next_question_selector_test.dart</files>
  <read_first>Read `enchiridion/lib/services/next_question_selector.dart` in full, `enchiridion/lib/models/serve_log.dart`, the `lastSeenAt` assignments in `enchiridion/lib/models/question_review.dart`, the serve-log and review accessors in `enchiridion/lib/services/storage_service.dart` (roughly lines 430-545), and the selector call sites at `enchiridion/lib/screens/exam_prep_home_screen.dart` lines 53 and 109 and `enchiridion/lib/services/bubble_alarm_callback.dart` line 54. Also skim `enchiridion/lib/widgets/exam_prep/in_app_study_prompt_host.dart` to confirm it only re-opens a tapped notification and performs no selection of its own.</read_first>
  <action>Write FINDINGS.md at the path above with exactly these six level-2 headings, in this order: `## Answer`, `## How selection works today`, `## Repetition guarantees`, `## Defects found`, `## Fixes applied`, `## Recommended follow-ups`. Leave `## Fixes applied` as a short placeholder line for now; Task 3 fills it.

Ground every statement in the code you read. The substance to cover: selection is centralized in one place, `NextQuestionSelector.next`, with three call sites only — the exam-prep home card on load and again after an answer, and the headless Android bubble worker. True randomness is confined to a single unseeded shuffle of the unseen-question bucket; the lapsed-due and fresh-due buckets are sorted deterministically by `dueAt`, bucket order alternates on the parity of the persisted serve counter, and the final fallback is deterministic. Distinguish that question-level selection from the separate seeded shuffle of answer options in `question_screen.dart` and `quick_check_card.dart`, which is keyed on question id plus attempt count so options stay stable within one attempt. Under `## Repetition guarantees`, list the four layers that exist today: the cross-surface serve log of the most recent ids, the 90-minute cooldown measured against the review's last-seen timestamp, the spaced-repetition due dates with jitter, and the exclusion of retired questions.

Under `## Defects found`, record two defects with their reproductions. First: a serve is never stamped onto the question itself — the last-seen timestamp is written only when an answer is folded in via `applyAnswer` — so every never-answered question ties at the epoch in the least-recently-seen fallback, and the strict comparison resolves that tie to the lowest position in bank order. Whenever the unlocked bank is no larger than the serve log's capacity, every candidate gets filtered out by the recent-ids check and the fallback returns that same lowest-position question indefinitely; the free tier's ten questions always satisfy that condition. Second: the foreground app and the headless bubble isolate each hold their own cached preferences instance and nothing under `lib/` refreshes it, so a serve recorded by the bubble worker is invisible to the running app and vice versa — defeating the very cross-surface deduplication the serve log was introduced for. Note as a third, unfixed observation that review state syncs to Supabase but the serve log is device-local, so two devices can serve the same question.

Under `## Recommended follow-ups`, note for the batch: the wrong-answer relearn interval is currently 3 hours, which a sibling task wants moved to 24 hours and which lives in `question_review.dart` (untouched here); the bubble worker is the delivery path a sibling notification task will need; and hiding bank size is a question-list concern, not a selector concern.

Then add one test to the existing group in `enchiridion/test/services/next_question_selector_test.dart`, named exactly `rotates through the free-tier bank without repeating a question`. It must build a ten-question bank, call `next` with `hasAccess: false` twenty-five times with a clock that advances a minute per call, never record an answer, collect the served ids, and assert the invariant that every consecutive window of ten serves contains ten distinct ids. This test is expected to FAIL now — that failure is the evidence the defect is real. If it unexpectedly passes, stop: record under `## Defects found` that no repetition defect was reproducible, mark Tasks 2 and 3 as not applicable, and finish the item there.</action>
  <verify>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; flutter analyze --no-fatal-infos test/services/next_question_selector_test.dart</automated>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; OUT=$(flutter test test/services/next_question_selector_test.dart --plain-name "rotates through the free-tier bank without repeating" 2>&1); STATUS=$?; echo "$OUT" | tail -6; if [ "$STATUS" -eq 0 ]; then echo "GATE FAIL: the new test must fail before the fix (a zero exit here also means the name never matched)"; exit 1; fi; echo "RED confirmed"</automated>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; F="$ROOT/.planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md"; for h in "## Answer" "## How selection works today" "## Repetition guarantees" "## Defects found" "## Fixes applied" "## Recommended follow-ups"; do grep -qF "$h" "$F" || { echo "missing heading: $h"; exit 1; }; done; echo "all six sections present"</automated>
  </verify>
  <done>FINDINGS.md exists with all six sections and answers the question from code the executor actually read; the new rotation test compiles cleanly and fails for the documented reason.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Make the least-recently-seen fallback rotate instead of repeating one question</name>
  <files>enchiridion/lib/services/next_question_selector.dart</files>
  <precondition>Task 1's rotation test exists and failed, and FINDINGS.md records a reproduced repetition defect. If Task 1 instead recorded that no defect was reproducible, skip this task.</precondition>
  <behavior>
    - A free-tier bank of ten, served repeatedly with no answers, yields ten distinct ids in every consecutive window of ten serves.
    - A lapsed, due question still outranks the fallback (existing test: a question the user got wrong outranks everything else).
    - A single-question bank still returns that question rather than null (existing cooldown test).
    - Retired questions are still offered only when nothing still in rotation is available.
  </behavior>
  <action>Change `_leastRecentlySeen` so it also consults the serve log it is already given elsewhere in `next`: pass the `ServeLog` in as a parameter and rank candidates by a composite key rather than by the review timestamp alone. A candidate whose id is absent from the log's recent ids ranks ahead of any candidate present in it; among candidates present in it, the one appearing later in that list — that is, served longer ago, since the list is newest-first — ranks ahead; only then compare the review's last-seen timestamp ascending; and break any remaining tie with the injected `_random` rather than letting the first position in bank order always win. Keep the existing preference for questions still in rotation over retired ones, and keep the method returning null only when there is genuinely nothing to offer. Do not add fields to `ServeLog` and do not change its persisted JSON — the ordering already carried by the recent-ids list is sufficient, and the free tier's ten ids fit inside its twelve-slot capacity without eviction. Do not touch the bucket priority order, the cooldown constant, or `_firstServable`.</action>
  <verify>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; flutter test test/services/next_question_selector_test.dart</automated>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; flutter analyze --no-fatal-infos lib/services/next_question_selector.dart</automated>
  </verify>
  <done>All seven tests in the selector test file pass, including the previously failing rotation test, and the analyzer reports no issues on the changed file.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Let the selector see serves recorded by the headless bubble isolate</name>
  <files>enchiridion/lib/services/storage_service.dart, enchiridion/lib/services/next_question_selector.dart, enchiridion/test/services/next_question_selector_test.dart, .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md</files>
  <precondition>Task 2 is complete and the selector test file is green.</precondition>
  <behavior>
    - Given a storage instance whose cached preferences predate an external write, when a serve log naming nine of ten free-tier ids is written behind that cache, `next` returns the tenth id rather than one of the nine.
    - Every other test in the suite still passes, including the storage-service serve-log round-trip test.
  </behavior>
  <action>Add a `refreshFromDisk` method to `StorageService` that awaits the preferences object's own `reload`, with a doc comment explaining that the headless bubble worker in `bubble_alarm_callback.dart` runs in a separate isolate with its own preferences instance, so the foreground instance's in-memory cache would otherwise never observe a serve it recorded. Await it at the top of `NextQuestionSelector.next`, before the review migration and before reading the reviews and the serve log. Make that call best-effort: if it throws, swallow the error and continue with the cached values, matching how the rest of this codebase treats local state as authoritative and remote or platform calls as best-effort. Do not add a refresh call anywhere else.

Add the regression test to the same selector test file, named exactly `sees a serve recorded by another isolate`. Build the storage over a held preferences instance, then simulate the other isolate by installing fresh mock preference values that contain a serve-log entry under key `serve_log_exam_prep` listing nine of the ten free-tier question ids; note that the mock helper prefixes keys itself and replaces the backing store, so write the complete desired state in one go. Construct the selector with a seeded `Random` so the assertion is deterministic, and pick a seed for which the test fails without the refresh call — confirm that by running it once with the refresh call commented out or by temporarily stubbing it, then restore. Assert that `next` over the ten-question bank with `hasAccess: false` returns the one id absent from that serve log.

Finally, fill in the `## Fixes applied` section of FINDINGS.md: describe the fallback ranking change from Task 2 and this refresh, each with the test that now guards it, and move the cross-device serve-log limitation into `## Recommended follow-ups` as still open.</action>
  <verify>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; flutter test</automated>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; cd "$ROOT/enchiridion" || exit 1; flutter analyze --no-fatal-infos lib/services/next_question_selector.dart lib/services/storage_service.dart test/services/next_question_selector_test.dart</automated>
    <automated>ROOT=$(git rev-parse --show-toplevel) || exit 1; F="$ROOT/.planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md"; awk '/^## Fixes applied/{f=1;next} /^## /{f=0} f&&NF' "$F" | grep -q . || { echo "GATE FAIL: Fixes applied section is empty"; exit 1; }; echo "fixes recorded"</automated>
  </verify>
  <done>The full suite passes with the two new tests included, the analyzer is clean on all three changed files, and FINDINGS.md documents both fixes.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| on-device storage to app | The serve log and review ladder are read from local shared preferences, which a rooted or jailbroken device owner can edit. |
| headless isolate to foreground app | The bubble worker isolate writes the same local keys the foreground app reads. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndw-01 | Tampering | `serve_log_<scope>` in `StorageService` | low | accept | The log only influences which practice question appears next. Grading, points, and entitlement are computed elsewhere, and `ServeLog.fromJson` already degrades to an empty log on malformed input. |
| T-ndw-02 | Denial of service | `refreshFromDisk` on the serving path | low | mitigate | The refresh is one local read per serve and is wrapped so a platform failure falls back to cached values instead of blocking the question. |
| T-ndw-03 | Information disclosure | FINDINGS.md | low | accept | Records selector behavior and file paths only; no credentials, keys, or user data. |

No package-manager installs are introduced by this item, so no package-legitimacy checkpoint applies.
</threat_model>

<verification>
The RED gate in Task 1 proves the repetition defect is real before anything is changed; Tasks 2 and 3 turn it green and then run the whole suite, which also guards the six pre-existing selector tests and the storage-service serve-log round trip.
</verification>

<success_criteria>
FINDINGS.md answers how randomization and repeat-avoidance are implemented, names the defects that made repeats possible, and the suite is green with regression tests covering free-tier rotation and cross-isolate serve visibility.
</success_criteria>

<output>
Create `.planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/260917-ndw-SUMMARY.md` when done
</output>
