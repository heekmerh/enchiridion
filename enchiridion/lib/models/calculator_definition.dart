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

const String _kDefaultDisclaimer =
    'Enchiridion calculators are clinical support tools and do not replace '
    'professional judgment, institutional guidelines, or senior review.';

const List<CalculatorDefinition> kCalculators = [
  CalculatorDefinition(
    id: 'weight-dosing',
    title: 'Weight-Based Drug Dosing',
    category: 'Drug Dosing',
    description: 'Calculate total dose from patient weight and dose per kg.',
    explanation:
        'Multiplies the patient\'s weight in kilograms by the ordered dose per kg to give '
        'the total dose per administration. If a maximum dose is entered, the result is capped.',
    clinicalInterpretation:
        'Suggested calculated dose per administration. Verify against current formulary, '
        'institutional guidelines, and the patient\'s renal and hepatic function before prescribing.',
    safetyNotes:
        'Estimate may be unreliable in extreme obesity or cachexia — consider ideal body weight '
        'for some agents. Always verify concentration and formulation before administration.',
    commonPitfalls:
        'Entering weight in lb without selecting the lb unit option. '
        'Forgetting to apply the maximum dose cap for high-risk drugs.',
    osceTips:
        'State the formula clearly: Total dose = weight (kg) × dose per kg. '
        'Mention the max dose cap and the need to verify against the drug chart.',
  ),
  CalculatorDefinition(
    id: 'iv-infusion',
    title: 'IV Infusion Rate',
    category: 'Drug Dosing',
    description: 'Calculate infusion rate in mL/hr or drops/min.',
    explanation:
        'Calculates the rate needed to deliver a specified volume over a specified time. '
        'Mode A gives mL/hr; Mode B gives drops/min using the drop factor of the giving set.',
    clinicalInterpretation:
        'Set the infusion pump (Mode A) or gravity-feed giving set (Mode B) to the calculated rate. '
        'Re-check rate if infusion volume or time changes.',
    safetyNotes:
        'Always double-check pump settings and drug concentration before starting. '
        'Gravity-feed rates drift over time — re-count drops/min every 30–60 minutes.',
    commonPitfalls:
        'Mismatching time units (hours vs minutes) when entering infusion time. '
        'Using the wrong drop factor for the giving set (standard is 20 gtt/mL; blood sets use 15 gtt/mL).',
    osceTips:
        'Know the formula: drops/min = (volume × drop factor) / time in minutes. '
        'In OSCEs, state the drop factor being used and confirm pump settings aloud.',
  ),
  CalculatorDefinition(
    id: 'gcs',
    title: 'Glasgow Coma Scale',
    category: 'Emergency & Critical Care',
    description: 'Score conscious level from Eye, Verbal, and Motor responses.',
    explanation:
        'The GCS quantifies conscious level by scoring Eye (1–4), Verbal (1–5), and Motor (1–6) responses. '
        'Total ranges from 3 (deepest impairment) to 15 (fully alert).',
    clinicalInterpretation:
        'GCS 13–15: mild impairment. GCS 9–12: moderate impairment. GCS ≤ 8: severe impairment — '
        'consider airway protection and urgent escalation. Trend over serial assessments is clinically important.',
    safetyNotes:
        'GCS alone does not determine airway management — assess clinically. '
        'Sedation, paralysis, intubation, and metabolic derangements confound verbal and eye scores.',
    commonPitfalls:
        'Scoring verbal as 1 in intubated patients instead of using the "T" notation. '
        'Failing to document component scores (E, V, M) separately.',
    osceTips:
        'Always state all three components: E_V_M = total (e.g., E3 V4 M5 = 12). '
        'Examiners expect you to name the severity category and state the airway-protection threshold (GCS ≤ 8).',
  ),
  CalculatorDefinition(
    id: 'bmi',
    title: 'BMI',
    category: 'General',
    description: 'Body Mass Index from weight and height with WHO category.',
    explanation:
        'BMI = weight (kg) ÷ height² (m²). It is a screening index for weight-related health risk, '
        'not a direct measure of body fat or adiposity.',
    clinicalInterpretation:
        'WHO categories: < 18.5 underweight, 18.5–24.9 normal, 25–29.9 overweight, '
        '≥ 30 obese (Class I ≥ 30, Class II ≥ 35, Class III ≥ 40). Interpret in clinical context.',
    safetyNotes:
        'BMI does not account for muscle mass, body composition, ethnicity, pregnancy, or oedema. '
        'Athletes may be misclassified as overweight. Use alongside waist circumference and clinical assessment.',
    commonPitfalls:
        'Entering height in cm without selecting the cm unit option. '
        'Applying BMI cut-offs without considering body composition or ethnicity-specific thresholds.',
    osceTips:
        'State the formula and the WHO category. Mention at least two limitations (muscle mass, ethnicity). '
        'In paediatrics, use BMI-for-age percentiles, not adult cut-offs.',
  ),
  CalculatorDefinition(
    id: 'edd-ega',
    title: 'EDD / Gestational Age',
    category: 'Obs & Gynae',
    description: 'Estimated delivery date and gestational age from LMP.',
    explanation:
        'Uses Naegele\'s rule: EDD = LMP + 280 days (40 weeks). '
        'Gestational age (EGA) is calculated as the interval between LMP and the reference date.',
    clinicalInterpretation:
        'EGA guides antenatal care scheduling, screening tests, and management of preterm or post-term labour. '
        'Dating ultrasound in the first trimester is more accurate when LMP is uncertain.',
    safetyNotes:
        'LMP-based dating assumes a regular 28-day cycle and may be unreliable with irregular cycles, '
        'recent hormonal contraception, or uncertainty about the LMP date.',
    commonPitfalls:
        'Using the LMP of a cycle with known irregularity without correction. '
        'Forgetting that gestational age starts from LMP, not conception (conception is approximately week 2).',
    osceTips:
        'State Naegele\'s rule clearly. Mention first-trimester USS as the gold standard for dating. '
        'Know the clinical significance of being 7+ days from expected dates (redating criteria).',
  ),
  CalculatorDefinition(
    id: 'anion-gap',
    title: 'Anion Gap',
    category: 'Emergency & Critical Care',
    description: 'Classify metabolic acidosis from Na, Cl, and HCO₃.',
    explanation:
        'Anion Gap = Na⁺ − (Cl⁻ + HCO₃⁻). It estimates the concentration of unmeasured anions in plasma. '
        'A raised gap implies accumulation of an unmeasured acid.',
    clinicalInterpretation:
        'Normal: 8–12 mEq/L. Elevated (HAGMA): consider MUDPILES (Methanol, Uraemia, DKA, Propylene glycol, '
        'Isoniazid, Lactic acidosis, Ethylene glycol, Salicylates). Low: consider hypoalbuminaemia or myeloma.',
    safetyNotes:
        'Normal ranges vary by lab. Hypoalbuminaemia lowers the gap — correct by adding 2.5 × (4 − albumin g/dL). '
        'The gap can be falsely normal in mixed acid-base disorders.',
    commonPitfalls:
        'Forgetting to correct for hypoalbuminaemia in critically ill patients. '
        'Interpreting the gap without blood gas pH and clinical context.',
    osceTips:
        'State the formula and normal range. Mention albumin correction and the MUDPILES mnemonic. '
        'Examiners may ask you to interpret a simultaneous blood gas — link the anion gap to pH and HCO₃.',
  ),
  CalculatorDefinition(
    id: 'creatinine-clearance',
    title: 'Creatinine Clearance',
    category: 'Drug Dosing',
    description: 'Estimate CrCl via Cockcroft-Gault for renal dosing.',
    explanation:
        'The Cockcroft-Gault equation estimates creatinine clearance as a surrogate for GFR, '
        'using age, sex, weight, and serum creatinine.',
    clinicalInterpretation:
        'CrCl ≥ 90 mL/min: normal. 60–89: mildly decreased. 30–59: moderately decreased. '
        '15–29: severely decreased. < 15: kidney failure — refer nephrology, consider renal replacement.',
    safetyNotes:
        'Estimate may be unreliable in pregnancy, extreme body weight (use IBW or ABW for obese patients), '
        'amputees, rapidly changing renal function, or non-steady-state creatinine.',
    commonPitfalls:
        'Using actual body weight in obese patients when IBW is more appropriate for some drugs. '
        'Not recalculating when creatinine changes acutely in AKI.',
    osceTips:
        'Know the formula components (age, sex factor 0.85 for female, weight, creatinine). '
        'State the clinical implication for renal drug dosing (e.g., renally cleared antibiotics, anticoagulants).',
  ),
  CalculatorDefinition(
    id: 'holliday-segar',
    title: 'Paediatric Maintenance Fluids',
    category: 'Paediatrics',
    description: 'Holliday-Segar 4-2-1 rule for maintenance IV fluids.',
    explanation:
        'The 4-2-1 rule gives hourly maintenance fluid requirement: 4 mL/kg/hr for first 10 kg, '
        '2 mL/kg/hr for next 10 kg, 1 mL/kg/hr for each kg above 20 kg.',
    clinicalInterpretation:
        'Provides a baseline maintenance estimate. Adjust upward for fever, ongoing losses, or dehydration. '
        'Adjust downward for cardiac failure, oliguric renal disease, or SIADH.',
    safetyNotes:
        'Holliday-Segar is validated for paediatric patients. In adults the formula overestimates maintenance. '
        'Adjust for dehydration, burns, shock, cardiac disease, and ongoing losses.',
    commonPitfalls:
        'Applying adult fluid rates to children. '
        'Not adjusting for clinical conditions that alter fluid requirements (e.g., fever adds ~10% per degree above 37°C).',
    osceTips:
        'Recite the 4-2-1 rule clearly and calculate step-by-step for the given weight. '
        'Mention the need to adjust for ongoing losses and clinical status — examiners reward nuanced answers.',
  ),
  // ─── 7 new Emergency & Critical Care calculators (Wave 2 — 04-02) ───────────
  CalculatorDefinition(
    id: 'qsofa',
    title: 'qSOFA Score',
    category: 'Emergency & Critical Care',
    description: 'Quick Sepsis-related Organ Failure Assessment — bedside sepsis screening.',
    explanation:
        'qSOFA scores three bedside criteria: altered mental status (GCS < 15), '
        'respiratory rate ≥ 22 breaths/min, and systolic BP ≤ 100 mmHg. '
        'A score ≥ 2 suggests high risk of poor outcome in suspected sepsis.',
    clinicalInterpretation:
        'Score 0–1: Low risk — reassess regularly. '
        'Score ≥ 2: High risk of poor sepsis outcome — consider full SOFA assessment, '
        'blood cultures, IV access, and urgent escalation.',
    safetyNotes:
        'qSOFA is a screening tool only — it does not diagnose sepsis. '
        'A score < 2 does not exclude sepsis; use clinical judgement and full SOFA if sepsis is suspected. '
        'Not validated for immunocompromised patients or post-surgical ICU settings.',
    commonPitfalls:
        'Using qSOFA as a definitive diagnostic tool rather than a screening prompt. '
        'Ignoring a score of 1 in a patient with a high clinical suspicion of sepsis.',
    osceTips:
        'State the three criteria clearly (mentation, RR, SBP). Examiners often ask: '
        '"What would you do next?" — answer: full SOFA score, blood cultures, IV antibiotics per protocol.',
  ),
  CalculatorDefinition(
    id: 'news2',
    title: 'NEWS2 Score',
    category: 'Emergency & Critical Care',
    description: 'National Early Warning Score 2 — aggregate physiological score for clinical deterioration.',
    explanation:
        'NEWS2 aggregates six scored parameters: respiratory rate, SpO2 (scale 1 or scale 2 for '
        'hypercapnic respiratory failure), supplemental O2, systolic BP, heart rate, '
        'temperature, and consciousness (ACVPU: Alert = 0, any other = 3). '
        'Higher totals indicate greater physiological derangement.',
    clinicalInterpretation:
        'Score 0: Low — routine monitoring. '
        '1–4: Low-medium — increase observation frequency. '
        '5–6: Medium — urgent clinical review. '
        '≥ 7: High — emergency assessment, consider critical care review.',
    safetyNotes:
        'For patients with hypercapnic respiratory failure (e.g., COPD with target SpO2 88–92%), '
        'use SpO2 scale 2 — otherwise scores will be artificially elevated. '
        'NEWS2 is designed for adult patients on general wards; not validated for paediatrics, '
        'pregnancy, or patients with chronic neurological conditions affecting ACVPU.',
    commonPitfalls:
        'Using scale 1 SpO2 scoring in COPD patients on target SpO2 88–92% — this inflates the score. '
        'Scoring ACVPU as 0 (Alert) when a subtle change in mentation has occurred.',
    osceTips:
        'Know the clinical response thresholds: 0 = routine, 1–4 = increase frequency, '
        '5–6 = urgent, ≥ 7 = emergency. Mention the scale 2 pitfall for hypercapnia. '
        'Examiners may give a COPD patient scenario to test scale selection.',
  ),
  CalculatorDefinition(
    id: 'shock-index',
    title: 'Shock Index',
    category: 'Emergency & Critical Care',
    description: 'Heart rate divided by systolic BP — screens for haemodynamic instability.',
    explanation:
        'Shock Index (SI) = HR ÷ SBP. A value ≥ 1.0 suggests the heart rate has met '
        'or exceeded systolic blood pressure, indicating significant haemodynamic stress.',
    clinicalInterpretation:
        'SI < 0.6: Normal. 0.6–0.99: Mildly elevated — monitor closely. '
        '≥ 1.0: High risk — consider volume resuscitation and urgent assessment.',
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
  CalculatorDefinition(
    id: 'osmolality',
    title: 'Osmolality & Osmolar Gap',
    category: 'Emergency & Critical Care',
    description: 'Calculated serum osmolality and osmolar gap to detect unmeasured osmoles.',
    explanation:
        'Calculated osmolality = 2 × Na (mEq/L) + glucose (mg/dL) / 18 + BUN (mg/dL) / 2.8. '
        'Osmolar gap = measured osmolality − calculated osmolality. '
        'An elevated gap implies the presence of unmeasured osmotically active substances.',
    clinicalInterpretation:
        'Normal calculated osmolality: 275–295 mOsm/kg. '
        'Osmolar gap > 10 mOsm/kg: elevated — consider toxic alcohols (methanol, ethylene glycol, '
        'isopropanol), mannitol, or severe uraemia. '
        'A gap ≤ 10 does not reliably exclude toxic alcohol ingestion in early presentations.',
    safetyNotes:
        'The osmolar gap calculation requires a measured (laboratory) osmolality for comparison. '
        'Without a measured value, only the calculated estimate is available. '
        'Formulae vary slightly between institutions — check local laboratory reference ranges.',
    commonPitfalls:
        'Confusing calculated osmolality (this tool) with measured osmolality (the lab result). '
        'Forgetting that a normal osmolar gap does not exclude toxic alcohol poisoning in early stages.',
    osceTips:
        'State the formula clearly: 2×Na + glucose/18 + BUN/2.8. '
        'Examiners often link osmolar gap to toxic alcohol poisoning — name the MUDPILES overlap '
        '(methanol, ethylene glycol). Mention that both anion gap and osmolar gap may be elevated.',
  ),
  CalculatorDefinition(
    id: 'corrected-sodium',
    title: 'Corrected Sodium (Hyperglycemia)',
    category: 'Emergency & Critical Care',
    description: 'Adjusts measured sodium for the dilutional effect of hyperglycaemia.',
    explanation:
        'In hyperglycaemia, elevated glucose draws water into the extracellular space, '
        'diluting sodium. Corrected Na = measured Na + 0.016 × (glucose mg/dL − 100). '
        'This reveals the true sodium once glucose is corrected.',
    clinicalInterpretation:
        'A corrected sodium in the normal range (135–145 mEq/L) confirms the hyponatraemia '
        'is dilutional and will correct with glucose treatment. '
        'A corrected sodium that is still low or high suggests concurrent sodium pathology.',
    safetyNotes:
        'The correction factor (0.016 per mg/dL, or 1.6 per 100 mg/dL) is derived from '
        'Katz 1973 and widely used; some guidelines use 0.024 (Hillier 1999) for glucose '
        '> 400 mg/dL. This calculator uses 0.016. '
        'Formula only applies above 100 mg/dL glucose; below this threshold there is no dilutional effect.',
    commonPitfalls:
        'Applying the correction to patients without significant hyperglycaemia (glucose near normal). '
        'Not re-checking sodium after glucose correction in DKA management.',
    osceTips:
        'In DKA/HHS OSCE scenarios: calculate corrected sodium, then interpret fluid management. '
        'Examiners may ask whether the hyponatraemia is true or dilutional — use this formula to answer.',
  ),
  CalculatorDefinition(
    id: 'aa-gradient',
    title: 'A-a Gradient',
    category: 'Emergency & Critical Care',
    description: 'Alveolar-arterial oxygen gradient to assess the cause of hypoxaemia.',
    explanation:
        'A-a gradient = PAO2 − PaO2, where PAO2 = FiO2 × (PB − 47) − PaCO2 / 0.8. '
        'PB is barometric pressure (default 760 mmHg at sea level). '
        'A normal gradient indicates a ventilation or low FiO2 cause of hypoxaemia; '
        'an elevated gradient points to V/Q mismatch, shunt, or diffusion impairment.',
    clinicalInterpretation:
        'Expected A-a gradient ≈ age / 4 + 4 mmHg (when age is known). '
        'Gradient > expected: elevated — consider PE, pulmonary oedema, ARDS, atelectasis, pneumonia. '
        'Normal gradient with hypoxaemia: consider hypoventilation or low inspired FiO2.',
    safetyNotes:
        'Requires arterial blood gas values (PaO2, PaCO2). '
        'FiO2 must be accurately known — estimated FiO2 from oxygen delivery device introduces error. '
        'Normal ranges vary with age and altitude; this calculator uses a sea-level default.',
    commonPitfalls:
        'Entering FiO2 as a percentage (e.g., 40) instead of a fraction (e.g., 0.40). '
        'Using a venous PO2 instead of arterial PaO2.',
    osceTips:
        'Know the formula by heart and be able to calculate at the bedside. '
        'Examiners will ask you to interpret: normal gradient = problem above the alveolus; '
        'elevated gradient = problem at or below the alveolus (V/Q mismatch, shunt, diffusion).',
  ),
  CalculatorDefinition(
    id: 'pao2-fio2',
    title: 'PaO2/FiO2 Ratio',
    category: 'Emergency & Critical Care',
    description: 'P/F ratio to assess oxygenation impairment and ARDS severity.',
    explanation:
        'P/F ratio = PaO2 (mmHg) ÷ FiO2 (fraction). '
        'It normalises arterial oxygen for the fraction of inspired oxygen, giving a '
        'standardised measure of oxygenation efficiency regardless of supplemental O2.',
    clinicalInterpretation:
        '> 400: Normal oxygenation. '
        '300–400: Mild impairment (Berlin criteria: mild ARDS). '
        '200–300: Moderate ARDS. '
        '< 200: Severe ARDS — consider prone positioning and advanced ventilatory support.',
    safetyNotes:
        'Berlin criteria for ARDS require PEEP ≥ 5 cmH2O at measurement — P/F alone is not sufficient '
        'for ARDS diagnosis. Requires arterial blood gas (PaO2), not pulse oximetry.',
    commonPitfalls:
        'Entering FiO2 as a percentage (e.g., 60) instead of a fraction (e.g., 0.60) — '
        'this gives a result 100× too high. '
        'Using SpO2 from pulse oximetry instead of PaO2 from ABG.',
    osceTips:
        'Memorise the ARDS bands: > 400 normal, 300–400 mild, 200–300 moderate, < 200 severe. '
        'Examiners may give a ventilated ICU patient scenario — state the Berlin criteria '
        '(bilateral infiltrates, non-cardiogenic, within 1 week of insult, PEEP ≥ 5).',
  ),
  // ─── 5 new Drug Dosing calculators (Wave 3 — 04-03) ─────────────────────────
  CalculatorDefinition(
    id: 'bsa',
    title: 'Body Surface Area (BSA)',
    category: 'Drug Dosing',
    description: 'Mosteller formula for BSA — used in chemotherapy, burns, and paediatric dosing.',
    explanation:
        'BSA (Mosteller) = √(height cm × weight kg / 3600). '
        'BSA is used to individualise drug doses, particularly in oncology and paediatrics, '
        'where weight-based dosing alone underestimates dose needs in larger patients.',
    clinicalInterpretation:
        'Calculated estimate of body surface area in m². '
        'Typical adult BSA: 1.7–1.9 m². Use the result to calculate BSA-based drug doses '
        '(e.g., chemotherapy dose = BSA × dose per m²). Always verify against institutional protocols.',
    safetyNotes:
        'BSA-based dosing does not account for organ function — adjust for renal or hepatic '
        'impairment separately. In extreme obesity, lean body weight or adjusted weight may be '
        'more appropriate — verify against the drug\'s prescribing information.',
    commonPitfalls:
        'Entering height in metres without selecting the m unit option — the Mosteller formula '
        'requires height in cm. '
        'Using BSA-calculated dose without checking the protocol\'s dose cap.',
    osceTips:
        'State the Mosteller formula clearly: √(Ht_cm × Wt_kg / 3600). '
        'Mention alternative formulas (DuBois, Haycock) and that Mosteller is preferred '
        'for simplicity. Note that BSA dosing is standard for cytotoxic chemotherapy.',
  ),
  CalculatorDefinition(
    id: 'egfr-ckd-epi',
    title: 'eGFR (CKD-EPI 2021)',
    category: 'Drug Dosing',
    description: 'Estimated GFR using the 2021 race-free CKD-EPI equation for CKD staging.',
    explanation:
        'Uses the 2021 race-free CKD-EPI equation (Inker et al., NEJM 2021), which eliminated '
        'race as a variable. eGFR = 142 × min(Scr/κ, 1)^α × max(Scr/κ, 1)^−1.200 × 0.9938^age '
        '× (1.012 if female). Female: κ = 0.7, α = −0.241. Male: κ = 0.9, α = −0.302.',
    clinicalInterpretation:
        'CKD stages: G1 ≥ 90, G2 60–89, G3a 45–59, G3b 30–44, G4 15–29, G5 < 15 mL/min/1.73 m². '
        'Calculated estimate only — interpret with urine albumin-to-creatinine ratio, trend, '
        'and clinical context. Values below 60 for ≥ 3 months define CKD.',
    safetyNotes:
        'This calculator uses the 2021 race-free CKD-EPI equation — no race variable is used. '
        'eGFR may be inaccurate in pregnancy, acute kidney injury, extremes of muscle mass '
        '(athletes, amputees, cachexia), or non-steady-state creatinine.',
    commonPitfalls:
        'Confusing eGFR (CKD-EPI) with creatinine clearance (Cockcroft-Gault) — they serve '
        'different purposes: eGFR for CKD staging; CrCl for renal drug dosing. '
        'Using µmol/L without selecting the correct unit (the formula requires mg/dL; '
        'this calculator converts automatically).',
    osceTips:
        'Know the CKD stages (G1–G5) by eGFR threshold. Mention that the 2021 equation '
        'removed race as a variable — examiners may ask why (equity in diagnosis). '
        'Distinguish from Cockcroft-Gault: eGFR for diagnosis; CrCl for drug dosing.',
  ),
  CalculatorDefinition(
    id: 'gentamicin-vancomycin',
    title: 'Gentamicin/Vancomycin Dosing',
    category: 'Drug Dosing',
    description: 'Suggested once-daily gentamicin or weight-based vancomycin initial dose.',
    explanation:
        'Gentamicin (aminoglycoside): conventional once-daily dosing of 5 mg/kg/day is a '
        'commonly used starting point, exploiting concentration-dependent killing. '
        'Vancomycin (glycopeptide): initial dosing of 15–20 mg/kg/dose, typically q8–12h, '
        'titrated to trough or AUC targets. Both agents are renally cleared.',
    clinicalInterpretation:
        'Suggested initial dose only — not a therapeutic recommendation. '
        'Therapeutic drug monitoring (TDM) is mandatory for both agents. '
        'Subsequent doses MUST be adjusted for renal function (CrCl) and monitored levels.',
    safetyNotes:
        'Both agents have narrow therapeutic windows. Gentamicin: nephrotoxicity and '
        'ototoxicity; monitor trough levels and renal function at least every 48–72 h. '
        'Vancomycin: nephrotoxicity risk increases with troughs > 20 mg/L. '
        'Always verify initial dose and interval against your institutional formulary '
        'and adjust for CrCl. Do not use this calculator as the sole basis for prescribing.',
    commonPitfalls:
        'Not adjusting the dosing interval for reduced renal function — both drugs accumulate '
        'rapidly in AKI. Failing to order TDM levels before the next dose.',
    osceTips:
        'State that TDM is mandatory for both agents. Know the target trough for vancomycin '
        '(10–20 mg/L conventional; AUC/MIC 400–600 in contemporary guidelines). '
        'Mention the renal adjustment principle: extend interval, not dose reduction, for aminoglycosides.',
  ),
  CalculatorDefinition(
    id: 'insulin-dose',
    title: 'Insulin Dose',
    category: 'Drug Dosing',
    description: 'Correction (supplemental) insulin dose from CBG, target glucose, and ISF.',
    explanation:
        'Correction dose = (current blood glucose − target glucose) / insulin sensitivity factor (ISF). '
        'ISF (also called correction factor) is the expected glucose drop per unit of rapid-acting insulin. '
        'A negative result is clamped to 0 — never administer negative correction doses.',
    clinicalInterpretation:
        'Calculated correction dose estimate in units of rapid-acting insulin. '
        'This is a supplemental correction dose only — it does not account for meal coverage, '
        'basal insulin, or the patient\'s prescribed sliding scale. '
        'Always review the full insulin regimen and blood glucose trend before administering.',
    safetyNotes:
        'Insulin is a high-risk medication. This calculator provides a correction dose estimate '
        'only — it is NOT a substitute for the patient\'s prescribed insulin regimen or '
        'clinical assessment. Hypoglycaemia risk increases with stacking of correction doses. '
        'Never administer insulin without checking the current blood glucose and prescribed chart.',
    commonPitfalls:
        'Stacking correction doses (giving correction before the previous dose has had time to act — '
        'typically 4 hours for rapid-acting insulin). '
        'Using an incorrect ISF — ISF varies significantly between patients and conditions.',
    osceTips:
        'Know the formula: correction dose = (CBG − target) / ISF. '
        'Mention the "rule of 1800" (for mg/dL): ISF ≈ 1800 / total daily dose of insulin as an estimate. '
        'Always emphasise TDM and that the prescribed regimen takes precedence.',
  ),
  CalculatorDefinition(
    id: 'paracetamol-dosing',
    title: 'Paracetamol Dosing',
    category: 'Drug Dosing',
    description: 'Weight-based paracetamol dose for adults and children with 24-hour cap.',
    explanation:
        'Child (< 12 years): 15 mg/kg/dose orally, max 4 doses in 24 hours, max 60 mg/kg/day. '
        'Adult (≥ 12 years): 1000 mg per dose, up to every 4–6 hours, maximum 4 g (4000 mg) per day. '
        'The 24-hour maximum must not be exceeded regardless of weight.',
    clinicalInterpretation:
        'Suggested dose per administration and 24-hour maximum. '
        'Dose is calculated from weight for children. '
        'For adults, the standard dose is 1 g regardless of weight for most patients. '
        'Verify against the patient\'s age, hepatic function, and current medications.',
    safetyNotes:
        'Paracetamol toxicity is dose-dependent and can cause fatal hepatic failure. '
        'The 4 g/day adult maximum must NEVER be exceeded. In hepatic impairment, chronic alcohol '
        'use, or malnutrition, consider reducing the maximum to 2 g/day. '
        'Always verify against your institutional formulary and the patient\'s full medication list.',
    commonPitfalls:
        'Exceeding the 4 g/day adult maximum — common when paracetamol is prescribed as both a '
        'regular drug AND as part of a combined analgesic (e.g., co-codamol, co-dydramol). '
        'Using adult doses in children, or not calculating weight-based dose for lighter children.',
    osceTips:
        'State the adult maximum: 1 g per dose, 4 g/day. For children: 15 mg/kg/dose, '
        'max 60 mg/kg/day or 4 g/day (whichever is lower). '
        'In OSCEs, always check for concurrent paracetamol-containing products.',
  ),
];

/// Returns calculators grouped by category, with the first per category free.
Map<String, List<CalculatorDefinition>> groupByCategory(
    List<CalculatorDefinition> calculators) {
  final map = <String, List<CalculatorDefinition>>{};
  for (final c in calculators) {
    map.putIfAbsent(c.category, () => []).add(c);
  }
  return map;
}
