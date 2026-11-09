# Phase 4: Phase 1 Calculators + Enhancements — Research

**Researched:** 2026-05-27
**Domain:** Flutter calculator UI, Dart data modeling, medical formula implementation
**Confidence:** HIGH (all findings verified directly from codebase)

---

## Summary

Phase 4 adds 18 new clinical calculators and enhances all 25 (7 existing + 18 new) with five
educational fields. The codebase already has a fully working calculator architecture with
consistent patterns: a central `CalculatorDefinition` model in
`enchiridion/lib/models/calculator_definition.dart`, a `kCalculators` constant list, routing
through `CalculatorScreen` via a `switch` on `calculatorId`, and per-calculator `StatefulWidget`
form classes within the same file. All 8 existing calculators follow this pattern precisely.

The five enhancement fields (explanation, clinicalInterpretation, safetyNotes, commonPitfalls,
osceTips) are NOT yet on the `CalculatorDefinition` model — they must be added. The `_ResultCard`
widget already renders `interpretation`, `educationalNote`, and `warningText` per-calculation at
runtime; the new fields are static metadata on the definition (shown after every calculation,
regardless of inputs). These are conceptually different and will be rendered as a separate
"Clinical Notes" expandable section below the result.

The BMI calculator (`_BmiForm`) currently does NOT auto-convert values when units change — it
only reads the unit at calculate time. The fix requires converting the raw field value on
`onChanged` of the unit `DropdownButton`.

Freemium gating is already implemented: `kFreeCalculatorsPerCategory = 1` in
`freemium_config.dart`, enforced in `CalculatorListScreen._isLocked()`. Adding new calculators
to existing categories will automatically gate them — no gating code changes needed.

**Primary recommendation:** Add the 5 new fields to `CalculatorDefinition`, populate them for all
25 calculators, add 18 new `_XxxForm` classes to `calculator_screen.dart`, and add a
`_ClinicalNotesSection` widget to render the new fields below the result card.

---

## Project Constraints (from CLAUDE.md)

- Flutter app lives in `enchiridion/` — all source files are under `enchiridion/lib/`
- All Flutter commands run from `enchiridion/` directory: `flutter test`, `flutter analyze`
- Architecture: `lib/models/`, `lib/screens/`, `lib/widgets/`, `lib/services/`, `lib/providers/`
- No web version; primary target is Android

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Calculator data model + formulas | `lib/models/calculator_definition.dart` + `lib/screens/calculator_screen.dart` | — | Model holds metadata; screen holds formula logic (current pattern) |
| Freemium gating | `lib/screens/calculator_list_screen.dart` + `lib/config/freemium_config.dart` | — | Already implemented; no changes needed for new calculators |
| Result display (dynamic) | `_ResultCard` in `calculator_screen.dart` | — | Runtime interpretation per-calculation |
| Educational metadata (static) | New `_ClinicalNotesSection` widget | `CalculatorDefinition` model | Static per-calculator text, sourced from definition |
| BMI unit conversion | `_BmiFormState` | — | State-local; convert on `onChanged` |
| Favorites persistence | `StorageService` + `SharedPreferences` | — | Existing; no changes needed |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REQ-4a | Add 18 calculator definitions to `kCalculators` | `kCalculators` is a `const List<CalculatorDefinition>` in `calculator_definition.dart`; add entries there |
| REQ-4b | Implement 7 Emergency & Critical Care calculators | Each needs a `_XxxForm` class + `case` in `_buildInputs()` switch |
| REQ-4c | Implement 5 Drug Dosing calculators | Same pattern as REQ-4b |
| REQ-4d | Implement 6 Pediatrics calculators | Same pattern as REQ-4b |
| REQ-4e | Add 5 enhancement fields to all 25 calculators | Add fields to `CalculatorDefinition`, populate for all calculators, render in UI |
| REQ-4f | BMI auto-conversion on unit change | `_BmiFormState`: convert `_weightCtrl`/`_heightCtrl` text on unit `DropdownButton.onChanged` |
</phase_requirements>

---

## Standard Stack

### Core (already in pubspec.yaml — no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | SDK | UI framework | [VERIFIED: codebase] |
| `provider` | ^6.1.1 | State management | [VERIFIED: codebase — pubspec.yaml] |
| `shared_preferences` | ^2.2.2 | Favorites persistence | [VERIFIED: codebase — pubspec.yaml] |
| `flutter_test` | SDK | Widget + unit tests | [VERIFIED: codebase — pubspec.yaml] |
| `mockito` | ^5.4.4 | Mock generation for tests | [VERIFIED: codebase — pubspec.yaml] |

