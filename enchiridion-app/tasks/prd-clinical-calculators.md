# PRD: Clinical Calculators

## Introduction

Enchiridion includes a clinical calculator module organized by specialty. Every calculator follows a shared screen pattern with inputs, a result block, interpretation, educational notes, and a safety disclaimer. This PRD covers the calculator engine (shared pattern + UX system) and the 8 fully-specified v1 calculators. The target is Android and iOS via Flutter, with Supabase used for persisting saved/favorite calculators.

---

## Goals

- Implement a reusable calculator screen pattern usable by all calculators
- Implement the 8 v1 calculators with correct formulas and clinical interpretations
- Allow users to save calculators to a favorites list
- Enforce safety and disclaimer requirements across all calculators

---

## User Stories

### US-001: Calculator Engine â€” Shared Screen Pattern
**Description:** As a developer, I need a reusable calculator screen widget so that each calculator only needs to define its inputs, formula, and interpretation rules.

**Acceptance Criteria:**
- [x] A `CalculatorScreen` widget accepts a `CalculatorDefinition` object and renders the full shared screen
- [x] `CalculatorDefinition` model has: `id`, `title`, `category`, `description`, `inputs` (list), `formula` (function), `interpretationRules` (list), `disclaimer`
- [x] The screen renders sections in order: title + description, inputs, calculate button, result block (hidden until calculated), interpretation, educational notes, safety disclaimer, action buttons (Calculate Â· Copy Result Â· Reset Â· Save to Favorites)
- [x] The "Calculate" button is disabled until all required inputs have valid values
- [x] Tapping "Reset" clears all input fields and hides the result block
- [x] Flutter analyzer passes with no errors

### US-002: Real-time Input Validation
**Description:** As a user, I want to see plain-English error messages when I enter invalid values so that I know what to fix before calculating.

**Acceptance Criteria:**
- [x] Each input field validates on change (not only on submit)
- [x] Negative or zero numeric values show: "Enter a value greater than 0"
- [x] Empty required fields show: "This field is required"
- [x] Out-of-range values (where defined per calculator) show a specific range message (e.g. "Age must be between 0 and 120")
- [x] Error messages appear inline below the relevant field
- [x] The "Calculate" button remains disabled while any field has a validation error
- [x] Flutter analyzer passes with no errors

### US-003: Unit Selectors
**Description:** As a user, I want to select units for inputs (e.g. kg or lb, cm or ft/in) so that I can use values in the unit I already have.

**Acceptance Criteria:**
- [x] Input fields that support multiple units have a unit selector (dropdown or toggle) adjacent to the field
- [x] Changing the unit converts the currently entered value to the new unit automatically
- [x] Last-used unit is remembered within the session (not persisted across app restarts in v1)
- [x] Flutter analyzer passes with no errors

### US-004: Copy Result
**Description:** As a clinician, I want to copy the calculated result as formatted text so that I can paste it into clinical notes.

**Acceptance Criteria:**
- [x] "Copy Result" button appears after a result is calculated
- [x] Tapping it copies a human-readable string to the clipboard, e.g.: `"GCS Score: 12 (E3 V4 M5) â€” Moderate injury"`
- [x] A brief confirmation (SnackBar or toast) appears: "Result copied to clipboard"
- [x] Flutter analyzer passes with no errors

### US-005: Save to Favorites
**Description:** As a user, I want to save frequently used calculators to a favorites list so that I can access them quickly.

**Acceptance Criteria:**
- [x] Each calculator screen has a "Save to Favorites" / heart icon button
- [x] Tapping it toggles the saved state; icon fills when saved, outlined when not
- [x] Saved state is stored locally on-device (favorites migrated from Supabase to SharedPreferences)
- [x] A "Favorites" section on the calculator list screen shows all saved calculators at the top
- [x] Flutter analyzer passes with no errors

### US-006: Calculator List Screen
**Description:** As a user, I want to browse all available calculators organized by category so that I can find the one I need.

**Acceptance Criteria:**
- [x] A calculator list screen shows all 8 v1 calculators grouped by category
- [x] Each item shows: calculator title and one-line description
- [x] Favorites are shown in a pinned section at the top
- [x] Tapping any item navigates to that calculator's screen
- [x] Flutter analyzer passes with no errors

### US-007: Weight-Based Drug Dosing (mg/kg)
**Description:** As a clinician, I want to calculate the total dose for a weight-based drug order so that I can prepare or verify the correct amount.

**Inputs:**
- Patient weight (kg or lb)
- Dose per kg (mg/kg)
- Frequency (once / BD / TDS / QID / other)
- Maximum dose (mg) â€” optional

