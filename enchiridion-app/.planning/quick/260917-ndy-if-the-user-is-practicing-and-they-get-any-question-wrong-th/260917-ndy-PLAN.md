---
quick_id: 260917-ndy
phase: quick-260917-ndy
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - enchiridion/lib/models/question_review.dart
  - enchiridion/lib/services/next_question_selector.dart
  - enchiridion/lib/services/notification_service.dart
  - enchiridion/test/models/question_review_test.dart
  - enchiridion/test/services/next_question_selector_test.dart
autonomous: true
requirements: [QB-260917-NDY]

estimate:
  tokens: 56000
  raw_tokens: 28000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Answering a practice question wrong schedules that question to come back no earlier than 24 hours later."
    - "The same question is not served again by any ambient surface (exam-prep card, Quick Check prompt, bubble alarm) before its 24-hour window elapses."
    - "Once the 24-hour window elapses, the missed question is served ahead of merely-due and unseen questions."
    - "A question missed in the past but since answered correctly is still freely servable."
  artifacts:
    - enchiridion/lib/models/question_review.dart
    - enchiridion/lib/services/next_question_selector.dart
    - enchiridion/test/models/question_review_test.dart
    - enchiridion/test/services/next_question_selector_test.dart
  key_links:
    - "QuestionScreen._submit -> StorageService.recordAnswer -> QuestionReview.applyAnswer (the only path a practice answer takes)"
    - "QuestionReview.dueAt -> NextQuestionSelector.next (bucket gate) AND NextQuestionSelector._leastRecentlySeen (floor gate)"
    - "QuestionReview.dueAt -> NotificationService.scheduleFollowUp (background re-serve time)"
---

<objective>
When a user answers a practice question wrong, requeue that question to be served
no earlier than 24 hours later — instead of the current ~3-hour rebound.

Purpose: The user reported that a missed question should come back a day later, not
the same study session. The spaced-repetition machinery already exists and every
practice answer already funnels through it; this plan retimes the lapse interval and
closes the one code path that can bypass it.

Output: A wrong answer produces a review whose `dueAt` is at least 24 hours out, and
no serving surface will hand that question back before then.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
The Flutter app lives under `enchiridion/` (see CLAUDE.md). All `flutter` commands run
from that directory; all paths below are repo-relative.

@enchiridion/lib/models/question_review.dart
@enchiridion/lib/services/next_question_selector.dart
@enchiridion/test/models/question_review_test.dart
@enchiridion/test/services/next_question_selector_test.dart

**Existing architecture (already verified — do not re-derive):**

- `QuestionReview` is the source of truth for *when a question may come back*.
  `UserAnswer` (the legacy `answers_` map) only drives tick marks in question lists.
- Every practice answer reaches the ladder through exactly one path:
  `QuestionScreen._submit` -> `StorageService.recordAnswer` ->
  `StorageService.recordQuestionReview` -> `QuestionReview.applyAnswer`.
  That path is already correct; no screen or service wiring needs to change.
- `QuestionReview.applyAnswer` has a wrong-answer branch that resets `stage` to 0,
  increments `lapses`, sets `lastCorrect` false, un-retires, and sets
  `dueAt = now + _jittered(relearnInterval, rng)`. `relearnInterval` is currently
  `Duration(hours: 3)`.
- `_jittered(base, random)` is symmetric: it draws the offset from
  `[-spread, +spread)` where `spread` is 25% of `base` under 12 hours and 12% at or
  above 12 hours. Symmetric jitter on a 24-hour base would allow a due time roughly
  21 hours out, which breaks the "no earlier than 24 hours" requirement.
- `NextQuestionSelector.next` gates the lapsed/fresh/unseen buckets on
  `review.isDue(moment)`, so those three paths respect `dueAt` automatically.
- `NextQuestionSelector._leastRecentlySeen` is a floor that runs when no bucket
  yields a pick. It consults neither `dueAt` nor the cooldown — it only orders by
  `lastSeenAt`, preferring non-retired questions. With a small bank (the 10 free-tier
  questions) this floor can re-serve a just-missed question well inside its window
  once the rest of the bank has cycled past it. **This is the bypass to close.**
- All three call sites of `NextQuestionSelector.next` already handle a `null` return:
  `lib/services/bubble_alarm_callback.dart` guards with `if (question != null)`, and
  `lib/screens/exam_prep_home_screen.dart` stores it in a nullable field that renders
  an empty-state `Text` when null. Returning null from the floor is therefore safe and
  needs no screen change.

