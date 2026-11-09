import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
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

/// Scrolls [finder] into view before tapping it — several Task 3 forms
/// (chads-vasc, has-bled, burn-tbsa) have enough switches that the
/// Calculate button and later switches sit below the test viewport.
Future<void> _scrollTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
    testWidgets(
        'Clinical Notes is present when calculator has enhancement fields (gcs)',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'gcs');
      expect(find.text('Clinical Notes'), findsOneWidget);
    });

    testWidgets(
        'Clinical Notes is present when calculator has enhancement fields (weight-dosing)',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'weight-dosing');
      expect(find.text('Clinical Notes'), findsOneWidget);
    });
  });

  group('BMI unit auto-conversion', () {
    testWidgets('weight auto-converts from kg to lb when unit changes',
        (tester) async {
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

    testWidgets('height auto-converts from cm to m when unit changes',
        (tester) async {
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

  group('Task 2 worked examples', () {
    testWidgets('map: systolic 120, diastolic 80 renders 93 mmHg',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'map');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '120');
      await tester.enterText(fields.at(1), '80');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('93'), findsWidgets);
    });

    testWidgets(
        'qtc: QT 400 at HR 60 renders 400 ms by Bazett (normal, not flagged)',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'qtc');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '400');
      await tester.enterText(fields.at(1), '60');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('400 ms'), findsWidgets);
    });

    testWidgets(
        'qtc: QT 400 at HR 100 renders 516 ms by Bazett and flags prolongation',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'qtc');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '400');
      await tester.enterText(fields.at(1), '100');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('516 ms'), findsWidgets);
      expect(find.textContaining('prolonged'), findsWidgets);
    });

    testWidgets(
        'corrected-calcium: measured 2.10 mmol/L with albumin 30 g/L renders 2.30 mmol/L',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'corrected-calcium');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '2.10');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2.30 mmol/L'), findsWidgets);
    });

    testWidgets(
        'ldl-friedewald: TC 200, HDL 50, TG 150 mg/dL renders 120 mg/dL',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'ldl-friedewald');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '200');
      await tester.enterText(fields.at(1), '50');
      await tester.enterText(fields.at(2), '150');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('120 mg/dL'), findsWidgets);
    });

    testWidgets(
        'ldl-friedewald: triglycerides above 400 mg/dL renders a validity warning',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'ldl-friedewald');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '200');
      await tester.enterText(fields.at(1), '50');
      await tester.enterText(fields.at(2), '450');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not valid'), findsWidgets);
    });

    testWidgets('waist-hip-ratio: waist 90 cm, hip 100 cm renders 0.90',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'waist-hip-ratio');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '90');
      await tester.enterText(fields.at(1), '100');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0.90'), findsWidgets);
    });

    testWidgets('ibw: male, height 177.8 cm renders 73 kg', (tester) async {
      await _pumpCalculatorScreen(tester, 'ibw');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '177.8');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('73.0 kg'), findsWidgets);
    });

    testWidgets(
        'cao2: haemoglobin 15 g/dL, SaO2 98%, PaO2 100 mmHg renders approximately 20 mL/dL',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'cao2');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '15');
      await tester.enterText(fields.at(1), '98');
      await tester.enterText(fields.at(2), '100');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('20.0 mL/dL'), findsWidgets);
    });
  });

  group('Task 3 worked examples', () {
    testWidgets(
        'chads-vasc: 76-year-old female with hypertension scores 4/9',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'chads-vasc');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '76');
      await _scrollTap(tester, find.text('Female sex'));
      await _scrollTap(tester, find.text('Hypertension'));
      await _scrollTap(tester, find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 / 9'), findsWidgets);
    });

    testWidgets(
        'has-bled: uncontrolled hypertension + age over 65 + labile INR scores 3, high risk',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'has-bled');
      await _scrollTap(tester, find.text('Uncontrolled hypertension'));
      await _scrollTap(tester, find.text('Age over 65'));
      await _scrollTap(tester, find.text('Labile INR'));
      await _scrollTap(tester, find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 / 9'), findsWidgets);
      expect(find.textContaining('High bleeding risk'), findsWidgets);
    });

    testWidgets(
        'burn-tbsa: adult head + one arm renders 18%; paediatric head + one leg renders 32%',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'burn-tbsa');
      await _scrollTap(tester, find.text('Head & neck'));
      await _scrollTap(tester, find.text('Left arm'));
      await _scrollTap(tester, find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('18%'), findsWidgets);

      // Switch to paediatric preset, swap the arm selection for a leg.
      await _scrollTap(tester, find.text('Adult'));
      await tester.tap(find.text('Paediatric').last);
      await tester.pumpAndSettle();
      await _scrollTap(tester, find.text('Left arm'));
      await _scrollTap(tester, find.text('Left leg'));
      await _scrollTap(tester, find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('32%'), findsWidgets);
    });

    testWidgets(
        'parkland: 70 kg with 20% TBSA renders 5600 mL total, 2800 mL in the first 8 hours',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'parkland');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '70');
      await tester.enterText(fields.at(1), '20');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5600 mL'), findsWidgets);
      expect(find.textContaining('2800 mL'), findsWidgets);
    });

    testWidgets(
        'gtpal: gravida 3, term 1, preterm 1, abortions 1, living 2 renders G3 T1 P1 A1 L2',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'gtpal');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '3');
      await tester.enterText(fields.at(1), '1');
      await tester.enterText(fields.at(2), '1');
      await tester.enterText(fields.at(3), '1');
      await tester.enterText(fields.at(4), '2');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('G3 T1 P1 A1 L2'), findsWidgets);
    });

    testWidgets(
        'gtpal: term + preterm + abortions exceeding gravida renders a consistency warning',
        (tester) async {
      await _pumpCalculatorScreen(tester, 'gtpal');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '1');
      await tester.enterText(fields.at(1), '1');
      await tester.enterText(fields.at(2), '1');
      await tester.enterText(fields.at(3), '1');
      await tester.enterText(fields.at(4), '1');
      await tester.tap(find.text('Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('exceeds gravida'), findsWidgets);
    });
  });
}