**Acceptance Criteria:**
- [x] Formula: `total_dose = weight_kg Ã— dose_per_kg`; if max dose provided and total_dose > max_dose, cap at max_dose and show warning
- [x] Result block shows: total dose (mg), per-dose amount, frequency label
- [x] If max dose cap is applied, result shows: "Max dose applied: [max_dose] mg (calculated: [raw_dose] mg)"
- [x] Interpretation explains dose in plain language and notes the max-dose cap if triggered
- [x] Safety note: "Verify dose against current formulary and institutional guidelines"
- [x] Flutter analyzer passes with no errors

### US-008: IV Infusion Rate
**Description:** As a clinician, I want to calculate IV infusion rate in mL/hr or drops/min so that I can set up the drip correctly.

**Inputs:**
- Total volume (mL)
- Infusion time (hours or minutes)
- Mode selector: mL/hr or gtt/min
- Drop factor (drops/mL) â€” shown only in gtt/min mode; standard options: 10, 15, 20, 60

**Acceptance Criteria:**
- [x] mL/hr formula: `rate = volume_mL / time_hr`
- [x] gtt/min formula: `rate = (volume_mL Ã— drop_factor) / time_min`
- [x] Result block shows the rate in the selected mode's unit, rounded to 1 decimal place
- [x] Switching mode recalculates immediately if all inputs are valid
- [x] Safety note: "Double-check pump settings before starting infusion"
- [x] Flutter analyzer passes with no errors

### US-009: Glasgow Coma Scale (GCS)
**Description:** As a clinician, I want to calculate GCS score from Eye, Verbal, and Motor subscores so that I can document and interpret a patient's conscious level.

**Inputs:**
- Eye response (E): 1â€“4 (with labeled options)
- Verbal response (V): 1â€“5 (with labeled options); intubated toggle sets V to "T" (not scored)
- Motor response (M): 1â€“6 (with labeled options)

**Acceptance Criteria:**
- [x] Each subscale is a labeled selector (not a free-text field), showing the clinical descriptor for each score (e.g. E4 = "Spontaneous", E3 = "To voice")
- [x] Total score = E + V + M (when not intubated); displays as "E[n] V[n] M[n] = [total]"
- [x] When intubated toggle is on, Verbal shows "T" and total is displayed as "[E+M]T"
- [x] Severity interpretation: 13â€“15 Mild, 9â€“12 Moderate, 3â€“8 Severe
- [x] Educational note: "A GCS â‰¤ 8 is the conventional threshold for considering airway protection"
- [x] Safety note: "GCS alone does not determine airway management â€” use full clinical assessment"
- [x] Flutter analyzer passes with no errors

### US-010: BMI
**Description:** As a clinician or user, I want to calculate BMI from weight and height so that I can determine weight category.

**Inputs:**
- Weight (kg or lb)
- Height (cm, m, or ft/in)

**Acceptance Criteria:**
- [x] Formula: `BMI = weight_kg / height_mÂ²`
- [x] Result shows BMI to 1 decimal place and WHO weight category: Underweight (<18.5), Normal (18.5â€“24.9), Overweight (25â€“29.9), Obese (â‰¥30)
- [x] Obesity sub-classification: Class I (30â€“34.9), Class II (35â€“39.9), Class III (â‰¥40)
- [x] Interpretation explains category in plain language
- [x] Educational note: "BMI does not account for muscle mass or fat distribution"
- [x] Flutter analyzer passes with no errors

### US-011: EDD / EGA Calculator
**Description:** As a clinician, I want to calculate the Estimated Delivery Date and Gestational Age from LMP so that I can track pregnancy progress.

**Inputs:**
- LMP date (date picker)
- Reference date (optional date picker; defaults to today)

