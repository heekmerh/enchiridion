---
phase: quick-260919-kit
plan: 01
subsystem: exam-prep-copy
tags: [flutter, dart, copy, mock-exam, guard]
provides:
  - "Exam Prep home card reads Mock Exam / Start Mock Exam; dead _StudyCard removed"
  - "Ambient one-question surfaces read Practice Question"
  - "retired_quick_check_copy_guard_test repo guard"
affects: [exam_prep_home_screen, quick_check_card, notification_service, bubble_alarm_callback]
completed: 2026-09-19
status: complete
---

# Quick 260919-kit: Retire Quick Check copy Summary

User-facing "Quick Check" copy is gone. The Exam Prep home card is the mock-exam entry point; the ambient one-question surfaces describe themselves accurately as a single practice question.

## Changes
- `lib/screens/exam_prep_home_screen.dart` — third card: title `Mock Exam`; subtitle `Take a mock exam drawn from your unlocked questions. Your answers feed the performance stats above.`; empty state `No unlocked questions are available yet.`; button `Start Mock Exam` with `Icons.quiz_outlined` (bolt read as "quick"). Deleted unreferenced `_StudyCard`/`_StudyCardState` (confirmed only declaration sites matched) including its second copy of the retired label; dropped the now-unused `explanation_text` import. Updated `_serveNextQuestion` + related doc comments to the new label; no counting/advance/shuffle logic touched.
- `lib/widgets/exam_prep/quick_check_card.dart` — heading `Practice Question` (sub-sentence unchanged). Class name, filename, and `bubble_main.dart` import untouched.
- `lib/services/notification_service.dart` — `scheduleFollowUp` title `Practice Question`; channel id/name/description untouched.
- `lib/services/bubble_alarm_callback.dart` — bubble payload title `Practice Question`.
- `test/screens/exam_prep_home_screen_test.dart` — both title assertions → `Mock Exam`; header comment refreshed.
- `test/guards/retired_quick_check_copy_guard_test.dart` — new guard mirroring `bank_disclosure_guard_test.dart`: case-insensitive `quick[\s\-_]?check` over non-comment `lib/` Dart lines, exempting `QuickCheckCard` and `quick_check_card`. Teeth verified: temp reintroduction failed the guard naming path+line, revert passed.

## Verification
- Repo-root gate reports 0 (was 5).
- `flutter analyze` on the four lib files clean; full `flutter analyze` 8 issues, all pre-existing in untouched files (one fewer than before — deleting `_StudyCard` removed its `unused_element_parameter` warning).
- Full `flutter test` green (279).

## Follow-up candidate (deliberately deferred)
Android native strings out of scope per plan: `BubblePlugin.kt` title is a fallback Dart always overrides; the notification-channel display name is guarded by an early return when the channel already exists, so renaming reaches fresh installs only — a channel-migration decision, not a copy tweak.
