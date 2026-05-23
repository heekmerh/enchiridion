import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/widgets/drawer/toc_drawer.dart';
import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/bookmark.dart';
import 'package:enchiridion/theme/app_colors.dart';

void main() {
  // Stub chapter with one section and one subsection.
  final stubSubsection = ChapterSubsection(
    id: 'sub1',
    title: 'Subsection One',
    contentGroups: [],
  );
  final stubSection = ChapterSection(
    id: 's1',
    title: 'Section One',
    order: 0,
    subsections: [stubSubsection],
  );
  final stubChapter = Chapter(
    id: 'ch1',
    title: 'Chapter One',
    order: 0,
    sections: [stubSection],
  );

  // Helper to build the widget wrapped in MaterialApp + Scaffold.
  Widget buildWidget({
    String? currentSectionId,
    void Function(String sectionId, String subsectionId)? onSectionSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TocDrawerContent(
            chapters: [stubChapter],
            currentChapterId: 'ch1',
            bookmarks: const <Bookmark>[],
            visitedChapterIds: const <String>{},
            onChapterSelected: (_) {},
            onSearchResults: (_) {},
            currentSectionId: currentSectionId,
            onSectionSelected: onSectionSelected ?? (_, __) {},
          ),
        ),
      ),
    );
  }

  // Test 1 (REQ-2.3a): TocDrawerContent renders an ExpansionTile for each chapter.
  testWidgets(
    'REQ-2.3a: TocDrawerContent renders an ExpansionTile for the chapter',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(ExpansionTile), findsWidgets,
          reason: 'Expected at least one ExpansionTile for the chapter');
    },
  );

  // Test 2 (REQ-2.3b): All ExpansionTile nodes are initially collapsed;
  // tapping the chapter header reveals its children.
  testWidgets(
    'REQ-2.3b: Subsection ListTile is not visible initially (collapsed); appears after expanding',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // The subsection title should NOT be visible initially.
      expect(find.text('Subsection One'), findsNothing,
          reason: 'Subsection should be hidden in collapsed ExpansionTile');

      // Tap the top-level ExpansionTile header (chapter title).
      await tester.tap(find.text('Chapter One'));
      await tester.pumpAndSettle();

      // After tapping, section should appear. Tap section to reveal subsection.
      await tester.tap(find.text('Section One'));
      await tester.pumpAndSettle();

      // Now the subsection title should be visible.
      expect(find.text('Subsection One'), findsOneWidget,
          reason: 'Subsection should appear after expanding chapter and section');
    },
  );

  // Test 3 (REQ-2.3c): Tapping a subsection ListTile calls onSectionSelected
  // with correct sectionId and subsectionId.
  testWidgets(
    'REQ-2.3c: Tapping subsection ListTile fires onSectionSelected with correct ids',
    (WidgetTester tester) async {
      String? capturedSectionId;
      String? capturedSubsectionId;

      await tester.pumpWidget(buildWidget(
        onSectionSelected: (sId, subId) {
          capturedSectionId = sId;
          capturedSubsectionId = subId;
        },
      ));
      await tester.pumpAndSettle();

      // Expand chapter then section to reveal subsection.
      await tester.tap(find.text('Chapter One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Section One'));
      await tester.pumpAndSettle();

      // Tap the subsection ListTile.
      await tester.tap(find.text('Subsection One'));
      await tester.pumpAndSettle();

      expect(capturedSectionId, equals('s1'),
          reason: 'onSectionSelected sectionId should be s1');
      expect(capturedSubsectionId, equals('sub1'),
          reason: 'onSectionSelected subsectionId should be sub1');
    },
  );

  // Test 4 (REQ-2.3d): The subsection whose id matches currentSectionId has
  // neonTeal text color (Color(0xFF00D2FF)).
  testWidgets(
    'REQ-2.3d: Active subsection (currentSectionId matches) has neonTeal text color',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget(currentSectionId: 'sub1'));
      await tester.pumpAndSettle();

      // Expand chapter then section to reveal subsection.
      await tester.tap(find.text('Chapter One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Section One'));
      await tester.pumpAndSettle();

      // Find the Text widget for the active subsection title.
      final textWidgets = tester.widgetList<Text>(
        find.text('Subsection One'),
      ).toList();

      expect(textWidgets, isNotEmpty,
          reason: 'Subsection One Text widget should exist when expanded');

      // At least one Text widget for the subsection should have neonTeal color.
      final hasNeonTeal = textWidgets.any((t) =>
          t.style?.color == AppColors.neonTeal);

      expect(hasNeonTeal, isTrue,
          reason:
              'Active subsection text should have neonTeal color (${AppColors.neonTeal})');
    },
  );
}
