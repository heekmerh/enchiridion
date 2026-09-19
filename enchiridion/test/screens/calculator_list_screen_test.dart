import 'package:enchiridion/models/calculator_definition.dart';
import 'package:enchiridion/screens/calculator_list_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpList(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService(await SharedPreferences.getInstance());
  await tester.pumpWidget(Provider<StorageService>.value(
    value: storage,
    child: const MaterialApp(home: CalculatorListScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('CalculatorListScreen — full access', () {
    setUp(() {
      AccessService.testAccessOverride = true;
    });
    tearDown(() {
      AccessService.testAccessOverride = null;
    });

    testWidgets('renders all 9 category headers', (tester) async {
      await _pumpList(tester);
      final listFinder = find.byType(ListView);

      for (final category in [
        'DRUG DOSING',
        'EMERGENCY & CRITICAL CARE',
        'GENERAL',
        'OBS & GYNAE',
        'PAEDIATRICS',
        'CARDIOLOGY',
        'RESPIRATORY',
        'SURGERY & TRAUMA',
        'UTILITY',
      ]) {
        // Scroll to reach trailing categories rather than assuming they
        // are on screen — the list has 58 entries across 9 categories.
        await tester.dragUntilVisible(
          find.text(category),
          listFinder,
          const Offset(0, -300),
        );
        expect(find.text(category), findsOneWidget,
            reason: 'expected category header "$category" to render');
      }
    });

    testWidgets('a coming-soon row shows exactly one ComingSoonBadge and no lock',
        (tester) async {
      await _pumpList(tester);

      // Cardiology is entirely coming-soon at this point in the catalog and
      // is one of the trailing categories — scroll until its header shows.
      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('CARDIOLOGY'),
        listFinder,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      // The first Cardiology entry ("Mean Arterial Pressure (MAP)") is
      // coming-soon at this point (Task 1) — flipped to implemented later.
      expect(find.text('Mean Arterial Pressure (MAP)'), findsOneWidget);
      final tile = find.ancestor(
        of: find.text('Mean Arterial Pressure (MAP)'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: tile, matching: find.byType(ComingSoonBadge)),
        findsOneWidget,
      );
      // No lock icon anywhere in a fully-unlocked, all-coming-soon category.
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
    });

    testWidgets('tapping a coming-soon row shows a SnackBar and does not navigate',
        (tester) async {
      await _pumpList(tester);
      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('CARDIOLOGY'),
        listFinder,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mean Arterial Pressure (MAP)'));
      await tester.pump();

      expect(find.text('Mean Arterial Pressure (MAP) — $kComingSoonLabel'),
          findsOneWidget);
      // Still on the list screen — no CalculatorScreen pushed.
      expect(find.byType(CalculatorListScreen), findsOneWidget);
    });

    testWidgets('tapping an implemented row still opens CalculatorScreen',
        (tester) async {
      await _pumpList(tester);
      await tester.tap(find.text('Weight-Based Drug Dosing'));
      await tester.pumpAndSettle();
      expect(find.text('Calculate'), findsWidgets);
    });
  });

  group('CalculatorListScreen — access denied', () {
    setUp(() {
      AccessService.testAccessOverride = false;
    });
    tearDown(() {
      AccessService.testAccessOverride = null;
    });

    testWidgets('no coming-soon row renders a lock icon in Cardiology',
        (tester) async {
      await _pumpList(tester);
      final listFinder = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('CARDIOLOGY'),
        listFinder,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      final cardiologyIds = kCalculators
          .where((c) => c.category == 'Cardiology')
          .map((c) => c.title)
          .toList();
      // Every Cardiology entry is coming-soon at this point — zero locked
      // rows should render for the whole category.
      for (final title in cardiologyIds) {
        final tile = find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(of: tile, matching: find.byIcon(Icons.lock_outline)),
          findsNothing,
          reason: '$title is coming-soon and must never render a lock icon',
        );
      }
    });

    testWidgets('the free (unlocked) entry in each category is an implemented calculator',
        (tester) async {
      await _pumpList(tester);
      // Drug Dosing's free slot (first implemented entry) must be unlocked.
      expect(find.text('Weight-Based Drug Dosing'), findsOneWidget);
      final freeTile = find.ancestor(
        of: find.text('Weight-Based Drug Dosing'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(
            of: freeTile, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
    });
  });
}
