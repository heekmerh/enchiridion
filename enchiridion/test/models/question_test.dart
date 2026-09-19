import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/models/question.dart';

Question _question(String text) => Question(
      id: 'q1',
      questionText: text,
      options: const {'a': '1', 'b': '2'},
      correctOption: 'a',
      explanation: 'because',
      questionNumber: 1,
    );

void main() {
  group('Question.displayLabel', () {
    test('maps positions to capital letters', () {
      expect(Question.displayLabel(0), 'A');
      expect(Question.displayLabel(1), 'B');
      expect(Question.displayLabel(2), 'C');
      expect(Question.displayLabel(3), 'D');
    });

    test('rejects out-of-range positions', () {
      expect(() => Question.displayLabel(-1), throwsA(isA<AssertionError>()));
      expect(() => Question.displayLabel(26), throwsA(isA<AssertionError>()));
    });
  });

  group('Question.previewText', () {
    test('flattens multiline stems into one line', () {
      final question =
          _question('A 5 year old boy.\nWhat is the\n\nnext step?');
      expect(
          question.previewText(), 'A 5 year old boy. What is the next step?');
    });

    test('measures maxLength after flattening', () {
      final question = _question('Alpha\n\nBeta');
      expect(question.previewText(maxLength: 10), 'Alpha Beta');
    });

    test('returns the text unchanged when already within maxLength', () {
      final question = _question('Short question?');
      expect(question.previewText(), 'Short question?');
    });

    test(
        'shows the tail — the actual question — not the front of a long '
        'clinical vignette', () {
      const vignette = 'A 32 year old woman presents to the Emergency '
          'Department with a sudden onset of high fever, vomiting, '
          'diarrhoea, and a diffuse rash. What is the most likely diagnosis?';
      final preview = _question(vignette).previewText(maxLength: 40);

      expect(preview, startsWith('…'));
      expect(preview, endsWith('most likely diagnosis?'));
      // The scene-setting opener must not appear at all — that's the whole
      // point of previewing the tail instead of the front.
      expect(preview.contains('32 year old woman'), isFalse);
    });

    test('does not split a word in half at the truncation boundary', () {
      final question = _question('one two three four five six seven eight');
      final preview = question.previewText(maxLength: 10);

      // Every word in the preview (after stripping the leading ellipsis)
      // must be a whole word from the source string.
      final words = preview.replaceFirst('…', '').split(' ');
      for (final word in words) {
        expect(question.questionText.split(' '), contains(word));
      }
    });
  });
}
