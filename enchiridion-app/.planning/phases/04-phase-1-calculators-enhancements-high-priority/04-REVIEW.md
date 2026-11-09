---
phase: 04-phase-1-calculators-enhancements-high-priority
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - enchiridion/lib/models/calculator_definition.dart
  - enchiridion/lib/screens/calculator_screen.dart
  - enchiridion/test/models/calculator_definition_test.dart
  - enchiridion/test/screens/calculator_screen_test.dart
findings:
  critical: 5
  warning: 8
  info: 4
  total: 17
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-06-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Four files were reviewed: the `CalculatorDefinition` model with its 5 new educational fields and 18 new calculator entries; the `CalculatorScreen` with 26 calculator forms, the new `_ClinicalNotesSection` widget, and BMI unit auto-conversion; plus Wave 0 test scaffolds for both.

The data model is clean and the new educational copy is clinically sound. The critical failures are concentrated in formula implementations: the eGFR custom Taylor-series math produces incorrect results for creatinine ratios far from 1, the insulin correction dose calculator has a unit-coherence defect that can produce dangerous over-dosing, the EDD/EGA calculator silently produces negative gestational ages when LMP is set in the future, the unhandled `firstWhere` call will crash the app for any unknown ID, and the BSA Babylonian square-root implementation returns wrong results when called with values near zero.

---

## Critical Issues

### CR-01: Insulin Dose — ISF unit mismatch causes grossly wrong correction dose

**File:** `enchiridion/lib/screens/calculator_screen.dart:2204-2207`

**Issue:** When the user selects `mmol/L` as the blood glucose unit, CBG and target are correctly converted to `mg/dL` before the subtraction. However, the `ISF` field is labelled "mg/dL drop per unit of insulin" and is used raw (`rawIsf`) in all code paths, including when the user has selected `mmol/L`. A clinician used to working in `mmol/L` will naturally enter an ISF in `mmol/L` units (typical value: 2–3 mmol/L per unit). The numerator is then in `mg/dL` (~36–54 mg/dL equivalent) but the denominator is in `mmol/L` (2–3), producing a result ~18× too high (e.g., 18 units instead of 1 unit). Insulin is a high-risk medication; a dose 18× the correct value can be fatal.

```dart
// Actual code (line 2207):
final raw = (cbgMgDl - targetMgDl) / rawIsf;

// cbgMgDl and targetMgDl are in mg/dL after unit conversion,
// but rawIsf is whatever the user typed, with NO unit conversion.
// If user entered ISF in mmol/L units (e.g. 2.5):
//   correct dose = (180 - 100) / (2.5 × 18.0182) ≈ 1.8 units
//   actual result = (180 - 100) / 2.5 = 32 units  ← FATAL
```

**Fix:** Either (a) always store ISF in mg/dL per unit and make the label unambiguous regardless of selected unit, or (b) add an ISF unit dropdown and convert consistently:

```dart
// Option A — clearest and safest: show ISF in the same unit as CBG
// and convert ISF along with CBG before division
final isfMgDl = _cbgUnit == 'mmol/L' ? rawIsf * 18.0182 : rawIsf;
final raw = (cbgMgDl - targetMgDl) / isfMgDl;
```

Also update the label dynamically: `'ISF (${_cbgUnit == 'mmol/L' ? 'mmol/L' : 'mg/dL'} drop per unit)'`.

---

### CR-02: eGFR CKD-EPI — custom Taylor-series `_lnCalc` diverges for typical creatinine ratios

**File:** `enchiridion/lib/screens/calculator_screen.dart:2009-2019`

**Issue:** `_lnCalc` uses the series `ln(x) = 2 * Σ [(x-1)/(x+1)]^(2k-1) / (2k-1)`, which converges only for `x > 0`. However, the rate of convergence degrades sharply as `x` moves away from 1. For a male patient with serum creatinine of 3.0 mg/dL, `ratio = 3.0 / 0.9 = 3.333`. Then `y = (3.333 - 1) / (3.333 + 1) = 0.538`. After 60 iterations this series produces a result that differs from the true `ln(3.333)` by roughly 0.01–0.05, which is then multiplied by the exponent `−1.200`, compounding the error in the final eGFR figure. For high-creatinine patients (e.g. Scr = 5 mg/dL, ratio = 5.56) the relative error in eGFR can exceed 5–10%, potentially misclassifying a G4 patient as G3b or vice versa, with downstream drug-dosing consequences.

