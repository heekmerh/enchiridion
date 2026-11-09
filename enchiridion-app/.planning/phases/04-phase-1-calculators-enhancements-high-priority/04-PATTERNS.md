# Phase 4: Phase 1 Calculators + Enhancements — Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 4 (2 modified, 2 created)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `enchiridion/lib/models/calculator_definition.dart` | model | transform | self (existing file being extended) | exact |
| `enchiridion/lib/screens/calculator_screen.dart` | screen/widget | request-response | self (existing file being extended) | exact |
| `enchiridion/test/models/calculator_definition_test.dart` | test | — | `enchiridion/test/models/book_test.dart` | role-match |
| `enchiridion/test/screens/calculator_screen_test.dart` | test | — | `enchiridion/test/screens/library_screen_test.dart` | exact |

---

## Pattern Assignments

### `enchiridion/lib/models/calculator_definition.dart` (model, transform)

**Analog:** self — `enchiridion/lib/models/calculator_definition.dart`

**Existing class structure** (lines 1–15):
```dart
class CalculatorDefinition {
  final String id;
  final String title;
  final String category;
  final String description;
  final String disclaimer;

  const CalculatorDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    this.disclaimer = _kDefaultDisclaimer,
  });
}
```

**How to extend — add 5 optional fields with empty-string defaults** (insert after `disclaimer` field and constructor param):
```dart
class CalculatorDefinition {
  final String id;
  final String title;
  final String category;
  final String description;
  final String disclaimer;
  // NEW fields — all optional, default '' so existing const entries compile unchanged
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

**Existing kCalculators entry pattern** (lines 22–28) — copy this for all 25 entries (existing 8 unchanged; append 18 new below them in category order):
```dart
CalculatorDefinition(
  id: 'weight-dosing',
  title: 'Weight-Based Drug Dosing',
  category: 'Drug Dosing',
  description: 'Calculate total dose from patient weight and dose per kg.',
),
```

**New entry pattern with all 5 enhancement fields populated** (from RESEARCH.md code examples):
```dart
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

**Critical ordering rule:** New calculators for each category MUST be appended AFTER the existing entry for that category. Current free (position-0) calculators must remain position-0:
- Drug Dosing → `weight-dosing` stays first
- Emergency & Critical Care → `gcs` stays first
- General → `bmi` stays first (no new General calculators)
- Obs & Gynae → `edd-ega` stays first (no new Obs & Gynae calculators)
- Paediatrics → `holliday-segar` stays first

---

### `enchiridion/lib/screens/calculator_screen.dart` (screen/widget, request-response)

**Analog:** self — existing file (1094 lines total, all patterns below are from this file)

#### Pattern A: Form widget shell (lines 330–337 — `_WeightDosingForm`)
```dart
class _WeightDosingForm extends StatefulWidget {
  final void Function({
    required String result,
    required String interpretation,
    String? educationalNote,
    String? warning,
  }) onResult;
  final VoidCallback onReset;
  const _WeightDosingForm({required this.onResult, required this.onReset});

  @override
  State<_WeightDosingForm> createState() => _WeightDosingFormState();
}
```
Copy this shell for every new `_XxxForm`. Replace class names only.

#### Pattern B: State class with controller dispose (lines 339–353 — `_WeightDosingFormState`)
```dart
class _WeightDosingFormState extends State<_WeightDosingForm> {
  final _weightCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  // ... additional controllers as needed ...

  @override
  void dispose() {
    _weightCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }
  // ...
}
```
Every `TextEditingController` field MUST be disposed in `dispose()`.

#### Pattern C: Input validation + SnackBar error (lines 355–364 — `_WeightDosingFormState._calculate`)
```dart
void _calculate() {
  final rawWeight = double.tryParse(_weightCtrl.text);
  final dosePerKg = double.tryParse(_doseCtrl.text);
  if (rawWeight == null || rawWeight <= 0 || dosePerKg == null || dosePerKg <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid weight and dose per kg')));
    return;
  }
  // ... formula logic ...
}
```
All `_calculate()` methods MUST use `double.tryParse()` (never `.parse()`), check for null AND non-positive values, and show a SnackBar on invalid input.

