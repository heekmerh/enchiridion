---
phase: quick-260919-kis
plan: 01
subsystem: exam-prep
tags: [question-screen, ux, tdd]
status: complete
dependency-graph:
  requires: []
  provides:
    - "QuestionScreen advances only on explicit user action (no timed auto-advance)"
  affects:
    - enchiridion/lib/screens/question_screen.dart
tech-stack:
  added: []
  patterns:
    - "User-initiated advance only; no periodic Timer on the answered-question footer"
key-files:
  created: []
  modified:
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/test/screens/question_screen_test.dart
decisions:
  - "Removed the six-second countdown and 'Stay on this question' control entirely rather than lengthening the pause — the countdown itself (any duration) was the defect, since an idle/slow reader could still be carried forward mid-explanation."
metrics:
  duration: "~25m"
  completed: 2026-09-19
actuals:
  tokens: 2969
  tasks: 2
  commits: 2
plan_head_before: 7662dc01adfba2888d81a523430da220f1262f8e
---

# Phase quick-260919-kis Plan 01: Remove timed auto-advance from QuestionScreen Summary

Removed the six-second countdown/auto-advance timer from `QuestionScreen` so an
answered question, its explanation, and its OSCE tip stay on screen until the
user explicitly taps "Next question" — eliminating the timed carry-forward that
was yanking feedback away mid-read.

## What Was Built

- **Task 1 (TDD):** Rewrote the `auto-advance` test group as `no timed advance`
  with five new cases (idle user never carried forward, no countdown
  affordances render, "Next question" advances exactly once and stays
  advanced, an exhausted queue is discovered only on explicit tap, popping an
  answered screen raises no exception). Confirmed two of the five new cases
  failed against the pre-change screen (RED), then removed
  `_feedbackPause`, `_autoAdvanceTimer`, `_secondsRemaining`,
  `_startAutoAdvanceCountdown()`, and `_cancelAutoAdvance()` from
  `question_screen.dart`, stopped `_submit()` from starting a countdown,
  dropped the now-dead `_cancelAutoAdvance()` call from `_advance()`, and
  removed the countdown `Text`/`SizedBox` and "Stay on this question"
  `TextButton` from `build()`. All 12 tests in
  `question_screen_test.dart` pass (GREEN).
- **Task 2:** Updated the three dartdoc/comment blocks that still advertised
  an eventual unattended auto-advance (`NextQuestionLoader` typedef,
  `QuestionScreen.onRequestNext` field doc, `_advancing` field comment) so
  they describe a purely user-driven advance. Left the `readOnly` doc's
  "ambient Quick Check sheet" wording untouched per the plan's scope note
  (owned by sibling item `260919-kit`). Verified no executable reference to
  the removed timer symbols remains and the full `test/screens/` suite
  (85 tests) passes.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `cd enchiridion && flutter test test/screens/question_screen_test.dart` — 12/12 passed, `no timed advance` group present.
- `cd enchiridion && flutter analyze lib/screens/question_screen.dart test/screens/question_screen_test.dart` — no issues.
- `cd enchiridion && flutter test test/screens/` — 85/85 passed (full screens suite, confirming no other screen test relied on the timed advance).
- Executable-line grep for `_autoAdvanceTimer|_secondsRemaining|_feedbackPause|Timer` in `question_screen.dart` — 0 matches.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: enchiridion/lib/screens/question_screen.dart
- FOUND: enchiridion/test/screens/question_screen_test.dart
- FOUND commit: dd10f51 (Task 1)
- FOUND commit: 705425f (Task 2)
