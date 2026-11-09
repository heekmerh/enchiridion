// Covers `lib/utils/osce_subtopics.dart`'s `isOsceSubtopicHeading` predicate
// in isolation, then proves the end-to-end effect it has once wired into
// `subtopicTabsFor`'s `isSectionHeading` parameter (`osce_screen.dart`'s
// actual call path) against the real, shipped Abdominal Examination JSON.
// The JSON is read with a plain `dart:io` `File`, not `rootBundle` — real
// asset loading hangs indefinitely in this project's widget-test
// environment (see `subtopic_tabs_test.dart` and
// `surgical_instrumentation_source_fidelity_test.dart` for the same
// pattern). If the file is not present in this checkout, that one test
// skips with a clear reason instead of failing the suite.

import 'dart:convert';
import 'dart:io';

import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/utils/osce_subtopics.dart';
import 'package:enchiridion/widgets/common/subtopic_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

const _abdominalJsonPath = 'assets/data/resources/abdominal_examination.json';

void main() {
  group('isOsceSubtopicHeading', () {
    test('ALL-CAPS titles are headings', () {
      expect(isOsceSubtopicHeading('SPECIAL TESTS (HIGH-YIELD)'), isTrue);
      expect(isOsceSubtopicHeading('COMPLETION'), isTrue);
    });

    test('a single-letter enumerator prefix is stripped before checking', () {
      expect(isOsceSubtopicHeading('A. INSPECTION'), isTrue);
      expect(isOsceSubtopicHeading('B. PALPATION'), isTrue);
    });

    test('short abbreviations and symbol-joined abbreviations are headings',
        () {
      expect(isOsceSubtopicHeading('FBC'), isTrue);
      expect(isOsceSubtopicHeading('U&E'), isTrue);
    });

    test('a title with no letters at all is a heading (starts its own group)',
        () {
      expect(isOsceSubtopicHeading('🔑 TIPS'), isTrue);
      expect(isOsceSubtopicHeading('123'), isTrue);
    });

    test('sentence-case continuations are not headings', () {
      expect(isOsceSubtopicHeading('Light palpation'), isFalse);
      expect(isOsceSubtopicHeading('What is guarding?'), isFalse);
      expect(isOsceSubtopicHeading('Deep palpation'), isFalse);
    });

    test('a mixed-case title with any lowercase letter is not a heading', () {
      expect(
        isOsceSubtopicHeading('ASCITES (e.g., Liver Cirrhosis)'),
        isFalse,
      );
    });
  });

  group('subtopicTabsFor with isSectionHeading (real Abdominal content)', () {
    test(
        'groups the shipped 69-subsection Abdominal chapter into heading-bounded sub-topics',
        () {
      final file = File(_abdominalJsonPath);
      if (!file.existsSync()) {
        markTestSkipped(
          '$_abdominalJsonPath not present in this checkout; skipping the '
          'real-content grouping assertion.',
        );
        return;
      }

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final chapter = Chapter.fromJson(json);
      final sourceSubsections = chapter.sections.single.subsections;

      const topic = ResourceTopic(
        id: 'abdominal-examination',
        title: 'Abdominal Examination',
        categoryTitle: 'OSCE',
        heroAssetPath: 'assets/resources/osce.jpeg',
      );

      final tabs = subtopicTabsFor(
        topic: topic,
        chapter: chapter,
        isSectionHeading: isOsceSubtopicHeading,
      );

      // First sub-topic is the opening heading.
      expect(tabs.first.title, 'INTRODUCTION (OSCE OPENING)');

      // Grouping strictly reduces the tab count from the raw subsection
      // count — this is the whole point of inferring sub-topics rather than
      // exposing every raw subsection as its own tab.
      expect(tabs.length, lessThan(sourceSubsections.length));

      // A pure continuation paragraph never surfaces as its own tab.
      expect(tabs.map((t) => t.title), isNot(contains('Light palpation')));
      expect(tabs.map((t) => t.title), isNot(contains('What is guarding?')));

      // Conservation invariant: concatenating each tab's slice subsections,
      // in order, reproduces the source subsection list exactly — nothing
      // dropped, nothing duplicated, order preserved.
      final reassembled = <ChapterSubsection>[
        for (final tab in tabs) ...tab.content!.sections.single.subsections,
      ];
      expect(
        reassembled.map((s) => s.id).toList(),
        sourceSubsections.map((s) => s.id).toList(),
      );
    });
  });
}
