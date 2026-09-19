// Covers `availableFirstByGroup` (the group-aware sibling of `availableFirst`
// in `utils/content_availability.dart`) and the derived
// `kMedicalInstrumentationTopicsInDisplayOrder` list it produces, ensuring
// the Medical Instrumentation section opens with IV Cannula — its only
// entry with real written content — leading the screen.
//
// Local `ResourceTopic` fixtures back the helper-level assertions so they
// stay valid independent of catalog churn; only the two assertions that name
// the real catalog reach into `kMedicalInstrumentationTopics` /
// `kMedicalInstrumentationTopicsInDisplayOrder`.

import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/utils/content_availability.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _heroPath = 'assets/resources/osce.jpeg';

const _aFirstNoContent = ResourceTopic(
  id: 'a-first-no-content',
  title: 'A First No Content',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  group: 'A',
);

const _bWithContent = ResourceTopic(
  id: 'b-with-content',
  title: 'B With Content',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  dataAssetPath: 'assets/data/resources/b_with_content.json',
  group: 'B',
);

const _aSecondNoContent = ResourceTopic(
  id: 'a-second-no-content',
  title: 'A Second No Content',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  group: 'A',
);

const _pending1 = ResourceTopic(
  id: 'pending-1',
  title: 'Pending 1',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
);

const _available1 = ResourceTopic(
  id: 'available-1',
  title: 'Available 1',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  dataAssetPath: 'assets/data/resources/available_1.json',
);

const _xPending1 = ResourceTopic(
  id: 'x-pending-1',
  title: 'X Pending 1',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  group: 'X',
);

const _xAvailable = ResourceTopic(
  id: 'x-available',
  title: 'X Available',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  dataAssetPath: 'assets/data/resources/x_available.json',
  group: 'X',
);

const _xPending2 = ResourceTopic(
  id: 'x-pending-2',
  title: 'X Pending 2',
  categoryTitle: 'Test',
  heroAssetPath: _heroPath,
  group: 'X',
);

