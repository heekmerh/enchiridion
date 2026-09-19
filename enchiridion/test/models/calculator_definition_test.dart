import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/models/calculator_definition.dart';

void main() {
  group('CalculatorDefinition', () {
    test(
        'default enhancement fields are empty strings when only required fields provided',
        () {
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

    test('implemented defaults to true for a definition constructed without it',
        () {
      const def = CalculatorDefinition(
        id: 'test-id',
        title: 'Test Calculator',
        category: 'General',
        description: 'A test calculator.',
      );
      expect(def.implemented, isTrue);
      expect(def.hasContent, isTrue);
      expect(def.isComingSoon, isFalse);
    });

    test('implemented: false flips hasContent/isComingSoon', () {
      const def = CalculatorDefinition(
        id: 'test-id',
        title: 'Test Calculator',
        category: 'General',
        description: 'A test calculator.',
        implemented: false,
      );
      expect(def.implemented, isFalse);
      expect(def.hasContent, isFalse);
      expect(def.isComingSoon, isTrue);
    });
  });

  group('kCalculators', () {
    // 58 entries total: the app's authored calculator catalog from
    // Ideas/ideas.md (nine-category calculator spec PROJECT.md points at),
    // minus three deliberate duplicates of shipped calculators (see
    // CALCULATOR-SOURCING.md).
    test('kCalculators has exactly 58 entries', () {
      expect(kCalculators.length, 58);
    });

    test('all calculator ids are unique', () {
      final ids = kCalculators.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('implemented count is 26 and coming-soon count is 32', () {
      // Goes 26/32 -> 33/25 (Task 2) -> 38/20 (Task 3) as this plan's
      // remaining tasks flip flags on the twelve verified formulas.
      final implemented = kCalculators.where((c) => c.implemented).length;
      final comingSoon = kCalculators.where((c) => c.isComingSoon).length;
      expect(implemented, 26);
      expect(comingSoon, 32);
      expect(implemented + comingSoon, kCalculators.length);
    });

    test(
        'existing calculator entries preserve correct ordering (freemium position-0 free)',
        () {
      final drugDosing =
          kCalculators.where((c) => c.category == 'Drug Dosing').toList();
      final emergency = kCalculators
          .where((c) => c.category == 'Emergency & Critical Care')
          .toList();
      final general =
          kCalculators.where((c) => c.category == 'General').toList();
      final obsGynae =
          kCalculators.where((c) => c.category == 'Obs & Gynae').toList();
      final paediatrics =
          kCalculators.where((c) => c.category == 'Paediatrics').toList();

      expect(drugDosing.first.id, 'weight-dosing');
      expect(emergency.first.id, 'gcs');
      expect(general.first.id, 'bmi');
      expect(obsGynae.first.id, 'edd-ega');
      expect(paediatrics.first.id, 'holliday-segar');
    });
  });

  group('groupByCategory', () {
    test('groupByCategory returns exactly 9 keys for kCalculators', () {
      final grouped = groupByCategory(kCalculators);
      expect(grouped.keys.toSet(), {
        'Drug Dosing',
        'Emergency & Critical Care',
        'General',
        'Obs & Gynae',
        'Paediatrics',
        'Cardiology',
        'Respiratory',
        'Surgery & Trauma',
        'Utility',
      });
      expect(grouped.keys.length, 9);
    });

    test('groupByCategory final per-category counts', () {
      final grouped = groupByCategory(kCalculators);
      expect(grouped['Drug Dosing']?.length, 9);
      expect(grouped['Emergency & Critical Care']?.length, 11);
      expect(grouped['General']?.length, 6);
      expect(grouped['Obs & Gynae']?.length, 5);
      expect(grouped['Paediatrics']?.length, 7);
      expect(grouped['Cardiology']?.length, 7);
      expect(grouped['Respiratory']?.length, 5);
      expect(grouped['Surgery & Trauma']?.length, 5);
      expect(grouped['Utility']?.length, 3);

      // Grouped lengths sum to kCalculators.length, and no group is empty.
      final total =
          grouped.values.fold<int>(0, (sum, list) => sum + list.length);
      expect(total, kCalculators.length);
      for (final list in grouped.values) {
        expect(list, isNotEmpty);
      }
    });
  });

  group('groupedCalculatorsInDisplayOrder', () {
    test(
        'categories with at least one implemented calculator precede categories with none',
        () {
      final grouped = groupedCalculatorsInDisplayOrder();
      final keys = grouped.keys.toList();
      final categoryHasImplemented = <String, bool>{
        for (final entry in grouped.entries)
          entry.key: entry.value.any((c) => c.implemented),
      };
      final firstUnimplementedIndex =
          keys.indexWhere((k) => categoryHasImplemented[k] == false);
      final lastImplementedIndex =
          keys.lastIndexWhere((k) => categoryHasImplemented[k] == true);
      // At this point (Task 1), Cardiology, Respiratory, Surgery & Trauma,
      // and Utility have no implemented calculators and must be the
      // trailing four.
      expect(firstUnimplementedIndex, isNot(-1));
      expect(lastImplementedIndex, lessThan(firstUnimplementedIndex));
      expect(
        keys.sublist(firstUnimplementedIndex),
        containsAll(
            ['Cardiology', 'Respiratory', 'Surgery & Trauma', 'Utility']),
      );
    });

    test(
        'within each category, implemented calculators precede coming-soon ones in authored order',
        () {
      final grouped = groupedCalculatorsInDisplayOrder();
      for (final entry in grouped.entries) {
        final implementedFlags = entry.value.map((c) => c.implemented).toList();
        final firstComingSoon = implementedFlags.indexOf(false);
        final lastImplemented = implementedFlags.lastIndexOf(true);
        if (firstComingSoon == -1 || lastImplemented == -1) continue;
        expect(lastImplemented, lessThan(firstComingSoon),
            reason:
                '${entry.key}: a coming-soon entry ranks before an implemented one');
      }

      // Sanity: authored relative order among implemented ones is unchanged.
      expect(grouped['Drug Dosing']?.first.id, 'weight-dosing');
      expect(grouped['Emergency & Critical Care']?.first.id, 'gcs');
      expect(grouped['General']?.first.id, 'bmi');
      expect(grouped['Obs & Gynae']?.first.id, 'edd-ega');
      expect(grouped['Paediatrics']?.first.id, 'holliday-segar');
    });
  });
}
