import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_detail_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/utils/content_availability.dart';
import 'package:enchiridion/widgets/common/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Local fixtures rather than the real catalogs, so this file stays valid
// while sibling Task 2 rewrites kMedicalInstrumentationTopics.
const _groupANoContent1 = ResourceTopic(
  id: 'group-a-no-content-1',
  title: 'Group A No Content 1',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
  group: 'Group A',
);

const _groupBWithContent = ResourceTopic(
  id: 'group-b-with-content',
  title: 'Group B With Content',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
  dataAssetPath: 'assets/data/resources/group_b_with_content.json',
  description: 'Has real content.',
  group: 'Group B',
);

const _groupANoContent2 = ResourceTopic(
  id: 'group-a-no-content-2',
  title: 'Group A No Content 2',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
  group: 'Group A',
);

const _groupedFixture = [
  _groupANoContent1,
  _groupBWithContent,
  _groupANoContent2,
];

const _available = ResourceTopic(
  id: 'available-topic',
  title: 'Available Topic',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
  dataAssetPath: 'assets/data/resources/available_topic.json',
  description: 'Has real content.',
);

const _pending = ResourceTopic(
  id: 'pending-topic',
  title: 'Pending Topic',
  categoryTitle: 'Test',
  heroAssetPath: 'assets/resources/osce.jpeg',
);

const _groupLessFixture = [_available, _pending];

Widget _groupedSubject() => const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Grouped Test List',
        topics: _groupedFixture,
      ),
    );

Widget _groupLessSubject() => const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Group-less Test List',
        topics: _groupLessFixture,
      ),
    );

void main() {
  test(
      'groupTopicsForDisplay ranks a group holding content ahead of a group '
      'holding none, group order otherwise first-appearance', () {
    final grouped = groupTopicsForDisplay(_groupedFixture);

    expect(grouped.keys.toList(), ['Group B', 'Group A']);
  });

  test(
      'groupTopicsForDisplay keeps topics available-first within a group, '
      'otherwise authored relative order', () {
    const groupAContent = ResourceTopic(
      id: 'group-a-with-content',
      title: 'Group A With Content',
      categoryTitle: 'Test',
      heroAssetPath: 'assets/resources/osce.jpeg',
      dataAssetPath: 'assets/data/resources/group_a_with_content.json',
      group: 'Group A',
    );
    final mixedGroupA = [
      _groupANoContent1,
      groupAContent,
      _groupANoContent2,
    ];

    final grouped = groupTopicsForDisplay(mixedGroupA);

    expect(
      grouped['Group A']!.map((t) => t.id).toList(),
      ['group-a-with-content', 'group-a-no-content-1', 'group-a-no-content-2'],
    );
  });

  test(
      'groupTopicsForDisplay on an all-null-group list returns one bucket '
      'keyed null, matching flat availableFirst order', () {
    final grouped = groupTopicsForDisplay(_groupLessFixture);

    expect(grouped.keys.toList(), [null]);
    expect(
      grouped[null],
      availableFirst(_groupLessFixture, (t) => t.hasContent),
    );
  });

  testWidgets(
      'a grouped fixture renders the leading group\'s SectionHeader, '
      'uppercased', (tester) async {
    await tester.pumpWidget(_groupedSubject());

    expect(find.byType(SectionHeader), findsWidgets);
    expect(find.text('GROUP B'), findsOneWidget);
  });

  testWidgets(
      'a grouped fixture renders the trailing group\'s SectionHeader too, '
      'uppercased', (tester) async {
    await tester.pumpWidget(_groupedSubject());

    await tester.scrollUntilVisible(find.text('GROUP A'), 300);
    await tester.pumpAndSettle();

    expect(find.text('GROUP A'), findsOneWidget);
  });

  testWidgets(
      'a group-less fixture renders zero SectionHeader widgets, rows and '
      'order unchanged', (tester) async {
    await tester.pumpWidget(_groupLessSubject());

    expect(find.byType(SectionHeader), findsNothing);
    expect(find.text('Available Topic'), findsOneWidget);
  });

  testWidgets('tapping an available row in a grouped list pushes the detail '
      'screen', (tester) async {
    await tester.pumpWidget(_groupedSubject());

    await tester.tap(find.text('Group B With Content'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceTopicDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a coming-soon row in a grouped list shows the '
      'SnackBar and pushes nothing', (tester) async {
    await tester.pumpWidget(_groupedSubject());
    await tester.scrollUntilVisible(find.text('Group A No Content 1'), 300);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Group A No Content 1'));
    await tester.pump();

    expect(find.byType(ResourceTopicDetailScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Coming Soon'), findsWidgets);
  });

  testWidgets(
      'the real kMedicalInstrumentationTopics catalog opens on the '
      'Diagnostic and Monitoring Equipment header with IV Cannula first',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Medical Instrumentation',
        topics: kMedicalInstrumentationTopics,
      ),
    ));

    expect(
      find.text('DIAGNOSTIC AND MONITORING EQUIPMENT'),
      findsOneWidget,
    );

    final firstHeaderFinder = find.byType(SectionHeader).first;
    final firstTopicRowFinder = find.ancestor(
      of: find.text('IV Cannula'),
      matching: find.byType(Ink),
    );

    // The header precedes the first topic row in paint order, so the
    // header's top offset must be smaller than the topic row's.
    final headerTop = tester.getTopLeft(firstHeaderFinder).dy;
    final topicTop = tester.getTopLeft(firstTopicRowFinder).dy;
    expect(headerTop, lessThan(topicTop));
  });

  testWidgets(
      'the real kSurgicalInstrumentationTopics catalog renders no '
      'SectionHeader at all', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Surgical Instrumentation',
        topics: kSurgicalInstrumentationTopics,
        dense: true,
      ),
    ));

    expect(find.byType(SectionHeader), findsNothing);

    await tester.scrollUntilVisible(find.text('Wound dressing set'), 300);
    await tester.pumpAndSettle();

    expect(find.byType(SectionHeader), findsNothing);
  });
}
