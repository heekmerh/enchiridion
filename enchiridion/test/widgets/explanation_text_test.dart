import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/widgets/exam_prep/explanation_text.dart';

void main() {
  Future<void> show(WidgetTester tester, String content, {TextStyle? style}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ExplanationText(text: content, style: style)),
    ));
  }

  Finder explanationText() => find.descendant(
        of: find.byType(ExplanationText),
        matching: find.byType(Text),
      );

  testWidgets('separates paragraphs with vertical space', (tester) async {
    await show(tester, 'Why?\n\nThis is the reason.');

    expect(find.text('Why?'), findsOneWidget);
    expect(find.text('This is the reason.'), findsOneWidget);
    expect(explanationText(), findsNWidgets(2));
    expect(
        find.descendant(
          of: find.byType(ExplanationText),
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && (widget.height ?? 0) > 0,
          ),
        ),
        findsWidgets);
  });

  testWidgets('renders a lead-in above separate hanging-indent bullet rows',
      (tester) async {
    await show(tester, 'Key Clues:\n- High fever\n- Hypotension');

    expect(find.text('Key Clues:'), findsOneWidget);
    expect(find.text('High fever'), findsOneWidget);
    expect(find.text('Hypotension'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.byType(Row), findsNWidgets(2));
    expect(find.text('- High fever'), findsNothing);
    final firstRow = tester.widget<Row>(find.byType(Row).first);
    expect(firstRow.children.last, isA<Expanded>());
  });

  testWidgets('single line has one Text and no bullet rows', (tester) async {
    await show(tester, 'One plain line.');

    expect(explanationText(), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('empty input has no text or spacing', (tester) async {
    await show(tester, '');

    expect(explanationText(), findsNothing);
    expect(
        find.descendant(
          of: find.byType(ExplanationText),
          matching: find.byType(Column),
        ),
        findsNothing);
  });

  testWidgets('accepts hyphen, dot, and en dash bullet prefixes after spaces',
      (tester) async {
    await show(tester, 'Lead-in\n  - First\n  • Second\n  – Third');

    expect(find.text('Lead-in'), findsOneWidget);
    for (final item in ['First', 'Second', 'Third']) {
      expect(find.text(item), findsOneWidget);
    }
    expect(find.byType(Row), findsNWidgets(3));
  });

  testWidgets('uses supplied style for paragraphs and bullet text',
      (tester) async {
    const style = TextStyle(color: Colors.purple, fontSize: 17);
    await show(tester, 'Lead-in\n- Detail', style: style);

    for (final label in ['Lead-in', 'Detail']) {
      expect(tester.widget<Text>(find.text(label)).style, style);
    }
  });
}
