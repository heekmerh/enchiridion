import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/widgets/common/subtopic_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ChapterSubsection _subsection(String id, String title) => ChapterSubsection(
      id: id,
      title: title,
      contentGroups: const [],
    );

ChapterSection _section(
  String id,
  String title,
  List<ChapterSubsection> subsections,
) =>
    ChapterSection(id: id, title: title, order: 0, subsections: subsections);

Chapter _chapter(List<ChapterSection> sections) => Chapter(
      id: 'chapter-id',
      title: 'Chapter Title',
      order: 0,
      sections: sections,
    );

const _topic = ResourceTopic(
  id: 'topic-id',
  title: 'Topic Title',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
);

void main() {
  group('subtopicTabsFor (pure derivation)', () {
    test('1 section with 3 subsections yields 3 tabs titled by subsection',
        () {
      final chapter = _chapter([
        _section('sec-1', 'Section One', [
          _subsection('sub-1', 'Alpha'),
          _subsection('sub-2', 'Beta'),
          _subsection('sub-3', 'Gamma'),
        ]),
      ]);

      final tabs = subtopicTabsFor(topic: _topic, chapter: chapter);

      expect(tabs.map((t) => t.title).toList(), ['Alpha', 'Beta', 'Gamma']);
    });

    test('subsection slices preserve section and subsection ids', () {
      final chapter = _chapter([
        _section('sec-1', 'Section One', [
          _subsection('sub-1', 'Alpha'),
          _subsection('sub-2', 'Beta'),
        ]),
      ]);

      final tabs = subtopicTabsFor(topic: _topic, chapter: chapter);

      expect(tabs, hasLength(2));
      for (var i = 0; i < tabs.length; i++) {
        final slice = tabs[i].content!;
        expect(slice.sections, hasLength(1));
        expect(slice.sections.single.id, 'sec-1');
        expect(slice.sections.single.subsections, hasLength(1));
        expect(
          slice.sections.single.subsections.single.id,
          chapter.sections.first.subsections[i].id,
        );
      }
    });

    test(
        '2 sections yields 2 tabs titled by section, each slice carrying that whole section',
        () {
      final sectionA =
          _section('sec-a', 'Section A', [_subsection('sub-1', 'One')]);
      final sectionB = _section('sec-b', 'Section B', [
        _subsection('sub-2', 'Two'),
        _subsection('sub-3', 'Three'),
      ]);
      final chapter = _chapter([sectionA, sectionB]);

      final tabs = subtopicTabsFor(topic: _topic, chapter: chapter);

      expect(tabs.map((t) => t.title).toList(), ['Section A', 'Section B']);
      expect(tabs[0].content!.sections.single, same(sectionA));
      expect(tabs[1].content!.sections.single, same(sectionB));
    });

    test(
        '1 section with 1 subsection yields exactly 1 tab carrying the chapter unchanged',
        () {
      final chapter = _chapter([
        _section('sec-1', 'Section One', [_subsection('sub-1', 'Alpha')]),
      ]);

      final tabs = subtopicTabsFor(topic: _topic, chapter: chapter);

      expect(tabs, hasLength(1));
      expect(tabs.single.content, same(chapter));
    });

    test('null chapter with a 7-entry outline yields 7 tabs with no content',
        () {
      const topic = ResourceTopic(
        id: 'topic-id',
        title: 'Topic Title',
        categoryTitle: 'Test',
        heroAssetPath: 'assets/resources/osce.jpeg',
        outline: ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      );

      final tabs = subtopicTabsFor(topic: topic, chapter: null);

      expect(tabs.map((t) => t.title).toList(), topic.outline);
      expect(tabs.every((t) => t.content == null), isTrue);
    });

    test(
        'null chapter with no outline yields exactly 1 tab titled with the topic title',
        () {
      final tabs = subtopicTabsFor(topic: _topic, chapter: null);

      expect(tabs, hasLength(1));
      expect(tabs.single.title, _topic.title);
      expect(tabs.single.content, isNull);
    });

    test('a blank section or subsection title still produces a non-empty tab label',
        () {
      final subsectionChapter = _chapter([
        _section('sec-1', 'Section One', [
          _subsection('sub-1', ''),
          _subsection('sub-2', '   '),
        ]),
      ]);
      final subsectionTabs =
          subtopicTabsFor(topic: _topic, chapter: subsectionChapter);
      expect(subsectionTabs.every((t) => t.title.trim().isNotEmpty), isTrue);

      final sectionChapter = _chapter([
        _section('sec-a', '', [_subsection('sub-1', 'One')]),
        _section('sec-b', '   ', [_subsection('sub-2', 'Two')]),
      ]);
      final sectionTabs =
          subtopicTabsFor(topic: _topic, chapter: sectionChapter);
      expect(sectionTabs.every((t) => t.title.trim().isNotEmpty), isTrue);
    });
  });

  group('SubtopicTabsView', () {
    testWidgets(
        'a topic with no content and a 4-entry outline shows a TabBar with 4 labels, swipeable by drag',
        (tester) async {
      const topic = ResourceTopic(
        id: 'topic-id',
        title: 'Topic Title',
        categoryTitle: 'Test',
        heroAssetPath: 'assets/resources/osce.jpeg',
        outline: ['One', 'Two', 'Three', 'Four'],
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SubtopicTabsView(topic: topic)),
      ));

      expect(find.byType(TabBar), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.tabs.map((t) => (t as Tab).text).toList(),
        topic.outline,
      );
      expect(tabBar.controller!.index, 0);

      await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    });

    testWidgets('a topic whose derivation yields a single entry renders no TabBar',
        (tester) async {
      const topic = ResourceTopic(
        id: 'topic-id',
        title: 'Topic Title',
        categoryTitle: 'Test',
        heroAssetPath: 'assets/resources/osce.jpeg',
      );

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SubtopicTabsView(topic: topic)),
      ));

      expect(find.byType(TabBar), findsNothing);
    });
  });
}