#### Pattern D: onResult callback invocation (lines 371–378 — `_WeightDosingFormState._calculate`)
```dart
widget.onResult(
  result: '${total.toStringAsFixed(1)} mg per dose, $_frequency\n'
      'Weight used: ${weightKg.toStringAsFixed(2)} kg × $dosePerKg mg/kg',
  interpretation: 'Administer ${total.toStringAsFixed(1)} mg per dose, $_frequency.',
  educationalNote: null,
  warning: warning ?? 'Verify dose against current formulary and institutional guidelines.',
);
```
`result` and `interpretation` are always required. `educationalNote` and `warning` are optional (pass `null` when not applicable).

#### Pattern E: Build method column layout (lines 380–415 — `_WeightDosingFormState.build`)
```dart
@override
Widget build(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // numeric fields and dropdowns...
      FilledButton(onPressed: _calculate, child: const Text('Calculate')),
    ],
  );
}
```
Every form's `build()` returns a `Column` with `crossAxisAlignment: CrossAxisAlignment.stretch`. The last child is always `FilledButton(onPressed: _calculate, child: const Text('Calculate'))`.

#### Pattern F: Inline unit dropdown (lines 386–395 — `_WeightDosingFormState.build`)
```dart
Row(
  children: [
    Expanded(child: _NumericField(label: 'Weight', controller: _weightCtrl)),
    const SizedBox(width: 8),
    DropdownButton<String>(
      value: _weightUnit,
      items: ['kg', 'lb']
          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
          .toList(),
      onChanged: (v) => setState(() => _weightUnit = v!),
    ),
  ],
),
```
Numeric field + unit dropdown pairs use `Row(children: [Expanded(...), SizedBox(width: 8), DropdownButton(...)])`.

#### Pattern G: Scored-item dropdown (lines 610–626 — `_GcsFormState._gcsDropdown`)
```dart
Widget _gcsDropdown(
  String label,
  int currentValue,
  List<(int, String)> options,
  void Function(int) onChanged,
) {
  return DropdownButtonFormField<int>(
    initialValue: currentValue,
    decoration: InputDecoration(
        labelText: label, border: const OutlineInputBorder(), isDense: true),
    items: options
        .map((o) =>
            DropdownMenuItem(value: o.$1, child: Text('${o.$1} — ${o.$2}')))
        .toList(),
    onChanged: (v) => onChanged(v!),
  );
}
```
For scored items (GCS, APGAR, NEWS2 parameters), use this helper pattern: a private `_xxxDropdown()` method that produces a `DropdownButtonFormField<int>` with labeled options.

#### Pattern H: Switch case registration (lines 182–203 — `_CalculatorScreenState._buildInputs`)
```dart
Widget _buildInputs(BuildContext context) {
  switch (widget.calculatorId) {
    case 'weight-dosing':
      return _WeightDosingForm(onResult: _setResult, onReset: _reset);
    // ... existing cases ...
    case 'holliday-segar':
      return _HollidaySegarForm(onResult: _setResult, onReset: _reset);
    default:
      return const Text('Unknown calculator');
  }
}
```
Add one `case 'new-id': return _NewForm(onResult: _setResult, onReset: _reset);` line per new calculator. The `default` branch must remain.

#### Pattern I: _ClinicalNotesSection widget (NEW — no existing analog, from RESEARCH.md pattern)
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
`_noteRow()` is a private helper to be defined alongside this widget, styled consistently with `_ResultCard`'s row pattern (icon + SizedBox(8) + Expanded text).

#### Pattern J: Where to insert _ClinicalNotesSection in the build tree (lines 140–176 — `_CalculatorScreenState.build`)

Currently the build ListView children are:
1. description text
2. `_buildInputs(context)`
3. SizedBox(height: 8)
4. action row (Reset / Copy)
5. `if (_resultText != null)` → `_ResultCard`
6. SizedBox(height: 24)
7. Disclaimer Container

