// Repo-wide guard: fails the suite if any `CalculatorDefinition` marked
// `implemented: true` has no case branch wired into
// `CalculatorScreen._buildInputs` — i.e. a flag flipped without a form
// cannot merge. Pumps every implemented id and asserts the screen's
// unknown-calculator fallback text never renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:enchiridion/models/calculator_definition.dart';
import 'package:enchiridion/screens/calculator_screen.dart';
import 'package:enchiridion/services/storage_service.dart';

// Mirrors `CalculatorScreen._buildInputs`'s `default` branch fallback text
// exactly (`lib/screens/calculator_screen.dart`).
const String _kUnknownCalculatorFallback = 'Unknown calculator';

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

  testWidgets(
      'every implemented calculator id opens a working form (no unknown-calculator fallback)',
      (tester) async {
    final implementedIds =
        kCalculators.where((c) => c.implemented).map((c) => c.id).toList();
    final offenders = <String>[];

    for (final id in implementedIds) {
      await _pumpCalculatorScreen(tester, id);
      final fallbackFound =
          find.text(_kUnknownCalculatorFallback).evaluate().isNotEmpty;
      if (fallbackFound) {
        offenders.add(id);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: offenders.isEmpty
          ? null
          : 'Calculators marked implemented but with no working form: '
              '${offenders.join(', ')}',
    );
  });
}