No new packages are required for this phase. All calculator logic is pure Dart arithmetic. All
UI widgets are standard Flutter Material widgets already in use.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline formula in `StatefulWidget` | Separate `calculator_logic.dart` service | Separation of concerns is cleaner for complex formulas; but existing pattern is inline and consistent — keep inline for now |
| Static fields on `CalculatorDefinition` | Remote content (Supabase) | Static is simpler, offline-first, matches existing pattern |

---

## Package Legitimacy Audit

> No new packages are being installed in this phase. All dependencies are already present in
> `pubspec.yaml` and were installed in earlier phases.

| Package | Registry | Status | Disposition |
|---------|----------|--------|-------------|
| (none) | — | — | No new packages required |

---

## Architecture Patterns

### System Architecture Diagram

```
User taps calculator in CalculatorListScreen
        │
        ▼
_isLocked() check → [locked] → UnlockScreen
        │ [unlocked]
        ▼
CalculatorScreen(calculatorId: calc.id)
        │
        ├── _def = kCalculators.firstWhere(id)   ← CalculatorDefinition metadata
        │         (title, description, disclaimer,
        │          explanation, clinicalInterpretation,
        │          safetyNotes, commonPitfalls, osceTips)  ← NEW fields
        │
        ├── _buildInputs(context) → switch(calculatorId)
        │         └── _XxxForm(onResult: _setResult, onReset: _reset)
        │                   └── on Calculate: calls onResult(result, interpretation, ...)
        │
        ├── _ResultCard                            ← dynamic, per-calculation
        │         (resultText, interpretation, educationalNote, warningText)
        │
        ├── _ClinicalNotesSection                  ← NEW: static, per-definition
        │         (explanation, clinicalInterpretation,
        │          safetyNotes, commonPitfalls, osceTips)
        │
        └── Disclaimer block                       ← _def.disclaimer
```

### Recommended Project Structure

No structural changes needed. All new code goes into existing files:

```
enchiridion/lib/
├── models/
│   └── calculator_definition.dart   ← ADD 5 fields + 18 new kCalculators entries
├── screens/
│   └── calculator_screen.dart       ← ADD 18 _XxxForm classes + switch cases
│                                       ADD _ClinicalNotesSection widget
│                                       UPDATE _BmiFormState unit conversion
└── test/
    └── models/
        └── calculator_definition_test.dart   ← NEW: unit tests for new fields + groupByCategory
    └── screens/
        └── calculator_screen_test.dart       ← NEW: widget tests for enhancement rendering + BMI
```

### Pattern 1: CalculatorDefinition Model Extension

**What:** Add 5 optional String fields to `CalculatorDefinition`. All default to empty string so existing `const` construction doesn't break.

**When to use:** All new and existing calculators.

**Example:**
```dart
// Source: enchiridion/lib/models/calculator_definition.dart (existing pattern)
class CalculatorDefinition {
  final String id;
  final String title;
  final String category;
  final String description;
  final String disclaimer;
  // NEW fields — all optional with empty string defaults
  final String explanation;
  final String clinicalInterpretation;
  final String safetyNotes;
  final String commonPitfalls;
  final String osceTips;

  const CalculatorDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.disclaimer = _kDefaultDisclaimer,
    this.explanation = '',
    this.clinicalInterpretation = '',
    this.safetyNotes = '',
    this.commonPitfalls = '',
    this.osceTips = '',
  });
}
```

### Pattern 2: New Calculator Form Class

**What:** Each new calculator is a `StatefulWidget` with an `onResult` callback.

**When to use:** Every one of the 18 new calculators.

**Example (pattern extracted from existing `_HollidaySegarForm`):**
```dart
// Source: enchiridion/lib/screens/calculator_screen.dart (existing pattern)
class _ShockIndexForm extends StatefulWidget {
  final void Function({
    required String result,
    required String interpretation,
    String? educationalNote,
    String? warning,
  }) onResult;
  final VoidCallback onReset;
  const _ShockIndexForm({required this.onResult, required this.onReset});

  @override
  State<_ShockIndexForm> createState() => _ShockIndexFormState();
}

class _ShockIndexFormState extends State<_ShockIndexForm> {
  final _hrCtrl = TextEditingController();
  final _sbpCtrl = TextEditingController();

  @override
  void dispose() {
    _hrCtrl.dispose();
    _sbpCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final hr = double.tryParse(_hrCtrl.text);
    final sbp = double.tryParse(_sbpCtrl.text);
    if (hr == null || hr <= 0 || sbp == null || sbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid HR and SBP')));
      return;
    }
    final si = hr / sbp;
    String category;
    if (si < 0.6) { category = 'Normal'; }
    else if (si < 1.0) { category = 'Mildly elevated'; }
    else { category = 'Shock likely (≥ 1.0)'; }

    widget.onResult(
      result: 'Shock Index: ${si.toStringAsFixed(2)} — $category',
      interpretation: 'A shock index of ${si.toStringAsFixed(2)} suggests $category.',
      warning: 'Shock Index is a screening tool; assess clinical picture in full.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Heart rate (bpm)', controller: _hrCtrl),
        _NumericField(label: 'Systolic BP (mmHg)', controller: _sbpCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}
```

