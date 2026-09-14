---
phase: 04-phase-1-calculators-enhancements-high-priority
plan: 04
subsystem: ui
tags: [flutter, dart, calculators, paediatrics, clinical-notes, forms, wave-4]

# Dependency graph
requires:
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 01
    provides: "CalculatorDefinition with 5 enhancement fields, _ClinicalNotesSection widget"
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 02
    provides: "7 Emergency & Critical Care calculators"
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 03
    provides: "5 Drug Dosing calculators; wave-3 merge complete"
provides:
  - "6 Paediatrics kCalculators entries (apls-weight, broselow, pediatric-bp, neonatal-bilirubin, apgar, growth-percentile)"
  - "6 _XxxForm StatefulWidget + State classes with full validation and dispose"
  - "6 switch cases in _buildInputs routing to new form classes"
  - "kCalculators total = 26 (8 existing + 18 new); count test GREEN"
  - "All 5 enhancement fields + safety disclaimers per threat model"
affects:
  - "test/models/calculator_definition_test.dart: count test (26) now PASSES"
  - "Phase 4 complete: all calculator plans done"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_XxxForm pattern: StatefulWidget + State with TextEditingController dispose + double.tryParse validation + SnackBar on invalid + onResult callback without title prefix"
    - "Scored int dropdown pattern: DropdownButton<int> with const items [0, 1, 2] for APGAR"
    - "Static const zone lookup: List<(double, double, String, String)> for Broselow zones"
    - "Simplified z-score band: qualitative (< -2 SD, -2..+2, > +2) from approximate WHO median/SD reference table"

key-files:
  modified:
    - "enchiridion/lib/models/calculator_definition.dart"
    - "enchiridion/lib/screens/calculator_screen.dart"

key-decisions:
  - "APLS age-unit dropdown (years/months) avoids ambiguity in < 1 year vs older children"
  - "Broselow defers drug dose columns to a future phase — zone + weight range only (per Open Q1 resolution)"
  - "Pediatric BP uses simplified 2017 AAP 95th-percentile table; 90th approximated as 95th-7 for SBP"
  - "Neonatal bilirubin uses simplified Bhutani-based thresholds; explicit disclaimer to confirm against local AAP nomogram (assumption A3)"
  - "APGAR scored dropdowns constrain inputs to 0-2 — no tryParse needed; no TextEditingControllers to dispose"
  - "Growth percentile uses simplified z-score bands from approximate WHO median/SD — not full LMS; disclaimer in explanation field (Open Q2)"
  - "unnecessary_brace_in_string_interps lint fixed: removed unnecessary ${_risk} -> $_risk"

requirements-completed: [REQ-4a, REQ-4d, REQ-4e]

# Metrics
duration: ~35min
completed: 2026-06-04
---

# Phase 4 Plan 04: 6 Paediatrics Calculators Summary

**6 Paediatrics calculators (APLS Weight, Broselow, Pediatric BP, Neonatal Bilirubin, APGAR, WHO Growth Percentile) wired end-to-end; kCalculators = 26; count test GREEN**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-06-04
- **Completed:** 2026-06-04
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Appended 6 `const CalculatorDefinition` entries to `kCalculators` — all with `category: 'Paediatrics'`, positioned after `holliday-segar` (position 0 preserved)
- Each definition populated with all 5 enhancement fields: explanation, clinicalInterpretation, safetyNotes, commonPitfalls, osceTips
- Safety disclaimers per threat model:
  - `neonatal-bilirubin` safetyNotes states "confirm against local AAP phototherapy nomogram" (T-04-10 / assumption A3)
  - `pediatric-bp` safetyNotes notes "simplified thresholds — verify against full 2017 AAP tables" (A4)
  - `growth-percentile` explanation states "simplified z-score bands, not full LMS" (Open Q2)
- kCalculators total now exactly 26 (8 existing + 7 E&CC + 5 Drug Dosing + 6 Paediatrics)
- Count test `kCalculators has exactly 26 entries` PASSES (was RED through plans 02-03)
- groupByCategory test PASSES with exact per-category counts: Drug Dosing 8, Emergency & Critical Care 9, General 1, Obs & Gynae 1, Paediatrics 7 = 26
- Implemented 6 form classes with section comments:
  - `_AplsWeightForm`: 3-band APLS formula (months/< 1y/1–5y/6–12y) with age-unit dropdown
  - `_BroselowForm`: length-to-zone lookup via static const list of (min, max, colour, range) tuples
  - `_PediatricBpForm`: 2017 AAP simplified 95th-percentile table for SBP/DBP; classifies SBP/DBP/Overall
  - `_NeonatalBilirubinForm`: simplified Bhutani thresholds by age-hours × risk; µmol/L ↔ mg/dL conversion
  - `_ApgarForm`: 5 int dropdowns (0–2) using helper method `_apgarRow`; no controllers to dispose
  - `_GrowthPercentileForm`: approximate WHO median/SD reference table; optional head circumference
