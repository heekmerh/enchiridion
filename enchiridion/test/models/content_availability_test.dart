import 'package:enchiridion/models/book_catalog.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/utils/content_availability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  final String name;
  final bool available;
  const _Item(this.name, this.available);

  @override
  String toString() => name;
}

void main() {
  group('availableFirst', () {
    test('partitions available items ahead of pending items, stably', () {
      const a = _Item('a', false);
      const b = _Item('b', true);
      const c = _Item('c', false);
      const d = _Item('d', true);

      final result = availableFirst([a, b, c, d], (i) => i.available);

      expect(result, [b, d, a, c]);
    });

    test('is idempotent on an already-ordered list', () {
      const b = _Item('b', true);
      const d = _Item('d', true);
      const a = _Item('a', false);
      const c = _Item('c', false);
      final ordered = [b, d, a, c];

      final result = availableFirst(ordered, (i) => i.available);

      expect(result, ordered);
    });

    test('returns an empty list for empty input', () {
      final result = availableFirst<_Item>([], (i) => i.available);
      expect(result, isEmpty);
    });

    test('returns input order unchanged when all items are available', () {
      const a = _Item('a', true);
      const b = _Item('b', true);
      final result = availableFirst([a, b], (i) => i.available);
      expect(result, [a, b]);
    });

    test('returns input order unchanged when all items are pending', () {
      const a = _Item('a', false);
      const b = _Item('b', false);
      final result = availableFirst([a, b], (i) => i.available);
      expect(result, [a, b]);
    });
  });

  group('booksInDisplayOrder', () {
    test('with no history, readable books rank ahead of every placeholder',
        () {
      final result = booksInDisplayOrder(const {});

      final lastReadableIndex =
          result.lastIndexWhere((b) => b.hasContent);
      final firstPlaceholderIndex =
          result.indexWhere((b) => !b.hasContent);

      expect(lastReadableIndex, lessThan(firstPlaceholderIndex));
    });

    test(
        'with history on a readable book, that book ranks first and readable '
        'books still rank above placeholders', () {
      final readableBook = kBooks.firstWhere((b) => b.hasContent);
      final history = {readableBook.id: DateTime.now()};

      final result = booksInDisplayOrder(history);

      expect(result.first.id, readableBook.id);

      final lastReadableIndex =
          result.lastIndexWhere((b) => b.hasContent);
      final firstPlaceholderIndex =
          result.indexWhere((b) => !b.hasContent);
      expect(lastReadableIndex, lessThan(firstPlaceholderIndex));
    });

    test('placeholder books keep their authored relative order', () {
      final result = booksInDisplayOrder(const {});

      final authoredPlaceholderIds =
          kBooks.where((b) => !b.hasContent).map((b) => b.id).toList();
      final resultPlaceholderIds =
          result.where((b) => !b.hasContent).map((b) => b.id).toList();

      expect(resultPlaceholderIds, authoredPlaceholderIds);
    });
  });

  group('isComingSoon', () {
    test('ResourceTopic.isComingSoon is true for cardiovascular-system and '
        'false for abdominal-examination', () {
      final cardiovascular =
          kOsceTopics.firstWhere((t) => t.id == 'cardiovascular-system');
      final abdominal =
          kOsceTopics.firstWhere((t) => t.id == 'abdominal-examination');

      expect(cardiovascular.isComingSoon, isTrue);
      expect(abdominal.isComingSoon, isFalse);
    });

    test('CatalogBook.isComingSoon is false for paediatrics and true for '
        'surgery', () {
      final paediatrics = kBooks.firstWhere((b) => b.id == 'paediatrics');
      final surgery = kBooks.firstWhere((b) => b.id == 'surgery');

      expect(paediatrics.isComingSoon, isFalse);
      expect(surgery.isComingSoon, isTrue);
    });
  });

  group('ResourceTopicListScreen', () {
    testWidgets(
        'orders its own input so a topic with content renders as the first '
        'tile even when given first without content', (tester) async {
      const placeholder = ResourceTopic(
        id: 'placeholder',
        title: 'Placeholder Topic',
        categoryTitle: 'Test',
        heroAssetPath: 'assets/resources/osce.jpeg',
      );
      const withContent = ResourceTopic(
        id: 'with-content',
        title: 'Real Topic',
        categoryTitle: 'Test',
        heroAssetPath: 'assets/resources/osce.jpeg',
        dataAssetPath: 'assets/data/resources/real_topic.json',
      );

      await tester.pumpWidget(const MaterialApp(
        home: ResourceTopicListScreen(
          title: 'Test List',
          topics: [placeholder, withContent],
        ),
      ));

      final titleFinder = find.text('Real Topic');
      final placeholderFinder = find.text('Placeholder Topic');
      expect(titleFinder, findsOneWidget);
      expect(placeholderFinder, findsOneWidget);

      final titleY = tester.getTopLeft(titleFinder).dy;
      final placeholderY = tester.getTopLeft(placeholderFinder).dy;
      expect(titleY, lessThan(placeholderY));
    });
  });
}
