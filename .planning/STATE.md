---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: MVP Polish
status: milestone_complete
last_updated: 2026-09-15T17:51:44Z
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 12
  completed_plans: 12
  percent: 100
stopped_at: Post-milestone testing-report fixes committed through f9e4cd1; continue validation and remaining issues
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

See [TESTING_REPORT.md](../TESTING_REPORT.md) for the current issue list and [the TOC audit](../scripts/output/paediatrics_toc_audit.md) for the extraction cross-check. The original detailed audit in TESTING_REPORT.md is historical; use its dated progress note and current code before selecting an issue.

### Quick Tasks Completed

| # | Description | Date | Commit | Status | Directory |
|---|-------------|------|--------|--------|-----------|
| 260915-r9g | Fix the IV Cannula resource extraction error reported in TESTING_REPORT.md | 2026-09-15 | 8013e70 | passed | .planning/quick/260915-r9g-fix-the-iv-cannula-resource-extraction-error-reported-in-tes |
| 260915-r9i | Audit Flutterwave payment-verification readiness and write deployment/test checklist | 2026-09-15 | 7a6c539 | passed | .planning/quick/260915-r9i-audit-flutterwave-payment-verification-readiness-from-enchir |
| 260915-r9k | Update dated testing report with book rerun and attributed migration status | 2026-09-15 | 6f43307 | passed | .planning/quick/260915-r9k-update-the-dated-progress-note-in-testing-report-md-to-recor |

Batch `260915-r9f` remains open: SQL verification item `260915-r9h` failed its safety-gate verification, and OSCE inventory item `260915-r9j` awaits the plan-checker checkpoint decision. See [BATCH.json](quick-batches/260915-r9f/BATCH.json) and the per-item verification reports.

## Remaining Validation and External Setup

- Spot-check the regenerated Paediatrics content, headings, colors, tables, and figures in the app; the source DOCX has inconsistent authoring.
- Complete Phase 4 human UAT and verify Android bubble notifications on a device.
- The user reports applying SQL migrations `001_flagged_questions.sql` through `004_payments.sql`; independently confirm their catalog objects and behavior in the live backend. Fix the SQL verifier safety gate before relying on it, and configure/deploy and test Flutterwave payment verification separately.
- Source full content for the remaining OSCE and instrumentation topics. `scripts/content/medical_instrumentation.md` is an empty, untracked file and cannot yet supply new topics.

## Session Continuity

Last session: 2026-09-15
Stopped at: Testing-report follow-up; three post-milestone fixes committed through `f9e4cd1`. Local `origin/main` tracks `f9e4cd1`.
Resume file: none (no HANDOFF.json or .continue-here).

## Next Step

Continue the remaining TESTING_REPORT.md validation and fixes with the user, then decide whether to open a v1.1 milestone. Keep the completed v1.0 roadmap and phase artifacts as historical records.