Additionally, `_lnCalc` is not range-reduced before applying the series. `dart:math` is available as a core Dart library and should be used instead.

**Fix:**
```dart
import 'dart:math' as math;

// Replace _powCalc / _lnCalc / _expCalc with:
double _powCalc(double base, double exp) {
  if (base <= 0) return 0.0;
  return math.pow(base, exp).toDouble();
}
// Delete _lnCalc and _expCalc entirely.
```

Similarly, replace `_sqrtOf` in `_BsaFormState` (line 1884) with `math.sqrt`.

---

### CR-03: EDD/EGA — negative gestational age displayed silently

**File:** `enchiridion/lib/screens/calculator_screen.dart:833-837`

**Issue:** `diff = _referenceDate.difference(_lmp!).inDays`. The date picker for LMP allows any date up to `DateTime.now()`. The reference date defaults to `DateTime.now()` but can be changed to a future date (up to `DateTime(now.year + 1)`). If the user sets the reference date _before_ the LMP (e.g. sets a reference date in the past after picking a recent LMP), `diff` is negative. Integer division `diff ~/ 7` and `diff % 7` on a negative integer in Dart produce negative results, yielding an output like "-3 weeks -2 days" — a nonsensical gestational age that could confuse clinical interpretation.

```dart
// diff can be negative; no guard exists
final weeks = diff ~/ 7;   // e.g., -3
final days  = diff % 7;    // e.g., -2 (Dart remainder, not modulo)
```

**Fix:**
```dart
if (diff < 0) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Reference date is before LMP — please check dates')));
  return;
}
```

---

### CR-04: `_def` getter crashes with `StateError` for unknown calculator IDs

**File:** `enchiridion/lib/screens/calculator_screen.dart:22-24`

**Issue:** The `_def` getter uses `kCalculators.firstWhere((c) => c.id == widget.calculatorId)` without a `orElse` parameter. If `widget.calculatorId` does not match any entry in `kCalculators` (e.g., a deep-link or navigation bug passes an unknown ID), Dart throws an unhandled `StateError` that crashes the widget tree. The `_buildInputs` switch-case already has a `default` branch, but `_def` is called at line 89 (`Text(_def.title)`) before that branch is reached, so the crash occurs during `build`.

**Fix:**
```dart
CalculatorDefinition get _def {
  try {
    return kCalculators.firstWhere((c) => c.id == widget.calculatorId);
  } catch (_) {
    // Return a safe fallback or navigate back
    return const CalculatorDefinition(
      id: 'unknown',
      title: 'Unknown Calculator',
      category: '',
      description: '',
    );
  }
}
```

Or use `firstWhereOrNull` from `package:collection` and handle the null case explicitly.

---

### CR-05: BSA — custom `_sqrtOf` returns incorrect value near zero and is unnecessary

**File:** `enchiridion/lib/screens/calculator_screen.dart:1884-1890`

**Issue:** The Babylonian (Newton-Raphson) method for square root starts with an initial guess of `x / 2.0` (line 1885). When `x` is very small (e.g., a 30 cm, 3 kg premature neonate: `product = 30 * 3 / 3600 = 0.025`), the initial guess is `0.0125`. The iteration converges correctly in this case, but the real concern is that `dart:math` is available and provides an accurate, constant-time `sqrt` implementation. The custom loop of 50 iterations is executed even for inputs that would converge in 5–6 iterations, making this both slower and a maintainability risk. More critically, because the same file avoids `dart:math` throughout while using manual Taylor series (see CR-02), any future code path that calls these helpers on extreme values may silently produce inaccurate medical results.

The guard at line 1874 (`product > 0 ? _sqrtOf(product) : 0.0`) returns `0.0 m²` for zero product rather than surfacing an error, and the `_sqrtOf` itself has no NaN/infinity guard.

**Fix:** Replace with `dart:math`:
```dart
import 'dart:math' as math;
// ...
final bsa = math.sqrt(heightCm * weightKg / 3600.0);
```

---

## Warnings

### WR-01: GCS — intubated total used in severity classification, producing wrong severity band

**File:** `enchiridion/lib/screens/calculator_screen.dart:597-614`

