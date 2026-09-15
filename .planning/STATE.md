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

## Remaining Validation and External Setup

- Spot-check the regenerated Paediatrics content, headings, colors, tables, and figures in the app; the source DOCX has inconsistent authoring.
- Complete Phase 4 human UAT and verify Android bubble notifications on a device.
- Apply the SQL migrations `001_flagged_questions.sql` through `004_payments.sql` and configure/deploy Flutterwave payment verification; these have not been confirmed in the live backend.
- Source full content for the remaining OSCE and instrumentation topics. `scripts/content/medical_instrumentation.md` is an empty, untracked file and cannot yet supply new topics.

## Session Continuity

Last session: 2026-09-15
Stopped at: Testing-report follow-up; three post-milestone fixes committed through `f9e4cd1`. Local `origin/main` tracks `f9e4cd1`.
Resume file: none (no HANDOFF.json or .continue-here).

## Next Step

Continue the remaining TESTING_REPORT.md validation and fixes with the user, then decide whether to open a v1.1 milestone. Keep the completed v1.0 roadmap and phase artifacts as historical records.