### Pattern 3: _buildInputs() Switch Extension

**What:** Add a `case` for each new calculator ID.

```dart
// Source: enchiridion/lib/screens/calculator_screen.dart (existing switch)
case 'shock-index':
  return _ShockIndexForm(onResult: _setResult, onReset: _reset);
```

### Pattern 4: _ClinicalNotesSection Widget (NEW)

**What:** A new private widget rendered below the result card, showing static metadata from `_def`.

**When to use:** Always — shown unconditionally when any of the 5 new fields is non-empty.

```dart
class _ClinicalNotesSection extends StatefulWidget {
  final CalculatorDefinition def;
  const _ClinicalNotesSection({required this.def});

  @override
  State<_ClinicalNotesSection> createState() => _ClinicalNotesSectionState();
}

class _ClinicalNotesSectionState extends State<_ClinicalNotesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Only render if any field is populated
    final def = widget.def;
    if ([def.explanation, def.clinicalInterpretation,
         def.safetyNotes, def.commonPitfalls, def.osceTips]
        .every((s) => s.isEmpty)) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      title: const Text('Clinical Notes'),
      initiallyExpanded: false,
      children: [
        if (def.explanation.isNotEmpty)
          _noteRow(context, Icons.info_outline, 'Explanation', def.explanation),
        if (def.clinicalInterpretation.isNotEmpty)
          _noteRow(context, Icons.medical_services_outlined,
              'Clinical Interpretation', def.clinicalInterpretation),
        if (def.safetyNotes.isNotEmpty)
          _noteRow(context, Icons.warning_amber_outlined,
              'Safety Notes', def.safetyNotes),
        if (def.commonPitfalls.isNotEmpty)
          _noteRow(context, Icons.error_outline,
              'Common Pitfalls', def.commonPitfalls),
        if (def.osceTips.isNotEmpty)
          _noteRow(context, Icons.school_outlined, 'OSCE Tips', def.osceTips),
      ],
    );
  }
}
```

### Pattern 5: BMI Unit Auto-Conversion

**What:** On weight or height unit `DropdownButton.onChanged`, read current controller text, convert, and write back.

**Why it doesn't work now:** `_BmiFormState` only reads units during `_calculate()` — it never converts on change.

```dart
// Replace the weight unit DropdownButton onChanged:
onChanged: (v) {
  if (v == null || v == _weightUnit) return;
  final current = double.tryParse(_weightCtrl.text);
  if (current != null && current > 0) {
    final converted = _weightUnit == 'kg'
        ? current * 2.20462   // kg → lb
        : current / 2.20462;  // lb → kg
    _weightCtrl.text = converted.toStringAsFixed(2);
  }
  setState(() => _weightUnit = v);
},

// Replace the height unit DropdownButton onChanged:
onChanged: (v) {
  if (v == null || v == _heightUnit) return;
  final current = double.tryParse(_heightCtrl.text);
  if (current != null && current > 0) {
    // Convert current value to meters first, then to target unit
    double meters;
    switch (_heightUnit) {
      case 'cm': meters = current / 100; break;
      case 'm':  meters = current; break;
      case 'ft': meters = current * 0.3048; break;
      default:   meters = current / 100;
    }
    double converted;
    switch (v) {
      case 'cm': converted = meters * 100; break;
      case 'm':  converted = meters; break;
      case 'ft': converted = meters / 0.3048; break;
      default:   converted = meters * 100;
    }
    _heightCtrl.text = converted.toStringAsFixed(2);
  }
  setState(() => _heightUnit = v);
},
```

### Anti-Patterns to Avoid

