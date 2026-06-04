import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/models/calculator_definition.dart';

void main() {
  group('CalculatorDefinition', () {
    test('default enhancement fields are empty strings when only required fields provided', () {
      const def = CalculatorDefinition(
        id: 'test-id',
        title: 'Test Calculator',
        category: 'General',
        description: 'A test calculator.',
      );
      expect(def.explanation, '');
      expect(def.clinicalInterpretation, '');
      expect(def.safetyNotes, '');
      expect(def.commonPitfalls, '');
      expect(def.osceTips, '');
    });

    test('all 5 enhancement fields can be set and read back', () {
      const def = CalculatorDefinition(
        id: 'test-id',
        title: 'Test Calculator',
        category: 'General',
        description: 'A test calculator.',
        explanation: 'This explains the result.',
        clinicalInterpretation: 'Use this to interpret clinically.',
        safetyNotes: 'Do not use in pregnancy.',
        commonPitfalls: 'Forgetting to convert units.',
        osceTips: 'In OSCEs, state the normal range.',
      );
      expect(def.explanation, 'This explains the result.');
      expect(def.clinicalInterpretation, 'Use this to interpret clinically.');
      expect(def.safetyNotes, 'Do not use in pregnancy.');
      expect(def.commonPitfalls, 'Forgetting to convert units.');
      expect(def.osceTips, 'In OSCEs, state the normal range.');
    });
  });

  group('kCalculators', () {
    test('kCalculators has exactly 26 entries', () {
      // Goes GREEN at end of Phase 4 (after 04-02/03/04 add 18 new calculators)
      // Currently 8 existing calculators; will be 8 + 18 = 26 after Wave 2-4.
      expect(kCalculators.length, 26);
    });

    test('existing calculator entries preserve correct ordering (freemium position-0 free)', () {
      final drugDosing = kCalculators.where((c) => c.category == 'Drug Dosing').toList();
      final emergency = kCalculators.where((c) => c.category == 'Emergency & Critical Care').toList();
      final general = kCalculators.where((c) => c.category == 'General').toList();
      final obsGynae = kCalculators.where((c) => c.category == 'Obs & Gynae').toList();
      final paediatrics = kCalculators.where((c) => c.category == 'Paediatrics').toList();

      expect(drugDosing.first.id, 'weight-dosing');
      expect(emergency.first.id, 'gcs');
      expect(general.first.id, 'bmi');
      expect(obsGynae.first.id, 'edd-ega');
      expect(paediatrics.first.id, 'holliday-segar');
    });
  });

  group('groupByCategory', () {
    test('groupByCategory returns exactly 5 keys for kCalculators', () {
      // Goes GREEN at end of Phase 4 (after 04-02/03/04 add 18 new calculators)
      // Currently 8 calculators in 5 categories; after all plans: 26 in same 5 categories.
      final grouped = groupByCategory(kCalculators);
      expect(grouped.keys.toSet(), {
        'Drug Dosing',
        'Emergency & Critical Care',
        'General',
        'Obs & Gynae',
        'Paediatrics',
      });
      expect(grouped.keys.length, 5);
    });

    test('groupByCategory final per-category counts (goes GREEN at end of Phase 4)', () {
      // Goes GREEN at end of Phase 4 (after 04-02/03/04 add 18 new calculators)
      // Final expected: Drug Dosing 8, Emergency & Critical Care 9, General 1, Obs & Gynae 1, Paediatrics 7 = 26
      final grouped = groupByCategory(kCalculators);
      expect(grouped['Drug Dosing']?.length, 8);
      expect(grouped['Emergency & Critical Care']?.length, 9);
      expect(grouped['General']?.length, 1);
      expect(grouped['Obs & Gynae']?.length, 1);
      expect(grouped['Paediatrics']?.length, 7);
    });
  });
}