Insert `_ClinicalNotesSection(def: _def)` between the `_ResultCard` block (item 5) and the SizedBox + Disclaimer (items 6–7):
```dart
// After _ResultCard block:
_ClinicalNotesSection(def: _def),

const SizedBox(height: 24),

// Disclaimer block...
```
`_ClinicalNotesSection` renders `SizedBox.shrink()` when all fields are empty, so no conditional wrapping is needed.

#### Pattern K: BMI unit auto-conversion fix (lines 699–718 — `_BmiFormState.build`)

Current weight DropdownButton onChanged (line 704) — replace with:
```dart
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
```

Current height DropdownButton onChanged (line 715) — replace with:
```dart
onChanged: (v) {
  if (v == null || v == _heightUnit) return;
  final current = double.tryParse(_heightCtrl.text);
  if (current != null && current > 0) {
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

---

### `enchiridion/test/models/calculator_definition_test.dart` (test — NEW FILE)

**Analog:** `enchiridion/test/models/book_test.dart`

**Import + group structure** (book_test.dart lines 1–8):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/models/calculator_definition.dart';

void main() {
  group('CalculatorDefinition', () {
    // unit tests here
  });

  group('kCalculators', () {
    // list-level tests here
  });

  group('groupByCategory', () {
    // helper tests here
  });
}
```

**Pure Dart `test()` pattern** (book_test.dart lines 7–12):
```dart
test('description of what is expected', () {
  // arrange
  const def = CalculatorDefinition(
    id: 'test-id',
    title: 'Test',
    category: 'General',
    description: 'desc',
  );
  // assert
  expect(def.explanation, '');
  expect(def.osceTips, '');
});
```
Model tests are pure Dart — no `testWidgets`, no `SharedPreferences.setMockInitialValues`, no `Supabase.initialize`. Just `test()` calls inside `group()`.

**Required test cases to implement:**
- `kCalculators` has exactly 25 entries (`expect(kCalculators.length, 25)`)
- All 5 enhancement fields default to `''` on existing definitions (spot-check `kCalculators.first`)
- Enhancement fields can be set on new `const CalculatorDefinition(...)` instances
- `groupByCategory` produces exactly 5 keys for the 25-entry list
- Each category key has the correct calculator count

---

### `enchiridion/test/screens/calculator_screen_test.dart` (test — NEW FILE)

**Analog:** `enchiridion/test/screens/library_screen_test.dart`

