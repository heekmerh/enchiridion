import '../utils/content_availability.dart';

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

  /// Whether this calculator has a working form wired into `CalculatorScreen`.
  /// Defaults to true so all pre-existing const entries compile unchanged.
  final bool implemented;

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
    this.implemented = true,
  });

  /// Mirrors the same getter pair on `ResourceTopic`/`CatalogBook`: a
  /// calculator "has content" when its form is actually implemented.
  bool get hasContent => implemented;

  /// A calculator with no working form is "coming soon" — the inverse of
  /// [hasContent].
  bool get isComingSoon => !hasContent;
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
    explanation: 'Uses Naegele\'s rule: EDD = LMP + 280 days (40 weeks). '
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
    commonPitfalls: 'Applying adult fluid rates to children. '
        'Not adjusting for clinical conditions that alter fluid requirements (e.g., fever adds ~10% per degree above 37°C).',
    osceTips:
        'Recite the 4-2-1 rule clearly and calculate step-by-step for the given weight. '
        'Mention the need to adjust for ongoing losses and clinical status — examiners reward nuanced answers.',
  ),
  // 7 new Emergency & Critical Care calculators (Wave 2 — 04-02)
  CalculatorDefinition(
    id: 'qsofa',
    title: 'qSOFA Score',
    category: 'Emergency & Critical Care',
    description:
        'Quick Sepsis-related Organ Failure Assessment — bedside sepsis screening.',
    explanation:
        'qSOFA scores three bedside criteria: altered mental status (GCS < 15), '
        'respiratory rate ≥ 22 breaths/min, and systolic BP ≤ 100 mmHg. '
        'A score ≥ 2 suggests high risk of poor outcome in suspected sepsis.',
    clinicalInterpretation: 'Score 0–1: Low risk — reassess regularly. '
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
    description:
        'National Early Warning Score 2 — aggregate physiological score for clinical deterioration.',
    explanation:
        'NEWS2 aggregates six scored parameters: respiratory rate, SpO2 (scale 1 or scale 2 for '
        'hypercapnic respiratory failure), supplemental O2, systolic BP, heart rate, '
        'temperature, and consciousness (ACVPU: Alert = 0, any other = 3). '
        'Higher totals indicate greater physiological derangement.',
    clinicalInterpretation: 'Score 0: Low — routine monitoring. '
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
    description:
        'Heart rate divided by systolic BP — screens for haemodynamic instability.',
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
    description:
        'Calculated serum osmolality and osmolar gap to detect unmeasured osmoles.',
    explanation:
        'Calculated osmolality = 2 × Na (mEq/L) + glucose (mg/dL) / 18 + BUN (mg/dL) / 2.8. '
        'Osmolar gap = measured osmolality − calculated osmolality. '
        'An elevated gap implies the presence of unmeasured osmotically active substances.',
    clinicalInterpretation: 'Normal calculated osmolality: 275–295 mOsm/kg. '
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
    osceTips: 'State the formula clearly: 2×Na + glucose/18 + BUN/2.8. '
        'Examiners often link osmolar gap to toxic alcohol poisoning — name the MUDPILES overlap '
        '(methanol, ethylene glycol). Mention that both anion gap and osmolar gap may be elevated.',
  ),
  CalculatorDefinition(
    id: 'corrected-sodium',
    title: 'Corrected Sodium (Hyperglycemia)',
    category: 'Emergency & Critical Care',
    description:
        'Adjusts measured sodium for the dilutional effect of hyperglycaemia.',
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
    description:
        'Alveolar-arterial oxygen gradient to assess the cause of hypoxaemia.',
    explanation:
        'A-a gradient = PAO2 − PaO2, where PAO2 = FiO2 × (PB − 47) − PaCO2 / 0.8. '
        'PB is barometric pressure (default 760 mmHg at sea level). '
        'A normal gradient indicates a ventilation or low FiO2 cause of hypoxaemia; '
        'an elevated gradient points to V/Q mismatch, shunt, or diffusion impairment.',
    clinicalInterpretation:
        'Expected A-a gradient ≈ age / 4 + 4 mmHg (when age is known). '
        'Gradient > expected: elevated — consider PE, pulmonary oedema, ARDS, atelectasis, pneumonia. '
        'Normal gradient with hypoxaemia: consider hypoventilation or low inspired FiO2.',
    safetyNotes: 'Requires arterial blood gas values (PaO2, PaCO2). '
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
    description:
        'P/F ratio to assess oxygenation impairment and ARDS severity.',
    explanation: 'P/F ratio = PaO2 (mmHg) ÷ FiO2 (fraction). '
        'It normalises arterial oxygen for the fraction of inspired oxygen, giving a '
        'standardised measure of oxygenation efficiency regardless of supplemental O2.',
    clinicalInterpretation: '> 400: Normal oxygenation. '
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
  // 5 new Drug Dosing calculators (Wave 3 — 04-03)
  CalculatorDefinition(
    id: 'bsa',
    title: 'Body Surface Area (BSA)',
    category: 'Drug Dosing',
    description:
        'Mosteller formula for BSA — used in chemotherapy, burns, and paediatric dosing.',
    explanation: 'BSA (Mosteller) = √(height cm × weight kg / 3600). '
        'BSA is used to individualise drug doses, particularly in oncology and paediatrics, '
        'where weight-based dosing alone underestimates dose needs in larger patients.',
    clinicalInterpretation: 'Calculated estimate of body surface area in m². '
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
    osceTips: 'State the Mosteller formula clearly: √(Ht_cm × Wt_kg / 3600). '
        'Mention alternative formulas (DuBois, Haycock) and that Mosteller is preferred '
        'for simplicity. Note that BSA dosing is standard for cytotoxic chemotherapy.',
  ),
  CalculatorDefinition(
    id: 'egfr-ckd-epi',
    title: 'eGFR (CKD-EPI 2021)',
    category: 'Drug Dosing',
    description:
        'Estimated GFR using the 2021 race-free CKD-EPI equation for CKD staging.',
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
    description:
        'Suggested once-daily gentamicin or weight-based vancomycin initial dose.',
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
    description:
        'Correction (supplemental) insulin dose from CBG, target glucose, and ISF.',
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
    osceTips: 'Know the formula: correction dose = (CBG − target) / ISF. '
        'Mention the "rule of 1800" (for mg/dL): ISF ≈ 1800 / total daily dose of insulin as an estimate. '
        'Always emphasise TDM and that the prescribed regimen takes precedence.',
  ),
  CalculatorDefinition(
    id: 'paracetamol-dosing',
    title: 'Paracetamol Dosing',
    category: 'Drug Dosing',
    description:
        'Weight-based paracetamol dose for adults and children with 24-hour cap.',
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
  // 6 new Paediatrics calculators (Wave 4 — 04-04)
  CalculatorDefinition(
    id: 'apls-weight',
    title: 'APLS Weight Estimation',
    category: 'Paediatrics',
    description: 'APLS formula for estimated weight in children from age.',
    explanation:
        'APLS weight estimation uses age to estimate weight in children: '
        '< 1 year: weight (kg) = 0.5 × (age in months + 9); '
        '1–5 years: weight (kg) = 2 × (age + 4); '
        '6–12 years: weight (kg) = 3 × age + 7. '
        'These are bedside estimates for resuscitation scenarios.',
    clinicalInterpretation:
        'Suggested estimated weight for resuscitation and drug dosing when actual weight is unknown. '
        'Use alongside clinical judgement — actual weight should be measured whenever possible. '
        'Over- or under-estimation is clinically significant for weight-based drug doses.',
    safetyNotes:
        'APLS weight formulas are estimations only and may be inaccurate in obese, '
        'underweight, or premature children. For precise dosing (e.g., chemotherapy, insulin), '
        'always obtain an actual weight. For resuscitation, use in conjunction with a Broselow tape '
        'or clinical estimation by an experienced clinician.',
    commonPitfalls:
        'Using the wrong age range formula — e.g., applying the 1–5y formula to a 7-year-old. '
        'Entering age in months when the formula expects years (or vice versa) for children ≥ 1 year.',
    osceTips:
        'Recite the three formulas for each age band. Examiners expect you to know which band '
        'applies and to verbalise the calculation step-by-step. '
        'State clearly: "This is an estimate — actual weight should be used where available."',
  ),
  CalculatorDefinition(
    id: 'broselow',
    title: 'Broselow Tape Equivalent',
    category: 'Paediatrics',
    description:
        'Map measured length/height to Broselow colour zone and estimated weight range.',
    explanation:
        'The Broselow tape uses measured length (crown-heel) to assign a colour zone and estimate '
        'weight range. Each colour zone corresponds to a height range and expected weight band '
        'used for paediatric resuscitation. Drug dose columns are deferred — use the estimated weight '
        'with the weight-based dosing calculator for specific drug doses.',
    clinicalInterpretation:
        'Suggested interpretation: colour zone and weight range estimate from measured length. '
        'Use the estimated weight range to guide equipment selection (e.g., ET tube size, '
        'defibrillation energy) and as input for weight-based drug dose calculations. '
        'Always verify with actual weight when available.',
    safetyNotes:
        'This calculator provides zone and weight range only — it does not output individual '
        'drug doses. Drug dose columns are deferred to a future phase. '
        'The Broselow system is designed for children up to approximately 36 kg / 146 cm. '
        'For children above this range, use standard adult or weight-based calculations.',
    commonPitfalls:
        'Measuring sitting height instead of crown-heel length — always measure supine. '
        'Using the Broselow estimate for children over 36 kg or 146 cm where the tape is no longer validated.',
    osceTips:
        'In PALS/paediatric resuscitation OSCEs, the Broselow tape is the expected tool for '
        'weight estimation when scales are unavailable. State the colour zone and use the '
        'midpoint of the weight range for drug dose calculations.',
  ),
  CalculatorDefinition(
    id: 'pediatric-bp',
    title: 'Pediatric BP Percentiles',
    category: 'Paediatrics',
    description:
        'Classify paediatric blood pressure using simplified 2017 AAP thresholds.',
    explanation:
        'Blood pressure in children must be interpreted against age- and sex-specific percentiles. '
        'This calculator uses a simplified lookup of the 95th-percentile SBP by age and sex '
        'from the 2017 AAP Clinical Practice Guideline. '
        'Classification: Normal < 90th percentile; Elevated 90th–95th; Stage 1 HTN 95th–99th+5; '
        'Stage 2 HTN ≥ 99th+5 mmHg.',
    clinicalInterpretation:
        'Suggested interpretation of blood pressure category for the entered age and sex. '
        'Stage 1 hypertension: lifestyle intervention; confirm on 3 separate occasions. '
        'Stage 2 hypertension: prompt evaluation and treatment. '
        'Interpret in the context of growth, symptoms, and repeat measurements.',
    safetyNotes:
        'This calculator uses simplified threshold values based on the 2017 AAP tables. '
        'Verify classification against the full 2017 AAP tables (Pediatrics 140(3):e20171904) '
        'for precise percentile values. Simplified thresholds may not reflect the exact '
        'height-specific percentile cutoffs in the full guideline.',
    commonPitfalls:
        'Applying adult BP thresholds to children — paediatric BP norms differ significantly '
        'from adult thresholds and vary by age, sex, and height. '
        'Single measurement classification — BP diagnosis requires at least 3 readings on '
        'separate occasions.',
    osceTips:
        'Know the four BP categories (normal, elevated, Stage 1, Stage 2) and be prepared '
        'to discuss management for each. Mention that hypertension in children requires '
        'repeat measurement and investigation for secondary causes (renal, endocrine).',
  ),
  CalculatorDefinition(
    id: 'neonatal-bilirubin',
    title: 'Neonatal Bilirubin (Phototherapy)',
    category: 'Paediatrics',
    description:
        'Bhutani-based risk zone and phototherapy guidance for neonatal jaundice.',
    explanation:
        'Uses the Bhutani nomogram risk zones to classify neonatal bilirubin level by age in hours '
        'and risk category. Risk categories: low (no risk factors), medium (mild risk factors), '
        'high (haemolysis, GGPD, early jaundice). '
        'Output provides a phototherapy guidance band based on intersecting bilirubin level and age-hours.',
    clinicalInterpretation:
        'Suggested interpretation: bilirubin risk zone and guidance band for phototherapy consideration. '
        'High-risk zone: initiate phototherapy. Intermediate zone: consider repeat bilirubin in 4–8 hours. '
        'Low-risk zone: routine follow-up. Always confirm the result against your local AAP nomogram '
        'and institutional thresholds before making clinical decisions.',
    safetyNotes:
        'Thresholds are a guide only — confirm against the local AAP phototherapy nomogram. '
        'The Bhutani nomogram and AAP 2004/2022 guidelines should be consulted for exact treatment '
        'thresholds, particularly for infants < 35 weeks gestation. '
        'This tool is not validated for preterm infants (< 35 weeks) — use gestation-specific tables.',
    commonPitfalls:
        'Using total serum bilirubin without accounting for risk factors — the same level requires '
        'different action depending on haemolysis risk. '
        'Forgetting to convert units: 1 mg/dL = 17.1 µmol/L.',
    osceTips:
        'Know that phototherapy thresholds vary by age in hours and risk category. '
        'In OSCEs: state the level, risk category, age in hours, and recommended action. '
        'Always mention confirming against local guidelines and the AAP nomogram.',
  ),
  CalculatorDefinition(
    id: 'apgar',
    title: 'APGAR Score',
    category: 'Paediatrics',
    description:
        'Neonatal assessment at 1 and 5 minutes — Appearance, Pulse, Grimace, Activity, Respiration.',
    explanation:
        'The APGAR score rates five signs: Appearance (colour), Pulse (heart rate), '
        'Grimace (reflex irritability), Activity (muscle tone), and Respiration. '
        'Each is scored 0–2. Total ranges from 0 to 10. '
        'Assessed at 1 minute and 5 minutes after birth; repeated at 10 minutes if ≤ 6.',
    clinicalInterpretation: 'Score 7–10: Reassuring — routine newborn care. '
        'Score 4–6: Moderately abnormal — supplemental oxygen and stimulation; prepare for resuscitation. '
        'Score 0–3: Low — immediate resuscitation required; Newborn Life Support protocol.',
    safetyNotes:
        'APGAR score is a clinical communication tool, not a predictor of long-term neurological '
        'outcome. A persistently low APGAR (≤ 5 at 5 minutes) is associated with increased risk '
        'but is not diagnostic. Resuscitation decisions are based on clinical assessment — '
        'do not delay resuscitation to complete the APGAR score.',
    commonPitfalls:
        'Confusing grimace (reflex irritability — response to suction) with facial expression. '
        'Scoring central cyanosis (blue trunk) vs acrocyanosis (blue hands/feet only) — '
        'acrocyanosis alone scores 1 for appearance, not 0.',
    osceTips:
        'Use the mnemonic A-P-G-A-R. Examiners expect you to state each component score and the '
        'corresponding clinical action for the band. '
        'Know that a score ≤ 6 at 5 minutes mandates reassessment at 10 minutes.',
  ),
  CalculatorDefinition(
    id: 'growth-percentile',
    title: 'WHO Growth Percentile',
    category: 'Paediatrics',
    description:
        'WHO simplified z-score bands for weight, height, and head circumference.',
    explanation:
        'Uses simplified WHO z-score bands (not full LMS tables) to classify weight, height, '
        'and head circumference for age and sex. Z-score bands: < −2 SD (below 3rd percentile), '
        '−2 to +2 SD (normal/3rd–97th percentile range), > +2 SD (above 97th percentile). '
        'This calculator provides qualitative zone classification — not precise percentile values.',
    clinicalInterpretation:
        'Suggested interpretation: qualitative z-score band for each entered measurement. '
        'Below 3rd percentile: investigate for undernutrition, growth failure, or underlying pathology. '
        'Above 97th percentile: investigate for overweight/obesity or pathological causes. '
        'Serial measurements over time are more informative than single-point assessment.',
    safetyNotes:
        'This calculator uses simplified z-score bands, not the full WHO LMS (lambda-mu-sigma) '
        'method. Results are approximate. For clinical growth monitoring, use the full WHO '
        'growth charts for the child\'s age, sex, and measurement type. '
        'Classify only within the validated WHO Child Growth Standards age range (0–5 years).',
    commonPitfalls:
        'Using a single measurement in isolation rather than tracking growth trajectory over time. '
        'Applying simplified z-score thresholds without considering gestational age correction '
        'in preterm infants.',
    osceTips: 'Know the three z-score zones and their clinical significance. '
        'In paediatric OSCEs, plot growth on a centile chart and describe the trend. '
        'Mention that the WHO standards are based on healthy breastfed children in optimal conditions.',
  ),
  // Coming-soon: Emergency & Critical Care (Ideas/ideas.md §1)
  CalculatorDefinition(
    id: 'parkland',
    title: 'Fluid Resuscitation (Parkland)',
    category: 'Emergency & Critical Care',
    description: 'Burn fluid resuscitation volume for the first 24 hours.',
    explanation:
        'Parkland formula: total 24-hour crystalloid volume = 4 mL × weight (kg) × %TBSA burned. '
        'Half is given over the first 8 hours from the time of injury, and the remaining half '
        'over the next 16 hours.',
    clinicalInterpretation:
        'Use the total, first-8-hour rate, and next-16-hour rate as a starting point for '
        'resuscitation. Titrate the actual infusion rate to urine output (typically 0.5 mL/kg/hr '
        'in adults) and other perfusion markers, not to the formula alone.',
    safetyNotes:
        'The clock starts at the time of injury, not at presentation — hours already elapsed '
        'before arrival must be subtracted from the first 8-hour window. This is a resuscitation '
        'starting point only and must be titrated to the individual patient\'s response.',
    commonPitfalls:
        'Starting the 8-hour clock at presentation instead of at the time of burn. '
        'Not adjusting the running rate once urine output and vital signs are available.',
    osceTips:
        'State the formula, the 8-hour/16-hour split, and that timing starts at injury. '
        'Examiners expect you to mention urine output as the titration target.',
  ),
  CalculatorDefinition(
    id: 'sofa',
    title: 'SOFA Score',
    category: 'Emergency & Critical Care',
    description: 'Six-organ sequential organ failure assessment score.',
    implemented: false,
  ),
  // Coming-soon: Drug Dosing (Ideas/ideas.md §2)
  CalculatorDefinition(
    id: 'adrenaline-dose',
    title: 'Adrenaline Dose (Resuscitation)',
    category: 'Drug Dosing',
    description: 'Weight-based adrenaline dose for arrest and anaphylaxis.',
    implemented: false,
  ),
  // Coming-soon: General (Ideas/ideas.md §6)
  CalculatorDefinition(
    id: 'corrected-calcium',
    title: 'Corrected Calcium',
    category: 'General',
    description: 'Albumin-corrected serum calcium.',
    explanation:
        'Total serum calcium is partly bound to albumin, so hypoalbuminaemia lowers the '
        'measured total calcium without changing the physiologically active ionised fraction. '
        'Corrected Ca = measured Ca + 0.02 mmol/L (SI) or 0.8 mg/dL (conventional) for every unit '
        'albumin falls below 40 g/L (SI) or 4 g/dL (conventional).',
    clinicalInterpretation:
        'Interpret the corrected value against the local normal range for total calcium — the '
        'correction estimates what total calcium would be if albumin were normal. '
        'It does not replace an ionised calcium measurement when precision is needed.',
    safetyNotes:
        'The correction is an estimate and is unreliable in critical illness, acid-base '
        'disturbance, or paraproteinaemia. Measure ionised calcium directly when a precise '
        'value is required for clinical decisions.',
    commonPitfalls:
        'Mixing SI and conventional unit correction factors. '
        'Applying the correction when albumin is already normal or high — the formula only '
        'adjusts for low albumin.',
    osceTips:
        'State the formula for the unit system given and explain why hypoalbuminaemia lowers '
        'total (but not ionised) calcium. Mention ionised calcium as the gold standard when asked.',
  ),
  CalculatorDefinition(
    id: 'ldl-friedewald',
    title: 'LDL (Friedewald)',
    category: 'General',
    description: 'Calculated LDL cholesterol from a lipid panel.',
    explanation:
        'The Friedewald equation estimates LDL cholesterol from a standard lipid panel: '
        'LDL = Total cholesterol − HDL − Triglycerides/5 (mg/dL) or Triglycerides/2.2 (mmol/L). '
        'It assumes a fixed ratio of triglycerides to VLDL cholesterol that breaks down at high '
        'triglyceride levels.',
    clinicalInterpretation:
        'Use the calculated LDL alongside total cholesterol and HDL to guide cardiovascular risk '
        'assessment and lipid-lowering therapy decisions per local guidelines.',
    safetyNotes:
        'Invalid above 400 mg/dL (4.5 mmol/L) triglycerides — the assumed VLDL ratio breaks down '
        'and the formula silently underestimates LDL. Request a direct LDL measurement instead.',
    commonPitfalls:
        'Reporting a Friedewald LDL when triglycerides exceed the validity ceiling. '
        'Mixing mg/dL and mmol/L conversion factors between the numerator and triglyceride term.',
    osceTips:
        'Recite the formula and state its triglyceride ceiling. Examiners often test whether '
        'you know to request a direct LDL when triglycerides are markedly elevated.',
  ),
  CalculatorDefinition(
    id: 'waist-hip-ratio',
    title: 'Waist-to-Hip Ratio',
    category: 'General',
    description: 'Central adiposity risk from waist and hip circumference.',
    explanation:
        'Waist-to-hip ratio = waist circumference ÷ hip circumference, measured in the same '
        'units. It reflects central (visceral) fat distribution, an independent cardiometabolic '
        'risk factor beyond BMI alone.',
    clinicalInterpretation:
        'WHO thresholds: above 0.90 in men and above 0.85 in women indicate increased '
        'cardiometabolic risk from central adiposity, regardless of overall BMI.',
    safetyNotes:
        'Measurement technique affects reliability — measure waist at the midpoint between the '
        'lowest rib and iliac crest, and hip at the widest point, with the patient standing and '
        'relaxed. Not validated in pregnancy.',
    commonPitfalls:
        'Measuring waist over clothing or at the umbilicus rather than the anatomical midpoint. '
        'Comparing measurements taken with inconsistent technique between visits.',
    osceTips:
        'State the measurement landmarks precisely and the sex-specific thresholds. Mention that '
        'waist-to-hip ratio adds information beyond BMI for cardiometabolic risk.',
  ),
  CalculatorDefinition(
    id: 'meld',
    title: 'MELD Score',
    category: 'General',
    description: 'End-stage liver disease severity score.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'child-pugh',
    title: 'Child-Pugh Score',
    category: 'General',
    description: 'Chronic liver disease severity class A–C.',
    implemented: false,
  ),
  // Coming-soon: Obs & Gynae (Ideas/ideas.md §7)
  CalculatorDefinition(
    id: 'gtpal',
    title: 'GTPAL',
    category: 'Obs & Gynae',
    description:
        'Obstetric history as Gravida, Term, Preterm, Abortions, Living.',
    explanation:
        'GTPAL summarises obstetric history: Gravida (total pregnancies, including the current '
        'one), Term births (37 weeks or later), Preterm births (20–36 completed weeks), '
        'Abortions (losses before 20 weeks, spontaneous or induced), and Living children.',
    clinicalInterpretation:
        'Rendered as a five-figure string (e.g. G3 T1 P1 A1 L2) for quick obstetric history '
        'documentation and handover. A current pregnancy counts toward gravida but not toward '
        'the para components until it delivers.',
    safetyNotes:
        'GTPAL is a documentation summary, not a risk score — it does not itself predict '
        'obstetric risk. Verify the counts directly with the patient rather than inferring them.',
    commonPitfalls:
        'Counting the current pregnancy toward term/preterm/abortions before it has concluded. '
        'Confusing multiple gestations (e.g. twins) as multiple pregnancies rather than one.',
    osceTips:
        'State each letter and its definition in order. Examiners often test whether term + '
        'preterm + abortions is internally consistent with gravida.',
  ),
  CalculatorDefinition(
    id: 'bishop-score',
    title: 'Bishop Score',
    category: 'Obs & Gynae',
    description: 'Cervical favourability for induction of labour.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'partograph',
    title: 'Partograph Plotting',
    category: 'Obs & Gynae',
    description: 'Plot labour progress against alert and action lines.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'preeclampsia-risk',
    title: 'Preeclampsia Risk',
    category: 'Obs & Gynae',
    description: 'Risk stratification for pre-eclampsia.',
    implemented: false,
  ),
  // Coming-soon: Cardiology (new category — Ideas/ideas.md §4)
  CalculatorDefinition(
    id: 'map',
    title: 'Mean Arterial Pressure (MAP)',
    category: 'Cardiology',
    description: 'Mean arterial pressure from systolic and diastolic BP.',
    explanation:
        'MAP = diastolic BP + ⅓ × pulse pressure, where pulse pressure = systolic − diastolic. '
        'It approximates the average arterial pressure driving organ perfusion across the '
        'cardiac cycle (diastole occupies about two-thirds of the cycle at normal heart rates).',
    clinicalInterpretation:
        'A MAP of at least 65 mmHg is the conventional threshold widely used to support organ '
        'perfusion, particularly in sepsis and shock resuscitation targets. Interpret alongside '
        'the clinical picture, not in isolation.',
    safetyNotes:
        'The ⅓/⅔ diastole-to-systole assumption is derived at normal heart rates; MAP estimated '
        'this way is less accurate at extremes of heart rate. Direct arterial line measurement is '
        'more accurate when available.',
    commonPitfalls:
        'Entering diastolic BP greater than or equal to systolic BP. '
        'Using MAP alone to judge perfusion without considering heart rate, urine output, and '
        'lactate.',
    osceTips:
        'State the formula and the 65 mmHg perfusion threshold. Examiners often use MAP targets '
        'in sepsis/shock scenarios — know it is a resuscitation target, not a diagnosis.',
  ),
  CalculatorDefinition(
    id: 'qtc',
    title: 'QTc (Corrected QT)',
    category: 'Cardiology',
    description: 'Heart-rate-corrected QT interval.',
    explanation:
        'QT interval varies with heart rate, so it must be corrected to compare across rates. '
        'RR (seconds) = 60 ÷ heart rate. Bazett: QTc = QT ÷ √RR. Fridericia: QTc = QT ÷ ∛RR. '
        'Both are reported in the same units as the entered QT (ms).',
    clinicalInterpretation:
        'Conventional thresholds: QTc above 450 ms in men or above 470 ms in women is prolonged; '
        'above 500 ms carries the highest torsades de pointes risk and warrants urgent review of '
        'QT-prolonging drugs and electrolytes.',
    safetyNotes:
        'Bazett over-corrects at fast heart rates and under-corrects at slow heart rates — '
        'Fridericia is more accurate outside the normal heart rate range. Always check '
        'potassium, magnesium, and calcium, and review the drug chart for QT-prolonging agents.',
    commonPitfalls:
        'Using Bazett at tachycardia or bradycardia without cross-checking Fridericia. '
        'Measuring QT from a lead with a poorly defined T-wave end.',
    osceTips:
        'State both formulas and their rate-dependent bias. Examiners expect you to name the '
        'torsades risk threshold and the electrolyte/drug review that follows a prolonged QTc.',
  ),
  CalculatorDefinition(
    id: 'chads-vasc',
    title: 'CHA₂DS₂-VASc Score',
    category: 'Cardiology',
    description: 'Stroke risk in non-valvular atrial fibrillation.',
    explanation:
        'CHA₂DS₂-VASc scores stroke risk factors in non-valvular atrial fibrillation: '
        'congestive heart failure (1), hypertension (1), age ≥ 75 (2), diabetes (1), prior '
        'stroke/TIA/thromboembolism (2), vascular disease (1), age 65–74 (1), and female sex '
        '(1) — maximum 9. The two age bands are mutually exclusive by construction from a '
        'single age input.',
    clinicalInterpretation:
        'Higher scores indicate greater annual stroke risk and support the discussion of '
        'anticoagulation. Applies to non-valvular atrial fibrillation only — do not use for '
        'valvular AF or other arrhythmias.',
    safetyNotes:
        'This score applies to non-valvular atrial fibrillation only. It informs, but does not '
        'replace, an individualised anticoagulation discussion that also weighs bleeding risk '
        '(e.g. HAS-BLED) and patient preference.',
    commonPitfalls:
        'Double-counting both age bands instead of using the higher applicable one. '
        'Applying the score to valvular atrial fibrillation, where it was not derived.',
    osceTips:
        'Recite each criterion and its point value. Examiners expect you to state that the score '
        'applies to non-valvular AF and that anticoagulation is a shared decision weighing '
        'bleeding risk.',
  ),
  CalculatorDefinition(
    id: 'has-bled',
    title: 'HAS-BLED Score',
    category: 'Cardiology',
    description: 'Major bleeding risk on anticoagulation.',
    explanation:
        'HAS-BLED scores bleeding risk factors on anticoagulation: uncontrolled hypertension '
        '(1), abnormal renal function (1), abnormal liver function (1), prior stroke (1), '
        'bleeding history or predisposition (1), labile INR (1), age over 65 (1), drugs '
        'predisposing to bleeding (1), and alcohol excess (1) — maximum 9.',
    clinicalInterpretation:
        'A score of 3 or more indicates high bleeding risk. This should prompt addressing '
        'modifiable bleeding risk factors (blood pressure control, concurrent antiplatelets, '
        'alcohol use) rather than withholding anticoagulation outright when it is otherwise '
        'indicated.',
    safetyNotes:
        'A high HAS-BLED score is not, by itself, a reason to withhold anticoagulation when '
        'stroke risk is high — it identifies modifiable risks to address alongside the '
        'anticoagulation decision.',
    commonPitfalls:
        'Using a high HAS-BLED score in isolation to deny anticoagulation without weighing '
        'stroke risk (e.g. CHA₂DS₂-VASc). '
        'Failing to act on the modifiable risk factors the score identifies.',
    osceTips:
        'Recite each criterion. Examiners often test whether you know a high score should '
        'prompt risk modification, not automatic discontinuation of anticoagulation.',
  ),
  CalculatorDefinition(
    id: 'timi',
    title: 'TIMI Risk Score',
    category: 'Cardiology',
    description: 'Risk stratification in acute coronary syndrome.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'framingham',
    title: 'Framingham Risk Score',
    category: 'Cardiology',
    description: 'Ten-year cardiovascular risk estimate.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'cardiac-output',
    title: 'Cardiac Output',
    category: 'Cardiology',
    description: 'Cardiac output and cardiac index estimate.',
    implemented: false,
  ),
  // Coming-soon: Respiratory (new category — Ideas/ideas.md §5)
  CalculatorDefinition(
    id: 'cao2',
    title: 'Oxygen Content (CaO₂)',
    category: 'Respiratory',
    description: 'Arterial oxygen content from haemoglobin, SaO₂, and PaO₂.',
    explanation:
        'CaO₂ = (1.34 × Hb g/dL × SaO₂ fraction) + (0.003 × PaO₂ mmHg). '
        'The first term is oxygen bound to haemoglobin; the second is oxygen dissolved in '
        'plasma, which is small at room air but becomes more significant at high PaO₂.',
    clinicalInterpretation:
        'Oxygen content describes how much oxygen the blood carries, not how much reaches the '
        'tissues — delivery (DO₂) additionally requires cardiac output (DO₂ = CaO₂ × cardiac '
        'output). Low CaO₂ with normal cardiac output can still mean adequate delivery.',
    safetyNotes:
        'The dissolved-oxygen term (0.003 × PaO₂) is small under room-air conditions and matters '
        'mainly with supplemental oxygen or hyperbaric therapy. This calculator reports content, '
        'not delivery — do not conflate the two.',
    commonPitfalls:
        'Entering SaO₂ as a fraction instead of a percentage, or vice versa. '
        'Treating CaO₂ as a delivery measure without factoring in cardiac output.',
    osceTips:
        'State the formula and both terms. Examiners often probe the distinction between oxygen '
        'content and oxygen delivery — know that delivery needs cardiac output as well.',
  ),
  CalculatorDefinition(
    id: 'alveolar-gas',
    title: 'Alveolar Gas Equation',
    category: 'Respiratory',
    description: 'Alveolar oxygen tension from FiO₂ and PaCO₂.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'pefr-predicted',
    title: 'PEFR Predicted',
    category: 'Respiratory',
    description: 'Predicted peak expiratory flow from age, sex, and height.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'fev1-predicted',
    title: 'FEV1 Predicted',
    category: 'Respiratory',
    description:
        'Predicted FEV1 from age, sex, height, and ethnicity.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'abg-interpretation',
    title: 'ABG Interpretation Assistant',
    category: 'Respiratory',
    description: 'Step-through acid–base interpretation of a blood gas.',
    implemented: false,
  ),
  // Coming-soon: Surgery & Trauma (new category — Ideas/ideas.md §8)
  CalculatorDefinition(
    id: 'burn-tbsa',
    title: 'Burn % (Rule of 9s)',
    category: 'Surgery & Trauma',
    description: 'Total body surface area burned, adult and paediatric.',
    explanation:
        'The rule of 9s estimates total body surface area (TBSA) burned by assigning each body '
        'region a multiple of 9%. Adult: head and neck 9%, each arm 9%, each leg 18%, anterior '
        'trunk 18%, posterior trunk 18%, perineum 1%. Paediatric preset: head and neck 18%, each '
        'leg 14%, with the remaining regions unchanged from the adult values.',
    clinicalInterpretation:
        'The summed percentage of selected regions drives fluid resuscitation calculations '
        '(e.g. Parkland formula) and burn severity triage. Only partial- and full-thickness burns '
        'count toward the total.',
    safetyNotes:
        'The rule of 9s is a field estimate. Lund–Browder charts are the reference method in '
        'children because body proportions change with age more than the rule of 9s accounts '
        'for.',
    commonPitfalls:
        'Including superficial (erythema-only, first-degree) burns in the total — only partial- '
        'and full-thickness burns count. '
        'Using the adult preset for a child, whose head and legs occupy different proportions.',
    osceTips:
        'State the adult and paediatric region percentages and when to switch presets. Mention '
        'Lund–Browder as the more accurate paediatric reference method.',
  ),
  CalculatorDefinition(
    id: 'alvarado',
    title: 'Alvarado Score',
    category: 'Surgery & Trauma',
    description: 'Likelihood of acute appendicitis.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'wells-score',
    title: 'Wells Score (DVT / PE)',
    category: 'Surgery & Trauma',
    description: 'Pre-test probability for DVT and pulmonary embolism.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'revised-trauma-score',
    title: 'Revised Trauma Score',
    category: 'Surgery & Trauma',
    description: 'Physiological trauma severity from GCS, SBP, and RR.',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'iss',
    title: 'Injury Severity Score (ISS)',
    category: 'Surgery & Trauma',
    description: 'Anatomical trauma severity from AIS region scores.',
    implemented: false,
  ),
  // Coming-soon: Utility (new category — Ideas/ideas.md §9)
  CalculatorDefinition(
    id: 'ibw',
    title: 'Ideal Body Weight (IBW)',
    category: 'Utility',
    description: 'Ideal and adjusted body weight from height and sex.',
    explanation:
        'Devine formula: IBW = 50 kg (men) or 45.5 kg (women), plus 2.3 kg for every inch of '
        'height above 60 inches (5 feet). When an actual weight is supplied, adjusted body '
        'weight (ABW) = IBW + 0.4 × (actual weight − IBW), used for dosing in obesity.',
    clinicalInterpretation:
        'IBW and ABW are used to individualise dosing for weight-based drugs, particularly in '
        'obese patients where actual body weight overestimates the dose some agents need.',
    safetyNotes:
        'The Devine formula is not valid below 60 inches (152 cm) — it can produce negative or '
        'unreliable values. Use a different method (e.g., paediatric or alternative adult '
        'formulas) below this height.',
    commonPitfalls:
        'Applying the formula below 60 inches without a fallback method. '
        'Using actual body weight instead of adjusted body weight for drugs that require it in '
        'obesity.',
    osceTips:
        'State the Devine formula and its 60-inch validity floor. Know when to use IBW versus '
        'adjusted body weight versus actual body weight for a given drug class.',
  ),
  CalculatorDefinition(
    id: 'unit-conversions',
    title: 'Unit Conversions',
    category: 'Utility',
    description: 'Convert between clinical units (mg ↔ mmol, lb ↔ kg).',
    implemented: false,
  ),
  CalculatorDefinition(
    id: 'calorie-requirements',
    title: 'Calorie Requirements',
    category: 'Utility',
    description:
        'Daily energy requirement from weight, height, age, activity.',
    implemented: false,
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

/// Returns calculators grouped by category in the app's display order:
/// categories holding at least one implemented calculator precede categories
/// that hold none, and within each category implemented calculators precede
/// coming-soon ones. Both partitions are done with [availableFirst], which
/// is stable, so the authored relative order is preserved inside each
/// bucket. Built on top of [groupByCategory], which stays the authored-order
/// primitive this helper composes over.
Map<String, List<CalculatorDefinition>> groupedCalculatorsInDisplayOrder(
    [List<CalculatorDefinition> calculators = kCalculators]) {
  final byCategory = groupByCategory(calculators);
  final orderedCategoryEntries = availableFirst<MapEntry<String, List<CalculatorDefinition>>>(
    byCategory.entries,
    (entry) => entry.value.any((c) => c.hasContent),
  );
  final result = <String, List<CalculatorDefinition>>{};
  for (final entry in orderedCategoryEntries) {
    result[entry.key] = availableFirst(entry.value, (c) => c.hasContent);
  }
  return result;
}
