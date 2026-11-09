---
quick_id: 260918-dqz
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, calculators, freemium, coming-soon, clinical-formulas]

# Dependency graph
requires:
  - phase: 260918-dqx
    provides: "availableFirst() / kComingSoonLabel in enchiridion/lib/utils/content_availability.dart"
  - phase: 260918-dqy
    provides: "ComingSoonStyle / ComingSoonBadge / ComingSoonDim in enchiridion/lib/widgets/common/coming_soon.dart"
provides:
  - "kCalculators expanded from 26 to 58 entries across 9 categories (up from 5), carrying an `implemented` flag"
  - "groupedCalculatorsInDisplayOrder() — the calculator-catalog display-order helper other catalogs' groupers can mirror"
  - "CalculatorListScreen consuming ComingSoonStyle/ComingSoonBadge for genuinely-unbuilt calculators, freemium lock kept as a separate lower-precedence state"
  - "Twelve new working calculators (MAP, QTc, corrected calcium, LDL Friedewald, waist-to-hip ratio, IBW, CaO2, CHA2DS2-VASc, HAS-BLED, burn TBSA, Parkland, GTPAL)"
  - "CALCULATOR-SOURCING.md — sourcing/blocker report for the 20 remaining coming-soon calculators"
affects: []

actuals:
  tokens: 28785
  tasks: 3
  commits: 3
  plan_head_before: b806ba76553d955194f9d59aa9299f55e26cda5a

tech-stack:
  added: []
  patterns:
    - "CalculatorDefinition.implemented -> hasContent/isComingSoon mirrors the exact getter pair dqx/dqy established on ResourceTopic/CatalogBook"
    - "groupedCalculatorsInDisplayOrder() composes over groupByCategory (kept as the authored-order primitive) by applying availableFirst() twice: once over category keys (keyed on 'does this category hold any implemented entry'), once over each category's entry list (keyed on hasContent) — both partitions stable, so authored order survives inside each bucket"
    - "_isLocked checks isComingSoon before hasAccess, and computes the freemium free-slot index over that category's implemented entries only — a coming-soon entry can never consume the free slot or show a lock, regardless of access state"
    - "_calcTile branches on isComingSoon before the locked branch, so coming-soon always wins when both could apply"

key-files:
  created:
    - enchiridion/test/screens/calculator_list_screen_test.dart
    - enchiridion/test/guards/calculator_form_coverage_guard_test.dart
    - .planning/quick/260918-dqz-for-the-calculators-all-should-be-part-of-the-list-and-those/CALCULATOR-SOURCING.md
  modified:
    - enchiridion/lib/models/calculator_definition.dart
    - enchiridion/lib/screens/calculator_list_screen.dart
    - enchiridion/lib/screens/calculator_screen.dart
    - enchiridion/lib/widgets/common/coming_soon.dart
    - enchiridion/test/models/calculator_definition_test.dart
    - enchiridion/test/screens/calculator_screen_test.dart
    - enchiridion/test/guards/available_before_coming_soon_guard_test.dart

key-decisions:
  - "32 coming-soon entries were sourced verbatim from Ideas/ideas.md's nine-category calculator catalog, per the plan's <catalog> table; three lines (Serum Osmolality, IV drip rate calculator, Time-based infusion calculator) were deliberately NOT added because they duplicate already-shipped calculators (osmolality, iv-infusion) — recorded in CALCULATOR-SOURCING.md."
  - "QTc reports both Bazett and Fridericia values in one result string rather than a single number, since the plan's worked examples and safety notes require surfacing both and stating Bazett's rate-dependent bias."
  - "CHA2DS2-VASc drives its two age-based point bands (75+, 65-74) from a single age input rather than two separate checkboxes, making the bands mutually exclusive by construction instead of relying on the user not double-checking both."
  - "Burn TBSA (Rule of 9s) models left/right arm and left/right leg as four separate switches (not two 'arms'/'legs' toggles), because the plan's worked examples require selecting exactly one whole arm or one whole leg to reproduce the 18%/32% totals."
  - "The 12 calculators built in Tasks 2-3 were chosen exactly as the plan's <catalog> table assigned them (7 numeric-formula in Task 2, 5 score-based in Task 3); no substitutions were made."

