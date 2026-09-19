---
quick_id: 260918-dqz
batch_id: 260918-dqw
type: execute
autonomous: true
depends_on:
  - 260918-dqx
  - 260918-dqy
files_modified:
  - enchiridion/lib/models/calculator_definition.dart
  - enchiridion/lib/screens/calculator_list_screen.dart
  - enchiridion/lib/screens/calculator_screen.dart
  - enchiridion/test/models/calculator_definition_test.dart
  - enchiridion/test/screens/calculator_list_screen_test.dart
  - enchiridion/test/screens/calculator_screen_test.dart
  - enchiridion/test/guards/available_before_coming_soon_guard_test.dart
  - enchiridion/test/guards/calculator_form_coverage_guard_test.dart
  - .planning/quick/260918-dqz-for-the-calculators-all-should-be-part-of-the-list-and-those/CALCULATOR-SOURCING.md

estimate:
  tokens: 95000
  raw_tokens: 95000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - "Every calculator named in the app's authored calculator catalog (Ideas/ideas.md, the source PROJECT.md points at for calculator specs) appears in the Calculators list — none are hidden because they are unbuilt."
    - "A calculator with no working form renders grayed (muted title, muted description, muted avatar icon) and carries the shared 'Coming Soon' badge, using the same module every other coming-soon row in the app already uses."
    - "Tapping a coming-soon calculator never opens a calculator screen with a broken/unknown form — it acknowledges with a snackbar and stays on the list."
    - "Within a category, calculators that work are listed above calculators that do not; categories that contain at least one working calculator are listed above categories that contain none."
    - "The one free calculator per category on the free tier is always a calculator that actually works — a coming-soon entry can never occupy the free slot, and a coming-soon entry never shows a paywall lock."
    - "Twelve previously-listed-only calculators now compute real results from verified, standard clinical formulas, each with its explanation, clinical interpretation, and safety notes filled in."
    - "The calculators that could not be implemented are named in writing, each with the specific reason and the exact source decision needed to unblock it."
  artifacts:
    - enchiridion/lib/models/calculator_definition.dart
    - enchiridion/lib/screens/calculator_list_screen.dart
    - enchiridion/lib/screens/calculator_screen.dart
    - enchiridion/test/screens/calculator_list_screen_test.dart
    - enchiridion/test/guards/calculator_form_coverage_guard_test.dart
    - .planning/quick/260918-dqz-for-the-calculators-all-should-be-part-of-the-list-and-those/CALCULATOR-SOURCING.md
  key_links:
    - "CalculatorDefinition.implemented -> hasContent/isComingSoon getters -> the same predicate shape dqx/dqy established on ResourceTopic and CatalogBook"
    - "groupedCalculatorsInDisplayOrder() -> availableFirst() from lib/utils/content_availability.dart (dqx) -> CalculatorListScreen.build"
    - "CalculatorDefinition.isComingSoon -> ComingSoonStyle/ComingSoonBadge from lib/widgets/common/coming_soon.dart (dqy) -> _calcTile"
    - "CalculatorDefinition.implemented == true -> a real case branch in CalculatorScreen._buildInputs, locked together by the form-coverage guard test"
    - "_isLocked computed over implemented-only entries in a category -> kFreeCalculatorsPerCategory free slot always lands on a working calculator"
---

<objective>
Put every calculator from the app's authored catalog into the Calculators list, gray out the
ones with no working form and badge them "Coming Soon", implement the twelve whose formulas are
standard and verifiable, and write down exactly which remaining ones cannot be implemented and
what is needed to unblock each.

Purpose: `kCalculators` currently holds 26 entries and every one of them has a working form —
so the list silently hides the ~32 other calculators the user specified in `Ideas/ideas.md`
(Cardiology, Respiratory, Surgery & Trauma, Utility categories have no presence in the app at
all). A user browsing Calculators cannot tell what is planned, and the team cannot tell what
is left to build. The two sibling tasks in this batch already shipped the shared ordering rule
(`availableFirst`) and the shared grayed treatment (`ComingSoonStyle`/`ComingSoonBadge`) and
deliberately left `calculator_list_screen.dart` untouched for this task.

Output: a 58-entry `kCalculators` catalog carrying an `implemented` flag, a display-order helper
that ranks working calculators and working categories first, a calculator list screen that grays
and badges unbuilt entries and refuses to navigate into them, twelve new working calculators, a
guard test that makes "marked implemented but has no form" impossible, and a written sourcing
report for the ones that are blocked.
</objective>