- **Splitting calculator_screen.dart into separate files per calculator:** The existing single-file pattern is intentional for this stage. The switch-based routing is clean and easily navigable. Do not introduce a separate file per calculator or a `calculators/` subdirectory unless file size becomes unmanageable (>2000 lines is a reasonable threshold to revisit).
- **Adding formula logic to `CalculatorDefinition`:** The model is a data class. Formula functions belong in form `State` classes.
- **Storing enhancement fields as runtime state:** These are static per-calculator — they go in the `const CalculatorDefinition` entries, not in `_CalculatorScreenState`.
- **Resetting unit dropdowns to default on Reset:** The `_reset()` method in `_CalculatorScreenState` only clears result fields (`_resultText`, `_interpretation`, etc.). Form-level `_reset` callbacks should reset form fields AND units to defaults — currently most forms don't call `onReset` to clear themselves. This is the existing pattern; maintain it.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SOFA score severity mapping | Custom severity string logic | Hard-code lookup table in the form State | SOFA score categories are fixed clinical standards — a simple if-else or list lookup is correct |
| WHO growth percentile curves | Custom percentile calculation algorithm | Embed simplified reference bands in code | Full WHO LMS method requires large lookup tables; a simplified band approach (e.g. "below 3rd, 3rd–15th, …") is clinically adequate for a bedside calculator and safe to implement |
| Neonatal bilirubin nomogram | Custom nomogram rendering | Phototherapy threshold bands by age-in-hours + risk factor | The Bhutani nomogram is a fixed table; implement as risk zone lookup |
| Pediatric BP percentiles | Custom normative curve fitting | Age/sex band lookup table | Full NHBPEP tables are large; use simplified threshold bands (stage 1 hypertension by age) |
| eGFR (CKD-EPI) sex/race variants | Complex branching across all CKD-EPI equations | Implement the 2021 race-free CKD-EPI equation | The 2021 revision eliminated race as a variable; this is the current clinical standard |

**Key insight:** Medical calculators' formulas are well-defined published standards. The complexity is in validation, unit handling, and clear result display — not in the math itself.

---

## Existing Calculator Inventory (7 calculators currently implemented)

| ID | Title | Category | Form Class |
|----|-------|----------|------------|
| `weight-dosing` | Weight-Based Drug Dosing | Drug Dosing | `_WeightDosingForm` |
| `iv-infusion` | IV Infusion Rate | Drug Dosing | `_IvInfusionForm` |
| `gcs` | Glasgow Coma Scale | Emergency & Critical Care | `_GcsForm` |
| `bmi` | BMI | General | `_BmiForm` |
| `edd-ega` | EDD / Gestational Age | Obs & Gynae | `_EddEgaForm` |
| `anion-gap` | Anion Gap | Emergency & Critical Care | `_AnionGapForm` |
| `creatinine-clearance` | Creatinine Clearance | Drug Dosing | `_CrClForm` |
| `holliday-segar` | Paediatric Maintenance Fluids | Paediatrics | `_HollidaySegarForm` |

---

## 18 New Calculators — IDs, Categories, and Formula Summary

### Emergency & Critical Care (7 new)

| ID | Title | Key Inputs | Formula / Logic |
|----|-------|-----------|-----------------|
| `qsofa` | qSOFA Score | Altered mentation (bool), RR ≥ 22 (bool), SBP ≤ 100 (bool) | Sum of 3 binary flags; 0=low, ≥2=high risk sepsis |
| `news2` | NEWS2 Score | RR, SpO2 scale 1 (and optional scale 2 for hypercapnia), on supplemental O2 (bool), SBP, HR, consciousness (ACVPU: 0 or 3), temp | Sum of 6 scored parameters; clinical response thresholds: 0=low, 1-4=low-medium, 5-6=medium, ≥7=high |
| `shock-index` | Shock Index | HR, SBP | SI = HR / SBP; normal <0.6, mildly elevated 0.6–0.9, elevated ≥1.0 |
| `osmolality` | Osmolality & Osmolar Gap | Na (mEq/L), glucose (mg/dL), BUN (mg/dL), measured osmolality (optional) | Calc = 2×Na + glucose/18 + BUN/2.8; gap = measured − calculated |
| `corrected-sodium` | Corrected Sodium (Hyperglycemia) | Na (mEq/L), glucose (mg/dL) | Corrected Na = measured Na + 0.016 × (glucose − 100); or Katz formula: +0.024 per mg/dL above 100 |
| `aa-gradient` | A-a Gradient | PaO2 (mmHg), PaCO2 (mmHg), FiO2 (fraction), altitude/PB (optional, default 760) | PAO2 = FiO2×(PB−47) − PaCO2/0.8; A-a = PAO2 − PaO2; expected = age/4 + 4 |
| `pao2-fio2` | PaO₂/FiO₂ Ratio | PaO2 (mmHg), FiO2 (fraction 0.21–1.0) | P/F = PaO2 / FiO2; >400=normal, 300–400=mild ARDS, 200–300=moderate, <200=severe |

