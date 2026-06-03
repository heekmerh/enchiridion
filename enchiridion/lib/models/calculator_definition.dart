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
