---
quick_id: 260917-ndw
phase: quick
plan: 260917-ndw
subsystem: exam-prep
tags: [flutter, shared_preferences, question-selection, spaced-repetition]
requires: []
provides:
  - Code-grounded explanation of question serving and repeat avoidance
  - Free-tier rotation when questions are served without answers
  - Cross-isolate serve-log visibility before selection
affects: [exam-prep, android-bubble]
tech-stack:
  added: []
  patterns: [serve-log recency fallback, best-effort preferences reload]
key-files:
  created:
    - .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/FINDINGS.md
    - .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement/260917-ndw-SUMMARY.md
  modified:
    - enchiridion/lib/services/next_question_selector.dart
    - enchiridion/lib/services/storage_service.dart
    - enchiridion/test/services/next_question_selector_test.dart
key-decisions:
  - Use the existing newest-first ServeLog order to rank fallback candidates without changing persisted JSON.
  - Reload preferences once at the selector entry point and use cached values if reload fails.
requirements-completed: []
coverage:
  - id: D1
    description: Free-tier serves rotate through all ten questions without answers.
    verification:
      - kind: unit
        ref: test/services/next_question_selector_test.dart#rotates through the free-tier bank without repeating a question
        status: pass
    human_judgment: false
  - id: D2
    description: The selector sees a serve written behind a held preferences cache.
    verification:
      - kind: unit
        ref: test/services/next_question_selector_test.dart#sees a serve recorded by another isolate
        status: pass
    human_judgment: false
  - id: D3
    description: FINDINGS.md explains the selector, safeguards, defects, and remaining limits.
    verification:
      - kind: other
        ref: six required section headings checked against FINDINGS.md
        status: pass
    human_judgment: true
    rationale: Accuracy and clarity of the explanation require reading it against the code.
actuals:
  tasks: 3
  commits: 0
commits: 0
plan_head_before: ef6d7eae1fec9107204cf4b68b7b9bab5ba9be7d
duration: 5 min
completed: 2026-09-17
status: complete
---

# Quick Plan 260917-ndw: Question serving and repetition Summary

**Free-tier questions now rotate after the serve log fills, and a selector refreshes preferences to see serves made by the headless bubble isolate.**

## Performance

- Started: 2026-09-17T16:49:44Z
- Completed: 2026-09-17T16:54:22Z
- Tasks: 3 of 3
- Files created or modified: 5

## Accomplishments

- Traced the three selector call sites, bucket priority, randomization, and four repeat-avoidance layers in FINDINGS.md.
- Added a failing rolling-window regression for 25 unanswered free-tier serves, then changed the fallback to prefer questions absent from the serve log and older serves within it.
- Added a failing held-cache regression for an external serve-log write, then reloaded preferences before selection with a cached-value fallback on reload failure.

## Verification

- Rotation test before fix: failed as expected; serves 1–10 held only nine distinct IDs.
- Cross-isolate test before refresh: failed as expected; selected `q6` instead of the sole unserved `q10`.
- `flutter test --no-pub`: passed, 76 tests.
- `flutter analyze --no-pub --no-fatal-infos` on the two changed services and selector test: no issues.
- `git diff --check`: passed.

## Task Commits

No commits were created. `git add` failed because the linked worktree's Git index is outside the writable sandbox:

`fatal: Unable to create '/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/.git/worktrees/agent-260917-ndw/index.lock': Read-only file system`

All changes remain in this worktree for the coordinator to commit.

## Deviations from Plan

None in implementation. The sandbox prevented the planned per-task Git commits.

## Remaining Limit

The serve log is device-local; review synchronization does not deduplicate serves between devices.

## Self-Check: PASSED

All five listed files exist, both new regressions and the full suite pass, and FINDINGS.md has all six required sections. No commit hashes were claimed.
