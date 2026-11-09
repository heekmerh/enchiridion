---
phase: 04-phase-1-calculators-enhancements-high-priority
fixed_at: 2026-06-05T00:00:00Z
review_path: .planning/phases/04-phase-1-calculators-enhancements-high-priority/04-REVIEW.md
iteration: 1
findings_in_scope: 13
fixed: 13
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-06-05T00:00:00Z
**Source review:** .planning/phases/04-phase-1-calculators-enhancements-high-priority/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 13 (5 Critical, 8 Warning)
- Fixed: 13
- Skipped: 0

## Fixed Issues

### CR-01: Insulin Dose — ISF unit mismatch causes grossly wrong correction dose

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `dd72d1c`
**Applied fix:** Added `isfMgDl = _cbgUnit == 'mmol/L' ? rawIsf * 18.0182 : rawIsf` before the
correction dose division so the ISF is converted from mmol/L to mg/dL when the user is working in
mmol/L units (matching the already-converted cbgMgDl and targetMgDl). Also updated the ISF field
label to dynamically show the current unit: `'ISF (${_cbgUnit == 'mmol/L' ? 'mmol/L' : 'mg/dL'} drop per unit of insulin)'`.

---

### CR-02: eGFR CKD-EPI — custom Taylor-series `_lnCalc` diverges for typical creatinine ratios

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `0177ffe`
**Applied fix:** Added `import 'dart:math' as math;` at the top of the file. Replaced `_powCalc`
with a one-line implementation using `math.pow(base, exp).toDouble()`. Deleted `_lnCalc` and
`_expCalc` entirely (both were only used by `_powCalc`). This also covers CR-05 (see below).

---

### CR-03: EDD/EGA — negative gestational age displayed silently

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `1d4e226`
**Applied fix:** Added `if (diff < 0)` guard immediately after computing `diff`, showing a snackbar
("Reference date is before LMP — please check dates") and returning early. This prevents negative
weeks/days from being displayed when the reference date is before the LMP date.

---

### CR-04: `_def` getter crashes with `StateError` for unknown calculator IDs

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `a30aa9c`
**Applied fix:** Converted the `_def` one-liner to a multi-line getter with a try/catch. The catch
block returns a safe fallback `CalculatorDefinition` with id `'unknown'` so the widget tree renders
gracefully rather than crashing with an unhandled StateError.

---

### CR-05: BSA — custom `_sqrtOf` returns incorrect value near zero and is unnecessary

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `0177ffe` (committed together with CR-02)
**Applied fix:** Replaced `_sqrtOf(product)` with `math.sqrt(product)` in the BSA calculation.
Deleted the `_sqrtOf` Babylonian-method method (50-iteration loop). Both CR-02 and CR-05 are in
the same commit since they both involved removing custom math helpers and adding the dart:math import.

---

### WR-01: GCS — intubated total used in severity classification, producing wrong severity band

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `13fd7c8`
**Applied fix:** Added an early-return branch for `_intubated == true` that outputs the E/V(T)/M
result with an interpretation stating severity cannot be classified and instructing the clinician
to trend E and M components. The 13/9 threshold severity labels are now only applied when the
patient is not intubated (full 3–15 scale).

---

### WR-02: Paracetamol — child 24-hour maximum cap of 4 g/day not enforced

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `032f10d`
**Applied fix:** Added a `maxAbsoluteDaily = 4000.0` constant and a `maxAbsolutePerDose = 1000.0`
constant. Per-dose is now capped at 1000 mg. Daily dose is now the minimum of three values:
`dailyByDose`, `maxDailyByKg` (60 mg/kg/day), and `maxAbsoluteDaily` (4000 mg/day), using a
`List.reduce` pattern. Updated interpretation text to reflect both caps.

---

### WR-03: NEWS2 — `tempVal <= 0` guard rejects hypothermic patients

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `4b0190d`
**Applied fix:** Added a plausibility range check after the null/zero guard: `if (tempVal < 25.0 || tempVal > 45.0)` shows a snackbar stating "Temperature must be in °C (plausible range: 25–45°C)" and returns early. This catches accidental Fahrenheit entry (e.g. 98.6°F) and values that are physiologically impossible.

---

### WR-04: Shock Index — division by zero when SBP is entered as 0

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `66caf90`
**Applied fix:** Added plausibility bounds check after the null/zero guard: `if (sbp < 50 || sbp > 300)` shows a snackbar "SBP value appears implausible (expected 50–300 mmHg)" and returns early. This prevents a decimal typo (e.g. SBP=0.1) from producing a Shock Index of 1200 and incorrectly matching the "Shock likely" band.

---

### WR-05: Corrected Sodium — rejects glucose values of exactly 100 mg/dL with misleading error

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `0018c4c`
**Applied fix:** Changed `if (glucose <= 100)` to `if (glucose < 100)`. At glucose == 100 the Katz
formula produces zero correction (a valid result). Also updated the snackbar message from "must be > 100" to "must be >= 100" for consistency with the new boundary.

---

### WR-06: BMI height unit auto-conversion loses precision with ft → cm → ft round-trip

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `7708445`
**Applied fix:** Added a conditional hint widget below the height row that appears when `_heightUnit == 'ft'`,
explaining: "Enter height as decimal feet (e.g. 5.83 for 5'10"). Do not enter feet and inches
separately." This addresses the UI/UX safety concern without changing the conversion algorithm.

---

### WR-07: APLS Weight — boundary case at exactly 5 years uses wrong formula

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `aea5adb`
**Applied fix:** Added a special case for `rawAge == 12` in the months branch that uses the
1–5y formula (`2 × (1 + 4) = 10 kg`) instead of the months formula (which gives 10.5 kg at 12
months). This eliminates the 0.5 kg medical inconsistency between the months and years code paths
for the same 12-month-old child.

---

### WR-08: `_ClinicalNotesSection` is a `StatefulWidget` with no state — unnecessary overhead

**Files modified:** `enchiridion/lib/screens/calculator_screen.dart`
**Commit:** `ff6b873`
**Applied fix:** Converted `_ClinicalNotesSection` from `StatefulWidget` (with a `_ClinicalNotesSectionState`
inner class) to `StatelessWidget`. Replaced `widget.def` references with `def` directly (the widget's
own field). `ExpansionTile` manages its own open/closed state internally; the outer State class added
no value.

---

## Skipped Issues

None — all 13 in-scope findings were fixed successfully.

---

_Fixed: 2026-06-05T00:00:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