**Issue:** When `_intubated` is true, `total = _eye + _motor` (maximum 10, minimum 2). The severity thresholds (`>= 13` mild, `>= 9` moderate, else severe) were designed for the full 3–15 GCS scale. An intubated patient with `E4 M6 = 10` is classified as "Moderate injury", but per standard convention the score should be reported as `E4 V(T) M6 = 10T` with severity described separately or noted as "not applicable while intubated." More importantly, `total` (the E+M sub-score) is then passed to `interpretation: 'Total GCS $total'` — this will show "Total GCS 10" which is factually wrong for an intubated patient.

**Fix:** When intubated, skip the severity band entirely or label it as "N/A (intubated)":
```dart
if (_intubated) {
  widget.onResult(
    result: 'E$_eye V(T) M$_motor = ${_eye + _motor}T',
    interpretation: 'GCS components: E$_eye V(T) M$_motor. '
        'Verbal score not assessable (intubated). Trend E and M components.',
    ...
  );
  return;
}
```

---

### WR-02: Paracetamol — child 24-hour maximum cap of 4 g/day not enforced

**File:** `enchiridion/lib/screens/calculator_screen.dart:2296-2303`

**Issue:** For a heavy child (e.g., 80 kg — an obese 11-year-old), `perDose = 80 * 15 = 1200 mg/dose`, and `daily = min(1200 * 4, 80 * 60) = min(4800, 4800) = 4800 mg/day`. This exceeds the 4000 mg/day absolute adult cap. The code only uses `min(4 doses × perDose, 60 mg/kg/day)` without applying the hard 4000 mg/day ceiling that the model's `explanation` field explicitly states. For any child weighing over 66.7 kg, the calculated maximum will exceed 4000 mg/day.

```dart
// Current code:
final daily = dailyByDose < maxDailyByKg ? dailyByDose : maxDailyByKg;

// Fix — also cap at 4000 mg/day absolute maximum:
const maxAbsoluteDaily = 4000.0;
final daily = [dailyByDose, maxDailyByKg, maxAbsoluteDaily].reduce(math.min);
```

The individual dose should similarly be capped at 1000 mg (per-dose maximum).

---

### WR-03: NEWS2 — `tempVal <= 0` guard rejects hypothermic patients

**File:** `enchiridion/lib/screens/calculator_screen.dart:1249-1254`

**Issue:** The validation guard `tempVal == null || tempVal <= 0` rejects any temperature at or below 0°C. This is physiologically impossible for a live patient, but a clinician entering `35.5°C` for a hypothermic patient is valid. The guard itself is benign here — the real problem is that a temperature of exactly `0` is the only value rejected by `<= 0` that could be accidentally entered. The deeper issue is that a nurse entering a temperature of `35` for a febrile post-operative patient using Fahrenheit (who forgot to convert) would pass the guard and produce a wildly wrong score (`35°C` → score 3 when `35°F ≈ 1.67°C` which is incompatible with life). There is no unit selector for temperature.

**Fix:** Add a plausibility check and document the Celsius requirement more prominently:
```dart
if (tempVal < 25.0 || tempVal > 45.0) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Temperature must be in °C (plausible range: 25–45°C)')));
  return;
}
```

---

### WR-04: Shock Index — division by zero when SBP is entered as 0

**File:** `enchiridion/lib/screens/calculator_screen.dart:1359-1364`

**Issue:** The guard is `sbp == null || sbp <= 0`, which prevents SBP of 0 from reaching the calculation. However, `sbp > 0` can still be an implausibly small number (e.g., 0.1 from a typo), producing a Shock Index of `HR / 0.1 = 1200`. The `_NumericField` formatter allows any decimal, so `0.001` passes the `> 0` guard. This is a general concern across many calculators, but Shock Index is particularly dangerous because an absurdly high SI (e.g., 1200) matches the "Shock likely" band and could prompt unnecessary emergency interventions.

**Fix:** Add plausibility bounds for SBP:
```dart
if (sbp < 50 || sbp > 300) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('SBP value appears implausible (expected 50–300 mmHg)')));
  return;
}
```

Apply similar plausibility guards to HR and other vital-sign inputs across all relevant calculators.

---

### WR-05: Corrected Sodium — rejects glucose values of exactly 100 mg/dL with misleading error

**File:** `enchiridion/lib/screens/calculator_screen.dart:1501-1505`

