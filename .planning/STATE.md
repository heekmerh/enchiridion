---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: MVP Polish
status: milestone_complete
last_updated: 2026-09-17T16:31:55Z
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 12
  completed_plans: 12
  percent: 100
stopped_at: Resumed context; 11 pending question-practice plans in batch 260917-ndp; awaiting next-action selection
---

# Milestone State: MVP Polish

**Last Updated:** 2026-09-15
**Status:** All four phases and 12 plans complete; human UAT and deployment checks remain.

## Completed Milestone

- [x] Phase 1: Email Confirmation & Device Binding — implemented and verified in code
- [x] Phase 2: Reader UX Polish — executed and verified
- [x] Phase 3: Content Lock & Resources Redesign — executed and verified
- [x] Phase 4: Phase 1 Calculators + Enhancements — executed, reviewed, and verified in code

Phase 4's [human UAT](phases/04-phase-1-calculators-enhancements-high-priority/04-HUMAN-UAT.md) still has three pending checks: BMI unit conversion, clinical notes on all calculators, and calculator form validation. The milestone's plan count remains 12/12; these checks do not change plan completion.

## Post-Milestone Testing Report Work

- `a99b27c` — re-extracted the Paediatrics DOCX using direct 24pt-bold topic markers, preserved source colors, and placed 82 body figures inline. Both generated JSON copies and the bundled figure assets were committed.
- `5fc1104` — added an independent ordered table-of-contents audit (211/211 non-empty entries matched), preserved adjacent empty headings, and corrected the fever table row from `ARadiation` to `Radiation` by regenerating from the updated DOCX.
- `f9e4cd1` — guarded the Android-only bubble startup call so Brave/Flutter web does not evaluate `Platform.isAndroid`; `flutter analyze lib/main.dart` passed. Browser runtime after this fix has not yet been reported as verified.
- 2026-09-16 — spot-checked the regenerated Paediatrics content in a running Flutter-web instance (Brave, via a throwaway `ReaderScreen`-only harness with `AccessService.testAccessOverride` set, deleted afterward — no auth flow was exercised). Confirmed: the `overview` chapter's fever table now reads "Radiation" (not "ARadiation", matching `5fc1104`); all four source heading colors render distinctly (red, black, blue, green) across the `overview` and `genetics_syndromes` chapters; 2- and 3-column tables render cleanly; an inline figure (`assets/images/paediatrics/image4.png`, cleft palate) renders at correct size with its caption; TOC navigation between chapters and subsections works. No console errors or exceptions; only the two expected Flutter-web warnings (viewport meta tag, missing Noto glyphs for emoji). Not covered: the other 10 chapters, and only one of several figures was checked.

