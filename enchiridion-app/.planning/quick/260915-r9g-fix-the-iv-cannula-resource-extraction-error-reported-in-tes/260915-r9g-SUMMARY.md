---
quick_id: 260915-r9g
subsystem: content
tags: [iv-cannula, docx, resource-extraction]
requires: []
provides:
  - IV Cannula quick-size heading and five ordered checklist rules
affects: [medical-instrumentation, resource-reader]
tech-stack:
  added: []
  patterns: [topic-only resource regeneration from the corrected source DOCX]
key-files:
  created: []
  modified:
    - scripts/content/IV_Cannula_instrumentation.docx
    - enchiridion/assets/data/resources/iv_cannula.json
key-decisions:
  - Split the mixed source paragraph into a Heading 2 title and a Normal (Web) rule rather than changing the shared parser.
requirements-completed: []
status: complete
completed: 2026-09-15
---

# Quick 260915-r9g: IV Cannula Resource Extraction Summary

The emergency/shock size rule now appears first in the five-item checklist under the title “Quick Size Selection Rules”.

## Accomplishments

- Split the DOCX's mixed Heading 2 paragraph into a title-only heading and an immediately following Normal (Web) rule paragraph, preserving the rule's existing runs.
- Regenerated only the `iv_cannula` topic JSON through `build_topic_json`; its diff is limited to the corrected title and one added checklist item.
- Kept both IV Cannula image assets and all unrelated resource outputs unchanged.

## Task Commit

- Task 1, source correction and topic-only regeneration: `8013e70` (`fix(260915-r9g)`), on `agent-260915-r9g`.

## Verification

- The plan's Python assertion passed: Heading 2 title, following Normal (Web) rule, exactly five ordered checklist items, and no subsection title containing the emergency/shock rule.
- The plan's unrelated-resource `git diff --exit-code` passed for Sutures, Abdominal Examination, exam-prep questions, and their content assets.
- A separate diff check passed for `image_01.png` and `image_02.png`. The source DOCX retains all original package parts except the edited `word/document.xml`; paragraph text and styles outside the split are unchanged.
- The JSON diff contains only two inserted lines and one removed line; original CRLF formatting was preserved.

## Deviations from Plan

None. The unchanged image assets required no commit entries.

## Known Stubs

None found in the regenerated IV Cannula JSON.

## Self-Check: PASSED

The corrected source and JSON exist, and commit `8013e70` is present.
