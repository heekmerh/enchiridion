---
phase: quick-260917-ndy
plan: 01
quick_id: 260917-ndy
subsystem: exam-prep
tags: [flutter, spaced-repetition, question-selection]
requires: []
provides:
  - Wrong answers requeue at least one day after the answer.
  - The selector floor excludes questions inside an open lapse window.
affects: [practice, quick-check, bubble-alarm, notifications]
actuals:
  tokens: 3590
  tasks: 3
  commits: 0
plan_head_before: 13e92932c2ee0cf2c2fdf83fd6773be2560590aa
tech-stack:
  added: []
  patterns: [forward-only jitter for minimum review intervals]
key-files:
  created: []
  modified:
    - enchiridion/lib/models/question_review.dart
    - enchiridion/lib/services/next_question_selector.dart
    - enchiridion/lib/services/notification_service.dart
    - enchiridion/test/models/question_review_test.dart
    - enchiridion/test/services/next_question_selector_test.dart
key-decisions:
  - Keep the existing 12% jitter spread, but apply it only after the one-day minimum for wrong answers.
  - Test serving at the recorded dueAt because forward jitter can extend beyond 25 hours.
requirements-completed: [QB-260917-NDY]
coverage:
  - id: D1
    description: A wrong answer is due no earlier than 24 hours later and retains lapse state.
    verification:
      - kind: unit
        ref: test/models/question_review_test.dart#a wrong answer resets to stage 0 and requeues no sooner than a day
        status: pass
    human_judgment: false
  - id: D2
    description: A missed question waits until due and then outranks unseen questions.
    verification:
      - kind: integration
        ref: test/services/next_question_selector_test.dart#a stored miss waits a full day then outranks unseen questions
        status: pass
    human_judgment: false
  - id: D3
    description: The selector floor never serves an open lapse window and permits later-correct answers.
    verification:
      - kind: unit
        ref: test/services/next_question_selector_test.dart#floor skips a missed question while its lapse window is open
        status: pass
      - kind: unit
        ref: test/services/next_question_selector_test.dart#returns null if the only question is inside its lapse window
        status: pass
      - kind: unit
        ref: test/services/next_question_selector_test.dart#floor can serve a past miss that was since answered correctly
        status: pass
    human_judgment: false
duration: 9min
completed: 2026-09-17
status: complete
---

# Quick 260917-ndy Summary

Wrong practice answers now schedule their next review at least 24 hours later, and the selector's fallback respects that deadline.

## Accomplishments

- Changed the wrong-answer interval to one day with forward-only jitter; correct-answer jitter and ladder behavior remain unchanged.
- Excluded open lapse windows from the least-recently-seen floor, including when it must return null. A question answered correctly after an earlier miss remains eligible.
- Updated the notification scheduling comment and added regression tests for storage-to-selector behavior and the floor cases.

## Verification

- `flutter test --no-pub` — passed, 80 tests.
- `flutter analyze --no-pub lib/models/question_review.dart lib/services/next_question_selector.dart lib/services/notification_service.dart` — passed, no issues.
- `git diff --check` — passed.
- Repository-wide `flutter analyze --no-pub` — reported 10 pre-existing warnings and info notices in untouched files; none were in the changed source files. No out-of-scope files were edited.

## Deviations from Plan

- The plan asked the storage-to-selector test to expect a missed question at T+25h. Its required 12% forward jitter can place `dueAt` as late as about T+26h53m, so that expectation would be nondeterministic. The test checks exclusion at T+23h and priority exactly at the stored `dueAt`.
- Updated two old test times that assumed the three-hour interval, and corrected comments that would otherwise describe the new timing inaccurately.

## Commit Status

No commits were created. Staging failed because the shared Git metadata is read-only in this sandbox:

`fatal: Unable to create '/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/.git/worktrees/agent-260917-ndy/index.lock': Read-only file system`

The five source and test changes and this summary remain in the specified worktree for the coordinator to commit.

## Self-Check: PASSED

All five changed files and this summary exist in the specified worktree. Targeted and full Flutter tests pass; changed-source analysis is clean. Git commit creation is deferred as directed above.
