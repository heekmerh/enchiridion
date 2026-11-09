---
phase: 04-phase-1-calculators-enhancements-high-priority
plan: 02
subsystem: ui
tags: [flutter, dart, calculators, emergency-care, clinical-notes, forms, wave-2]

# Dependency graph
requires:
  - phase: 04-phase-1-calculators-enhancements-high-priority
    plan: 01
    provides: "CalculatorDefinition with 5 enhancement fields, _ClinicalNotesSection widget, wave 0 test scaffolds"
provides:
  - "7 Emergency & Critical Care kCalculators entries (qsofa, news2, shock-index, osmolality, corrected-sodium, aa-gradient, pao2-fio2)"
  - "7 _XxxForm StatefulWidget + State classes with full validation and dispose"
  - "7 switch cases in _buildInputs routing to new form classes"
  - "NEWS2 scale 1/scale 2 SpO2 scoring with hypercapnic toggle"
  - "Osmolar gap optional calculation when measured osmolality is provided"
affects:
  - "04-03-PLAN: can append Drug Dosing calculators to kCalculators after these 7"
  - "04-04-PLAN: can append Paediatrics calculators to kCalculators after all Emergency entries"
  - "test/models/calculator_definition_test.dart: count test moves from 8 to 15 (still RED until 26)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_XxxForm pattern: StatefulWidget + State with TextEditingController dispose + double.tryParse validation + SnackBar on invalid + onResult callback without title prefix"
    - "Boolean toggle inputs: SwitchListTile with contentPadding: EdgeInsets.zero for consistent layout"
    - "NEWS2 scale selection: bool state field (_hypercapnic) switches static scoring method"
    - "Optional field pattern: empty-string text.trim() check before parsing optional numeric inputs"

key-files:
  modified:
    - "enchiridion/lib/models/calculator_definition.dart"
    - "enchiridion/lib/screens/calculator_screen.dart"

key-decisions:
  - "NEWS2 state holds only _onO2 and _consciousnessScore as state; all other scoring is local to _calculate() to avoid unused field lint"
  - "P/F ratio boundary 300 is inclusive for 'Mild ARDS' (pf >= 300 => mild, pf >= 200 => moderate)"
  - "Corrected sodium validation rejects glucose <= 100 mg/dL with SnackBar (correction factor only applies above 100)"
  - "A-a Gradient FiO2 > 1.0 is rejected with SnackBar; default barometric pressure is 760 mmHg"
  - "Osmolality form accepts optional measured osmolality; gap only shown when measured value is present"

requirements-completed: [REQ-4b]

# Metrics
duration: ~40min
completed: 2026-06-04
---

# Phase 4 Plan 02: 7 Emergency & Critical Care Calculators Summary

**7 Emergency & Critical Care calculators (qSOFA, NEWS2, Shock Index, Osmolality & Osmolar Gap, Corrected Sodium, A-a Gradient, PaO2/FiO2 Ratio) wired end-to-end with 5 enhancement fields, validated forms, and switch cases**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-06-04
- **Completed:** 2026-06-04
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Appended 7 `const CalculatorDefinition` entries to `kCalculators` — all with `category: 'Emergency & Critical Care'`, all placed after `gcs` and `anion-gap` (freemium ordering preserved)
- Each definition populated with all 5 enhancement fields: explanation, clinicalInterpretation, safetyNotes, commonPitfalls, osceTips
- Implemented 7 form classes (`_QsofaForm`, `_News2Form`, `_ShockIndexForm`, `_OsmolalityForm`, `_CorrectedSodiumForm`, `_AaGradientForm`, `_PaO2FiO2Form`) — each preceded by section comment
- All forms: `double.tryParse` + null + physiological-range guards; SnackBar on invalid; all controllers disposed; `super.dispose()` called last
- NEWS2 implements full scale 1 and scale 2 SpO2 scoring (hypercapnic respiratory failure toggle) per RESEARCH.md Pitfall #3
- Osmolality calculates optional osmolar gap when measured osmolality is entered
- A-a Gradient supports optional age (expected gradient calculation) and optional barometric pressure
- Added 7 switch cases to `_buildInputs` before the `default:` branch
- `flutter analyze` clean on both modified files; all pre-existing tests pass (4 screen tests, 2 intentional RED model tests remain RED as expected)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add 7 Emergency & Critical Care definitions to kCalculators** - `d23ec95` (feat)
2. **Task 2: Implement 7 Emergency form classes + switch cases** - `a12f744` (feat)

