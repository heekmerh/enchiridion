---
phase: 04-phase-1-calculators-enhancements-high-priority
plan: 01
subsystem: ui
tags: [flutter, dart, calculators, bmi, clinical-notes, widget-test, unit-test]

# Dependency graph
requires:
  - phase: 03-content-lock-resources-redesign
    provides: "existing calculator architecture with 8 calculators, StorageService, flutter test infrastructure"
provides:
  - "CalculatorDefinition with 5 educational enhancement fields (explanation, clinicalInterpretation, safetyNotes, commonPitfalls, osceTips)"
  - "_ClinicalNotesSection widget rendering enhancement fields as collapsible ExpansionTile"
  - "All 8 existing calculators populated with clinical content in all 5 enhancement fields"
  - "BMI auto-conversion: weight (kg<->lb) and height (cm/m/ft) auto-converts on unit change"
  - "Wave 0 test scaffolds (calculator_definition_test.dart, calculator_screen_test.dart) for Wave 2-4 plans"
affects:
  - "04-02-PLAN: can extend kCalculators and rely on model + widget being present"
  - "04-03-PLAN: same dependency"
  - "04-04-PLAN: same dependency"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_ClinicalNotesSection: StatefulWidget wrapping ExpansionTile, self-hides when all 5 fields empty"
    - "Enhancement fields: optional final String fields with '' defaults on const CalculatorDefinition"
    - "BMI unit conversion: guard null/same-unit, tryParse + >0 before converting via intermediate (meters for height)"
    - "Wave 0 test scaffolds: annotated RED tests with // Goes GREEN at end of Phase 4 comments"

key-files:
  created:
    - "enchiridion/test/models/calculator_definition_test.dart"
    - "enchiridion/test/screens/calculator_screen_test.dart"
  modified:
    - "enchiridion/lib/models/calculator_definition.dart"
    - "enchiridion/lib/screens/calculator_screen.dart"

key-decisions:
  - "5 new CalculatorDefinition fields default to '' to preserve const compatibility with all 8 existing entries"
  - "BMI height conversion uses meters as intermediate unit (cm/m/ft all convert via meters), not direct pairwise"
  - "_ClinicalNotesSection placed unconditionally — self-hides via SizedBox.shrink() when all fields empty"
  - "_noteRow defined as file-level function (not method) since it needs BuildContext but no state"
  - "26-count and final category-count tests written as intentional RED with annotation comments"

patterns-established:
  - "Pattern: enhancement fields on CalculatorDefinition populated via string literals in const constructor"
  - "Pattern: ExpansionTile + conditional _noteRow children for static clinical metadata display"
  - "Pattern: unit dropdown onChanged with tryParse guard before conversion"

requirements-completed: [REQ-4e, REQ-4f]

# Metrics
duration: 45min
completed: 2026-06-04
---

# Phase 4 Plan 01: Calculator Foundation — Enhancement Fields, Clinical Notes, BMI Fix Summary

**CalculatorDefinition extended with 5 educational fields + _ClinicalNotesSection ExpansionTile widget + BMI unit auto-conversion fix + Wave 0 test scaffolds for all 8 existing calculators**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-04T00:00:00Z
- **Completed:** 2026-06-04
- **Tasks:** 4 (+ 1 auto-fix deviation)
- **Files modified:** 4

## Accomplishments
- Extended `CalculatorDefinition` model with 5 optional string fields (explanation, clinicalInterpretation, safetyNotes, commonPitfalls, osceTips) defaulting to '' — all 8 existing const entries compile unchanged
- Populated all 5 fields for all 8 existing calculators (weight-dosing, iv-infusion, gcs, bmi, edd-ega, anion-gap, creatinine-clearance, holliday-segar) with clinically appropriate content
- Added `_ClinicalNotesSection` widget: collapsible ExpansionTile showing non-empty fields with icons; self-hides (SizedBox.shrink) when all 5 fields are empty
- Fixed BMI unit auto-conversion: weight kg<->lb and height cm/m/ft auto-convert without data loss on unit change; T-04-01 (STRIDE) mitigated with double.tryParse + current > 0 guard
- Created Wave 0 test scaffolds: 2 new test files with 10 tests (8 green, 2 intentional RED annotated to go green at Phase 4 end)

## Task Commits

Each task was committed atomically:

1. **Task 1: Write Wave 0 test scaffolds (RED)** - `b03f40f` (test)
2. **Task 2: Extend CalculatorDefinition model + populate 8 existing calculators** - `5a1b63b` (feat)
3. **Task 3: Add _ClinicalNotesSection widget + wire into build tree** - `4d0daa0` (feat)
4. **Task 4: Fix BMI unit auto-conversion** - `7aada32` (fix)
5. **Auto-fix: Remove unused import** - `b796078` (fix - Rule 1)

## Files Created/Modified
- `enchiridion/lib/models/calculator_definition.dart` - 5 new fields + content for all 8 existing calculators
- `enchiridion/lib/screens/calculator_screen.dart` - _ClinicalNotesSection widget + _noteRow helper + BMI auto-conversion
- `enchiridion/test/models/calculator_definition_test.dart` - Wave 0 model unit tests (NEW)
- `enchiridion/test/screens/calculator_screen_test.dart` - Wave 0 widget tests: ClinicalNotes + BMI conversion (NEW)

## Decisions Made
- Used '' defaults for all 5 new fields on CalculatorDefinition to avoid breaking existing const entries (critical for Dart const correctness)
- BMI height conversion uses meters as an intermediate representation rather than direct pairwise (cleaner, handles all 6 pair directions)
- _ClinicalNotesSection self-hides — placed unconditionally in build tree, no wrapper needed
- _noteRow defined as file-level function to access BuildContext without being a class method
- 26-count and per-category tests written at the final expected values and annotated RED — Wave 2-4 plans will make them green without needing to change test expectations

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused import in calculator_screen_test.dart**
- **Found during:** Post-Task 4 flutter analyze
- **Issue:** `package:enchiridion/models/calculator_definition.dart` was imported but not directly used in the test file (used indirectly via CalculatorScreen)
- **Fix:** Removed the unused import
- **Files modified:** enchiridion/test/screens/calculator_screen_test.dart
- **Verification:** `flutter analyze` reports no errors for new files
- **Committed in:** b796078 (fix commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - unused import)
**Impact on plan:** Minor cleanup only. No scope creep.

## Issues Encountered
- None. All tasks executed as planned with one minor unused-import cleanup.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Wave 2-4 plans (04-02, 04-03, 04-04) can now add new calculators using the established patterns
- Wave 0 test scaffolds in place — downstream plans extend the same test files
- _ClinicalNotesSection already in build tree — new calculators with populated fields will auto-show Clinical Notes
- 2 RED tests (26-count, final category counts) annotated and waiting for Wave 2-4 to go GREEN

## Known Stubs
None - all 8 existing calculators have non-empty values in all 5 enhancement fields. The Clinical Notes section renders for all 8 existing calculators.

## Threat Flags
None — no new network endpoints, auth paths, file access patterns, or schema changes beyond what the plan's threat model covers. T-04-01 (BMI conversion tampering) mitigated as planned via double.tryParse + current > 0 guard.

---
*Phase: 04-phase-1-calculators-enhancements-high-priority*
*Completed: 2026-06-04*