### Drug Dosing (5 new)

| ID | Title | Key Inputs | Formula / Logic |
|----|-------|-----------|-----------------|
| `bsa` | Body Surface Area (BSA) | Weight (kg/lb), Height (cm/m) | Mosteller: BSA = √(Ht_cm × Wt_kg / 3600); DuBois: 0.007184 × Ht^0.725 × Wt^0.425 — offer Mosteller as default |
| `egfr-ckd-epi` | eGFR (CKD-EPI 2021) | Age, Sex, Serum creatinine (mg/dL or µmol/L) | 2021 race-free CKD-EPI: different κ and α by sex; see standard CKD-EPI 2021 coefficients |
| `gentamicin-vancomycin` | Gentamicin/Vancomycin Dosing | Drug selection, Weight (kg/lb), CrCl or age/sex/Cr for auto-calc, target trough (optional) | Gentamicin: standard 3–5 mg/kg/day, renally adjusted by CrCl bands; Vancomycin: 15–20 mg/kg q8-12h adjusted by CrCl |
| `insulin-dose` | Insulin Dose | CBG (mmol/L or mg/dL), Target range, Insulin sensitivity factor | Correction dose = (CBG − target) / ISF; also sliding scale mode |
| `paracetamol-dosing` | Paracetamol Dosing | Weight (kg/lb), Age group (adult/child), Route (oral/IV) | Child <12y: 15 mg/kg/dose (oral), max 60 mg/kg/day, max 4 doses/24h; Adult: 500–1000 mg q4-6h, max 4 g/day |

### Pediatrics (6 new)

| ID | Title | Key Inputs | Formula / Logic |
|----|-------|-----------|-----------------|
| `apls-weight` | APLS Weight Estimation | Age (years/months), method selector | Age 0–1y: weight = 0.5 × (age_months + 9); 1–5y: 2 × (age + 4); 6–12y: 3 × age + 7 |
| `broselow` | Broselow Tape Equivalent | Height/length (cm) | Map height to Broselow color zone + weight range + standard drug dose ranges |
| `pediatric-bp` | Pediatric BP Percentiles | Age (years), Sex, SBP, DBP | Age+sex-based threshold lookup; simplified: SBP normal < 90th percentile; stage 1 HTN ≥ 95th; stage 2 ≥ 99th + 5 mmHg |
| `neonatal-bilirubin` | Neonatal Bilirubin (Phototherapy) | Bilirubin (µmol/L or mg/dL), Age in hours, Risk category (low/medium/high) | Bhutani nomogram risk zones: map age-in-hours + bilirubin to zone; threshold for phototherapy varies by risk |
| `apgar` | APGAR Score | Appearance, Pulse, Grimace, Activity, Respiration (each 0–2) | Sum 0–10; 7–10=normal, 4–6=moderate concern, 0–3=severe concern |
| `growth-percentile` | WHO Growth Percentile | Weight, Height, Head circumference (optional), Age, Sex | Simplified WHO band approach: < -2 SD = below 3rd, -2 to +2 SD = normal, > +2 SD = above 97th. Display as qualitative zone |

---

## Freemium Gating — No Changes Needed

The existing gating is category-based (`kFreeCalculatorsPerCategory = 1`):

```dart
// enchiridion/lib/config/freemium_config.dart
const int kFreeCalculatorsPerCategory = 1;

// enchiridion/lib/screens/calculator_list_screen.dart
bool _isLocked(CalculatorDefinition calc) {
  if (_hasAccess) return false;
  final categoryCalcs =
      kCalculators.where((c) => c.category == calc.category).toList();
  final index = categoryCalcs.indexWhere((c) => c.id == calc.id);
  return index >= kFreeCalculatorsPerCategory;
}
```

Adding new calculators to existing categories will automatically lock all but the first. The
first calculator per category in `kCalculators` is the free one. **Order matters** in
`kCalculators` — the planner must ensure the intended free calculator appears first in each
category list.

Current free calculators per category (first entry in `kCalculators` for each):
- Drug Dosing → `weight-dosing`
- Emergency & Critical Care → `gcs`
- General → `bmi`
- Obs & Gynae → `edd-ega`
- Paediatrics → `holliday-segar`

The 7 new Emergency & Critical Care calculators will be added after `gcs` — all locked for free
users. Same for new Drug Dosing and Paediatrics calculators.

