---
phase: quick-260919-kiv
plan: 01
subsystem: exam-prep
tags: [flutter, dart, question-options, shuffle, scoring]
provides:
  - "Question.displayLabel(position) — position-to-letter helper"
  - "Practice screen + bubble card render letters by slot; scoring stays key-based"
  - "option_label_position_guard_test repo guard"
affects: [question_screen, quick_check_card, question_model]
completed: 2026-09-19
status: complete
---

# Quick 260919-kiv: Option shuffle labels Summary

Scrambled options now render letters A/B/C(/D) from the final rendered position on both the practice question screen and the bubble Quick Check card. Tapping a row records the underlying option key, so scoring is unchanged.

## Coupled-bug check (brief asked, no second bug)
Correctness never assumed a fixed letter-to-answer mapping: `question_screen.dart` and `quick_check_card.dart` compare the tapped option key to `question.correctOption` (lower-cased at `question.dart:48`); `UserAnswer.selectedOption` stores the key; read-only restore compares keys. Change is display-only. Pinned by the two new scoring assertions in `quick_check_card_test.dart` (correct-text → Correct, wrong-text → Not quite) plus the untouched read-only case in `question_screen_test.dart`.

## Changes
- `lib/models/question.dart` — added static `displayLabel(int)` (`String.fromCharCode(0x41 + position)`, assert 0–25), documented as slot-not-option.
- `lib/screens/question_screen.dart` — `_OptionTile` takes required `label`, renders it in the avatar; option map walks `asMap().entries` passing `label: Question.displayLabel(entry.key)`. Tap/selected/correctness still key-based.
- `lib/widgets/exam_prep/quick_check_card.dart` — same: `asMap().entries`, avatar renders `Question.displayLabel(entry.key)`; seeding untouched.
- `test/models/question_test.dart` — displayLabel mapping + assertion tests.
- `test/screens/question_screen_test.dart` — `_buildSubject` gains `optionSeed`; new group: seed 0 permutes to [c,b,a], texts render in derived order with letters A,B,C, correct-text row scores correct.
- `test/widgets/quick_check_card_test.dart` — new: letters A–D in tree order (seed-independent), correct/wrong verdicts by text.
- `test/guards/option_label_position_guard_test.dart` — source guard over the two shuffling surfaces: requires `Question.displayLabel(` and forbids `toUpperCase` (both files now have no other use of it). `exam_prep_home_screen.dart` excluded (sorted, never shuffles).

## Verification
- Targeted suites pass; `flutter analyze` on the three lib files clean; full `flutter test` green (278).