requirements-completed: []

coverage:
  - id: D1
    description: "kCalculators holds 58 entries across 9 categories (Drug Dosing 9, Emergency & Critical Care 11, General 6, Obs & Gynae 5, Paediatrics 7, Cardiology 7, Respiratory 5, Surgery & Trauma 5, Utility 3); every id unique; every calculator from Ideas/ideas.md present except the three deliberate duplicates"
    verification:
      - kind: unit
        ref: "enchiridion/test/models/calculator_definition_test.dart#kCalculators has exactly 58 entries"
      - kind: unit
        ref: "enchiridion/test/models/calculator_definition_test.dart#all calculator ids are unique"
      - kind: unit
        ref: "enchiridion/test/models/calculator_definition_test.dart#groupByCategory final per-category counts"
    human_judgment: false
  - id: D2
    description: "A coming-soon calculator renders muted title/description, exactly one ComingSoonBadge, never a lock icon, and tapping it shows a snackbar without navigating to CalculatorScreen"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_list_screen_test.dart#a coming-soon row shows exactly one ComingSoonBadge and no lock"
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_list_screen_test.dart#tapping a coming-soon row shows a SnackBar and does not navigate"
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_list_screen_test.dart#no coming-soon row renders a lock icon in Cardiology"
    human_judgment: false
  - id: D3
    description: "Within every category the free (unlocked) slot always lands on a working calculator; a coming-soon entry never occupies the free slot and never shows a paywall lock, even with access denied"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_list_screen_test.dart#the free (unlocked) entry in each category is an implemented calculator"
      - kind: unit
        ref: "enchiridion/test/models/calculator_definition_test.dart#every category key maps to a list whose first entry is implemented"
    human_judgment: false
  - id: D4
    description: "Every calculator marked implemented has a working form wired into CalculatorScreen (form-coverage guard) — a flag flipped without a form cannot merge"
    verification:
      - kind: unit
        ref: "enchiridion/test/guards/calculator_form_coverage_guard_test.dart#every implemented calculator id opens a working form (no unknown-calculator fallback)"
    human_judgment: false
  - id: D5
    description: "Twelve new calculators (map, qtc, corrected-calcium, ldl-friedewald, waist-hip-ratio, ibw, cao2, chads-vasc, has-bled, burn-tbsa, parkland, gtpal) compute their exact worked-example results, including two validity/warning paths (LDL triglyceride ceiling, GTPAL consistency check)"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_screen_test.dart#Task 2 worked examples (7 tests: map, qtc x2, corrected-calcium, ldl-friedewald x2, waist-hip-ratio, ibw, cao2)"
      - kind: automated_ui
        ref: "enchiridion/test/screens/calculator_screen_test.dart#Task 3 worked examples (6 tests: chads-vasc, has-bled, burn-tbsa, parkland, gtpal x2)"
    human_judgment: false
  - id: D6
    description: "CALCULATOR-SOURCING.md names all 20 remaining coming-soon calculators, split into blocked-on-a-source-decision (12) and formula-verified-deferred-for-scope (8), each with its specific unblock condition, plus the three deliberate Ideas/ideas.md duplicates"
    verification: []
    human_judgment: true
    rationale: "Editorial completeness/accuracy of a written report (does each entry state a real blocker and a genuine unblock condition) is a judgment call, not something a test can assert."

duration: 70min
completed: 2026-09-19
status: complete
---

# Quick Item 260918-dqz: Full Calculator Catalog Summary

**`kCalculators` grew from 26 entries in 5 categories to 58 entries in 9 categories — the 32 unbuilt ones render grayed with a Coming Soon badge via the shared `coming_soon.dart` module, 12 of them now have real working forms (bringing the total working count to 38), and the remaining 20 are named with their specific blocker in `CALCULATOR-SOURCING.md`.**

## Performance

- **Duration:** ~70 min
- **Started:** 2026-09-19T07:55:00Z (approx.)
- **Completed:** 2026-09-19T09:05:00Z (approx.)
- **Tasks:** 3/3
- **Files modified:** 10 (3 created, 7 modified)

## Accomplishments