**Scope boundary:** do NOT edit `lib/screens/exam_prep_home_screen.dart`,
`lib/widgets/exam_prep/`, or `lib/services/bubble_alarm_callback.dart`. Sibling batch
items own those files; this item is independent of them by staying out.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: A wrong practice answer requeues the question a full day out</name>
  <files>enchiridion/lib/models/question_review.dart, enchiridion/test/models/question_review_test.dart, enchiridion/test/services/next_question_selector_test.dart</files>
  <read_first>
    enchiridion/lib/models/question_review.dart (whole file — the `relearnInterval`
    constant, the `applyAnswer` wrong-answer branch, and the `_jittered` helper)
  </read_first>
  <behavior>
    - Wrong answer at T: `dueAt` is at or after `T + 24h`, and within a modest jitter
      band above it (not below).
    - Wrong answer still resets `stage` to 0, increments `lapses`, sets `lastCorrect`
      false, and un-retires a previously retired question (unchanged).
    - A confident correct answer and a guessed-correct answer keep their existing
      intervals and their existing symmetric spread (unchanged).
    - End to end through storage: record a wrong answer at T, then ask
      `NextQuestionSelector.next` at `T + 23h` over a bank that also contains unseen
      questions — the missed question is NOT the pick. Ask again at `T + 25h` — the
      missed question IS the pick (the lapsed bucket outranks unseen).
  </behavior>
  <action>
    This is the thin end-to-end slice: one wrong answer, through the real storage
    path, to the real selector.

    In `enchiridion/lib/models/question_review.dart`:

    1. Retime `relearnInterval` from three hours to one day. Replace its doc comment:
       it currently explains a same-day rebound and cites a TESTING_REPORT.md note
       calling that the intended behavior. The product decision has changed — say that
       a missed question returns a full day later so the correction is re-tested in a
       fresh session rather than the same sitting, and that the scheduled time is a
       floor, never brought forward by jitter.
    2. Make the wrong-answer branch use a forward-only jitter. Keep `_jittered` as it
       is for the correct-answer paths (`guessedInterval` and `stageIntervals` must
       keep their existing symmetric spread and their existing test bands). Add a
       sibling static helper — `_jitteredForward(base, random)` — that returns
       `base + offset` where `offset` is drawn from `[0, spread)` using the same
       `spread` rule `_jittered` already applies. Call it only from the wrong-answer
       branch. Document on the helper *why* it is one-sided: the interval is a
       contract floor, and spreading only upward still prevents six misses from
       queueing six prompts for the same minute.
    3. Change nothing else in `applyAnswer` — the stage reset, lapse increment,
       `lastCorrect`, `lastSeenAt` and un-retire semantics all stay as they are.

    In `enchiridion/test/models/question_review_test.dart`, update the first test in
    the `QuestionReview.applyAnswer` group (it currently asserts the delta falls in a
    135..225 minute band) to assert the new contract: rename it to describe a
    one-day requeue, assert `delta` is greater than or equal to exactly 24 hours, and
    assert an upper bound matching the forward jitter band you implemented. Run the
    assertion in a loop of at least 50 iterations with a fresh `Random` each time so a
    one-sided draw that accidentally goes negative cannot pass by luck. Leave the
    guessed-correct test's 360..600 minute band and the ladder/retire tests untouched.

    In `enchiridion/test/services/next_question_selector_test.dart`, add the
    end-to-end test described in `<behavior>`: use `storage.recordQuestionReview` with
    a wrong `UserAnswer` answered at a fixed `now`, a bank of 5 questions, then two
    `selector.next(..., now: ...)` calls at plus-23-hours and plus-25-hours. Follow the
    file's existing `_question(int)` helper and `SharedPreferences.setMockInitialValues`
    setup. Note that `next` records each serve, so the two calls share a serve log —
    assert on the picked id, not on call count.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/models/question_review_test.dart test/services/next_question_selector_test.dart</automated>
  </verify>
  <done>
    Both test files pass. A wrong answer recorded through `StorageService` yields a
    review whose `dueAt` is at least 24 hours after the answer time across repeated
    random draws, and `NextQuestionSelector` declines to serve it at 23 hours while
    serving it at 25 hours.
  </done>
  <reversibility rating="reversible">
    A stored interval constant; changing it again only reschedules future answers, and
    already-written `dueAt` values simply elapse.
  </reversibility>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Close the least-recently-seen bypass so the floor cannot undercut the window</name>
  <files>enchiridion/lib/services/next_question_selector.dart, enchiridion/test/services/next_question_selector_test.dart</files>
  <read_first>
    enchiridion/lib/services/next_question_selector.dart (whole file — `next`,
    `_firstServable`, `_leastRecentlySeen`)
  </read_first>
  <behavior>
    - Small bank, one question missed: after the rest of the bank has been served more
      recently than the miss, the floor still does not return the missed question while
      its window is open.
    - Small bank where every alternative is exhausted and the only remaining candidate
      is inside its open window: `next` returns null rather than serving it early.
    - A question with `lapses` greater than zero but `lastCorrect` true (missed once,
      since answered correctly) is still eligible for the floor.
    - The existing single-question-bank test — which serves the same question twice in
      five minutes with no wrong answer involved — still passes unchanged.
  </behavior>
  <action>
    `_leastRecentlySeen` currently orders by `lastSeenAt` and consults neither `dueAt`
    nor the cooldown, so it is the one path that can hand back a question inside its
    requeue window.

    1. Give `_leastRecentlySeen` the current moment as a parameter (`next` already has
       it as `moment`) and pass it at the single call site.
    2. Inside the loop, skip any question whose review represents an open lapse window:
       the review's `lastCorrect` is false AND its `dueAt` is after the moment. Key the
       skip on `lastCorrect` being false, NOT on `lapses` being greater than zero —
       `lapses` is a lifetime counter, so a question missed months ago but since
       answered correctly must stay eligible.
    3. Keep the existing two-tier preference for everything that survives the skip:
       still prefer a non-retired candidate, still fall back to the least-recently-seen
       retired one. If both tiers end up empty, return null; `next` already propagates
       null and all three call sites handle it (see `<context>`).
    4. Update the class-level doc comment's numbered priority list to record the new
       floor rule — that the floor may now legitimately yield nothing when everything
       left is cooling off after a miss — and update the `cooldown` field's comment,
       which currently claims a rebound never lands in the same sitting *regardless of
       schedule*; that guarantee now comes from the lapse window, with the cooldown
       acting only as the short cross-surface spacing for everything else.

    Add the three new tests from `<behavior>` to
    `enchiridion/test/services/next_question_selector_test.dart` in the existing
    `NextQuestionSelector` group, reusing its `_question` helper. For the null case,
    the simplest construction is a one-question bank whose single question was just
    answered wrong.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/services/next_question_selector_test.dart</automated>
  </verify>
  <done>
    All tests in `next_question_selector_test.dart` pass, including the pre-existing
    cooldown-floor test. The floor never returns a question whose `lastCorrect` is
    false and whose `dueAt` has not yet elapsed.
  </done>
