[09:33, 4/6/2026] Lẹwa: on clicking it opens up to show a list of calculators
[09:35, 4/6/2026] Lẹwa: 1. Emergency & Critical Care
Glasgow Coma Scale (GCS)
qSOFA / SOFA score
NEWS2 (Early Warning Score)
Shock Index (HR/SBP)
Anion Gap
Osmolality & Osmolar Gap
Corrected Sodium (Hyperglycemia)
A-a Gradient
PaO₂/FiO₂ Ratio
Fluid Resuscitation (e.g., Burns – Parkland Formula)
[09:36, 4/6/2026] Lẹwa: 2. Drug Dosing & Pharmacology
Weight-based dosing (mg/kg)
Body Surface Area (BSA)
IV Infusion Rate (drops/min, ml/hr)
Creatinine Clearance (Cockcroft-Gault)
eGFR (CKD-EPI)
Gentamicin / Vancomycin dosing
Insulin dose calculators
Paracetamol dosing (pediatric & adult)
Adrenaline dose (resuscitation)
[09:36, 4/6/2026] Lẹwa: 3. Pediatrics
Weight estimation (APLS formula)
Broselow Tape equivalent (color → dose)
Pediatric BP percentiles
Fluid requirements (Holliday-Segar)
Neonatal bilirubin (nomogram)
APGAR score
Growth percentile calculator (WHO)
Gestational age calculator (EGA/EDD)
[09:36, 4/6/2026] Lẹwa: 4. Cardiology
CHA₂DS₂-VASc score
HAS-BLED score
TIMI score
Framingham Risk Score
QTc calculator
Mean Arterial Pressure (MAP)
Cardiac Output (basic)
[09:37, 4/6/2026] Lẹwa: 5. Respiratory
PEFR predicted
FEV1 predicted
ABG interpretation assistant
Alveolar gas equation
Oxygen content (CaO₂)
[09:37, 4/6/2026] Lẹwa: 6. General Medicine / Metabolic
BMI
Waist-to-hip ratio
Corrected Calcium
Serum Osmolality
LDL (Friedewald formula)
MELD score
Child-Pugh score
[09:38, 4/6/2026] Lẹwa: 7. Obstetrics & Gynecology
EDD / EGA calculator
Bishop Score
Partograph plotting
Preeclampsia risk tools
GTPAL calculator
[09:38, 4/6/2026] Lẹwa: 8. Surgery & Trauma
Revised Trauma Score
Injury Severity Score (ISS)
Burn % (Rule of 9s)
Alvarado Score (appendicitis)
Wells Score (DVT/PE)
[09:39, 4/6/2026] Lẹwa: 9. Simple Utility
Unit conversions (mg ↔️ mmol, lbs ↔️ kg)
IV drip rate calculator
Time-based infusion calculator
Calorie requirements
Ideal Body Weight (IBW)
[09:41, 4/6/2026] Lẹwa: if the calculators can include
“Explain result”
 “Clinical interpretation”
 “Next step suggestion”
“Common pitfalls”
“OSCE tips tied to result”

1. Weight-based drug dosing (mg/kg)
Purpose

Calculate total dose based on patient weight and prescribed dose per kilogram.

Primary use cases

Pediatric medication dosing
Emergency drug preparation
Quick adult weight-based dosing when required

Inputs

Weight value
Weight unit: kg or lb
Dose ordered per kg
Dose unit: mg/kg, mcg/kg, g/kg, mL/kg
Optional frequency text field: once, q8h, q12h, daily, stat
Optional maximum dose

Outputs

Converted weight in kg
Calculated total dose per administration
If max dose is entered, display capped dose when exceeded
Optional warning if calculated dose exceeds max dose

Formula

If weight entered in lb: weight_kg = weight_lb / 2.20462
Total dose = weight_kg × ordered_dose_per_kg
If maximum dose exists and total dose > max dose, final dose = max dose

Validation rules

Weight must be greater than 0
Ordered dose must be greater than 0
Maximum dose must be greater than 0 if entered
Show hard stop if required fields are missing

Interpretation text examples