- `CalculatorDefinition` gained an `implemented` flag (defaulting to `true`) plus `hasContent`/`isComingSoon` getters mirroring the pair dqx/dqy already established on `ResourceTopic`/`CatalogBook`.
- `kCalculators` grew from 26 to 58 entries, adding four brand-new categories (Cardiology, Respiratory, Surgery & Trauma, Utility) sourced verbatim from `Ideas/ideas.md`'s nine-category calculator spec.
- New `groupedCalculatorsInDisplayOrder()` ranks categories with at least one working calculator ahead of categories with none, and within each category ranks working calculators ahead of coming-soon ones — both partitions stable via `availableFirst()`, so authored order is preserved inside each bucket.
- `CalculatorListScreen` rewritten to consume the grouped order: coming-soon rows are grayed via `ComingSoonStyle`, badged with `ComingSoonBadge`, never navigable (tap shows a snackbar), and never show a paywall lock; the freemium free-slot calculation now runs over each category's implemented entries only, so padding the catalog with unbuilt entries can never push a previously-free working calculator behind the paywall.
- Twelve calculators flipped from coming-soon to fully working with real clinical-notes content: MAP, QTc (Bazett + Fridericia), corrected calcium (SI + conventional units), LDL by Friedewald (with a triglyceride validity ceiling), waist-to-hip ratio, IBW (Devine, with adjusted body weight), CaO2, CHA2DS2-VASc, HAS-BLED, burn TBSA (Rule of 9s with adult/paediatric preset), Parkland fluid resuscitation, and GTPAL — bringing the working total to 38/58.
- A new form-coverage guard test (`calculator_form_coverage_guard_test.dart`) pumps every implemented calculator id and fails if the screen's unknown-calculator fallback renders, making "flag flipped without a form" impossible to merge silently.
- `CALCULATOR-SOURCING.md` names all 20 remaining coming-soon calculators, split into 12 blocked on a source decision (e.g. which TIMI variant, which MELD variant, AIS coding access) and 8 verified-formula-deferred-for-scope (e.g. SOFA, Child-Pugh, Bishop Score), plus the three `Ideas/ideas.md` lines deliberately not added because they duplicate shipped calculators.

## Task Commits

Each task was committed atomically:

1. **Task 1: Whole catalog in the list, grayed and badged when there is no form** - `4e26bfb` (feat)
2. **Task 2: Implement the seven numeric-formula calculators** - `5633558` (feat)
3. **Task 3: Implement the five score calculators and write the sourcing report** - `7571c5e` (feat)

_Tasks 2 and 3 were `tdd="true"`: worked-example widget tests were written against the exact numbers the plan specified and run to confirm the implementation before each commit; `flutter test`/`flutter analyze` were green before every commit._

## Files Created/Modified

- `enchiridion/lib/models/calculator_definition.dart` - Added `implemented`/`hasContent`/`isComingSoon`; appended 32 coming-soon entries grouped by category with section comments; added `groupedCalculatorsInDisplayOrder()`; flipped 12 entries to `implemented: true` with full clinical-notes content across Tasks 2-3.
- `enchiridion/lib/screens/calculator_list_screen.dart` - `build` now reads `groupedCalculatorsInDisplayOrder()`; `_isLocked` returns false immediately for coming-soon entries and computes the free-slot index over implemented entries only; `_calcTile` branches on `isComingSoon` before the `locked` branch, rendering `ComingSoonStyle`/`ComingSoonBadge` and a snackbar-guarded tap for unbuilt calculators.
- `enchiridion/lib/screens/calculator_screen.dart` - Added 12 `case` branches to `_buildInputs` and 12 new private `StatefulWidget` forms (MAP, QTc, corrected calcium, LDL Friedewald, waist-to-hip ratio, IBW, CaO2, CHA2DS2-VASc, HAS-BLED, burn TBSA, Parkland, GTPAL), following the file's established form shape.
- `enchiridion/lib/widgets/common/coming_soon.dart` - Dartdoc updated: the calculator list is now a documented consumer of the shared module for genuinely-unbuilt calculators, with the freemium lock kept as a separate, lower-precedence state.
- `enchiridion/test/models/calculator_definition_test.dart` - Rewritten count/grouping assertions to survive future additions (per-category totals, uniqueness, non-empty groups); added `groupedCalculatorsInDisplayOrder` ordering tests and the end-state "every category's first entry is implemented" assertion.
- `enchiridion/test/screens/calculator_screen_test.dart` - Added 13 worked-example widget tests across Task 2 and Task 3, including both validity/warning paths (LDL triglyceride ceiling, GTPAL consistency check).
- `enchiridion/test/guards/available_before_coming_soon_guard_test.dart` - Registered the calculator catalog per-category (not flattened) with dqx's existing ordering guard.
- `enchiridion/test/screens/calculator_list_screen_test.dart` - **New.** Screen-level behavior tests: category headers render, coming-soon styling/badge/no-lock/no-navigate, implemented rows still navigate, free-slot-is-implemented under access-denied.
- `enchiridion/test/guards/calculator_form_coverage_guard_test.dart` - **New.** Pumps every implemented id and asserts the unknown-calculator fallback never renders.
- `.planning/quick/260918-dqz-.../CALCULATOR-SOURCING.md` - **New.** The 20-calculator sourcing/blocker report.