</task>

<task type="auto">
  <name>Task 3: Sync the rebound docs and gate the whole suite</name>
  <files>enchiridion/lib/services/notification_service.dart</files>
  <read_first>
    enchiridion/lib/services/notification_service.dart lines 24-36 (the class doc
    comment above `NotificationService`)
  </read_first>
  <action>
    The `NotificationService` class doc comment describes the wrong-answer rebound by
    its old duration while explaining why the background notification exists. Restate
    that sentence in terms of the new interval so the comment matches
    `QuestionReview.relearnInterval` again. Keep the rest of the comment — the
    `scheduleFollowUp` re-booking explanation and the pointer to
    `lib/services/bubble_alarm_callback.dart` for ambient prompts — exactly as written.

    Touch nothing else in this file: the scheduling code already reads `review.dueAt`
    and therefore books the new time with no logic change. Sibling batch item
    260917-ndz may also edit this file; confine your diff to the doc sentence.

    Then run the full analyzer and test suite to confirm no other call site or test
    assumed the old interval.
  </action>
  <verify>
    <automated>cd enchiridion && flutter analyze lib/models/question_review.dart lib/services/next_question_selector.dart lib/services/notification_service.dart && flutter test</automated>
  </verify>
  <done>
    `flutter analyze` reports no issues on the three changed source files and the full
    `flutter test` suite passes with no new failures.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| local device storage -> app logic | `SharedPreferences`-backed review rows are read back and drive scheduling; a tampered or corrupt row could alter when a question returns. |
| remote review sync -> local ladder | `QuestionReviewSyncService.pullAndMergeAll` folds server rows into the same `dueAt` field this plan retimes. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ndy-01 | Tampering | `QuestionReview.fromJson` `due_at` | low | accept | A user editing their own device's review state only shortens their own study schedule; no other user or server trust decision depends on it. Parsing already falls back to the epoch on a malformed value. |
| T-ndy-02 | Tampering | `mergeQuestionReviews` last-write-wins | low | accept | Pre-existing behavior, unchanged by this plan: a remote row with a newer `lastSeenAt` can replace a local lapse window. Same blast radius as T-ndy-01 (self-only). |
| T-ndy-03 | Denial of Service | `NextQuestionSelector._leastRecentlySeen` returning null | low | mitigate | Task 2 may now yield null; all three call sites already null-guard (bubble alarm skips, exam-prep card renders an empty-state message), so the worst case is an empty prompt, not a crash. Task 3's full-suite run gates this. |

No package-manager installs are introduced by this plan, so no package-legitimacy gate applies.
</threat_model>

<verification>
1. `cd enchiridion && flutter test` — full suite green.
2. `cd enchiridion && flutter analyze` — clean on changed files.
3. Manual spot-check (optional, on device or `flutter run`): answer an exam-prep
   question wrong, then repeatedly tap "Practice one now". The missed question must not
   reappear during that session.
</verification>

<success_criteria>
- A wrong answer in practice sets the question's `dueAt` to at least 24 hours after
  the answer, every time, across random jitter draws.
- No serving surface — exam-prep card, Quick Check prompt, or background bubble alarm —
  returns that question before its window elapses, including via the
  least-recently-seen floor.
- After the window elapses, the missed question is served ahead of merely-due and
  unseen questions (the existing lapsed-bucket priority still holds).
- Correct-answer intervals, the retire ladder, and the un-retire-on-lapse behavior are
  unchanged.
- No files outside `files_modified` are touched.
</success_criteria>

<output>
Create `.planning/quick/260917-ndy-if-the-user-is-practicing-and-they-get-any-question-wrong-th/260917-ndy-SUMMARY.md` when done.
</output>
</content>
</invoke>
