import 'package:enchiridion/screens/calculator_list_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('heart updates the favorites section after returning to the list',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    AccessService.testAccessOverride = true;
    addTearDown(() => AccessService.testAccessOverride = null);

    await tester.pumpWidget(Provider<StorageService>.value(
      value: storage,
      child: const MaterialApp(home: CalculatorListScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Weight-Based Drug Dosing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('FAVORITES'), findsOneWidget);

    await tester.tap(find.text('Weight-Based Drug Dosing').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove from favorites'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('FAVORITES'), findsNothing);
  });
}