## Decisions Made

See `key-decisions` in frontmatter. In short: the 32 coming-soon entries and their categories came verbatim from `Ideas/ideas.md`; QTc surfaces both Bazett and Fridericia; CHA2DS2-VASc derives its age bands from one input to make them mutually exclusive by construction; burn TBSA models all four limbs separately to match the plan's worked examples exactly; and the 12 built calculators were exactly the ones the plan's `<catalog>` table assigned to Tasks 2 and 3.

## Deviations from Plan

**Worktree was stale relative to `main` at spawn time** (infrastructure, not a plan deviation, but recorded for traceability): this worktree's branch (`worktree-agent-a6a7d1c17f2e0fe1f`) was created from a commit that predated the `260918-dqw` batch landing `260918-dr0`/`260918-dr2` on `main`. Verified the branch was a strict ancestor of `main` with no unique commits (`git merge-base --is-ancestor` returned true), then fast-forwarded (`git merge --ff-only main`) before starting. No destructive git operations were used.

Otherwise: None - plan executed exactly as written; the 12 built calculators, their formulas, and worked examples match the plan's `<catalog>` and Task 2/3 `<action>` blocks exactly.

## Issues Encountered

- Several new Task 3 forms (`chads-vasc`, `has-bled`, `burn-tbsa`) have enough `SwitchListTile` rows that the Calculate button and later switches sit below the default 800×600 test viewport. Fixed by adding a small `_scrollTap` test helper (`tester.ensureVisible` + `pumpAndSettle` before every tap) rather than assuming default scroll position.
- `test/screens/calculator_list_screen_test.dart`'s original coming-soon example (`Mean Arterial Pressure (MAP)`) became implemented partway through Task 2/3, which would have silently broken those assertions at the wrong task boundary. Moved the example to `TIMI Risk Score`, a Cardiology entry that remains coming-soon through the whole plan (confirmed against `CALCULATOR-SOURCING.md`), and scoped the "access denied — no lock icon" assertion to coming-soon entries only (the implemented Cardiology entries are correctly locked when denied and not the free slot).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `groupedCalculatorsInDisplayOrder()`, the form-coverage guard, and the `implemented`/`hasContent`/`isComingSoon` pattern are stable and ready for any future calculator additions to reuse.
- `flutter analyze lib test` and `flutter test` (full suite, 205 tests) are both green; the only analyzer findings are the 9 pre-existing issues in unrelated files the `260918-dqy` summary already documented.
- `CALCULATOR-SOURCING.md` is ready to drive a follow-up plan: the 8 formula-verified-deferred calculators need no further decisions and could be picked up directly; the 12 blocked-on-a-source-decision calculators need an explicit human/product decision per row before implementation.

---
*Quick item: 260918-dqz (batch 260918-dqw)*
*Completed: 2026-09-19*

## Self-Check: PASSED

All created/modified files confirmed present on disk (lib, test, and `.planning/quick/.../CALCULATOR-SOURCING.md`); all three task commits (`4e26bfb`, `5633558`, `7571c5e`) confirmed present in `git log`.
