---
phase: 04-phase-1-calculators-enhancements-high-priority
plan: 03
subsystem: ui
tags: [flutter, dart, calculators, drug-dosing, clinical-notes, forms, wave-3]

# Dependency graph
requires:
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 01
    provides: "CalculatorDefinition with 5 enhancement fields, _ClinicalNotesSection widget"
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 02
    provides: "7 Emergency & Critical Care calculators; wave-2 merge complete"
provides:
  - "5 Drug Dosing kCalculators entries (bsa, egfr-ckd-epi, gentamicin-vancomycin, insulin-dose, paracetamol-dosing)"
  - "5 _XxxForm StatefulWidget + State classes with full validation and dispose"
  - "5 switch cases in _buildInputs routing to new form classes"
  - "2021 CKD-EPI race-free eGFR equation (no race input, Pitfall #6)"
  - "Mosteller BSA formula with kg/lb + cm/m unit dropdowns"
affects:
  - "04-04-PLAN: can append Paediatrics calculators to kCalculators after these 5"
  - "test/models/calculator_definition_test.dart: count at 20 (needs 26 for GREEN)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_XxxForm pattern: StatefulWidget + State with TextEditingController dispose + double.tryParse validation + SnackBar on invalid + onResult callback without title prefix"
    - "Taylor series ln/exp helpers in _EgfrCkdEpiFormState to compute b^e without dart:math import"
    - "Weight-based dose with formulary warning: used for gentamicin, vancomycin, paracetamol child dosing"

key-files:
  modified:
    - "enchiridion/lib/models/calculator_definition.dart"
    - "enchiridion/lib/screens/calculator_screen.dart"

key-decisions:
  - "eGFR uses 2021 CKD-EPI race-free coefficients with no race dropdown or input field (Pitfall #6)"
  - "BSA sqrt computed via Newton-Raphson iteration (_sqrtOf helper) — no dart:math import needed"
  - "eGFR b^e computed via Taylor series ln/exp helpers — consistent with no additional import"
  - "Insulin ISF input is always in mg/dL per unit regardless of CBG display unit (conversion applied before calculation)"
  - "Paracetamol adult dose phrased as 500-1000 mg range per dose to handle lower-weight adults; weight-based daily cap warning issued when weight-based limit < 4 g/day"

requirements-completed: [REQ-4a, REQ-4c, REQ-4e]

# Metrics
duration: ~25min
completed: 2026-06-04
---

# Phase 4 Plan 03: 5 Drug Dosing Calculators Summary

**5 Drug Dosing calculators (BSA Mosteller, eGFR CKD-EPI 2021 race-free, Gentamicin/Vancomycin, Insulin Dose, Paracetamol) wired end-to-end with 5 enhancement fields, validated forms, and switch cases**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-06-04
- **Completed:** 2026-06-04
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Appended 5 `const CalculatorDefinition` entries to `kCalculators` — all with `category: 'Drug Dosing'`, positioned after weight-dosing/iv-infusion/creatinine-clearance (weight-dosing stays position 0 as the free calculator)
- Each definition populated with all 5 enhancement fields: explanation, clinicalInterpretation, safetyNotes, commonPitfalls, osceTips
- egfr-ckd-epi entry states the 2021 race-free CKD-EPI equation with no race variable (Pitfall #6)
- Implemented 5 form classes (`_BsaForm`, `_EgfrCkdEpiForm`, `_GentamicinVancomycinForm`, `_InsulinDoseForm`, `_ParacetamolDosingForm`) — each preceded by section comment
- All forms: `double.tryParse` + null + `> 0` guards; SnackBar on invalid; all controllers disposed; `super.dispose()` called last
- BSA (Mosteller): weight kg/lb + height cm/m unit dropdowns; sqrt via Newton-Raphson helper; spot check 70 kg / 170 cm = 1.82 m² confirmed
- eGFR: 2021 CKD-EPI race-free equation; 6 CKD bands (G1–G5); sex factor 1.012 for females; b^e via Taylor series ln/exp helpers; no race input at all
- Gentamicin/Vancomycin: drug selector dropdown; gentamicin 5 mg/kg/day; vancomycin 15–20 mg/kg/dose range; formulary/trough warning on all outputs
- Insulin dose: correction dose = (CBG − target) / ISF; negative clamped to 0; mmol/L + mg/dL unit dropdown with conversion
- Paracetamol: adult 500–1000 mg q4–6h max 4 g/day; child 15 mg/kg/dose max 60 mg/kg/day; automatic weight-based warning when weight-adjusted limit < 4 g adult cap
- Added 5 switch cases to `_buildInputs` before the `default:` branch
- `flutter analyze` clean on both modified files; all 4 pre-existing screen tests pass; 2 intentional RED model tests remain RED as expected

## Task Commits

Each task was committed atomically:

1. **Task 1: Add 5 Drug Dosing definitions to kCalculators** - `9f0961e` (feat)
2. **Task 2: Implement 5 Drug Dosing form classes + switch cases** - `71207c9` (feat)

## Files Created/Modified

- `enchiridion/lib/models/calculator_definition.dart` - 5 new Drug Dosing entries appended (committed in Task 1)
- `enchiridion/lib/screens/calculator_screen.dart` - 5 form classes + 5 switch cases (544 lines added)

## Decisions Made

- eGFR form implements 2021 CKD-EPI race-free equation with no race dropdown; sex factor only (1.012 for female) per Pitfall #6
- BSA sqrt and eGFR b^e computed via in-class helper methods (Newton-Raphson / Taylor series) to avoid importing dart:math
- Insulin ISF is always in mg/dL per unit; the mmol/L CBG is converted to mg/dL before applying the ISF denominator
- Paracetamol adult phrasing is "500–1000 mg" range to handle lower-weight adults; a warning fires if weight-based daily limit < 4 g/day

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None. `flutter analyze` was clean on the first pass; all pre-existing tests passed without modification.

## User Setup Required

None.

## Next Phase Readiness

- Wave 4 plan (04-04) can append Paediatrics calculators to `kCalculators` after Drug Dosing entries
- The 2 intentional RED tests (`kCalculators has exactly 26 entries` and `groupByCategory final per-category counts`) remain RED; they will go GREEN after 04-04 adds its calculators (currently 20, needs 26)

## Known Stubs

None. All 5 new calculators have non-empty values in all 5 enhancement fields and their form classes implement full formula logic.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes.

- T-04-06 (user numeric input → dosing formulas): mitigated via `double.tryParse` + null + `> 0` guards + SnackBar early return on all 5 forms
- T-04-07 (repudiation — gentamicin/vancomycin/paracetamol output): mitigated via warning field + "verify against formulary" wording + max-dose caps enforced in paracetamol child path
- T-04-08 (information disclosure — eGFR/dose results): mitigated via results including units + CKD band + explicit "Calculated estimate" framing

---

## Self-Check

### Files exist:
- [x] `enchiridion/lib/models/calculator_definition.dart` - modified (Task 1)
- [x] `enchiridion/lib/screens/calculator_screen.dart` - modified (Task 2)
- [x] `.planning/phases/04-phase-1-calculators-enhancements-high-priority/04-03-SUMMARY.md` - this file

### Commits exist:
- [x] `9f0961e` - feat(04-03): add 5 Drug Dosing calculator definitions
- [x] `71207c9` - feat(04-03): implement 5 Drug Dosing form classes + switch cases

## Self-Check: PASSED

---
*Phase: 04-phase-1-calculators-enhancements-high-priority*
*Completed: 2026-06-04*
