// Guards the full 48-entry Medical Instrumentation catalog against drift
// from `scripts/content/medical_instrumentation.md`: every bullet present
// exactly once, carrying its authored group, with ids unique across all
// three catalogs and the display helper opening on the group holding this
// catalog's only real content.

import 'package:enchiridion/models/resource_topic.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _expectedGroupsInSourceOrder = [
  'Cardiovascular Instrumentation',
  'Respiratory Instrumentation',
  'Neurological Instrumentation',
  'Diagnostic and Monitoring Equipment',
  'Imaging Equipment',
  'Ophthalmic Instruments',
  'ENT Instruments',
  'Biomedical Sensors and Transducers',
  'Therapeutic Equipment',
];

const Map<String, int> _expectedMemberCountsByGroup = {
  'Cardiovascular Instrumentation': 8,
  'Respiratory Instrumentation': 8,
  'Neurological Instrumentation': 4,
  'Diagnostic and Monitoring Equipment': 8,
  'Imaging Equipment': 5,
  'Ophthalmic Instruments': 4,
  'ENT Instruments': 4,
  'Biomedical Sensors and Transducers': 5,
  'Therapeutic Equipment': 2,
};

void main() {
  test('kMedicalInstrumentationTopics holds exactly 48 entries', () {
    expect(kMedicalInstrumentationTopics.length, 48);
  });

  test('every entry has a non-null group, and the set of distinct groups is '
      'exactly the 9 source headings', () {
    for (final topic in kMedicalInstrumentationTopics) {
      expect(topic.group, isNotNull, reason: '${topic.id} has a null group');
    }

    final distinctGroups =
        kMedicalInstrumentationTopics.map((t) => t.group).toSet();
    expect(distinctGroups, _expectedGroupsInSourceOrder.toSet());
  });

  test('member counts per group match the source file, in source-file order',
      () {
    for (final group in _expectedGroupsInSourceOrder) {
      final count =
          kMedicalInstrumentationTopics.where((t) => t.group == group).length;
      expect(
        count,
        _expectedMemberCountsByGroup[group],
        reason: 'group "$group" has the wrong member count',
      );
    }
  });

  test(
      'every entry has the Medical Instrumentation categoryTitle, and ids '
      'are unique across all three catalogs', () {
    for (final topic in kMedicalInstrumentationTopics) {
      expect(topic.categoryTitle, 'Medical Instrumentation');
    }

    final allIds = [
      ...kMedicalInstrumentationTopics,
      ...kSurgicalInstrumentationTopics,
      ...kOsceTopics,
    ].map((t) => t.id).toList();
    expect(
      allIds.toSet().length,
      allIds.length,
      reason: 'ids must be unique across kMedicalInstrumentationTopics, '
          'kSurgicalInstrumentationTopics, and kOsceTopics combined',
    );
  });

  test(
      'the iv-cannula entry is present exactly once, still carries its '
      'content asset and description, and sits in the Diagnostic and '
      'Monitoring Equipment group', () {
    final matches =
        kMedicalInstrumentationTopics.where((t) => t.id == 'iv-cannula');
    expect(matches, hasLength(1));

    final ivCannula = matches.first;
    expect(ivCannula.dataAssetPath, 'assets/data/resources/iv_cannula.json');
    expect(
      ivCannula.description,
      'Peripheral venous cannula parts, insertion, uses, and precautions.',
    );
    expect(ivCannula.group, 'Diagnostic and Monitoring Equipment');
  });

  test(
      'groupTopicsForDisplay(kMedicalInstrumentationTopics) opens on '
      'Diagnostic and Monitoring Equipment, with iv-cannula leading that '
      'bucket', () {
    final grouped = groupTopicsForDisplay(kMedicalInstrumentationTopics);

    expect(grouped.keys.first, 'Diagnostic and Monitoring Equipment');
    expect(
      grouped['Diagnostic and Monitoring Equipment']!.first.id,
      'iv-cannula',
    );
  });
}