<context>
@.planning/STATE.md
@CLAUDE.md
@enchiridion/lib/models/calculator_definition.dart
@enchiridion/lib/screens/calculator_list_screen.dart
@enchiridion/lib/screens/calculator_screen.dart
@enchiridion/lib/utils/content_availability.dart
@enchiridion/lib/widgets/common/coming_soon.dart
@enchiridion/lib/config/freemium_config.dart
@enchiridion/test/models/calculator_definition_test.dart
@enchiridion/test/guards/available_before_coming_soon_guard_test.dart
@enchiridion/test/screens/calculator_screen_test.dart
@enchiridion/test/screens/calculator_favorites_test.dart
@Ideas/ideas.md
</context>

<inherited_infrastructure>
Siblings `260918-dqx` and `260918-dqy` are ALREADY MERGED into `main`. Reuse their work; do
not re-declare any of it.

From `enchiridion/lib/utils/content_availability.dart` (dqx):
- `List<T> availableFirst<T>(Iterable<T> items, bool Function(T) isAvailable)` — a STABLE
  two-bucket partition (available group first, each group keeping its authored relative order).
  Use this, never `List.sort`.
- `const String kComingSoonLabel = 'Coming Soon'` — the single spelling. Do not declare a
  second one anywhere.

From `enchiridion/lib/widgets/common/coming_soon.dart` (dqy):
- `ComingSoonStyle` — `title(ColorScheme)`, `body(ColorScheme)`, `icon(ColorScheme)`,
  `container(ColorScheme)` plus the raw alphas. These alphas were lifted verbatim FROM this
  very file's freemium-locked branch (title 0.5, body 0.35, icon 0.4), so a coming-soon
  calculator row and a locked calculator row already read as one visual family.
- `ComingSoonBadge({bool compact = false})` — the only widget that renders the label. Use
  `compact: true` in a dense `ListTile` trailing slot.
- `ComingSoonDim({required Widget child, required bool dimmed})` — not needed here; the
  calculator list has no hero imagery.
- `coming_soon.dart` RE-EXPORTS `kComingSoonLabel`. Importing both files is safe and yields
  exactly one symbol.

Model precedent to mirror (set by dqx/dqy on `ResourceTopic` and `CatalogBook`):
`bool get hasContent => ...;` and `bool get isComingSoon => !hasContent;`

The dartdoc at the top of `coming_soon.dart` currently states that
`calculator_list_screen.dart` intentionally does NOT consume the module because its muted rows
are a freemium paywall lock rather than unavailable content. That carve-out expires with this
plan — Task 1 updates that dartdoc paragraph, because calculators now have BOTH states.
</inherited_infrastructure>

<catalog>
## Entries Task 1 adds to `kCalculators` (32 new, all `implemented: false`)

Sourced from `Ideas/ideas.md` lines 1–71 (the nine-category calculator catalog PROJECT.md
names as the calculator spec). Entries already present in `kCalculators` are not repeated.
Three `Ideas/ideas.md` lines are duplicates of shipped calculators and are deliberately NOT
added — "Serum Osmolality" (already `osmolality`), "IV drip rate calculator" and "Time-based
infusion calculator" (both already `iv-infusion`). Record that in the Task 3 report.

Existing categories keep their existing app names (`Drug Dosing`, `Emergency & Critical Care`,
`General`, `Obs & Gynae`, `Paediatrics`) — do not rename them. Four new categories are
introduced: `Cardiology`, `Respiratory`, `Surgery & Trauma`, `Utility`.