---

## Common Pitfalls

### Pitfall 1: Breaking `const` on `CalculatorDefinition`
**What goes wrong:** Adding new fields without default values causes compile errors on all 8
existing `const CalculatorDefinition(...)` usages in `kCalculators`.
**Why it happens:** Dart `const` constructors require all fields to have default values if not
required.
**How to avoid:** Give all 5 new fields `this.field = ''` defaults so existing definitions
compile unchanged.
**Warning signs:** `The default value of an optional parameter must be constant.` compile error.

### Pitfall 2: BMI Height Unit Conversion — ft/in Ambiguity
**What goes wrong:** Users enter height as `5.11` intending 5 feet 11 inches. Treating this as
5.11 feet gives wrong output.
**Why it happens:** The current `_BmiFormState` uses a single `ft` option, not a `ft/in` split.
**How to avoid:** Keep the single `ft` field (decimal feet) for now. Do NOT introduce a split
ft/in field — it would require two controllers and separate conversion logic. Document in the
UI that `ft` means decimal feet (e.g., 5'11" = 5.92 ft).
**Warning signs:** Conversion accuracy failures with non-round ft values.

### Pitfall 3: NEWS2 Score — SpO2 Scale 2 Complexity
**What goes wrong:** NEWS2 has two SpO2 scales (scale 1 = standard; scale 2 = for patients with
hypercapnic respiratory failure on target SpO2 88–92%). Implementing scale 2 is complex.
**Why it happens:** Oversimplifying to scale 1 only doesn't handle COPD patients.
**How to avoid:** Implement scale 1 as default. Add a toggle "Hypercapnic respiratory failure
(COPD target SpO2 88–92%)". If toggled, show scale 2 scoring table. This is the clinically
correct approach without over-engineering.
**Warning signs:** Scores that don't match NEWS2 reference for SpO2 of 88–92%.

### Pitfall 4: Ordering in kCalculators Breaks Freemium Gate
**What goes wrong:** New calculators accidentally inserted BEFORE existing ones in the same
category, shifting the position-0 free slot.
**Why it happens:** `_isLocked()` uses `indexWhere` — it finds position of a calculator in its
category's sub-list. Position 0 is free.
**How to avoid:** Always append new calculators AFTER existing ones in the same category in
`kCalculators`. Never reorder existing entries.
**Warning signs:** Previously free calculator becomes locked for free users.

### Pitfall 5: `_buildInputs()` Missing Case for New IDs
**What goes wrong:** A calculator is added to `kCalculators` but its `case` is missing in the
`switch` — causes `Text('Unknown calculator')` to render.
**Why it happens:** Two separate edits (model + screen) with an easy miss.
**How to avoid:** Each new calculator definition and its form class must be added together.
Run `flutter analyze` to catch any issues.
**Warning signs:** "Unknown calculator" text visible on a new calculator screen.

### Pitfall 6: CKD-EPI 2021 vs Older Equations
**What goes wrong:** Using the 2009 race-adjusted CKD-EPI equation instead of the 2021
race-free version.
**Why it happens:** Many online references still cite the 2009 equation.
**How to avoid:** Use the 2021 race-free CKD-EPI equation. Note in the calculator that it uses
the 2021 equation.
**Warning signs:** Calculator includes a "race" input field.

---

## Code Examples

### Adding a Calculator Definition with Enhancement Fields

```dart
// Source: enchiridion/lib/models/calculator_definition.dart — extended pattern
CalculatorDefinition(
  id: 'shock-index',
  title: 'Shock Index',
  category: 'Emergency & Critical Care',
  description: 'Heart rate divided by systolic BP — screens for haemodynamic instability.',
  explanation:
      'Shock Index (SI) = HR ÷ SBP. A value ≥ 1.0 suggests the heart rate has met '
      'or exceeded systolic blood pressure, indicating significant haemodynamic stress.',
  clinicalInterpretation:
      'SI < 0.6: Normal. 0.6–0.9: Mildly elevated — monitor. ≥ 1.0: High risk — '
      'consider volume resuscitation and urgent assessment.',
  safetyNotes:
      'Unreliable in patients on beta-blockers (blunted HR response), severe aortic '
      'stenosis, or pacemaker-dependent rhythms.',
  commonPitfalls:
      'Using resting HR from triage rather than current HR. Interpreting SI in isolation '
      'without clinical context (pallor, cap refill, mental status).',
  osceTips:
      'Examiners may ask: "What does a Shock Index of 1.2 indicate?" — answer: likely '
      'haemodynamic compromise, initiate resuscitation. Often tested in trauma scenarios.',
),
```

### BMI Unit Conversion on Change

```dart
// Source: enchiridion/lib/screens/calculator_screen.dart — _BmiFormState
// Weight unit conversion
onChanged: (v) {
  if (v == null || v == _weightUnit) return;
  final current = double.tryParse(_weightCtrl.text);
  if (current != null && current > 0) {
    final converted = _weightUnit == 'kg'
        ? current * 2.20462
        : current / 2.20462;
    _weightCtrl.text = converted.toStringAsFixed(2);
  }
  setState(() => _weightUnit = v);
},
```

### Widget Test Pattern (matching existing test style)

```dart
// Source: enchiridion/test/screens/calculator_screen_test.dart (new)
testWidgets('shock-index renders correctly and shows result', (tester) async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key',
  );
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<StorageService>.value(value: storage)],
      child: const MaterialApp(
        home: CalculatorScreen(calculatorId: 'shock-index'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Shock Index'), findsOneWidget);
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Race-adjusted CKD-EPI (2009) | Race-free CKD-EPI (2021) | 2021 NEJM publication | Remove race input; use updated coefficients |
| SOFA requires ICU labs (lactate, bilirubin) | qSOFA as bedside screening tool | 2016 Sepsis-3 guidelines | qSOFA appropriate for general ward use |

---

## Open Questions (RESOLVED)

1. **Broselow drug dose detail level**
   - What we know: Broselow maps height → color zone → approximate weight + standard doses
   - What's unclear: How many drug categories to show per zone (full chart is extensive)
   - Recommendation: Implement height → color zone → estimated weight + weight range. Omit specific drug doses for v1 (too many). User can use weight output with weight-dosing calculator.

2. **Growth Percentile — WHO LMS data inclusion**
   - What we know: Full WHO LMS method requires embedding large coefficient tables (L, M, S values per age/sex)
   - What's unclear: Whether to embed simplified z-score bands or full LMS tables
   - Recommendation: Use simplified z-score band approach for v1 (< -2 SD, -2 to +2 SD, > +2 SD). Full LMS tables can be added in a later phase as a separate data file.

3. **Pediatric BP Percentile table granularity**
   - What we know: Full NHBPEP tables are large (age 1–17, by sex, 50th/90th/95th/99th)
   - What's unclear: Whether to embed a simplified subset or full table
   - Recommendation: Implement simplified thresholds: normal = SBP < age+90 (rough approximation) + note to verify against full tables clinically. Or embed the key 95th percentile values for each age/sex in a Dart map. The latter is more accurate and feasible to embed.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Flutter SDK | All calculator code | Assumed available | Already in use for phases 1–3 |
| Dart | Pure formula logic | Assumed available | Part of Flutter SDK |
| `flutter test` | Test runner | Assumed available | Tests already pass (16/16 from Phase 3) |

Step 2.6: No new external tools, services, or CLIs are required for this phase. All calculator
logic is pure Dart arithmetic.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (Flutter SDK) + mockito ^5.4.4 |
| Config file | none — `flutter test` auto-discovers `test/` |
| Quick run command | `flutter test test/models/calculator_definition_test.dart` |
| Full suite command | `flutter test` (from `enchiridion/` directory) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-4a | `kCalculators` has 25 entries | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ Wave 0 |
| REQ-4a | All 5 categories present in grouped output | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ Wave 0 |
| REQ-4e | `CalculatorDefinition` has 5 new fields with correct types | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ Wave 0 |
| REQ-4e | `_ClinicalNotesSection` renders non-empty fields | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ Wave 0 |
| REQ-4e | `_ClinicalNotesSection` renders nothing when all fields empty | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ Wave 0 |
| REQ-4f | BMI weight converts kg→lb without resetting to zero | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ Wave 0 |
| REQ-4f | BMI height converts cm→m correctly | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ Wave 0 |
| REQ-4b | Shock Index screen renders and accepts inputs | widget | `flutter test test/screens/calculator_screen_test.dart` | ❌ Wave 0 |
| REQ-4b | APGAR sum is correct (test calculation logic) | unit | `flutter test test/models/calculator_definition_test.dart` | ❌ Wave 0 |
| Regression | `kFreeCalculatorsPerCategory` still = 1 | unit | `flutter test test/config/freemium_config_test.dart` | ✅ exists |

### Sampling Rate
- **Per task commit:** `flutter test test/models/calculator_definition_test.dart test/config/freemium_config_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/models/calculator_definition_test.dart` — covers REQ-4a (count), REQ-4e (new fields), and basic groupByCategory assertions
- [ ] `test/screens/calculator_screen_test.dart` — covers REQ-4e (_ClinicalNotesSection rendering), REQ-4f (BMI conversion), REQ-4b sample new calculator smoke tests

*(No new framework install required — `flutter_test` and `mockito` already in `dev_dependencies`)*

---

## Security Domain

> `security_enforcement` is absent from `.planning/config.json` — treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Calculators have no auth logic |
| V3 Session Management | no | No session data in calculators |
| V4 Access Control | yes | Freemium gating via `kFreeCalculatorsPerCategory` — already implemented |
| V5 Input Validation | yes | Each form validates inputs before calculation; `_NumericField` uses `FilteringTextInputFormatter` |
| V6 Cryptography | no | No encryption required |

### Known Threat Patterns for Medical Calculator Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid numeric inputs (negative, zero, overflow) | Tampering | `double.tryParse()` + explicit null/range checks before calculation; existing pattern enforces this |
| Misleading result display (missing units) | Information Disclosure | All result strings explicitly include units; enforced by calculator spec |
| Clinically inappropriate autonomous prescribing language | Repudiation | Use "Calculated estimate" / "Suggested interpretation" — not "Correct dose"; global disclaimer mandatory on every screen |

---

## Sources

### Primary (HIGH confidence — verified directly from codebase)
- `enchiridion/lib/models/calculator_definition.dart` — `CalculatorDefinition` class, 8-entry `kCalculators`, `groupByCategory` helper
- `enchiridion/lib/screens/calculator_screen.dart` — `CalculatorScreen`, `_ResultCard`, `_NumericField`, all 8 form classes (1095 lines)
- `enchiridion/lib/screens/calculator_list_screen.dart` — freemium gating implementation
- `enchiridion/lib/config/freemium_config.dart` — `kFreeCalculatorsPerCategory = 1`
- `enchiridion/lib/services/access_service.dart` — `hasFullAccess()`, `testAccessOverride`
- `enchiridion/pubspec.yaml` — all declared dependencies
- `.planning/REQUIREMENTS.md` sections 4.1, 4.2, 4.3 — detailed specs
- `Ideas/ideas.md` — calculator field-level specs and screen pattern rules
- `Ideas/new_features.md` — calculator UI system spec

### Secondary (MEDIUM confidence — from project planning artifacts)
- `.planning/ROADMAP.md` — Phase 4 task breakdown and estimates
- `.planning/PROJECT.md` — overall architecture decisions

### Tertiary (LOW confidence — medical reference, not independently verified)
- SOFA/qSOFA: Sepsis-3 2016 guidelines scoring (used as basis for formula) — [ASSUMED: training knowledge, not independently verified in this session]
- NEWS2 scoring: Royal College of Physicians 2017 — [ASSUMED]
- CKD-EPI 2021 race-free equation — [ASSUMED: cited in training, not fetched from source in this session]
- APLS weight estimation formulas — [ASSUMED]
- Bhutani neonatal bilirubin phototherapy thresholds — [ASSUMED]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CKD-EPI 2021 race-free equation coefficients (κ, α values by sex) | New Calculators — eGFR | Wrong GFR values displayed; planner should verify coefficients against official NIDDK/KDIGO source before coding |
| A2 | APLS weight formula for 1–5y is 2×(age+4) | New Calculators — APLS | Incorrect weight estimate for drug dosing; verify against APLS 6th edition |
| A3 | Bhutani phototherapy thresholds (age-in-hours bands) | New Calculators — Neonatal Bilirubin | Wrong phototherapy initiation; planner should embed verified AAP 2022 table values |
| A4 | Pediatric BP 95th percentile simplified as SBP < age+90 | New Calculators — Pediatric BP | Clinically inaccurate; planner should use the actual 2017 ACC/AHA pediatric BP tables embedded as a Dart constant map |
| A5 | NEWS2 SpO2 scale 2 scoring table values | New Calculators — NEWS2 | Wrong NEWS2 score for hypercapnia patients; planner should verify against RCP NEWS2 documentation |

---

## Metadata

**Confidence breakdown:**
- Existing architecture: HIGH — read directly from source files
- Freemium gating behavior: HIGH — verified from source
- Formula logic for 18 new calculators: MEDIUM — formulas are established medical standards but specific coefficients tagged [ASSUMED] and need verification
- Enhancement field integration: HIGH — clear extension of existing model pattern

**Research date:** 2026-05-27
**Valid until:** 2026-06-27 (stable domain; no moving parts)
