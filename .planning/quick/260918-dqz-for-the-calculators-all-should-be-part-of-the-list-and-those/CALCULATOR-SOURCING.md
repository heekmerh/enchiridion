# Calculator Sourcing Report

This report names every calculator still marked `implemented: false` in
`kCalculators` after this plan, why it was not implemented, and the exact
decision or source needed to unblock it. It also records the three
`Ideas/ideas.md` catalog lines that were deliberately not added because they
duplicate a calculator the app already ships.

## (a) Blocked on a source decision

Implementing these requires choosing between competing published
definitions, or obtaining reference data the repository does not have.
Picking the wrong one silently ships a clinically incorrect tool, so each
needs an explicit decision before a form can be written.

| id | title | category | Why blocked | What unblocks it |
|---|---|---|---|---|
| `timi` | TIMI Risk Score | Cardiology | There are two distinct, non-interchangeable TIMI scores — one for unstable angina/NSTEMI, one for STEMI — with different criteria and point weightings. | A decision on which TIMI variant (or both) to ship, and which one is the default when a user opens "TIMI Risk Score". |
| `framingham` | Framingham Risk Score | Cardiology | Requires sex-specific coefficient tables from a specific published edition (original vs. updated Framingham, vs. ASCVD/pooled cohort equations that have since superseded it in many guidelines). | A decision on which edition/coefficient table to implement, and confirmation it is still the reference guideline recommends for this app's audience. |
| `cardiac-output` | Cardiac Output | Cardiology | "Basic" cardiac output can mean several different methods (Fick, thermodilution-derived, pulse pressure-based estimates); the Fick method additionally needs an assumed oxygen consumption (VO₂) value when it isn't measured. | A decision on which method to implement, and — if Fick — the assumed VO₂ constant (or an input field for it) to use. |
| `pefr-predicted` | PEFR Predicted | Respiratory | Predicted peak flow depends on population-specific reference equations (e.g. EU/Nunn-Gregg vs. NHANES-derived) that differ by the population they were derived from. | A decision on which reference population/equation set applies to this app's users. |
| `fev1-predicted` | FEV1 Predicted | Respiratory | Same issue as PEFR: predicted FEV1 needs age/sex/height/ethnicity-specific reference equations (e.g. GLI-2012 vs. NHANES III), and ethnicity correction factors are themselves a live clinical-guideline debate. | A decision on which reference equation set (and whether to include an ethnicity correction at all) to implement. |
| `abg-interpretation` | ABG Interpretation Assistant | Respiratory | This is a step-through rule engine (primary disorder → compensation check → anion gap → delta ratio), not a single formula — it needs an explicit interpretation algorithm specified before it can be built. | A specified interpretation algorithm/decision tree the calculator should walk the user through, not just a formula. |
| `meld` | MELD Score | General | Three non-interchangeable variants exist in current use: original MELD, MELD-Na, and MELD 3.0 (which also incorporates sex and albumin). | A decision on which MELD variant to implement as the primary (and whether to offer more than one). |
| `partograph` | Partograph Plotting | Obs & Gynae | This is a plotting surface (a chart the user draws labour progress onto against alert/action lines), not a single-result calculator — it needs a UI spec for the chart interaction, which is out of scope for a form-based calculator screen. | A UI spec for the partograph plotting surface. |
| `preeclampsia-risk` | Preeclampsia Risk | Obs & Gynae | Several competing published risk tools exist (e.g. NICE/ACOG risk-factor checklists vs. first-trimester combined screening models using biomarkers and uterine artery Doppler), with materially different inputs and outputs. | A decision on which published tool to implement, given the inputs realistically available to this app's users. |
| `iss` | Injury Severity Score (ISS) | Surgery & Trauma | ISS requires AIS (Abbreviated Injury Scale) region coding as an input, which itself requires a licensed AIS reference dictionary the repository does not have and cannot supply. | Access to (or a substitute for) an AIS region-coding reference, or a decision to scope the calculator to a simplified proxy. |
| `unit-conversions` | Unit Conversions | Utility | A generic mg ↔ mmol converter needs a per-substance molar mass table (mg-to-mmol conversion is substance-specific, not a single constant) — there is no such table in the repository yet. | A decision on which substances to support and their molar masses (a small reference table), or scoping the first version to only lb ↔ kg (no molar mass needed). |
| `adrenaline-dose` | Adrenaline Dose (Resuscitation) | Drug Dosing | This is high-risk weight-based dosing for arrest and anaphylaxis — shipping a wrong dose formula or a dose for the wrong indication (arrest vs. anaphylaxis use very different adrenaline doses and routes) is a patient-safety risk. | A named resuscitation protocol (e.g. a specific ALS/APLS/anaphylaxis guideline edition) to tie the dose logic to, agreed before implementation, not inferred from general knowledge. |

## (b) Formula verified, deferred for scope

These are standard, unambiguous, and implementable in a follow-up plan with
no further decisions required — they were simply not in this plan's Task 2/3
scope of twelve calculators.

| id | title | category | Note |
|---|---|---|---|
| `sofa` | SOFA Score | Emergency & Critical Care | Six-organ scoring is standard and well-defined; larger form (six organ systems, each with graded criteria) than this plan's scope allowed. |
| `alveolar-gas` | Alveolar Gas Equation | Respiratory | Standard formula. Its PAO₂ term is already computed inside the shipped `aa-gradient` (A-a Gradient) calculator — a standalone form would expose that same intermediate value directly. |
| `child-pugh` | Child-Pugh Score | General | Standard, well-defined five-criterion score (bilirubin, albumin, INR, ascites, encephalopathy) with established class A/B/C bands. |
| `bishop-score` | Bishop Score | Obs & Gynae | Standard five-criterion cervical favourability score with no competing definitions. |
| `alvarado` | Alvarado Score | Surgery & Trauma | Standard ten-point appendicitis score with no competing definitions. |
| `wells-score` | Wells Score (DVT / PE) | Surgery & Trauma | Standard, though it has two variants (DVT and PE) that would need to be offered as a pair — well-defined, not blocked. |
| `revised-trauma-score` | Revised Trauma Score | Surgery & Trauma | Standard GCS/SBP/RR-weighted formula with no competing definitions. |
| `calorie-requirements` | Calorie Requirements | Utility | Standard predictive-equation calculators (e.g. Harris-Benedict, Mifflin-St Jeor) exist; the only open question is which predictive equation to default to — a minor scope decision, not a blocking one, since either is defensible and can ship with the other offered as an alternative. |

## Deliberate duplicates (not added to `kCalculators`)

Three `Ideas/ideas.md` lines describe calculators the app already ships
under a different name. They are intentionally not present as separate
`kCalculators` entries:

| `Ideas/ideas.md` line | Maps to shipped calculator |
|---|---|
| Serum Osmolality | `osmolality` (Osmolality & Osmolar Gap) |
| IV drip rate calculator | `iv-infusion` (IV Infusion Rate) |
| Time-based infusion calculator | `iv-infusion` (IV Infusion Rate) |

## Current split

58 listed, 38 working, 20 coming soon.