| id | title | category | description | implemented by |
|---|---|---|---|---|
| `parkland` | Fluid Resuscitation (Parkland) | Emergency & Critical Care | Burn fluid resuscitation volume for the first 24 hours. | Task 3 |
| `sofa` | SOFA Score | Emergency & Critical Care | Six-organ sequential organ failure assessment score. | — |
| `adrenaline-dose` | Adrenaline Dose (Resuscitation) | Drug Dosing | Weight-based adrenaline dose for arrest and anaphylaxis. | — |
| `map` | Mean Arterial Pressure (MAP) | Cardiology | Mean arterial pressure from systolic and diastolic BP. | Task 2 |
| `qtc` | QTc (Corrected QT) | Cardiology | Heart-rate-corrected QT interval. | Task 2 |
| `chads-vasc` | CHA₂DS₂-VASc Score | Cardiology | Stroke risk in non-valvular atrial fibrillation. | Task 3 |
| `has-bled` | HAS-BLED Score | Cardiology | Major bleeding risk on anticoagulation. | Task 3 |
| `timi` | TIMI Risk Score | Cardiology | Risk stratification in acute coronary syndrome. | — |
| `framingham` | Framingham Risk Score | Cardiology | Ten-year cardiovascular risk estimate. | — |
| `cardiac-output` | Cardiac Output | Cardiology | Cardiac output and cardiac index estimate. | — |
| `cao2` | Oxygen Content (CaO₂) | Respiratory | Arterial oxygen content from haemoglobin, SaO₂, and PaO₂. | Task 2 |
| `alveolar-gas` | Alveolar Gas Equation | Respiratory | Alveolar oxygen tension from FiO₂ and PaCO₂. | — |
| `pefr-predicted` | PEFR Predicted | Respiratory | Predicted peak expiratory flow from age, sex, and height. | — |
| `fev1-predicted` | FEV1 Predicted | Respiratory | Predicted FEV1 from age, sex, height, and ethnicity. | — |
| `abg-interpretation` | ABG Interpretation Assistant | Respiratory | Step-through acid–base interpretation of a blood gas. | — |
| `corrected-calcium` | Corrected Calcium | General | Albumin-corrected serum calcium. | Task 2 |
| `ldl-friedewald` | LDL (Friedewald) | General | Calculated LDL cholesterol from a lipid panel. | Task 2 |
| `waist-hip-ratio` | Waist-to-Hip Ratio | General | Central adiposity risk from waist and hip circumference. | Task 2 |
| `meld` | MELD Score | General | End-stage liver disease severity score. | — |
| `child-pugh` | Child-Pugh Score | General | Chronic liver disease severity class A–C. | — |
| `gtpal` | GTPAL | Obs & Gynae | Obstetric history as Gravida, Term, Preterm, Abortions, Living. | Task 3 |
| `bishop-score` | Bishop Score | Obs & Gynae | Cervical favourability for induction of labour. | — |
| `partograph` | Partograph Plotting | Obs & Gynae | Plot labour progress against alert and action lines. | — |
| `preeclampsia-risk` | Preeclampsia Risk | Obs & Gynae | Risk stratification for pre-eclampsia. | — |
| `burn-tbsa` | Burn % (Rule of 9s) | Surgery & Trauma | Total body surface area burned, adult and paediatric. | Task 3 |
| `alvarado` | Alvarado Score | Surgery & Trauma | Likelihood of acute appendicitis. | — |
| `wells-score` | Wells Score (DVT / PE) | Surgery & Trauma | Pre-test probability for DVT and pulmonary embolism. | — |
| `revised-trauma-score` | Revised Trauma Score | Surgery & Trauma | Physiological trauma severity from GCS, SBP, and RR. | — |
| `iss` | Injury Severity Score (ISS) | Surgery & Trauma | Anatomical trauma severity from AIS region scores. | — |
| `ibw` | Ideal Body Weight (IBW) | Utility | Ideal and adjusted body weight from height and sex. | Task 2 |
| `unit-conversions` | Unit Conversions | Utility | Convert between clinical units (mg ↔ mmol, lb ↔ kg). | — |
| `calorie-requirements` | Calorie Requirements | Utility | Daily energy requirement from weight, height, age, activity. | — |

Resulting catalog after Task 1: **58 entries in 9 categories**, 26 implemented, 32 coming soon.
Resulting catalog after Task 3: **58 entries, 38 implemented, 20 coming soon**, with every one
of the nine categories holding at least one working calculator.

Per-category totals after Task 1 (unchanged by Tasks 2–3, which only flip flags):
Drug Dosing 9, Emergency & Critical Care 11, General 6, Obs & Gynae 5, Paediatrics 7,
Cardiology 7, Respiratory 5, Surgery & Trauma 5, Utility 3 — sum 58.
</catalog>

<tasks>