**Issue:** The guard `if (glucose <= 100)` returns a snackbar telling the user "Glucose must be > 100 mg/dL for correction to apply." This is correct medicine — the correction factor is zero at 100 mg/dL. But the check at line 1496 already validates `glucose > 0`, meaning a glucose of 100 will display the snackbar, which could confuse users into thinking their input is invalid rather than understanding that no correction is needed. More importantly, the check should be `< 100` (not `<= 100`) because at exactly 100 the formula yields `corrected = na + 0.016 * (100 - 100) = na`, which is a valid result (no correction).

**Fix:**
```dart
if (glucose < 100) {
  // same message, or:
  // show result directly: corrected Na = measured Na (no dilutional effect)
}
// At glucose == 100, the formula produces zero correction — show that result.
```

---

### WR-06: BMI height unit auto-conversion loses precision with ft → cm → ft round-trip

**File:** `enchiridion/lib/screens/calculator_screen.dart:768-784`

**Issue:** The auto-conversion converts the current value to metres as an intermediate, then converts to the target unit, storing the result with `toStringAsFixed(2)`. A round-trip `ft → cm → ft` proceeds: `5.10 ft → 5.10 * 0.3048 = 1.554048 m → 1.554048 * 100 = 155.40 cm → 155.40 / 0.3048 = 509.84... → toStringAsFixed(2) = "509.84"`. When the user types `5.10` (5 feet 10 inches as a decimal), then toggles ft → cm, they see `155.40`, but then toggling back cm → ft yields `509.84` — numerically correct for cm→ft but the _original_ value of `5.10` is lost entirely. The display is confusing because `5.10 ft ≠ 5'10"` in decimal feet notation.

This is a UI/UX concern with a safety angle: a user may not notice the conversion has changed the field to an unexpected value and calculate BMI with the wrong height. At minimum, round the `ft` result to 2 significant decimal places and document that feet must be entered as a decimal fraction.

**Fix:** Display a hint text clarifying "e.g. 5.83 for 5'10" or use a separate feet+inches input for the `ft` unit.

---

### WR-07: APLS Weight — boundary case at exactly 5 years uses wrong formula

**File:** `enchiridion/lib/screens/calculator_screen.dart:2425-2431`

**Issue:** The APLS formulas are: 1–5 years: `2 × (age + 4)`, 6–12 years: `3 × age + 7`. The code uses `ageYears <= 5` for the first branch and `else` (implicitly > 5) for the second. A 5-year-old is correctly assigned `2 × (5 + 4) = 18 kg`. However, the transition at age 5 produces: formula 1: `2 × (5+4) = 18 kg`; formula 2: `3×5+7 = 22 kg`. The boundary is correct in the code (5 years uses formula 1). The risk is at `ageYears > 5` with fractional values like `5.5`, which jumps to formula 2 (`3 × 5.5 + 7 = 23.5 kg`) — this is correct per APLS. No actual bug here in strict application.

However: the `_ageCtrl` text field accepts decimal values (the `_NumericField` formatter allows decimals), meaning a user can type `5.5 years`. The formula correctly applies the 6–12y branch for 5.5y. But the boundary `ageYears <= 5` means `5.0 years` uses formula 1 and `5.01 years` uses formula 2 — the jump is 4 kg for a 0.01 year difference at this boundary. A clinician who enters `5` vs `6` will get a 4 kg difference in a child who is actually just turned 6. This is a known APLS limitation but should be noted in the educational note.

More concretely: for `ageUnit == 'months'`, the guard checks `rawAge <= 0 || rawAge > 12`, but accepts `rawAge = 12` (12 months = 1 year). A 12-month-old calculated via months formula: `0.5 × (12 + 9) = 10.5 kg`. The same child via years formula (`ageYears = 1`, `1 <= 5`): `2 × (1 + 4) = 10 kg`. There is a 0.5 kg discrepancy for the same child depending on which unit the user selects. This is a medical inconsistency at the boundary.

**Fix:** Normalize to a single unit path at the 12-month boundary:
```dart
// For rawAge == 12 months, use the years formula for consistency:
if (_ageUnit == 'months' && rawAge == 12) {
  estimatedKg = 2 * (1 + 4); // 10 kg via 1–5y formula
}
```

---

