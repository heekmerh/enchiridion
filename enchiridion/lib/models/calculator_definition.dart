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

const String _kDefaultDisclaimer =
    'Enchiridion calculators are clinical support tools and do not replace '
    'professional judgment, institutional guidelines, or senior review.';

const List<CalculatorDefinition> kCalculators = [
  CalculatorDefinition(
    id: 'weight-dosing',
    title: 'Weight-Based Drug Dosing',
    category: 'Drug Dosing',
    description: 'Calculate total dose from patient weight and dose per kg.',
  ),
  CalculatorDefinition(
    id: 'iv-infusion',
    title: 'IV Infusion Rate',
    category: 'Drug Dosing',
    description: 'Calculate infusion rate in mL/hr or drops/min.',
  ),
  CalculatorDefinition(
    id: 'gcs',
    title: 'Glasgow Coma Scale',
    category: 'Emergency & Critical Care',
    description: 'Score conscious level from Eye, Verbal, and Motor responses.',
  ),
  CalculatorDefinition(
    id: 'bmi',
    title: 'BMI',
    category: 'General',
    description: 'Body Mass Index from weight and height with WHO category.',
  ),
  CalculatorDefinition(
    id: 'edd-ega',
    title: 'EDD / Gestational Age',
    category: 'Obs & Gynae',
    description: 'Estimated delivery date and gestational age from LMP.',
  ),
  CalculatorDefinition(
    id: 'anion-gap',
    title: 'Anion Gap',
    category: 'Emergency & Critical Care',
    description: 'Classify metabolic acidosis from Na, Cl, and HCO₃.',
  ),
  CalculatorDefinition(
    id: 'creatinine-clearance',
    title: 'Creatinine Clearance',
    category: 'Drug Dosing',
    description: 'Estimate CrCl via Cockcroft-Gault for renal dosing.',
  ),
  CalculatorDefinition(
    id: 'holliday-segar',
    title: 'Paediatric Maintenance Fluids',
    category: 'Paediatrics',
    description: 'Holliday-Segar 4-2-1 rule for maintenance IV fluids.',
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
