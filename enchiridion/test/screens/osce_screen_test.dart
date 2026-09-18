import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/screens/osce_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OSCE opens as a list, then shows tabs at the selected station',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    expect(find.byType(TabBar), findsNothing);

    // Available-first ordering: the only station with real content leads
    // the list.
    final firstTileFinder = find.byType(ListTile).first;
    final firstTile = tester.widget<ListTile>(firstTileFinder);
    final firstTitle = (firstTile.title! as Text).data;
    expect(firstTitle, 'Abdominal Examination');

    expect(find.text('Cardiovascular System'), findsOneWidget);
    expect(find.text('Respiratory System'), findsOneWidget);

    await tester.tap(find.text('Respiratory System'));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final tabs = tester.widget<TabBar>(find.byType(TabBar));

    // Resolve the expected tab index from the same ordered list the screen
    // reads, rather than a hardcoded literal, so a later content addition
    // does not break this test.
    final expectedIndex = kOsceTopicsInDisplayOrder
        .indexWhere((t) => t.title == 'Respiratory System');
    expect(tabs.controller!.index, expectedIndex);
    expect(find.textContaining('Respiratory rate'), findsWidgets);

    // The first tab in the detail TabBar is Abdominal Examination.
    expect((tabs.tabs.first as Tab).text, 'Abdominal Examination');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Respiratory System'), findsOneWidget);
  });
}
