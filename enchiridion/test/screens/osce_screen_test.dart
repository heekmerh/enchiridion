import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/osce_screen.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Look up expected stations/labels by id and outline rather than hardcoding
// title literals, so siblings 260918-dr1/260918-dr6 (which rename topic
// titles) cannot break these tests.
ResourceTopic _topic(String id) => kOsceTopics.firstWhere((t) => t.id == id);

void main() {
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
      'dragging the content area sideways advances the tab controller by one, and dragging back returns it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final cardiovascular = _topic('cardiovascular-system');
    await tester.tap(find.text(cardiovascular.title));
    await tester.pumpAndSettle();

    final tabBarView = find.byType(TabBarView);

    await tester.drag(tabBarView, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);

    await tester.drag(tabBarView, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
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
}
