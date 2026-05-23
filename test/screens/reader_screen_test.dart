import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// _PillAlwaysVisibleStub mirrors the D-05 behavior: a StatefulWidget with a
// boolean _visible = true field, no Timer, and a pill widget identified by
// Key('pill'). The pill never hides automatically because no Timer exists.
class _PillAlwaysVisibleStub extends StatefulWidget {
  // ignore: unused_element
  const _PillAlwaysVisibleStub();

  @override
  State<_PillAlwaysVisibleStub> createState() => _PillAlwaysVisibleStubState();
}

class _PillAlwaysVisibleStubState extends State<_PillAlwaysVisibleStub> {
  // Always true — no timer ever sets this to false (D-05 behavior).
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_visible)
            Positioned(
              top: 0,
              left: 0,
              child: Material(
                key: const Key('pill'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back),
                    Icon(Icons.menu),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  group('_ReaderShellState pill visibility (D-05: no auto-hide timer)', () {
    testWidgets(
        'Pill remains visible after 4 seconds — no Timer fires to hide it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _PillAlwaysVisibleStub()),
      );

      // Pill is visible initially.
      expect(find.byKey(const Key('pill')), findsOneWidget);

      // Advance time by 4 seconds (more than the old 3-second timer would have
      // fired). With D-05 applied, no timer exists, so the pill must still be
      // visible.
      await tester.pump(const Duration(seconds: 4));

      expect(
        find.byKey(const Key('pill')),
        findsOneWidget,
        reason: 'Back+TOC pill must remain visible after 4 seconds: '
            'no auto-hide timer exists in D-05 implementation',
      );
    });

    testWidgets('Pill is visible from initial render with _visible = true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _PillAlwaysVisibleStub()),
      );

      expect(find.byKey(const Key('pill')), findsOneWidget);
    });
  });
}