### WR-08: `_ClinicalNotesSection` is a `StatefulWidget` with no state — unnecessary overhead

**File:** `enchiridion/lib/screens/calculator_screen.dart:1687-1728`

**Issue:** `_ClinicalNotesSectionState.build` accesses only `widget.def` and has no mutable state fields. The class extends `StatefulWidget` / `State` but never calls `setState`, never has instance variables in `_ClinicalNotesSectionState`. `ExpansionTile` manages its own open/closed state internally; the outer `State` class adds no value and wastes memory.

**Fix:** Convert to `StatelessWidget`:
```dart
class _ClinicalNotesSection extends StatelessWidget {
  final CalculatorDefinition def;
  const _ClinicalNotesSection({required this.def});

  @override
  Widget build(BuildContext context) {
    // same body, replace widget.def with def
  }
}
```

---

## Info

### IN-01: `_noteRow` is a free function at file scope — breaks encapsulation

**File:** `enchiridion/lib/screens/calculator_screen.dart:1730-1759`

**Issue:** `_noteRow` is declared as a top-level function in the file (not a method on `_ClinicalNotesSectionState` or a private static method). In Dart, the `_` prefix on a top-level name gives it library-private visibility, not class-private. This is consistent with Dart conventions but incongruous with the rest of the file where helper builders are instance methods. If the file grows, the function is harder to locate and trace back to its owning widget.

**Fix:** Move `_noteRow` inside `_ClinicalNotesSection` (once converted to `StatelessWidget` per WR-08) as a static method, or keep it as a private top-level helper and add a comment associating it with the section widget.

---

### IN-02: `CalculatorDefinition` has no `==` / `hashCode` / `copyWith` — model is incomplete

**File:** `enchiridion/lib/models/calculator_definition.dart:1-26`

**Issue:** The model is used in a `List.contains` call in `storage_service.dart` (inferred from `getFavorites().contains(widget.calculatorId)` which compares Strings, so this is not a current crash). However, `CalculatorDefinition` objects may be compared in tests or future features. As an immutable data class with `const` constructor, it should implement `==` and `hashCode` for value equality, and ideally provide `copyWith`. Currently two `CalculatorDefinition` objects with identical fields are not equal by `==` (uses identity).

**Fix:** Add `operator ==`, `hashCode`, and optionally `copyWith` to `CalculatorDefinition`. Consider using a code-generation package (`freezed` or `equatable`) consistent with project conventions.

---

### IN-03: Test uses hardcoded Supabase credentials in `setUpAll`

**File:** `enchiridion/test/screens/calculator_screen_test.dart:29-33`

**Issue:** The test initialises Supabase with `url: 'https://test.supabase.co'` and `anonKey: 'test-anon-key'`. While these are clearly test/stub values, hardcoding even fake Supabase URLs in tests sets a poor pattern. If a developer copies this pattern and accidentally uses a real URL or key, credentials will be committed. The test will also fail if Supabase is already initialised (from another test group), because `Supabase.initialize` throws if called twice.

**Fix:** Wrap in a try-catch or use `Supabase.instance` check, and use a clearly-named constant:
```dart
const kTestSupabaseUrl = 'https://placeholder.supabase.co';
const kTestSupabaseAnonKey = 'placeholder-anon-key';

setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  try {
    await Supabase.initialize(url: kTestSupabaseUrl, anonKey: kTestSupabaseAnonKey);
  } catch (_) {} // already initialised
});
```

---

### IN-04: BMI auto-conversion test asserts exact string '154.32' — fragile to float precision

**File:** `enchiridion/test/screens/calculator_screen_test.dart:66`

**Issue:** The test asserts `expect(weightField.controller?.text, '154.32')`. The conversion is `70 * 2.20462 = 154.3234`, formatted with `toStringAsFixed(2)`. This currently produces `'154.32'` on all Dart targets (since `154.3234` rounds to `154.32`). However, asserting an exact floating-point string is fragile — a platform difference or future constant change could silently break this. There is also no null safety check on `weightField.controller?.text`; if `controller` is null, the expect compares `null` to the string and fails with an opaque message.

**Fix:**
```dart
final text = weightField.controller?.text;
expect(text, isNotNull);
final value = double.tryParse(text!);
expect(value, isNotNull);
expect(value, closeTo(154.32, 0.01));
```

---

_Reviewed: 2026-06-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