**Acceptance Criteria:**
- [x] EDD formula (Naegele's rule): LMP + 280 days
- [x] EGA formula: `(reference_date - LMP).days / 7` expressed as "X weeks Y days"
- [x] Result shows: EDD as a formatted date (e.g. "15 Jan 2026") and EGA as "X weeks Y days"
- [x] If reference date is after EDD, shows: "Past EDD by [n] days"
- [x] LMP date cannot be in the future; shows validation error if selected
- [x] Educational note: "EGA is more accurately determined by first-trimester ultrasound when available"
- [x] Flutter analyzer passes with no errors

### US-012: Anion Gap
**Description:** As a clinician, I want to calculate anion gap from electrolytes so that I can classify metabolic acidosis.

**Inputs:**
- Sodium Naâº (mEq/L)
- Chloride Clâ» (mEq/L)
- Bicarbonate HCOâ‚ƒâ» (mEq/L)

**Acceptance Criteria:**
- [x] Formula: `AG = Naâº - (Clâ» + HCOâ‚ƒâ»)`
- [x] Normal range: 8â€“12 mEq/L; result block shows value and category: Low (<8), Normal (8â€“12), Elevated (>12)
- [x] Interpretation for elevated AG suggests common causes: MUDPILES mnemonic (Methanol, Uraemia, DKA, Paracetamol/propylene glycol, Isoniazid/Iron, Lactic acidosis, Ethylene glycol, Salicylates)
- [x] Educational note: "Consider albumin correction if hypoalbuminaemia is present"
- [x] Flutter analyzer passes with no errors

### US-013: Creatinine Clearance (Cockcroft-Gault)
**Description:** As a clinician, I want to estimate creatinine clearance so that I can adjust drug dosing for renal function.

**Inputs:**
- Age (years, integer)
- Sex (male / female selector)
- Weight (kg or lb)
- Serum creatinine (mg/dL or Âµmol/L)

**Acceptance Criteria:**
- [x] Formula: `CrCl = [(140 - age) Ã— weight_kg] / (72 Ã— SCr_mg/dL)`; multiply by 0.85 if female
- [x] If SCr input is in Âµmol/L, convert: `SCr_mg/dL = SCr_Âµmol/L / 88.4`
- [x] Result shows CrCl in mL/min to 1 decimal place and kidney function band: Normal (â‰¥90), Mild (60â€“89), Moderate (30â€“59), Severe (15â€“29), Kidney failure (<15)
- [x] Age validation: 1â€“120; weight and SCr must be > 0
- [x] Educational note: "Cockcroft-Gault uses actual body weight; consider IBW in obese patients"
- [x] Safety note: "Verify drug-specific renal dosing thresholds against current formulary"
- [x] Flutter analyzer passes with no errors

### US-014: Pediatric Maintenance Fluids (Holliday-Segar)
**Description:** As a clinician, I want to calculate pediatric maintenance fluid requirements using the 4-2-1 rule so that I can prescribe appropriate IV fluids.

**Inputs:**
- Weight (kg or lb)

**Acceptance Criteria:**
- [x] 4-2-1 formula: `rate = (4 Ã— first 10 kg) + (2 Ã— next 10 kg) + (1 Ã— remaining kg)` = mL/hr; mL/day = mL/hr Ã— 24
- [x] Result shows both mL/hr and mL/day
- [x] Breakdown shown: "First 10 kg: 40 mL/hr | Next 10 kg: 20 mL/hr | Remaining [n] kg: [n] mL/hr"
- [x] Weight cap warning shown if weight > 60 kg: "Holliday-Segar is validated for pediatric weights; adult maintenance may differ"
- [x] Educational note: "Adjust for clinical context: fever, losses, renal/cardiac disease"
- [x] Flutter analyzer passes with no errors

---

## Functional Requirements

- FR-1: Each calculator is defined as a `CalculatorDefinition` Dart object; the `CalculatorScreen` widget renders any definition without modification
- FR-2: All numeric inputs must reject negative, zero, and non-numeric values with inline errors
- FR-3: Unit conversion between input unit choices must happen automatically when the user switches units
- FR-4: The disclaimer "Enchiridion calculators are clinical support tools and do not replace professional judgment, institutional guidelines, or senior review." must appear on every calculator screen
- FR-5: Forbidden result phrasing: "Definitive diagnosis", "Guaranteed safe dose", "Correct treatment"
- FR-6: All results must show their unit explicitly (e.g. "240 mg", "2.3 mL/hr", "14 weeks 3 days")
- FR-7: Copy result must produce a complete, human-readable string suitable for pasting into clinical notes
- FR-8: Saved favorites stored in Supabase `user_favorites` table with RLS (users own their rows)

---

## Non-Goals

- Backlog calculators (SOFA, NEWS2, CHAâ‚‚DSâ‚‚-VASc, etc.) â€” not in this version
- Offline calculation (calculators work without internet; only favorites saving requires connectivity)
- Calculator history / log of past results â€” not in this version
- PDF export of results â€” not in this version

---

## Technical Considerations

- `CalculatorDefinition` model: pure Dart, no Flutter dependency; formula is a `Map<String, dynamic> Function(Map<String, dynamic> inputs)` returning result values and interpretation
- Input widgets: custom `NumericInputField` with built-in validation, unit selector, and large tap targets (min 48px height)
- Date inputs: use Flutter's `showDatePicker`
- Supabase `user_favorites`: `id` (UUID PK), `user_id` (UUID FK), `calculator_id` (text), `saved_at` (timestamp); unique constraint on (user_id, calculator_id)

---

## Success Metrics

- Each calculator produces a correct result for 3 test cases verified against published reference values
- A user can input values and get a result in under 30 seconds on first use
- Copy result produces a correctly formatted string for all 8 calculators

---

## Open Questions

- Should "real-time calculation" (as inputs become valid) replace the explicit "Calculate" button, or complement it?
- Should the calculator list be accessible from the Library screen or only via a bottom navigation tab?
- Should favorites sync across devices (Supabase â€” yes) or be local-only?
