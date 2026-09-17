import 'package:enchiridion/screens/osce_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OSCE opens as a list, then shows tabs at the selected station',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Cardiovascular System'), findsOneWidget);
    expect(find.text('Respiratory System'), findsOneWidget);

    await tester.tap(find.text('Respiratory System'));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.controller!.index, 1);
    expect(find.textContaining('Respiratory rate'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Respiratory System'), findsOneWidget);
  });
}
