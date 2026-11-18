import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_detail_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/screens/unlock_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ResourceTopic _topic(String id, {bool content = true}) => ResourceTopic(
      id: id,
      title: id,
      categoryTitle: 'Test',
      heroAssetPath: 'assets/resources/osce.jpeg',
      dataAssetPath: content ? 'assets/data/resources/$id.json' : null,
    );

final _first = _topic('First topic');
final _second = _topic('Second topic');
final _third = _topic('Third topic');
final _pending = _topic('Pending topic', content: false);

Widget _subject({bool dense = true}) => MaterialApp(
      home: ResourceTopicListScreen(
        title: 'Test List',
        // The coming-soon topic is given first: it must not use up the free
        // slot.
        topics: [_pending, _first, _second, _third],
        dense: dense,
      ),
    );

Finder _lockIn(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
      matching: find.byIcon(Icons.lock_outline),
    );

void main() {
  tearDown(() => AccessService.testAccessOverride = null);

  group('free account', () {
    setUp(() => AccessService.testAccessOverride = false);

    testWidgets('only the first topic with content is open', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(_lockIn('First topic'), findsNothing);
      expect(_lockIn('Second topic'), findsWidgets);
      expect(_lockIn('Third topic'), findsWidgets);
    });

    testWidgets('a coming-soon topic is never locked', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(_lockIn('Pending topic'), findsNothing);
      expect(
        find.descendant(
          of: find.ancestor(
              of: find.text('Pending topic'), matching: find.byType(ListTile)),
          matching: find.byType(ComingSoonBadge),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the free topic opens', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('First topic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResourceTopicDetailScreen), findsOneWidget);
    });

    testWidgets('a locked topic opens the unlock screen, not the topic',
        (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Second topic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResourceTopicDetailScreen), findsNothing);
      expect(find.byType(UnlockScreen), findsOneWidget);
    });

    testWidgets('card layout locks the same topics', (tester) async {
      await tester.pumpWidget(_subject(dense: false));
      await tester.pumpAndSettle();

      Finder cardLock(String title) => find.descendant(
            of: find.ancestor(of: find.text(title), matching: find.byType(Ink)),
            matching: find.byIcon(Icons.lock_outline),
          );
      expect(cardLock('First topic'), findsNothing);
      expect(cardLock('Second topic'), findsOneWidget);
    });
  });

  group('premium account', () {
    setUp(() => AccessService.testAccessOverride = true);

    testWidgets('no topic is locked', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('any topic opens', (tester) async {
      await tester.pumpWidget(_subject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Third topic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResourceTopicDetailScreen), findsOneWidget);
    });
  });

  group('real Resources cards', () {
    const cards = <String, List<ResourceTopic>>{
      'Medical examination OSCE': kOsceTopics,
      'O&G OSCE': kObstetricsOsceTopics,
      'Instrumentation in medicine & pediatrics': kMedicalInstrumentationTopics,
      'Pediatrics OSCE': kPediatricsOsceTopics,
      'Surgical instrumentation': kSurgicalInstrumentationTopics,
      'Quick revision': kQuickRevisionTopics,
    };

    for (final card in cards.entries) {
      test('${card.key} gives a free account exactly one topic', () {
        final displayOrder = [
          for (final group in groupTopicsForDisplay(card.value).values)
            ...group,
        ];
        final free = freeTopicIds(displayOrder);
        expect(free, hasLength(1));
        final freeTopic = displayOrder.firstWhere((t) => free.contains(t.id));
        expect(freeTopic.hasContent, isTrue);
      });
    }
  });
}
