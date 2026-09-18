---
quick_id: 260917-ndr
batch: 260917-ndp
status: complete
subsystem: exam-prep-content
tags: [python, flutter, questions, explanations]
requires: []
provides:
  - Newline-preserving question asset generation
  - Structured explanation rendering on three answer surfaces
  - Single-line question previews and notification teasers
affects: [exam-prep, quick-check, notifications]
tech-stack:
  added: []
  patterns: [plain-text paragraph and bullet rendering]
key-files:
  created:
    - scripts/tests/test_generate_questions.py
    - enchiridion/lib/widgets/exam_prep/explanation_text.dart
    - enchiridion/test/widgets/explanation_text_test.dart
  modified:
    - scripts/generate_resource_content.py
    - enchiridion/assets/data/exam_prep_questions.json
    - enchiridion/lib/models/question.dart
    - enchiridion/lib/services/notification_service.dart
    - enchiridion/lib/screens/question_screen.dart
    - enchiridion/lib/screens/exam_prep_home_screen.dart
    - enchiridion/lib/widgets/exam_prep/quick_check_card.dart
    - enchiridion/test/services/exam_prep_repository_test.dart
    - enchiridion/test/models/question_test.dart
    - enchiridion/test/services/notification_service_test.dart
key-decisions:
  - Keep clinical explanations as plain text and lay out paragraphs and bullets explicitly.
  - Preserve the asset's existing CRLF file endings to keep the diff limited to explanation values.
requirements-completed: []
coverage:
  - id: D1
    description: All 493 bundled explanations preserve source line breaks without wording drift.
    verification:
      - kind: unit
        ref: scripts/tests/test_generate_questions.py#test_regenerated_asset_preserves_clinical_wording
        status: pass
      - kind: integration
        ref: enchiridion/test/services/exam_prep_repository_test.dart#bundled explanations retain line breaks when loaded
        status: pass
    human_judgment: false
  - id: D2
    description: Three answer surfaces show paragraphs and hanging-indent bullets.
    verification:
      - kind: unit
        ref: enchiridion/test/widgets/explanation_text_test.dart
        status: pass
      - kind: integration
        ref: flutter test --no-pub
        status: pass
    human_judgment: false
  - id: D3
    description: Question previews and notification teasers remain single-line.
    verification:
      - kind: unit
        ref: enchiridion/test/models/question_test.dart
        status: pass
      - kind: unit
        ref: enchiridion/test/services/notification_service_test.dart
        status: pass
    human_judgment: false
actuals:
  tokens: 374369
  tasks: 3
  commits: 0
commits: 0
plan_head_before: 5abc039de6901f333b38bbe785b1835743945876
completed: 2026-09-17
---

# Quick Batch 260917-ndr Summary

**Question explanations retain their source paragraphs and bullets from generation through all three answer views, while previews and notifications stay on one line.**

## Accomplishments

- Repaired the concatenated-object source scan, validated required fields, and added a questions-only generation mode. The asset contains 493 rows; all 493 explanations have newlines, and every question, option, answer, and explanation matches the old asset after whitespace collapse.
- Added `ExplanationText` for separate paragraphs and hanging-indent bullet rows; wired it into the question screen, study card, and quick-check card.
- Flattened whitespace before preview and notification length limits, preserving existing tail and ellipsis behavior.

## Verification

- Python unittest discovery: 12 passed.
- Full Flutter test suite: 74 passed.
- Asset spot-check: `exam-0001` has `Key Clues in the Question:` followed by a blank line and a separate `- High fever` line.
- `git -c core.whitespace=cr-at-eol diff --check`: passed. Resource topic JSON has no diff.
- `flutter analyze --no-pub` reports 10 existing findings and exits 1. The same scan with `--no-fatal-infos --no-fatal-warnings` exits 0 and reports no findings introduced by this item. The findings include an existing unused `key` parameter in `exam_prep_home_screen.dart` and casts in the unchanged `exam_prep_repository.dart`.

## Deviations from Plan

- Preserved the asset's existing CRLF file endings during generation, reducing the content diff to 493 explanation lines.
- The baseline asset comparison reads the pinned pre-change commit `5abc039de6901f333b38bbe785b1835743945876`; `git show HEAD:...` would refer to the regenerated asset after a task commit.
- Atomic task commits could not be made because the worktree's Git metadata is read-only in the sandbox. All changes remain in this worktree for the coordinator. Exact error: `fatal: Unable to create '/home/kaasor/Documents/Backup/Hikma/Enchiridion/enchiridion/.git/worktrees/agent-260917-ndr/index.lock': Read-only file system`.

## Issues Encountered

- Flutter initially could not write to its SDK cache under the default sandbox. Test and analyzer runs succeeded with the permitted escalation.
- Standard Flutter analysis remains nonzero due to the 10 pre-existing findings above; no unrelated source was changed to clear them.

## Self-Check: PASSED

All 13 changed files and this summary exist in the assigned worktree. The expected commit count is zero because Git staging was blocked by the read-only worktree index.
