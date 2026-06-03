import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:enchiridion/models/calculator_definition.dart';
import 'package:enchiridion/screens/calculator_screen.dart';
import 'package:enchiridion/services/storage_service.dart';

Future<void> _pumpCalculatorScreen(
  WidgetTester tester,
  String calculatorId,
) async {
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [Provider<StorageService>.value(value: storage)],
      child: MaterialApp(
        home: CalculatorScreen(calculatorId: calculatorId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('_ClinicalNotesSection', () {
    testWidgets('Clinical Notes is present when calculator has enhancement fields (gcs)', (tester) async {
      await _pumpCalculatorScreen(tester, 'gcs');
      expect(find.text('Clinical Notes'), findsOneWidget);
    });

    testWidgets('Clinical Notes is present when calculator has enhancement fields (weight-dosing)', (tester) async {
      await _pumpCalculatorScreen(tester, 'weight-dosing');
      expect(find.text('Clinical Notes'), findsOneWidget);
    });
  });

  group('BMI unit auto-conversion', () {
    testWidgets('weight auto-converts from kg to lb when unit changes', (tester) async {
      await _pumpCalculatorScreen(tester, 'bmi');

      // Enter 70 in the weight field (first numeric field)
      final weightFields = find.byType(TextFormField);
      await tester.enterText(weightFields.first, '70');
      await tester.pumpAndSettle();

      // Tap the kg dropdown to change to lb
      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();

      // Select lb from the dropdown menu
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();

      // Weight field should now show the converted value
      final weightField = tester.widget<TextFormField>(weightFields.first);
      expect(weightField.controller?.text, '154.32');
    });

    testWidgets('height auto-converts from cm to m when unit changes', (tester) async {
      await _pumpCalculatorScreen(tester, 'bmi');

      // Enter 170 in the height field (second numeric field)
      final heightFields = find.byType(TextFormField);
      await tester.enterText(heightFields.at(1), '170');
      await tester.pumpAndSettle();

      // Tap the cm dropdown to change to m
      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();

      // Select m from the dropdown menu
      await tester.tap(find.text('m').last);
      await tester.pumpAndSettle();

      // Height field should now show the converted value
      final heightField = tester.widget<TextFormField>(heightFields.at(1));
      expect(heightField.controller?.text, '1.70');
    });
  });
}
