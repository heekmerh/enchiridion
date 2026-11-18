import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_search_screen.dart';
import 'package:enchiridion/screens/resource_topic_detail_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/screens/unlock_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/resource_search.dart';
import 'package:enchiridion/services/resource_topic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixture = '''
{
  "chapter_metadata": {"chapter_id": "t", "chapter_title": "T"},
  "sections": [{
    "section_id": "s1", "section_title": "T", "section_order": 1,
    "subsections": [
      {"subsection_id": "sub_1", "subsection_title": "Causes of chest pain",
       "content_groups": [{"group_id": "g1", "group_title": "Mnemonic: VINDICATE",
         "blocks": [{"type": "paragraph", "text": "**Vascular** causes include aortic dissection."}]}]},
      {"subsection_id": "sub_2", "subsection_title": "Heart failure",
       "content_groups": [{"group_id": "g2", "group_title": "",
         "blocks": [{"type": "table", "columns": ["Letter", "Cause"],
                     "rows": [["F", "Fluid overload"]]}]}]}
    ]
  }]
}
''';

const _first = ResourceTopic(
  id: 'first',
  title: 'Cardiology',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/quick_reference.jpg',
  dataAssetPath: 'fixture/first.json',
);

const _second = ResourceTopic(
  id: 'second',
  title: 'Respiratory',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/quick_reference.jpg',
  dataAssetPath: 'fixture/second.json',
);

void main() {
  setUp(() {
    ResourceSearch.clearCache();
    ResourceSearch.loadAsset = (_) async => _fixture;
  });
  tearDown(() {
    AccessService.testAccessOverride = null;
    ResourceSearch.clearCache();
  });

  group('ResourceSearch', () {
    test('matches words anywhere in a subsection, tables included', () async {
      final hits = await ResourceSearch.search([_first], 'fluid OVERLOAD');
      expect(hits, hasLength(1));
      expect(hits.single.subsectionId, 'sub_2');
      expect(hits.single.snippet, contains('Fluid overload'));
    });

    test('strips bold markers from snippets', () async {
      final hits = await ResourceSearch.search([_first], 'vascular');
      expect(hits.single.snippet, isNot(contains('**')));
    });

    test('matches topic titles', () async {
      final hits = await ResourceSearch.search([_first, _second], 'respir');
      expect(hits.single.topic.id, 'second');
      expect(hits.single.subsectionId, isNull);
    });

    test('searches only the topics it is given', () async {
      final hits = await ResourceSearch.search([_second], 'cardiology');
      expect(hits, isEmpty);
    });

    test('real mnemonics content is searchable', () async {
      ResourceSearch.loadAsset = rootBundle.loadString;
      final hits = await ResourceSearch.search(kMnemonicsTopics, 'vindicate');
      expect(hits, isNotEmpty);
      expect(hits.every((h) => kMnemonicsTopics.contains(h.topic)), isTrue);
    });
  });

  group('ResourceSearchScreen', () {
    Widget host(List<List<ResourceTopic>> catalogs) => MaterialApp(
          home: ResourceSearchScreen(
            sectionTitle: 'Test section',
            catalogs: catalogs,
          ),
        );

    testWidgets('a premium account opens the topic at the match',
        (tester) async {
      AccessService.testAccessOverride = true;
      await tester.pumpWidget(host([
        [_first]
      ]));
      await tester.enterText(find.byType(TextField), 'fluid');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Cardiology · Heart failure'), findsOneWidget);
      await tester.tap(find.text('Cardiology · Heart failure'));
      await tester.pumpAndSettle();

      final detail = tester.widget<ResourceTopicDetailScreen>(
          find.byType(ResourceTopicDetailScreen));
      expect(detail.initialSubsectionId, 'sub_2');
    });

    testWidgets('a free account is sent to unlock past the free topic',
        (tester) async {
      AccessService.testAccessOverride = false;
      await tester.pumpWidget(host([
        [_first, _second]
      ]));
      await tester.enterText(find.byType(TextField), 'respiratory');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.text('Respiratory'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('says when nothing matches', (tester) async {
      AccessService.testAccessOverride = true;
      await tester.pumpWidget(host([
        [_first]
      ]));
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.textContaining('No results'), findsOneWidget);
    });
  });

  testWidgets('every topic list has a search button for its own section',
      (tester) async {
    AccessService.testAccessOverride = true;
    await tester.pumpWidget(const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Prescriptions & medication guide',
        topics: kPrescriptionTopics,
        dense: true,
      ),
    ));
    await tester.tap(find.byTooltip('Search Prescriptions & medication guide'));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<ResourceSearchScreen>(find.byType(ResourceSearchScreen));
    expect(screen.catalogs, [kPrescriptionTopics]);
  });

  test('a search result opens the tab holding its subsection', () async {
    final topic = kMnemonicsTopics.first;
    final chapter =
        await ResourceTopicService.loadChapter(topic.dataAssetPath!);
    final second = chapter.sections.first.subsections[1].id;
    expect(
      initialTabFor(topic: topic, chapter: chapter, subsectionId: second),
      1,
    );
    expect(
      initialTabFor(topic: topic, chapter: chapter, subsectionId: null),
      0,
    );
  });
}
