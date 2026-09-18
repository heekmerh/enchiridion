import 'package:enchiridion/widgets/common/coming_soon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('kComingSoonLabel', () {
    test('is the canonical title-case label', () {
      expect(kComingSoonLabel, 'Coming Soon');
    });
  });

  group('ComingSoonBadge', () {
    testWidgets('renders the exact label text', (tester) async {
      await tester.pumpWidget(wrap(const ComingSoonBadge()));
      expect(find.text('Coming Soon'), findsOneWidget);
    });

    testWidgets('is never an AnimatedContainer anywhere in its subtree',
        (tester) async {
      await tester.pumpWidget(wrap(const ComingSoonBadge()));
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('compact mode drops the icon', (tester) async {
      await tester.pumpWidget(wrap(const ComingSoonBadge()));
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      await tester.pumpWidget(wrap(const ComingSoonBadge(compact: true)));
      expect(find.byIcon(Icons.schedule), findsNothing);
      expect(find.text('Coming Soon'), findsOneWidget);
    });
  });

  group('ComingSoonDim', () {
    testWidgets('dimmed: false returns child untouched, no wrapper widgets',
        (tester) async {
      await tester.pumpWidget(wrap(const ComingSoonDim(
        dimmed: false,
        child: Text('hello'),
      )));

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('dimmed: true wraps child in ColorFiltered and Opacity',
        (tester) async {
      await tester.pumpWidget(wrap(const ComingSoonDim(
        dimmed: true,
        child: Text('hello'),
      )));

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.byType(Opacity), findsOneWidget);
    });
  });

  group('ComingSoonStyle', () {
    testWidgets(
        'title/body/icon return progressively fainter onSurface colors at the exact alphas',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(wrap(Builder(builder: (context) {
        cs = Theme.of(context).colorScheme;
        return const SizedBox.shrink();
      })));

      expect(ComingSoonStyle.title(cs), cs.onSurface.withValues(alpha: 0.5));
      expect(ComingSoonStyle.body(cs), cs.onSurface.withValues(alpha: 0.35));
      expect(ComingSoonStyle.icon(cs), cs.onSurface.withValues(alpha: 0.4));

      // Body is the faintest of the three (alpha ordering).
      expect(ComingSoonStyle.bodyAlpha < ComingSoonStyle.iconAlpha, isTrue);
      expect(ComingSoonStyle.bodyAlpha < ComingSoonStyle.titleAlpha, isTrue);
    });
  });
}
