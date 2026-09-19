import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/content_block.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/common/subtopic_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// A repeated line long enough to wrap across several lines at the default
/// font size within a typical test viewport width.
String _longParagraph(String label, int index) =>
    'Paragraph $index for $label. ' * 8;

/// A chapter with one section holding four subsections, each carrying
/// enough paragraph blocks that the assembled document is several times
/// taller than the test viewport — otherwise "scrolling past a boundary" is
/// unobservable.
Chapter _tallContentChapter() {
  ChapterSubsection makeSubsection(String id, String title) {
    return ChapterSubsection(
      id: id,
      title: title,
      contentGroups: [
        ContentGroup(
          id: '$id-group',
          title: '',
          blocks: [
            for (var i = 0; i < 20; i++)
              ParagraphBlock(text: _longParagraph(title, i)),
          ],
        ),
      ],
    );
  }

  return Chapter(
    id: 'tall-chapter',
    title: 'Tall Chapter',
    order: 0,
    sections: [
      ChapterSection(
        id: 'sec-1',
        title: 'Section One',
        order: 0,
        subsections: [
          makeSubsection('sub-1', 'Sub One'),
          makeSubsection('sub-2', 'Sub Two'),
          makeSubsection('sub-3', 'Sub Three'),
          makeSubsection('sub-4', 'Sub Four'),
        ],
      ),
    ],
  );
}

/// Scopes a finder to the content scroll view, so a search for a heading
/// text (e.g. "Sub Four") never collides with the identically-worded tab
/// label rendered by the [TabBar] above it.
Finder _inContent(Finder matcher) => find.descendant(
      of: find.byType(CustomScrollView),
      matching: matcher,
    );

Finder _contentScrollable() => find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );

/// Scrolls [scrollable] until [heading] is visible, then aligns it to the
/// top of the viewport (`Scrollable.ensureVisible`'s default alignment),
/// so a scrollspy assertion can rely on the heading having actually crossed
/// the activation line near the viewport's top edge.
Future<void> _scrollHeadingToTop(
  WidgetTester tester,
  Finder scrollable,
  Finder heading,
) async {
  await tester.scrollUntilVisible(
    heading,
    300,
    scrollable: scrollable,
    maxScrolls: 200,
  );
  await tester.pump();
  // `scrollUntilVisible`'s final internal `Scrollable.ensureVisible` jumps
  // (zero-duration) rather than animates, so its scroll-position listener
  // notification fires synchronously — before the resulting layout has been
  // computed — leaving the scrollspy reading one-frame-stale render box
  // positions. A small following drag (past touch slop, then reversed to
  // net back to the same position) forces a fresh scroll notification once
  // the jumped-to layout has actually been built.
  await tester.drag(scrollable, const Offset(0, -40));
  await tester.pump();
  await tester.drag(scrollable, const Offset(0, 40));
  await tester.pump();
}

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

  group('SubtopicTabsView content-backed continuous scroll', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService(await SharedPreferences.getInstance());
    });

    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(
            body: MultiProvider(
              providers: [
                Provider<StorageService>.value(value: storage),
                ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
                ChangeNotifierProvider(
                    create: (_) => PinnedNotesProvider(storage)),
              ],
              child: child,
            ),
          ),
        );

    testWidgets(
        'a content-backed topic renders one Scrollable in the content area with no per-tab pager',
        (tester) async {
      final chapter = _tallContentChapter();
      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pump();

      expect(find.byType(TabBarView), findsNothing);
      expect(_contentScrollable(), findsOneWidget);
    });

    testWidgets(
        'scrolling down without tapping a tab eventually reaches the fourth sub-topic heading',
        (tester) async {
      final chapter = _tallContentChapter();
      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pump();

      await tester.scrollUntilVisible(
        _inContent(find.text('Sub Four')),
        300,
        scrollable: _contentScrollable(),
        maxScrolls: 200,
      );

      expect(_inContent(find.text('Sub Four')), findsOneWidget);
    });

    testWidgets('the source section title is rendered exactly once, not once per tab',
        (tester) async {
      final chapter = _tallContentChapter();
      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pump();

      expect(find.text('Section One'), findsOneWidget);
    });

    testWidgets(
        'scrolling the third sub-topic to the top of the content area moves the tab controller to index 2 with no tap',
        (tester) async {
      final chapter = _tallContentChapter();
      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pump();

      await _scrollHeadingToTop(
        tester,
        _contentScrollable(),
        _inContent(find.text('Sub Three')),
      );

      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    });

    testWidgets(
        'tapping the fourth tab settles with that sub-topic visible and the controller index at 3',
        (tester) async {
      final chapter = _tallContentChapter();
      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pump();

      await tester.tap(find.widgetWithText(Tab, 'Sub Four'));
      await tester.pumpAndSettle();

      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 3);
      expect(_inContent(find.text('Sub Four')), findsOneWidget);
      expect(
        _inContent(find.text(_longParagraph('Sub One', 0))),
        findsNothing,
      );
    });

    testWidgets(
        'rebuilding from a null chapter to a 4-subtopic chapter swaps the outline view for content and scrollspy keeps working',
        (tester) async {
      final chapter = _tallContentChapter();

      await tester.pumpWidget(
          wrap(const SubtopicTabsView(topic: _topic, chapter: null)));
      await tester.pump();

      expect(find.byType(TabBar), findsNothing);

      await tester
          .pumpWidget(wrap(SubtopicTabsView(topic: _topic, chapter: chapter)));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.tabs.map((t) => (t as Tab).text).toList(),
        ['Sub One', 'Sub Two', 'Sub Three', 'Sub Four'],
      );

      await tester.scrollUntilVisible(
        _inContent(find.text('Sub Four')),
        300,
        scrollable: _contentScrollable(),
        maxScrolls: 200,
      );

      expect(_inContent(find.text('Sub Four')), findsOneWidget);
    });
  });
}
