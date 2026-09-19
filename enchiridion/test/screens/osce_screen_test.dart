import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/screens/osce_screen.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Look up expected stations/labels by id and outline rather than hardcoding
// title literals, so siblings 260918-dr1/260918-dr6 (which rename topic
// titles) cannot break these tests.
ResourceTopic _topic(String id) => kOsceTopics.firstWhere((t) => t.id == id);

/// Shaped like the real `abdominal_examination.json`: a single section
/// whose subsections alternate ALL-CAPS headings and sentence-case
/// continuations, so grouping (not raw one-tab-per-subsection) is what
/// should reach the screen.
Chapter _syntheticAbdominalChapter() => const Chapter(
      id: 'abdominal-chapter',
      title: 'Abdominal Examination',
      order: 1,
      sections: [
        ChapterSection(
          id: 'section-1',
          title: 'Section',
          order: 1,
          subsections: [
            ChapterSubsection(
              id: 'sub-inspection',
              title: 'A. INSPECTION',
              contentGroups: [],
            ),
            ChapterSubsection(
              id: 'sub-palpation',
              title: 'B. PALPATION',
              contentGroups: [],
            ),
            ChapterSubsection(
              id: 'sub-light-palpation',
              title: 'Light palpation',
              contentGroups: [],
            ),
            ChapterSubsection(
              id: 'sub-deep-palpation',
              title: 'Deep palpation',
              contentGroups: [],
            ),
            ChapterSubsection(
              id: 'sub-percussion',
              title: 'C. PERCUSSION',
              contentGroups: [],
            ),
          ],
        ),
      ],
    );

Widget _wrapWithProviders(Widget child) {
  return FutureBuilder<StorageService>(
    future: SharedPreferences.getInstance().then(StorageService.new),
    builder: (context, snapshot) {
      final storage = snapshot.data;
      if (storage == null) return const SizedBox.shrink();
      return MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
          ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
        ],
        child: child,
      );
    },
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });


  testWidgets(
      'OSCE list has no TabBar; opening a content-less station shows its own outline as tabs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    expect(find.byType(TabBar), findsNothing);

    final cardiovascular = _topic('cardiovascular-system');
    final respiratory = _topic('respiratory-system');

    await tester.tap(find.text(cardiovascular.title));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labels = tabBar.tabs.map((t) => (t as Tab).text).toList();

    expect(labels, cardiovascular.outline);
    expect(tabBar.controller!.index, 0);
    expect(labels, isNot(contains(respiratory.title)));

    // The opened station's own title is the AppBar title, not a tab label.
    expect(find.widgetWithText(AppBar, cardiovascular.title), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text(cardiovascular.title), findsOneWidget);
  });

  testWidgets(
      'flinging the content area sideways advances the tab controller by one, and flinging back returns it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final cardiovascular = _topic('cardiovascular-system');
    await tester.tap(find.text(cardiovascular.title));
    await tester.pumpAndSettle();

    final content = find.byType(CustomScrollView);

    await tester.fling(content, const Offset(-500, 0), 1000);
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);

    await tester.fling(content, const Offset(500, 0), 1000);
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
  });

  testWidgets(
      'opening a content-less station (Cardiovascular System) scrolls continuously through its outline with no tab tap',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final cardiovascular = _topic('cardiovascular-system');
    await tester.tap(find.text(cardiovascular.title));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final lastEntry = cardiovascular.outline!.last;

    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text(lastEntry),
      ),
      300,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 200,
    );

    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.text(lastEntry),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'coming-soon stations show a badge and available stations do not',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final abdominal = _topic('abdominal-examination');
    final cardiovascular = _topic('cardiovascular-system');

    final abdominalTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text(abdominal.title),
        matching: find.byType(ListTile),
      ),
    );
    final cardiovascularTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text(cardiovascular.title),
        matching: find.byType(ListTile),
      ),
    );

    expect(abdominalTile.trailing, isNot(isA<ComingSoonBadge>()));
    expect(cardiovascularTile.trailing, isA<ComingSoonBadge>());
  });

  testWidgets(
      'tapping a grayed coming-soon station still opens the tabbed detail view',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final cardiovascular = _topic('cardiovascular-system');
    await tester.tap(find.text(cardiovascular.title));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 0);
  });

  testWidgets(
      'opening a content-backed station (Abdominal Examination) groups sub-topics by heading, never one tab per raw subsection',
      (tester) async {
    final abdominal = _topic('abdominal-examination');
    final chapter = _syntheticAbdominalChapter();

    await tester.pumpWidget(_wrapWithProviders(MaterialApp(
      home: OsceScreen(testChapterLoader: (_) async => chapter),
    )));
    await tester.pump();

    await tester.tap(find.text(abdominal.title));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, abdominal.title), findsOneWidget);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labels = tabBar.tabs.map((t) => (t as Tab).text).toList();

    // Grouped by heading: A. INSPECTION, B. PALPATION (absorbing its two
    // continuations), C. PERCUSSION -- three tabs, not five.
    expect(labels, ['A. INSPECTION', 'B. PALPATION', 'C. PERCUSSION']);
    expect(labels, isNot(contains('Light palpation')));
    expect(labels, isNot(contains('Deep palpation')));
  });
}