See [TESTING_REPORT.md](../TESTING_REPORT.md) for the current issue list and [the TOC audit](../scripts/output/paediatrics_toc_audit.md) for the extraction cross-check. The original detailed audit in TESTING_REPORT.md is historical; use its dated progress note and current code before selecting an issue.

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260915-r9g | Fix the IV Cannula resource extraction error reported in TESTING_REPORT.md | 2026-09-15 | 8013e70 | passed | .planning/quick/260915-r9g-fix-the-iv-cannula-resource-extraction-error-reported-in-tes |
| 260915-r9i | Audit Flutterwave payment-verification readiness and write deployment/test checklist | 2026-09-15 | 7a6c539 | passed | .planning/quick/260915-r9i-audit-flutterwave-payment-verification-readiness-from-enchir |
| 260915-r9k | Update dated testing report with book rerun and attributed migration status | 2026-09-15 | 6f43307 | passed | .planning/quick/260915-r9k-update-the-dated-progress-note-in-testing-report-md-to-recor |
| 260915-r9j | Inventory OSCE and instrumentation sourcing with manual source-status review | 2026-09-15 | e4c84d4 | passed | .planning/quick/260915-r9j-inventory-the-osce-and-instrumentation-content-gap-using-scr |
| 260915-r9h | Verify migrations 001–004 with read-only catalog checks | 2026-09-16 | f8145cd | passed | .planning/quick/260915-r9h-add-a-read-only-sql-verification-script-under-scripts-sql-fo |
| 260917-ndr | The question and answer rendering engine is not making use of the newline feature. it just jumbles everything together into one contiguous text flow. | 2026-09-17 | ef6d7eae1fec9107204cf4b68b7b9bab5ba9be7d | — | .planning/quick/260917-ndr-the-question-and-answer-rendering-engine-is-not-making-use-o |
| 260917-ndw | How is the randomization of questions being served implemented to ensure repetition doesn’t occur. | 2026-09-17 | 13e92932c2ee0cf2c2fdf83fd6773be2560590aa | — | .planning/quick/260917-ndw-how-is-the-randomization-of-questions-being-served-implement |
| 260917-ndy | If the user is practicing and they get any question wrong that question should be requeued to be served in 24hrs | 2026-09-17 | 7e4d5b6a0f65253702e0cb91d8ae19f0e869412b | — | .planning/quick/260917-ndy-if-the-user-is-practicing-and-they-get-any-question-wrong-th |
| 260917-ndz | I have had the app on my device for over 3hours yet no question notification has been served. The user can experience questions in app through the practice now feature which for freemium users allows them 10 questions but while studying questions will be served as notification bubbles. | 2026-09-17 | 6ab2d0483790c6409655a00f51a68417961d807b | — | .planning/quick/260917-ndz-i-have-had-the-app-on-my-device-for-over-3hours-yet-no-quest |
| 260917-nds | Question stats Dashboard should be clickable: Answered, Correct, Wrong, Points. Such that they can browse the questions they've answered, correct or failed then choose to retry anyone they failed | 2026-09-18 | f9b8c09697145b6da675ff365846577d31c78713 | — | .planning/quick/260917-nds-question-stats-dashboard-should-be-clickable-answered-correc |
| 260917-ndu | The question points system is not working correctly. I need to see my correct stats displayed. Accumulated points and question answer stats take some time to update on the dashboard, and I am thinking it should be automatic because it is local first before it pushes scores to supabase when there is connectivity. | 2026-09-18 | 89c67c7a26e742d03ef4fe1429ced6446bd93668 | — | .planning/quick/260917-ndu-the-question-points-system-is-not-working-correctly-i-need-t |
| 260917-ndx | Remove Browse Full Bank, that feature allows users to view the entire bank which we dont want | 2026-09-18 | 0fe180b8f89a8f715be035074ba2f92df31601cd | — | .planning/quick/260917-ndx-remove-browse-full-bank-that-feature-allows-users-to-view-th |
| 260917-ndq | users should not be able to see the full question bank for now. They should not know how many questions we have in total. | 2026-09-18 | 5ecd12aae961fed08244a0fd4d0baeb3ff7cd228 | — | .planning/quick/260917-ndq-users-should-not-be-able-to-see-the-full-question-bank-for-n |
| 260917-ndv | After I answer a particular question there is no next question feature neither does it automatically serve the next question. | 2026-09-18 | af7d9aacb86196b2345b3cf7f99be42661e52951 | — | .planning/quick/260917-ndv-after-i-answer-a-particular-question-there-is-no-next-questi |
| 260917-ndt | Question numbers should be removed completely from the UI, the user should not have any idea the number questions we have. | 2026-09-18 | ee0f1edcc0eb0e63bb2f5ce969430b74bbbc6f81 | — | .planning/quick/260917-ndt-question-numbers-should-be-removed-completely-from-the-ui-th |
| 260917-ne0 | User exam practice experience should be improved. Review it end to end and surface suggestions based on standard practice and innovation. | 2026-09-18 | 40f7cf3255ee5ee1f599106980a8be9d1e842941 | — | .planning/quick/260917-ne0-user-exam-practice-experience-should-be-improved-review-it-e |
| 260918-dqx | Also note that across the entire app available content ranks above coming soon. | 2026-09-18 | 0b99c306862465f7def495afc6ec4d19e63eeb15 | — | .planning/quick/260918-dqx-also-note-that-across-the-entire-app-available-content-ranks |
| 260918-dqy | All coming soon topics should be grayed out | 2026-09-18 | d549813a0725b1a84e0abb7837ed7c04aeb9d124 | — | .planning/quick/260918-dqy-all-coming-soon-topics-should-be-grayed-out |

Batch `260915-r9f` has five verified completions. The user-provided Supabase SQL Editor output from 2026-09-16 shows all 31 named migration catalog checks and OVERALL passing; [the saved result](../scripts/output/verify_001_004_live_results.md) records that evidence. The agent did not connect directly to the deployed database. See [BATCH.json](quick-batches/260915-r9f/BATCH.json) and the per-item verification reports.

## Remaining Validation and External Setup

- Complete Phase 4 human UAT and verify Android bubble notifications on a device.
- The user reports applying SQL migrations `001_flagged_questions.sql` through `004_payments.sql`, and their SQL Editor result passes the catalog checks. Configure/deploy and test Flutterwave payment verification separately; catalog checks do not exercise a payment grant or replay.
- Source full content for the remaining OSCE and instrumentation topics. `scripts/content/medical_instrumentation.md` is an empty, untracked file and cannot yet supply new topics.

## Session Continuity

Last session: 2026-09-17
Stopped at: Resumed project context; awaiting selection of the next action. The uncommitted batch `260917-ndp` contains 11 pending question-practice plans, with no execution summaries yet. Preserve the existing uncommitted content and report edits.
Resume file: none (no HANDOFF.json or .continue-here).

## Next Step

Continue the remaining TESTING_REPORT.md validation and fixes with the user, then decide whether to open a v1.1 milestone. Keep the completed v1.0 roadmap and phase artifacts as historical records.