“Calculated dose per administration: 240 mg.”
“Dose exceeds stated maximum. Final recommended displayed dose capped at 200 mg.”

Safety notes

Add label: “Always verify concentration and formulation before administration.”
Do not auto-convert mg to mL unless concentration is explicitly entered in a later version.

2. IV infusion rate calculator
Purpose

Calculate IV rate in mL/hour or drops/minute.

Modes
Mode A: Volume over time → mL/hour
Mode B: Volume, time, drop factor → drops/min

Inputs

Mode A

Total volume (mL)
Total infusion time (hours and/or minutes)

Mode B

Total volume (mL)
Total infusion time (hours and/or minutes)
Drop factor (gtt/mL), selectable presets: 10, 15, 20, 60

Outputs

mL/hour
drops/minute where applicable

Formulas

Total time in hours = hours + (minutes / 60)
mL/hour = total_volume / total_time_hours
Total time in minutes = hours × 60 + minutes
drops/min = (total_volume × drop_factor) / total_time_minutes

Validation rules

Volume must be greater than 0
Time must be greater than 0
Drop factor required for drops/min mode

Interpretation text examples

“Run at 125 mL/hour.”
“Equivalent gravity rate: 42 drops/min.”

Safety notes

Round drops/min to nearest whole number
Keep mL/hour to 1 decimal max unless whole number

3. Glasgow Coma Scale (GCS)
Purpose

Provide total GCS score and severity category.

Inputs

Eye response: 1 to 4
Verbal response: 1 to 5
Motor response: 1 to 6
Optional toggle: intubated / unable to verbalize

Outputs

Total GCS score
Component display, for example E3 V4 M5
Severity interpretation

Formula

GCS total = eye + verbal + motor
Interpretation categories
13–15: Mild impairment
9–12: Moderate impairment
8 or less: Severe impairment / coma

Validation rules

Inputs must be selected from valid ranges
If intubated toggle is on, verbal may be displayed as “VT” but scoring behavior should be defined in UI copy

UX note

Recommended approach for v1: keep numeric scoring standard, but allow note “verbal limited by intubation.” Avoid custom nonstandard total if not entered.

Interpretation text examples
“GCS 7 (E2 V1 M4): severe impairment.”

Safety notes

Add note: “Trend over time is clinically important.”

4. Body Mass Index (BMI)
Purpose

Calculate BMI and weight category.

Inputs

Weight: kg or lb
Height: cm or m or ft/in

Outputs

BMI value
Weight category

Formula

BMI = weight_kg / (height_m ^ 2)

Categories

< 18.5: Underweight
18.5–24.9: Healthy weight
25.0–29.9: Overweight
≥ 30.0: Obesity

Validation rules

Weight and height must be greater than 0
Convert all inputs to kg and meters internally

Interpretation text examples

“BMI 27.3: overweight.”
Safety notes
Add note: “BMI does not account for body composition, pregnancy, or edema.”

EDD / EGA calculator
Purpose

Calculate estimated date of delivery and gestational age from LMP.

Inputs

Last menstrual period (LMP)
Optional reference date, default = today
Optional cycle length field for later version; omit from v1 unless needed

Outputs

EDD
EGA in weeks and days on reference date
Formulas
EDD = LMP + 280 days
EGA_days = reference_date - LMP
EGA_weeks = floor(EGA_days / 7)
EGA_remaining_days = EGA_days mod 7

Validation rules

LMP cannot be in the future relative to reference date
If EGA < 0, return validation error
Interpretation text examples
“EDD: 10 May 2026.”
“Gestational age on 6 April 2026: 35 weeks + 1 day.”

Safety notes

Add note: “Dating ultrasound may be more accurate when LMP is uncertain or cycles are irregular.”

Anion Gap
Purpose

Calculate serum anion gap for metabolic acidosis evaluation.

Inputs

Sodium (Na+)
Chloride (Cl-)
Bicarbonate (HCO3-)
Optional potassium toggle for future version; do not include in v1 formula by default
Optional albumin field for later correction; not in v1 core calculation

Outputs

Anion gap value
Basic interpretation: normal, elevated, low