- All forms: tryParse + null + `> 0` guards (or constrained dropdown for APGAR); SnackBar on invalid; all TextEditingControllers disposed; `super.dispose()` called last
- Added 6 switch cases to `_buildInputs` before the `default:` branch
- `flutter analyze` clean on both modified files; full `flutter test` suite green (26 tests)

## Task Commits

Each task committed atomically:

1. **Task 1: Add 6 Paediatrics definitions to kCalculators** - `b216751` (feat)
2. **Task 2: Implement 6 Paediatrics form classes + switch cases** - `fa0e7b8` (feat)

## Files Created/Modified

- `enchiridion/lib/models/calculator_definition.dart` - 6 new Paediatrics entries appended (174 lines added)
- `enchiridion/lib/screens/calculator_screen.dart` - 6 form classes + 6 switch cases (699 lines added)

## Decisions Made

- APLS uses age-unit dropdown (years vs months) to avoid ambiguity at the < 1-year boundary
- Broselow defers drug dose columns to a future phase — zone + weight range only per plan's Open Q1 resolution
- Pediatric BP: 2017 AAP 95th-percentile SBP/DBP simplified table; 90th approximated as 95th − 7 (SBP) / 95th − 5 (DBP)
- Neonatal bilirubin uses simplified Bhutani-based thresholds (not Bhutani risk nomogram exact values); explicit AAP local nomogram disclaimer
- APGAR dropdowns constrain 0–2 per component — no TextEditingController needed; `_ApgarFormState` has no dispose override (no controllers)
- WHO growth uses simplified z-score bands from approximate median/SD, not full LMS tables — disclaimer in explanation and warning fields

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed unnecessary_brace_in_string_interps lint warning**
- **Found during:** `flutter analyze` after Task 2
- **Issue:** `'(${_risk} risk)'` should be `'($_risk risk)'` — single identifier doesn't need braces
- **Fix:** Removed braces from `${_risk}` interpolation in `_NeonatalBilirubinFormState._calculate()`
- **Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
- **Commit:** `fa0e7b8` (included in Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - lint)
**Impact on plan:** Minor lint fix only. No scope creep.

## Issues Encountered

None after auto-fix. `flutter analyze` was clean after the one-line brace removal.

## User Setup Required

None.

## Phase 4 Complete

All four plans in Phase 4 are now complete:

| Plan | Content | Calculators added | Status |
|------|---------|-------------------|--------|
| 04-01 | CalculatorDefinition enhancements + _ClinicalNotesSection | 0 (model/widget) | DONE |
| 04-02 | 7 Emergency & Critical Care calculators | 7 | DONE |
| 04-03 | 5 Drug Dosing calculators | 5 | DONE |
| 04-04 | 6 Paediatrics calculators | 6 | DONE |

**Total new calculators added in Phase 4:** 18 (7 + 5 + 6)
**Total kCalculators:** 26 (8 existing + 18 new)
**Count test:** GREEN

## Known Stubs

None. All 6 new calculators have non-empty values in all 5 enhancement fields and their form classes implement full formula logic. The Broselow drug-dose columns are intentionally deferred (documented in plan) — this is a product decision, not a code stub.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes.

- T-04-09 (user numeric input → paediatric formulas): mitigated via `double.tryParse` + null + `> 0` guards + SnackBar; APGAR uses constrained int dropdowns (0–2)
- T-04-10 (repudiation — bilirubin/BP/weight output): mitigated via safetyNotes disclaimers on all 6 new entries and warning fields in all 6 form classes
- T-04-11 (information disclosure): mitigated via results including units + qualitative band + explicit estimate framing

---

## Self-Check

### Files exist:
- [x] `enchiridion/lib/models/calculator_definition.dart` - modified (Task 1)
- [x] `enchiridion/lib/screens/calculator_screen.dart` - modified (Task 2)
- [x] `.planning/phases/04-phase-1-calculators-enhancements-high-priority/04-04-SUMMARY.md` - this file

### Commits exist:
- [x] `b216751` - feat(04-04): add 6 Paediatrics calculator definitions
- [x] `fa0e7b8` - feat(04-04): implement 6 Paediatrics form classes + switch cases

## Self-Check: PASSED

---
*Phase: 04-phase-1-calculators-enhancements-high-priority*
*Completed: 2026-06-04*