**Full import block** (library_screen_test.dart lines 1–17):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:enchiridion/models/calculator_definition.dart';
import 'package:enchiridion/screens/calculator_screen.dart';
import 'package:enchiridion/services/storage_service.dart';
```
No mockito needed for this file — `StorageService` can be built directly with `SharedPreferences.getInstance()`.

**setUpAll block** (library_screen_test.dart lines 88–100):
```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key',
  );
});
```
This block is required in every screen test file that indirectly uses `AccessService` (which calls `Supabase.instance`).

**Widget pump helper** (library_screen_test.dart lines 61–76 — adapted for CalculatorScreen):
```dart
Future<void> _pumpCalculatorScreen(
  WidgetTester tester,
  String calculatorId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<StorageService>.value(value: storage)],
      child: MaterialApp(
        home: CalculatorScreen(calculatorId: calculatorId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```
`CalculatorScreen` only needs `StorageService` in its provider tree (for favorites). No `AuthProvider` or `SettingsProvider` needed.

**testWidgets pattern** (library_screen_test.dart lines 106–113):
```dart
testWidgets('calculator screen title renders for shock-index', (tester) async {
  await _pumpCalculatorScreen(tester, 'shock-index');
  expect(find.text('Shock Index'), findsOneWidget);
});
```

**Required test cases to implement:**
- `_ClinicalNotesSection` is absent when all 5 fields are empty (pump `CalculatorScreen(calculatorId: 'bmi')` — bmi has no enhancement fields yet; verify `find.text('Clinical Notes')` returns `findsNothing`)
- `_ClinicalNotesSection` renders 'Clinical Notes' ExpansionTile when fields are populated (pump any new calculator that has fields set; tap the tile; verify field headings appear)
- BMI weight converts correctly: enter `70` in weight field, change unit kg→lb, verify field text is `'154.32'`
- BMI height converts correctly: enter `170` in height field (cm), change to m, verify field text is `'1.70'`
- Shock Index renders and accepts numeric input (smoke test: pump, enter HR=100 SBP=80, tap Calculate, verify result text contains 'Shock Index')

---

## Shared Patterns

### Validation (input guards)
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — `_AnionGapFormState._calculate` (lines 865–873)
**Apply to:** All 18 new `_XxxFormState._calculate()` methods
```dart
final na = double.tryParse(_naCtrl.text);
final cl = double.tryParse(_clCtrl.text);
final hco3 = double.tryParse(_hco3Ctrl.text);
if (na == null || cl == null || hco3 == null) {
  ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter all three electrolyte values')));
  return;
}
```
Pattern: use `double.tryParse()`, check nulls (and `<= 0` for physiological values), show SnackBar, `return` early. Never call `onResult` with invalid inputs.

### Numeric input field
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — `_NumericField` (lines 302–326)
**Apply to:** Every text input in every new form
```dart
_NumericField(label: 'Heart rate (bpm)', controller: _hrCtrl),
```
`_NumericField` already applies `FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))`, `TextInputType.numberWithOptions(decimal: true)`, and consistent padding. Always use it for numeric inputs — never raw `TextField`.

### Controller disposal
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — any `dispose()` method (e.g., lines 348–353)
**Apply to:** Every new `_XxxFormState`
```dart
@override
void dispose() {
  _ctrl1.dispose();
  _ctrl2.dispose();
  super.dispose();
}
```
Every `TextEditingController` declared in state must be disposed. Call `super.dispose()` last.

### Result formatting
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — `_setResult` (lines 59–71) and `_ResultCard` (lines 208–298)
**Apply to:** All `widget.onResult(...)` call sites
The `resultText` passed to `_setResult` is prefixed with `_def.title` automatically (line 66: `_resultText = '${_def.title}: $result'`). Do not repeat the calculator title in the `result` argument — it will be doubled. Pass the numeric outcome + category only:
```dart
// Correct:
widget.onResult(result: '${value.toStringAsFixed(2)} — $category', ...);

// Wrong (title duplication):
widget.onResult(result: 'Shock Index: ${value.toStringAsFixed(2)} — $category', ...);
```

### Warning/educational note usage
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — `_ResultCard` (lines 241–297)
**Apply to:** All new `_XxxFormState._calculate()` methods
- `warning` — renders an orange-bordered container with warning icon. Use for safety-critical notes (drug dosing limits, contraindications, "this is a screening tool only").
- `educationalNote` — renders a teal container with lightbulb icon. Use for teaching points and contextual caveats.
- Both are optional; pass `null` when not applicable.

### Section header comment
**Source:** `enchiridion/lib/screens/calculator_screen.dart` — lines 206, 300, 328, 417, 521, 629, 724, 841, 909, 1019
**Apply to:** Each new calculator section in `calculator_screen.dart`
```dart
// ─── Calculator N: Calculator Title ──────────────────────────────────────────
```
Every calculator's form class block starts with this comment line. Use em-dashes to fill to ~80 chars. This maintains the file's navigability.

---

## No Analog Found

All 4 files have close analogs in the codebase. The only genuinely new pattern is `_ClinicalNotesSection` — an `ExpansionTile`-based static metadata widget. While `ExpansionTile` is a standard Flutter widget already used in the codebase, there is no existing private expandable-section widget to copy from directly. The RESEARCH.md code example (Pattern 4) is the authoritative template for this widget.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `_ClinicalNotesSection` (within calculator_screen.dart) | widget | — | No existing expandable-section widget analog; use RESEARCH.md Pattern 4 directly |

---

## Metadata

**Analog search scope:** `enchiridion/lib/models/`, `enchiridion/lib/screens/`, `enchiridion/test/`
**Files scanned:** 6 source files read in full
**Pattern extraction date:** 2026-06-03