Formula

Anion gap = Na - (Cl + HCO3)
Reference interpretation for v1
Suggested normal range: about 8–12 mmol/L
Above range: elevated
Below range: low

Validation rules

All electrolyte inputs required
Inputs must be numeric
Interpretation text examples
“Anion gap 20 mmol/L: elevated.”
“Consider high anion gap metabolic acidosis in the right clinical context.”

Safety notes

Add note: “Normal ranges vary by lab and albumin level affects interpretation.”

7. Creatinine Clearance (Cockcroft-Gault)
Purpose

Estimate creatinine clearance for drug dosing support.

Inputs

Age (years)
Sex assigned at birth: male or female
Weight (kg or lb)
Serum creatinine
Creatinine unit: mg/dL or µmol/L

Outputs

Creatinine clearance estimate in mL/min
Kidney function interpretation band
Formula
Convert creatinine if in µmol/L: Scr_mg_dL = Scr_umol_L / 88.4
Male: CrCl = ((140 - age) × weight_kg) / (72 × Scr_mg_dL)
Female: CrCl = male_result × 0.85
Suggested interpretation bands for v1
≥ 90: normal or near-normal
60–89: mild reduction
30–59: moderate reduction
15–29: severe reduction
< 15: kidney failure range

Validation rules

Age > 0
Weight > 0
Creatinine > 0
Interpretation text examples
“Estimated creatinine clearance: 42 mL/min (moderate reduction).”

Safety notes

Add note: “Estimate may be unreliable in pregnancy, extremes of body size, amputees, or unstable renal function.”

8. Pediatric maintenance fluid calculator (Holliday-Segar)
Purpose

Calculate daily and hourly maintenance fluid requirements for children.

Inputs

Weight (kg or lb)

Outputs

Total maintenance fluid per 24 hours
Equivalent hourly maintenance rate
Formula

Using weight in kg:

First 10 kg: 100 mL/kg/day
Next 10 kg: 50 mL/kg/day
Each kg above 20 kg: 20 mL/kg/day

Hourly equivalent using 4-2-1 rule:

First 10 kg: 4 mL/kg/hr
Next 10 kg: 2 mL/kg/hr
Each kg above 20 kg: 1 mL/kg/hr

Validation rules

Weight must be greater than 0
Interpretation text examples
“Maintenance fluid: 1,250 mL/day.”
“Hourly rate: 52 mL/hour.”

Safety notes

Add note: “Adjust for dehydration, shock, renal disease, cardiac disease, burns, and ongoing losses.”

Calculator screen pattern

Each calculator should use a consistent structure:

Title
One-line purpose description
Input section
Result section
Interpretation section
Safety note / disclaimer
Save / copy / reset actions

Interaction rules
Compute in real time after valid input, or use a clear “Calculate” button.
Default to explicit unit selectors near each field.
Use large tap targets.
Preserve last used unit within session.
Reset button clears all fields.

Result design

Result block should include:

Main numeric answer in large type
Unit clearly shown
Short interpretation sentence
Optional secondary details below

Error states
Inline validation under the relevant field
No cryptic errors
Example: “Enter a valid weight greater than 0.”

Copy behavior

Allow one-tap copy of result as formatted text. Example: “Weight-based dose result: 240 mg per dose for 24 kg at 10 mg/kg.”

3) Clinical safety and disclaimer framework
Global disclaimer

“Enchiridion calculators are clinical support tools and do not replace professional judgment, institutional guidelines, or senior review.”

Global safety behaviors
Every calculator must show units.
Every calculator must reject impossible negative values.
Risk-prone calculators should display a short caution banner.
Avoid wording that implies autonomous prescribing.
High-risk wording guidance

Use:

“Calculated estimate”
“Suggested interpretation”
“Verify clinically”

Avoid:

“Definitive diagnosis”
“Guaranteed safe dose”
“Correct treatment”

Each calculator should define:

id
title
category
description
inputs
formula function
validation rules
formatter
interpretation rules
disclaimer

CTA labels
Calculate
Copy Result
Reset
Save
Add to Favorites