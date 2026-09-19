import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_detail_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _subject() => const MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Test List',
        topics: [_available, _pending],
      ),
    );

void main() {
  testWidgets(
      'available card renders no ComingSoonBadge and no ColorFiltered',
      (tester) async {
    await tester.pumpWidget(_subject());

    final availableCardFinder = find.ancestor(
      of: find.text('Available Topic'),
      matching: find.byType(Ink),
    );
    expect(
      find.descendant(
          of: availableCardFinder, matching: find.byType(ComingSoonBadge)),
      findsNothing,
    );
    expect(
      find.descendant(
          of: availableCardFinder, matching: find.byType(ColorFiltered)),
      findsNothing,
    );
  });

  testWidgets(
      'unavailable card renders both a ComingSoonBadge and a ColorFiltered',
      (tester) async {
    await tester.pumpWidget(_subject());
    await tester.scrollUntilVisible(find.text('Pending Topic'), 300);
    await tester.pumpAndSettle();

    final pendingCardFinder = find.ancestor(
      of: find.text('Pending Topic'),
      matching: find.byType(Ink),
    );
    expect(
      find.descendant(
          of: pendingCardFinder, matching: find.byType(ComingSoonBadge)),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: pendingCardFinder, matching: find.byType(ColorFiltered)),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping the unavailable card does not push the detail screen, shows a SnackBar',
      (tester) async {
    await tester.pumpWidget(_subject());
    await tester.scrollUntilVisible(find.text('Pending Topic'), 300);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pending Topic'));
    await tester.pump();

    expect(find.byType(ResourceTopicDetailScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Coming Soon'), findsWidgets);
  });

  testWidgets('tapping the available card pushes the detail screen',
      (tester) async {
    await tester.pumpWidget(_subject());

    await tester.tap(find.text('Available Topic'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceTopicDetailScreen), findsOneWidget);
  });

  Widget _denseSubject() => const MaterialApp(
        home: ResourceTopicListScreen(
          title: 'Test List',
          topics: [_available, _pending],
          dense: true,
        ),
      );

  testWidgets(
      'dense available row renders a chevron and no ComingSoonBadge',
      (tester) async {
    await tester.pumpWidget(_denseSubject());

    final availableTileFinder = find.ancestor(
      of: find.text('Available Topic'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
          of: availableTileFinder, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: availableTileFinder, matching: find.byType(ComingSoonBadge)),
      findsNothing,
    );
  });

  testWidgets(
      'dense coming-soon row renders a ComingSoonBadge, taps show a SnackBar and push nothing',
      (tester) async {
    await tester.pumpWidget(_denseSubject());

    final pendingTileFinder = find.ancestor(
      of: find.text('Pending Topic'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(
          of: pendingTileFinder, matching: find.byType(ComingSoonBadge)),
      findsOneWidget,
    );

    await tester.tap(find.text('Pending Topic'));
    await tester.pump();

    expect(find.byType(ResourceTopicDetailScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
