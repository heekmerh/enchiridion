import 'package:enchiridion/models/content_block.dart';
import 'package:enchiridion/widgets/blocks/list_block.dart';
import 'package:enchiridion/widgets/blocks/rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListBlock', () {
    test('parses nested items with labels and a title', () {
      final block = ContentBlock.fromJson({
        'type': 'list',
        'title': 'Look for:',
        'items': [
          {'text': 'Cyanosis', 'level': 0, 'label': '1.'},
          {'text': 'Tongue', 'level': 1},
        ],
      }) as ListBlock;

      expect(block.title, 'Look for:');
      expect(block.items.first.label, '1.');
      expect(block.items.last.level, 1);
      expect(block.items.last.label, isNull);
      expect(block.toJson()['items'], hasLength(2));
    });

    test('paragraph styles round-trip and default to body', () {
      final quote = ContentBlock.fromJson(
          {'type': 'paragraph', 'text': '"Is that okay?"', 'style': 'quote'});
      final body = ContentBlock.fromJson({'type': 'paragraph', 'text': 'x'});

      expect((quote as ParagraphBlock).style, ParagraphStyle.quote);
      expect(quote.toJson()['style'], 'quote');
      expect((body as ParagraphBlock).style, ParagraphStyle.body);
      expect(body.toJson().containsKey('style'), isFalse);
    });

    test('plainText drops bold markers', () {
      expect(plainText('**Look** for: **signs**'), 'Look for: signs');
    });
  });

  group('emphasisSpans', () {
    const base = TextStyle(fontSize: 14);

    test('bolds marked runs and keeps the rest plain', () {
      final spans = emphasisSpans('Ask **gently** please', base);
      expect(spans.map((s) => s.text), ['Ask ', 'gently', ' please']);
      expect(spans[1].style!.fontWeight, FontWeight.w700);
      expect(spans[0].style!.fontWeight, isNull);
    });

    test('an unclosed marker is shown as written', () {
      final spans = emphasisSpans('a **b', base);
      expect(spans.map((s) => s.text).join(), 'a **b');
    });
  });

  testWidgets('renders bullets, numbers, nesting and the lead-in title',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListBlockWidget(
          block: ListBlock(title: 'Then:', items: const [
            ListItem(text: 'Wash hands', label: '1.'),
            ListItem(text: 'Ensure **privacy**', label: '2.'),
            ListItem(text: 'Curtains', level: 1),
          ]),
          fontSize: 14,
          lineHeight: 1.4,
        ),
      ),
    ));

    expect(find.text('Then:', findRichText: true), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('◦'), findsOneWidget);
    expect(find.text('Ensure privacy', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });
}