<task type="tracer">
  <name>Task 1: Whole catalog in the list, grayed and badged when there is no form</name>
  <files>enchiridion/lib/models/calculator_definition.dart, enchiridion/lib/screens/calculator_list_screen.dart, enchiridion/lib/widgets/common/coming_soon.dart, enchiridion/test/models/calculator_definition_test.dart, enchiridion/test/screens/calculator_list_screen_test.dart, enchiridion/test/guards/available_before_coming_soon_guard_test.dart, enchiridion/test/guards/calculator_form_coverage_guard_test.dart</files>
  <behavior>
    - `CalculatorDefinition` gains `final bool implemented` defaulting to `true`, so all 26
      existing const entries compile untouched; `hasContent` returns it and `isComingSoon`
      returns its negation, matching the getter pair dqx/dqy put on the other two models.
    - `kCalculators` holds exactly 58 entries across exactly 9 distinct categories; every id is
      unique; the per-category totals are Drug Dosing 9, Emergency & Critical Care 11,
      General 6, Obs & Gynae 5, Paediatrics 7, Cardiology 7, Respiratory 5,
      Surgery & Trauma 5, Utility 3.
    - `groupedCalculatorsInDisplayOrder()` returns categories ordered so that every category
      containing at least one implemented calculator precedes every category containing none,
      with authored category order preserved inside each of those two buckets; at this point
      Cardiology, Respiratory, Surgery & Trauma, and Utility are the trailing four.
    - Inside each category's list, every implemented calculator precedes every coming-soon one,
      and the authored order among the implemented ones is unchanged (Drug Dosing still starts
      with `weight-dosing`, Emergency still starts with `gcs`, General still starts with `bmi`,
      Obs & Gynae still starts with `edd-ega`, Paediatrics still starts with `holliday-segar`).
    - On the list screen with full access granted, a coming-soon row renders its title in
      `ComingSoonStyle.title`, its description in `ComingSoonStyle.body`, and exactly one
      `ComingSoonBadge`; an implemented row renders neither.
    - Tapping a coming-soon row pushes no route and shows a `SnackBar`; tapping an implemented
      row still opens `CalculatorScreen`.
    - With access denied, no coming-soon row renders a lock icon, and the free (unlocked) entry
      in each category is an implemented calculator — specifically, denying access and reading
      Cardiology (whose entries are all coming-soon at this point) produces zero locked rows.
    - The form-coverage guard pumps `CalculatorScreen` once per implemented id and finds no
      unknown-calculator fallback text rendered for any of them.
    - The existing favorites round-trip test still passes unchanged.
  </behavior>
  <action>
    Add `final bool implemented;` to `CalculatorDefinition` with `this.implemented = true` in
    the const constructor so no existing entry needs editing, then add
    `bool get hasContent => implemented;` and `bool get isComingSoon => !hasContent;` with a
    dartdoc noting these mirror the same pair on `ResourceTopic`/`CatalogBook`.

    Append the 32 entries from the `<catalog>` table above to `kCalculators`, each passing
    `implemented: false` and supplying only `id`, `title`, `category`, `description`. Leave
    `explanation`, `clinicalInterpretation`, `safetyNotes`, `commonPitfalls`, and `osceTips`
    at their empty defaults — an entry with no form produces no result to explain, and Tasks 2
    and 3 fill those fields for the twelve they build. Group the appended entries by category
    with a section comment per category, keeping the file's existing formatting style. Do not
    reorder or edit any of the 26 existing entries, and do not rename any existing category.

    Add `Map<String, List<CalculatorDefinition>> groupedCalculatorsInDisplayOrder([List<CalculatorDefinition> calculators = kCalculators])`
    next to `groupByCategory`. Build it on top of `groupByCategory`, then apply `availableFirst`
    (imported from `../utils/content_availability.dart`) twice: once over the category keys,
    keyed on whether that category holds any entry with `hasContent`, and once over each
    category's entry list, keyed on `hasContent`. Return a `LinkedHashMap` so key insertion
    order is the display order. Keep `groupByCategory` as-is — it stays the authored-order
    primitive this helper composes over.

    Rewrite `_CalculatorListScreenState` to consume the above. `build` reads
    `groupedCalculatorsInDisplayOrder()` instead of `groupByCategory(kCalculators)`, and the
    favorites row filters to entries where `hasContent` is true so a stale favourite for a
    now-unbuilt id cannot surface. Change `_isLocked` to return false immediately when the
    calculator `isComingSoon` — an unbuilt calculator is not paywalled content and must never
    show a lock — and to compute the freemium index over that category's implemented entries
    only (`kCalculators.where((c) => c.category == calc.category && c.hasContent)`), so a
    coming-soon entry can never consume the `kFreeCalculatorsPerCategory` free slot. Because
    `availableFirst` is stable, that filtered order is exactly the order the user sees, so the
    free slot always lands on the first working calculator displayed in the category.

    In `_calcTile`, branch on `calc.isComingSoon` BEFORE the existing `locked` branch so
    coming-soon wins whenever both could apply. For a coming-soon tile: avatar background
    `ComingSoonStyle.container(cs)` with `Icons.schedule` tinted `ComingSoonStyle.icon(cs)`,
    title styled `ComingSoonStyle.title(cs)`, subtitle styled `ComingSoonStyle.body(cs)`,
    trailing `const ComingSoonBadge(compact: true)`, and an `onTap` that shows a floating
    `SnackBar` reading `'${calc.title} — $kComingSoonLabel'` and returns without navigating —
    the exact tap-guard shape `resource_topic_list_screen.dart` already uses. Replace the
    existing hardcoded alpha literals in the locked branch with the `ComingSoonStyle` helpers
    so the two states stay visually in lock-step from one place. Import
    `../widgets/common/coming_soon.dart` and `../utils/content_availability.dart`.

    Update the module dartdoc at the top of `coming_soon.dart`: replace the paragraph asserting
    that the calculator list does not consume this module with one stating that the calculator
    list consumes it for genuinely unbuilt calculators while keeping the freemium lock as a
    separate state that takes lower precedence, and add the calculator list to the consumers
    sentence.

    Fix the now-stale assertions in `test/models/calculator_definition_test.dart`. The entry
    count becomes 58 with a comment tying it to `Ideas/ideas.md` as the authored source. Replace
    the brittle per-category count block and the five-key set with checks that survive future
    additions: the nine category keys, the per-category totals listed in the behavior block,
    that the grouped lengths sum to `kCalculators.length`, that no group is empty, and that all
    ids are unique. Keep the existing first-per-category assertions — they now also prove the
    appended entries did not displace the freemium head of any category. Add assertions that
    `implemented` defaults to true for a definition constructed without it, that the count of
    implemented entries is 26 and coming-soon is 32 at this point, and a
    `groupedCalculatorsInDisplayOrder` test covering both the category-level and within-category
    ordering described above.

    Create `test/screens/calculator_list_screen_test.dart` for the screen-level behaviors. Use
    the harness `test/screens/calculator_favorites_test.dart` already establishes —
    `SharedPreferences.setMockInitialValues({})`, a `StorageService` provider, and
    `AccessService.testAccessOverride` with an `addTearDown` that restores it to null. Scroll the
    `ListView` to reach trailing categories rather than assuming they are on screen.

    Create `test/guards/calculator_form_coverage_guard_test.dart` asserting the one invariant
    that keeps Tasks 2 and 3 honest: for every entry in `kCalculators` where `implemented` is
    true, pumping `CalculatorScreen(calculatorId: id)` must not render the fallback widget
    `_buildInputs` returns from its `default` branch. Read that fallback's exact string out of
    `lib/screens/calculator_screen.dart` and assert its absence with `findsNothing`; collect
    every failing id and report them together so one run names all offenders. Mirror the
    `setUpAll` from `test/screens/calculator_screen_test.dart` verbatim — it initialises
    `SharedPreferences` mock values AND calls `Supabase.initialize` with test credentials, and
    the screen will throw without both.

    Finally, register the calculator catalog with dqx's existing ordering guard: in
    `test/guards/available_before_coming_soon_guard_test.dart`, add one `_Catalog` entry per
    category from `groupedCalculatorsInDisplayOrder()`, named so a failure names the offending
    category. Do NOT register a flattened calculator list — flattening interleaves categories
    and would violate that guard's flat-list invariant by design.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/models/calculator_definition_test.dart test/screens/calculator_list_screen_test.dart test/screens/calculator_favorites_test.dart test/guards/available_before_coming_soon_guard_test.dart test/guards/calculator_form_coverage_guard_test.dart</automated>
  </verify>
  <done>All 58 catalog entries render in the Calculators list; the 32 with no form are grayed, badged, unlockable-by-nobody, and non-navigable; the 26 working ones are unchanged in behavior and still hold the free slot in every category; the form-coverage guard passes.</done>
  <reversibility rating="reversible">Additive model field with a safe default plus presentation changes; revertible by dropping the appended entries and restoring the previous `_calcTile`.</reversibility>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Implement the seven numeric-formula calculators</name>
  <files>enchiridion/lib/models/calculator_definition.dart, enchiridion/lib/screens/calculator_screen.dart, enchiridion/test/models/calculator_definition_test.dart, enchiridion/test/screens/calculator_screen_test.dart</files>
  <behavior>
    Worked examples each new form must reproduce, asserted as widget tests in
    `test/screens/calculator_screen_test.dart`:
    - `map`: systolic 120, diastolic 80 renders a result containing 93 (mmHg).
    - `qtc`: QT 400 ms at heart rate 60 renders 400 ms by Bazett; QT 400 ms at heart rate 100
      renders 516 ms by Bazett (RR 0.6 s) and flags prolongation.
    - `corrected-calcium`: measured calcium 2.10 mmol/L with albumin 30 g/L renders 2.30 mmol/L.
    - `ldl-friedewald`: total cholesterol 200, HDL 50, triglycerides 150 mg/dL renders 120 mg/dL;
      triglycerides above 400 mg/dL renders a validity warning instead of a silent number.
    - `waist-hip-ratio`: waist 90 cm, hip 100 cm renders 0.90.
    - `ibw`: male, height 177.8 cm renders 73 kg.
    - `cao2`: haemoglobin 15 g/dL, SaO₂ 98%, PaO₂ 100 mmHg renders approximately 20 mL/dL.
    - Every one of the seven ids opens a working form (the Task 1 form-coverage guard now
      covers 33 implemented ids and still passes).
    - `kCalculators` is still 58 entries; implemented is now 33, coming soon 25.
  </behavior>
  <action>
    Flip `implemented` to true (drop the `implemented: false` argument) on `map`, `qtc`,
    `corrected-calcium`, `ldl-friedewald`, `waist-hip-ratio`, `ibw`, and `cao2`, and fill their
    five enhancement fields (`explanation`, `clinicalInterpretation`, `safetyNotes`,
    `commonPitfalls`, `osceTips`) to the same depth and voice as the surrounding entries — those
    fields drive the `_ClinicalNotesSection` the user sees, and an implemented calculator with
    empty notes is a regression against the Phase 4 standard.

    Add a `case` branch per id to `CalculatorScreen._buildInputs` and a matching private
    `StatefulWidget` form to `calculator_screen.dart`, following the file's established shape:
    an `onResult`/`onReset` callback pair, `_NumericField` for numeric inputs, a
    `DropdownButtonFormField` for unit or sex selection, a `FilledButton` labelled Calculate,
    rejection of non-positive values, and a `── Calculator N: Title ──` section comment.
    Append the new forms after `_GrowthPercentileForm` in catalog order; do not disturb the
    26 existing forms.

    Formulas to implement, each stated with the units its form must accept:
    - Mean arterial pressure: diastolic plus one third of the pulse pressure (systolic minus
      diastolic), in mmHg. Interpret against the 65 mmHg organ-perfusion threshold, and reject
      a diastolic that is not below the systolic.
    - QTc: offer Bazett and Fridericia. RR in seconds is 60 divided by heart rate; Bazett
      divides QT by the square root of RR, Fridericia by the cube root. Report in ms and band
      the result against the conventional thresholds (above 450 ms in men, above 470 ms in
      women, above 500 ms carrying the highest torsades risk). Note in the safety field that
      Bazett over-corrects at fast rates and under-corrects at slow rates.
    - Corrected calcium: offer both unit systems. In SI, add 0.02 mmol/L for every 1 g/L that
      albumin falls below 40 g/L. In conventional units, add 0.8 mg/dL for every 1 g/dL that
      albumin falls below 4 g/dL.
    - LDL by Friedewald: total cholesterol minus HDL minus triglycerides divided by five in
      mg/dL, or divided by 2.2 in mmol/L. The estimate is invalid when triglycerides exceed
      400 mg/dL (4.5 mmol/L) — surface that as a warning and withhold the number rather than
      printing a misleading value.
    - Waist-to-hip ratio: waist divided by hip in matching units. Band against the WHO
      thresholds (above 0.90 in men, above 0.85 in women) using a sex selector.
    - Ideal body weight by the Devine formula: 50 kg for men or 45.5 kg for women, plus 2.3 kg
      for every inch of height above 60 inches; accept height in cm or inches. Also report
      adjusted body weight as IBW plus four tenths of the difference between actual and ideal
      weight when an actual weight is supplied, and note in the safety field that IBW is not
      valid below 60 inches without a different method.
    - Arterial oxygen content: 1.34 multiplied by haemoglobin in g/dL multiplied by SaO₂ as a
      fraction, plus 0.003 multiplied by PaO₂ in mmHg, reported in mL per dL. Accept SaO₂ as a
      percentage in the UI and convert. Note that the dissolved term is small at room air and
      that this is content, not delivery — delivery additionally requires cardiac output.

    Extend `test/models/calculator_definition_test.dart`'s implemented/coming-soon counts to
    33/25. Extend `test/screens/calculator_screen_test.dart` with one widget test per worked
    example above, reusing its existing `_pumpCalculatorScreen` helper and `setUpAll`; enter
    values with `tester.enterText`, tap Calculate, and assert on the rendered result text using
    a substring matcher so trailing interpretation prose does not make the test brittle.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/calculator_screen_test.dart test/models/calculator_definition_test.dart test/guards/calculator_form_coverage_guard_test.dart</automated>
  </verify>
  <done>All seven calculators compute their worked examples correctly, carry full clinical notes, are no longer grayed in the list, and the form-coverage guard passes with 33 implemented ids.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Implement the five score calculators and write the sourcing report</name>
  <files>enchiridion/lib/models/calculator_definition.dart, enchiridion/lib/screens/calculator_screen.dart, enchiridion/test/models/calculator_definition_test.dart, enchiridion/test/screens/calculator_screen_test.dart, .planning/quick/260918-dqz-for-the-calculators-all-should-be-part-of-the-list-and-those/CALCULATOR-SOURCING.md</files>
  <behavior>
    Worked examples each new form must reproduce, asserted in
    `test/screens/calculator_screen_test.dart`:
    - `chads-vasc`: a 76-year-old female with hypertension scores 4 (age 2, sex 1,
      hypertension 1) out of 9.
    - `has-bled`: uncontrolled hypertension plus age over 65 plus labile INR scores 3, banded
      as high bleeding risk.
    - `burn-tbsa`: adult with head and one whole arm selected renders 18%; switching to the
      paediatric preset with head and one whole leg selected renders 32%.
    - `parkland`: 70 kg with 20% TBSA renders 5600 mL over 24 hours with 2800 mL in the first
      8 hours.
    - `gtpal`: gravida 3, term 1, preterm 1, abortions 1, living 2 renders the G3 T1 P1 A1 L2
      string; term plus preterm plus abortions exceeding gravida renders a consistency warning.
    - `kCalculators` is still 58 entries; implemented is 38, coming soon 20; every one of the
      nine categories now contains at least one implemented calculator, so
      `groupedCalculatorsInDisplayOrder` returns all nine categories in authored order with no
      category demoted.
  </behavior>
  <action>
    Flip `implemented` to true on `chads-vasc`, `has-bled`, `burn-tbsa`, `parkland`, and
    `gtpal`, filling their five enhancement fields to the same depth as the surrounding
    entries. Add a `case` branch and private form per id, following the `_QsofaForm` /
    `_ApgarForm` shape already in the file — `SwitchListTile` for binary criteria,
    `DropdownButtonFormField` for graded ones, `_NumericField` for counts and measurements.

    Scoring definitions to implement:
    - CHA₂DS₂-VASc: congestive heart failure 1, hypertension 1, age 75 or over 2, diabetes 1,
      prior stroke/TIA/thromboembolism 2, vascular disease 1, age 65 to 74 1, female sex 1;
      maximum 9. Drive age from a single age input so the 2-point and 1-point age bands are
      mutually exclusive by construction rather than by the user remembering. Interpret against
      the usual anticoagulation discussion thresholds and state in the safety field that the
      score applies to non-valvular atrial fibrillation only.
    - HAS-BLED: uncontrolled hypertension 1, abnormal renal function 1, abnormal liver function
      1, prior stroke 1, bleeding history or predisposition 1, labile INR 1, age over 65 1,
      drugs predisposing to bleeding 1, alcohol excess 1; maximum 9. Band 3 or more as high
      risk, and state in the interpretation that a high score prompts addressing modifiable
      bleeding risks rather than withholding anticoagulation.
    - Burn total body surface area by the rule of 9s, with an adult/paediatric selector. Adult
      regions: head and neck 9, each arm 9, each leg 18, anterior trunk 18, posterior trunk 18,
      perineum 1. Paediatric preset: head and neck 18, each leg 14, with the remaining regions
      unchanged. Sum only selected regions and cap the displayed total at 100. State in the
      safety field that the rule of 9s is a field estimate and that Lund–Browder is the
      reference method in children, and in the pitfalls field that superficial (erythema-only)
      burns are excluded from the total.
    - Parkland: 4 mL multiplied by weight in kg multiplied by percent TBSA, delivered over
      24 hours from the time of the burn, with half in the first 8 hours and the remainder over
      the following 16 hours. Report the total, the first-8-hour volume with its mL/hr rate, and
      the next-16-hour volume with its rate. Accept weight in kg or lb. State in the safety
      field that the clock starts at the time of injury, not at presentation, and that the
      formula is a starting point titrated to urine output.
    - GTPAL: gravida, term births at 37 weeks or later, preterm births from 20 to 36 completed
      weeks, losses before 20 weeks, and living children. Render the standard five-letter
      string. Warn when term plus preterm plus abortions exceeds gravida, and note that a
      current pregnancy counts toward gravida but not toward the para components.

    Extend the implemented/coming-soon counts in `test/models/calculator_definition_test.dart`
    to 38/20, and add an assertion that every category key in
    `groupedCalculatorsInDisplayOrder()` maps to a list whose first entry is implemented — the
    end-state property that the free slot in every category is a working calculator.

    Then write `CALCULATOR-SOURCING.md` in this task's quick directory: a table of the 20
    calculators still marked coming soon, each with the specific reason it was not implemented
    and the exact decision or source needed to unblock it. Split the table into two clearly
    separated groups, because they need different things from the reader:
    (a) BLOCKED ON A SOURCE DECISION — implementing them requires choosing between competing
    published definitions or obtaining reference data the repository does not have. Cover at
    minimum: `timi` (distinct unstable-angina/NSTEMI and STEMI scores — which one), `framingham`
    (sex-specific coefficient tables and which edition), `cardiac-output` (which method, and the
    assumed oxygen consumption if Fick), `pefr-predicted` and `fev1-predicted` (population-
    specific reference equations — which reference population for this app's users),
    `abg-interpretation` (a rule engine and a specified interpretation algorithm, not a
    formula), `meld` (original MELD, MELD-Na, or MELD 3.0), `partograph` (a plotting surface
    needing a UI spec, not a calculator), `preeclampsia-risk` (competing published tools — which
    one), `iss` (requires AIS region coding the app cannot supply), `unit-conversions`
    (mg-to-mmol needs a per-substance molar mass table), and `adrenaline-dose` (high-risk
    weight-based dosing that must be tied to a named resuscitation protocol before shipping).
    (b) FORMULA VERIFIED, DEFERRED FOR SCOPE — standard and unambiguous, implementable in a
    follow-up with no further decisions: `sofa`, `alveolar-gas` (note its PAO₂ term is already
    computed inside the shipped A-a gradient calculator), `child-pugh`, `bishop-score`,
    `alvarado`, `wells-score`, `revised-trauma-score`, and `calorie-requirements` (note the
    predictive-equation choice as the only open question).
    Also record the three `Ideas/ideas.md` lines deliberately not added as separate entries
    because they duplicate shipped calculators, naming the shipped calculator each maps to.
    Close with a one-line statement of the current split: 58 listed, 38 working, 20 coming soon.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test && flutter analyze lib test</automated>
  </verify>
  <done>All five score calculators compute their worked examples, every category holds at least one working calculator, the full test suite passes, `flutter analyze` introduces no new findings, and the sourcing report names all 20 remaining calculators with their blocker and unblock condition.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user input → calculator form | Free-text numeric entry crosses into clinical arithmetic rendered as a dose, volume, or risk score. |
| catalog flag → form dispatch | `implemented: true` is a claim that a form exists; a false claim renders a dead screen. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-dqz-01 | Tampering | `CalculatorScreen._buildInputs` dispatch | high | mitigate | `test/guards/calculator_form_coverage_guard_test.dart` (Task 1) pumps every implemented id and fails if the default fallback branch renders, so a flag flipped without a form cannot merge. |
| T-dqz-02 | Information disclosure | `_isLocked` freemium gating | medium | mitigate | Task 1 computes the free-slot index over implemented entries only and returns unlocked for coming-soon entries, so padding the catalog cannot silently push a previously-free working calculator behind the paywall, and no unbuilt calculator is ever presented as purchasable. |
| T-dqz-03 | Tampering | new clinical formulas (Tasks 2–3) | high | mitigate | Each new calculator ships a worked-example widget test asserting its numeric output, plus populated `clinicalInterpretation` and `safetyNotes` and the existing default disclaimer rendered by `CalculatorScreen`; invalid-input paths (LDL above the Friedewald triglyceride ceiling, GTPAL inconsistency, non-positive values) warn rather than print a misleading number. |
| T-dqz-04 | Denial of service | coming-soon tap path | low | mitigate | Coming-soon rows show a snackbar and do not navigate, closing the route into a screen whose form does not exist. |
| T-dqz-05 | Tampering | npm/pip/cargo installs | n/a | accept | No package-manager installs in this plan — no dependency is added to `pubspec.yaml`. |
</threat_model>

<verification>
- `cd enchiridion && flutter test` — full suite green, including the two guard tests.
- `cd enchiridion && flutter analyze lib test` — introduces no findings beyond the 9 pre-existing
  ones the `260918-dqy` summary already documented (unused `key`, missing curly braces, and
  unnecessary casts in files this plan does not touch).
- The Calculators list shows 9 category headers; every unbuilt calculator is grayed with a
  Coming Soon badge and does not navigate on tap; every built calculator opens and computes.
</verification>

<success_criteria>
- `kCalculators` holds 58 entries in 9 categories — every calculator from `Ideas/ideas.md`
  except the three deliberate duplicates, which the sourcing report accounts for by name.
- 38 calculators compute real results; 20 are grayed and badged Coming Soon.
- No coming-soon calculator shows a paywall lock, occupies a category's free slot, or opens a
  screen.
- Within every category, working calculators precede unbuilt ones, and the first entry of every
  category is a working calculator.
- `CALCULATOR-SOURCING.md` names all 20 remaining calculators, split into blocked-on-a-source
  and formula-verified-deferred, each with its unblock condition.
</success_criteria>

<output>
Create `.planning/quick/260918-dqz-for-the-calculators-all-should-be-part-of-the-list-and-those/260918-dqz-SUMMARY.md` when done.
</output>
