import 'dart:convert';
import 'dart:io';

import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Suture Material rename', () {
    final topic = kSurgicalInstrumentationTopics.firstWhere(
      (t) => t.id == 'sutures',
    );

    test('catalog entry keeps id sutures but displays as Suture Material', () {
      expect(topic.id, 'sutures');
      expect(topic.title, 'Suture Material');
      expect(topic.categoryTitle, 'Surgical Instrumentation');
      expect(
        topic.heroAssetPath,
        'assets/resources/surgical instrumentation.jpeg',
      );
      expect(
        topic.dataAssetPath,
        'assets/data/resources/sutures.json',
      );
      expect(
        topic.description,
        'Core suture types, handling, indications, and image-rich references.',
      );
    });

    test('no other Surgical Instrumentation entry is titled Suture Material, '
        'and all titles are unique case-insensitively', () {
      final lowerTitles = kSurgicalInstrumentationTopics
          .map((t) => t.title.toLowerCase())
          .toList();
      final duplicateTitleCount =
          lowerTitles.where((t) => t == 'suture material').length;
      expect(duplicateTitleCount, 1);
      expect(lowerTitles.toSet().length, lowerTitles.length);
    });

    test(
      'content asset display fields read Suture Material; ids unchanged',
      () {
        final raw = File(
          'assets/data/resources/sutures.json',
        ).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final chapterMetadata =
            json['chapter_metadata'] as Map<String, dynamic>;
        final sections = json['sections'] as List<dynamic>;
        final firstSection = sections[0] as Map<String, dynamic>;

        expect(chapterMetadata['chapter_title'], 'Suture Material');
        expect(chapterMetadata['tags'], ['Suture Material']);
        expect(firstSection['section_title'], 'Suture Material');

        expect(chapterMetadata['chapter_id'], 'sutures');
        expect(firstSection['section_id'], 'sutures_section_1');

        expect(raw.contains('Sutures are used in'), isTrue);
        expect(raw.contains('Absorbable Sutures'), isTrue);
        expect(raw.contains('Non-Absorbable Sutures'), isTrue);

        final occurrences =
            RegExp('Sutures').allMatches(raw).length;
        expect(occurrences, 7);
      },
    );

    testWidgets(
      'real Surgical Instrumentation catalog card list renders Suture '
      'Material, never the bare old name Sutures',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: ResourceTopicListScreen(
            title: 'Surgical Instrumentation',
            topics: kSurgicalInstrumentationTopics,
          ),
        ));

        expect(find.text('Suture Material'), findsOneWidget);
        expect(find.text('Sutures'), findsNothing);
      },
    );
  });
}