void main() {
  group('availableFirstByGroup', () {
    test(
        'groups A, B, A with only B available: B block leads, both A items '
        'stay adjacent and in their original relative order', () {
      final result = availableFirstByGroup(
        [_aFirstNoContent, _bWithContent, _aSecondNoContent],
        groupOf: (t) => t.group,
        isAvailable: (t) => t.hasContent,
      );

      expect(result, [_bWithContent, _aFirstNoContent, _aSecondNoContent]);
    });

    test(
        'a null group key for every item matches plain availableFirst for '
        'the same input', () {
      final items = [_pending1, _available1];

      final grouped = availableFirstByGroup(
        items,
        groupOf: (t) => t.group,
        isAvailable: (t) => t.hasContent,
      );
      final flat = availableFirst(items, (t) => t.hasContent);

      expect(grouped, flat);
    });

    test(
        'within a single group, an available item at position 2 leads the '
        'block and the two pending items keep their relative order', () {
      final result = availableFirstByGroup(
        [_xPending1, _xAvailable, _xPending2],
        groupOf: (t) => t.group,
        isAvailable: (t) => t.hasContent,
      );

      expect(result, [_xAvailable, _xPending1, _xPending2]);
    });

    test('is idempotent on an already-ordered input', () {
      final ordered = [_bWithContent, _aFirstNoContent, _aSecondNoContent];

      final result = availableFirstByGroup(
        ordered,
        groupOf: (t) => t.group,
        isAvailable: (t) => t.hasContent,
      );

      expect(result, ordered);
    });
  });

  group('kMedicalInstrumentationTopicsInDisplayOrder', () {
    test('leads with iv-cannula', () {
      expect(kMedicalInstrumentationTopicsInDisplayOrder.first.id,
          'iv-cannula');
    });

    test(
        'is a strict permutation of the authored list: same length, same id '
        'multiset, no duplicates, nothing dropped', () {
      final authoredIds =
          kMedicalInstrumentationTopics.map((t) => t.id).toList();
      final displayIds =
          kMedicalInstrumentationTopicsInDisplayOrder.map((t) => t.id).toList();

      expect(displayIds.length, authoredIds.length);
      expect(displayIds.toSet(), authoredIds.toSet());
      expect(displayIds.toSet().length, displayIds.length,
          reason: 'display-order list must not contain duplicate ids');
    });

    test(
        'every group occupies one contiguous run — no group key appears, '
        'disappears, then reappears', () {
      final collapsedGroupSequence = <String?>[];
      for (final topic in kMedicalInstrumentationTopicsInDisplayOrder) {
        if (collapsedGroupSequence.isEmpty ||
            collapsedGroupSequence.last != topic.group) {
          collapsedGroupSequence.add(topic.group);
        }
      }

      expect(
        collapsedGroupSequence.toSet().length,
        collapsedGroupSequence.length,
        reason: 'a group key repeated non-adjacently: $collapsedGroupSequence',
      );
    });

    test(
        'the set of group keys is unchanged from the authored list, and '
        'groups other than iv-cannula\'s keep their authored first-'
        'appearance relative order', () {
      final authoredGroups =
          kMedicalInstrumentationTopics.map((t) => t.group).toSet();
      final displayGroups =
          kMedicalInstrumentationTopicsInDisplayOrder.map((t) => t.group).toSet();
      expect(displayGroups, authoredGroups);

      final ivCannulaGroup = kMedicalInstrumentationTopics
          .firstWhere((t) => t.id == 'iv-cannula')
          .group;

      final authoredOtherGroupOrder = <String?>[];
      for (final topic in kMedicalInstrumentationTopics) {
        if (topic.group != ivCannulaGroup &&
            !authoredOtherGroupOrder.contains(topic.group)) {
          authoredOtherGroupOrder.add(topic.group);
        }
      }

      final displayOtherGroupOrder = <String?>[];
      for (final topic in kMedicalInstrumentationTopicsInDisplayOrder) {
        if (topic.group != ivCannulaGroup &&
            !displayOtherGroupOrder.contains(topic.group)) {
          displayOtherGroupOrder.add(topic.group);
        }
      }

      expect(displayOtherGroupOrder, authoredOtherGroupOrder);
    });

    test(
        'the first group block in display order is iv-cannula\'s group, and '
        'iv-cannula is that block\'s first member', () {
      final firstGroup = kMedicalInstrumentationTopicsInDisplayOrder.first.group;
      final ivCannulaGroup = kMedicalInstrumentationTopics
          .firstWhere((t) => t.id == 'iv-cannula')
          .group;

      expect(firstGroup, ivCannulaGroup);
      expect(kMedicalInstrumentationTopicsInDisplayOrder.first.id,
          'iv-cannula');
    });

    test(
        'iv-cannula\'s content survives the reorder unchanged, and it is '
        'still the catalog\'s only entry with hasContent true', () {
      final authoredIvCannula =
          kMedicalInstrumentationTopics.firstWhere((t) => t.id == 'iv-cannula');
      final displayIvCannula = kMedicalInstrumentationTopicsInDisplayOrder
          .firstWhere((t) => t.id == 'iv-cannula');

      expect(displayIvCannula.dataAssetPath, authoredIvCannula.dataAssetPath);
      expect(displayIvCannula.description, authoredIvCannula.description);
      expect(authoredIvCannula.hasContent, isTrue);

      final withContentCount = kMedicalInstrumentationTopicsInDisplayOrder
          .where((t) => t.hasContent)
          .length;
      expect(withContentCount, 1);
    });

    testWidgets(
        'IV Cannula renders strictly above every other Medical '
        'Instrumentation topic tile in the first viewport', (tester) async {
      // Enlarge the viewport so enough dense rows lay out without scrolling
      // for the position comparison below to be meaningful — this changes
      // only how much of the list is built, not the order under test.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: ResourceTopicListScreen(
          title: 'Medical Instrumentation',
          topics: kMedicalInstrumentationTopicsInDisplayOrder,
          dense: true,
        ),
      ));
      await tester.pump();

      final ivCannulaY = tester.getTopLeft(find.text('IV Cannula')).dy;

      final nextTopic = kMedicalInstrumentationTopicsInDisplayOrder
          .firstWhere((t) => t.id != 'iv-cannula');
      final nextTopicFinder = find.text(nextTopic.title);
      expect(
        nextTopicFinder,
        findsOneWidget,
        reason:
            'The next topic in display order must be visible in the first '
            'viewport for this comparison to be meaningful.',
      );
      final nextTopicY = tester.getTopLeft(nextTopicFinder).dy;

      expect(ivCannulaY, lessThan(nextTopicY));
    });
  });
}