## Files Created/Modified

- `enchiridion/lib/models/calculator_definition.dart` - 7 new Emergency & Critical Care entries appended (177 lines added)
- `enchiridion/lib/screens/calculator_screen.dart` - 7 form classes + 7 switch cases (610 lines added)

## Decisions Made

- NEWS2 state fields reduced to `_onO2` and `_consciousnessScore` only; scoring is computed inline in `_calculate()` to avoid unused-field warnings
- P/F ratio: boundary value 300 falls in "Mild ARDS (300–400)" band (inclusive lower bound for mild)
- Corrected sodium: Katz 1973 correction factor (0.016 per mg/dL above 100) used; form rejects glucose ≤ 100 with SnackBar
- A-a Gradient: FiO2 validated as fraction (0.0–1.0); PB default 760 mmHg (sea level); optional age for expected gradient
- Osmolality: optional measured osmolality field enables gap calculation; formula 2×Na + glucose/18 + BUN/2.8

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed 5 unused state fields in _News2FormState**
- **Found during:** flutter analyze after Task 2 initial implementation
- **Issue:** `_rrScore`, `_spo2Score`, `_sbpScore`, `_hrScore`, `_tempScore` were declared as mutable state fields but never read (scoring happens locally in `_calculate()`). Produced 5 `unused_field` warnings.
- **Fix:** Removed the 5 unused int fields; scoring methods (`_scoreRR`, `_scoreSpo2Scale1`, etc.) remain as static methods and are called inline
- **Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
- **Commit:** `a12f744` (part of Task 2 commit)

**2. [Rule 1 - Bug] Fixed prefer_const_literals for ACVPU DropdownMenuItems**
- **Found during:** flutter analyze after Task 2
- **Issue:** `items: [ const DropdownMenuItem(...), const DropdownMenuItem(...) ]` should be `items: const [ DropdownMenuItem(...), ... ]`
- **Fix:** Changed to `items: const [...]` list literal
- **Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
- **Commit:** `a12f744` (part of Task 2 commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 - lint/unused fields, const lint)
**Impact on plan:** Minor cleanup only. No scope creep.

## Issues Encountered
None after auto-fixes. Both fixes were caught by `flutter analyze` before committing.

## User Setup Required
None.

## Next Phase Readiness
- Wave 3 plan (04-03) can append Drug Dosing calculators to `kCalculators` after existing entries
- Wave 4 plan (04-04) can append Paediatrics calculators after Drug Dosing entries
- The 2 intentional RED tests (`kCalculators has exactly 26 entries` and `groupByCategory final per-category counts`) remain RED; they will go GREEN after 04-03 and 04-04 add their calculators (currently 15, needs 26)

## Known Stubs
None. All 7 new calculators have non-empty values in all 5 enhancement fields and their form classes implement full formula logic.

## Threat Flags
None. No new network endpoints, auth paths, file access patterns, or schema changes. T-04-03 (user numeric input → _calculate()) mitigated as planned via `double.tryParse` + null + `> 0` guards + SnackBar early return before onResult. T-04-04 (result strings include units and band labels) and T-04-05 (screening-only wording) implemented as specified.

---

## Self-Check

### Files exist:
- [x] `enchiridion/lib/models/calculator_definition.dart` - modified
- [x] `enchiridion/lib/screens/calculator_screen.dart` - modified
- [x] `.planning/phases/04-phase-1-calculators-enhancements-high-priority/04-02-SUMMARY.md` - this file

### Commits exist:
- [x] `d23ec95` - feat(04-02): add 7 Emergency & Critical Care calculator definitions
- [x] `a12f744` - feat(04-02): implement 7 Emergency & Critical Care form classes + switch cases

## Self-Check: PASSED

---
*Phase: 04-phase-1-calculators-enhancements-high-priority*
*Completed: 2026-06-04*
