import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/widgets/blocks/table_block.dart';
import 'package:enchiridion/models/content_block.dart';

void main() {
  // Stub TableBlock with 3 columns and 1 row for deterministic tests.
  final stubBlock = TableBlock(
    columns: ['A', 'B', 'C'],
    rows: [
      ['1', '2', '3']
    ],
  );

  // Wrap widget in MaterialApp + MediaQuery with fixed 375×812 screen size.
  Widget buildWidget({Color? headerTintColor}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 812)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TableBlockWidget(
                block: stubBlock,
                fontSize: 16,
                lineHeight: 1.5,
                headerTintColor: headerTintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Test 1: No horizontal SingleChildScrollView in the TableBlockWidget tree.
  testWidgets(
      'TableBlockWidget renders without a horizontal SingleChildScrollView',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildWidget());

    // Find all SingleChildScrollView widgets in the entire tree.
    final horizontalScrollViews = tester
        .widgetList<SingleChildScrollView>(
            find.byType(SingleChildScrollView))
        .where((w) => w.scrollDirection == Axis.horizontal)
        .toList();

    expect(horizontalScrollViews, isEmpty,
        reason:
            'TableBlockWidget must not use SingleChildScrollView with Axis.horizontal');
  });

  // Test 2: With 3 columns on a 375px screen, each column is approximately
  // (375 - 48) / 3 ≈ 109 px wide (48px total horizontal padding from Scaffold
  // wrapping; plan specifies 48px content padding offset).
  testWidgets(
      'TableBlockWidget assigns equal FixedColumnWidth to each column (~109px on 375px screen)',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildWidget());

    // Find the Table widget.
    final table = tester.widget<Table>(find.byType(Table).first);

    // Table.columnWidths must be non-null and map each index to FixedColumnWidth.
    expect(table.columnWidths, isNotNull,
        reason: 'Table.columnWidths must be set');
    final widths = table.columnWidths!;

    for (int i = 0; i < 3; i++) {
      expect(widths[i], isA<FixedColumnWidth>(),
          reason: 'Column $i must use FixedColumnWidth');
      final fixedWidth = (widths[i]! as FixedColumnWidth).value;
      // (375 - 48) / 3 = 109.0
      expect(fixedWidth, closeTo(109.0, 1.0),
          reason:
              'Column $i width should be ~109px (got $fixedWidth); '
              'expected (375-48)/3');
    }
  });

  // Test 3: headerTintColor: Colors.red causes the header TableRow to have a
  // red-tinted background color.
  testWidgets(
      'TableBlockWidget with headerTintColor: Colors.red uses red background on header row',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildWidget(headerTintColor: Colors.red));

    // The header TableRow has a BoxDecoration. Find it via DecoratedBox.
    // TableRow decoration is applied as a DecoratedBox around the row cells.
    final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(
            of: find.byType(Table), matching: find.byType(DecoratedBox)));

    bool foundRedTint = false;
    for (final db in decoratedBoxes) {
      final decoration = db.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        final color = decoration.color!;
        // Colors.red with alpha 0.15 in light mode: red channel dominant, non-zero alpha.
        if (color.red > color.blue && color.red > color.green &&
            color.alpha > 0) {
          foundRedTint = true;
          break;
        }
      }
    }

    expect(foundRedTint, isTrue,
        reason:
            'Header row must use a red-tinted background when headerTintColor is Colors.red');
  });

  // Test 4: headerTintColor: null falls back to a non-brandPink (or low-saturation)
  // background — specifically NOT the literal brandPink #FF66A3 (0xFFFF66A3).
  testWidgets(
      'TableBlockWidget with headerTintColor: null does not use full-opacity brandPink (#FF66A3)',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildWidget());

    const brandPink = Color(0xFFFF66A3);

    final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.descendant(
            of: find.byType(Table), matching: find.byType(DecoratedBox)));

    bool foundFullBrandPink = false;
    for (final db in decoratedBoxes) {
      final decoration = db.decoration;
      if (decoration is BoxDecoration && decoration.color == brandPink) {
        foundFullBrandPink = true;
        break;
      }
    }

    expect(foundFullBrandPink, isFalse,
        reason:
            'Header row must not use full-opacity brandPink; it should use an alpha-reduced tint or inkCharcoal');
  });
}
