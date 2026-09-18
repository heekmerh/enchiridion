import 'package:flutter_test/flutter_test.dart';
import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/services/question_visibility.dart';

List<Question> _makeBank(int count) => List.generate(
      count,
      (index) {
        final number = index + 1;
        return Question(
          id: 'q-$number',
          questionText: 'Question text $number',
          options: const {'a': 'Option A', 'b': 'Option B'},
          correctOption: 'a',
          explanation: 'Explanation $number',
          questionNumber: number,
        );
      },
    );

void main() {
  group('reviewableQuestions', () {
    test('returns only the answered ids, in bank order', () {
      final bank = _makeBank(25);
      final answeredIds = {bank[6].id, bank[2].id};

      final result =
          reviewableQuestions(bank: bank, answeredIds: answeredIds);

      expect(result.length, 2);
      expect(result[0].id, bank[2].id);
      expect(result[1].id, bank[6].id);
    });

    test('returns an empty list for an empty answered-id set', () {
      final bank = _makeBank(25);

      final result =
          reviewableQuestions(bank: bank, answeredIds: <String>{});

      expect(result, isEmpty);
    });

    test('ignores an answered id absent from the bank and does not throw',
        () {
      final bank = _makeBank(5);

      final result = reviewableQuestions(
        bank: bank,
        answeredIds: {bank[1].id, 'not-in-bank'},
      );

      expect(result.length, 1);
      expect(result.single.id, bank[1].id);
    });
  });

  group('hasReviewableQuestions', () {
    test('is false for an empty answer map', () {
      expect(hasReviewableQuestions(const {}), isFalse);
    });

    test('is true for a non-empty answer map', () {
      final answers = {
        'q-1': UserAnswer(
          questionId: 'q-1',
          selectedOption: 'a',
          isCorrect: true,
          answeredAt: DateTime(2024, 1, 1),
        ),
      };

      expect(hasReviewableQuestions(answers), isTrue);
    });
  });

  group('answeredProgressLabel', () {
    test('builds label from answered and correct counts', () {
      expect(
        answeredProgressLabel(answered: 2, correct: 1),
        '2 answered — 1 correct',
      );
    });

    test('builds label for zero answered and zero correct', () {
      expect(
        answeredProgressLabel(answered: 0, correct: 0),
        '0 answered — 0 correct',
      );
    });

    test('never contains a bank size', () {
      final bank = _makeBank(25);
      final label = answeredProgressLabel(answered: 2, correct: 1);

      expect(label.contains('${bank.length}'), isFalse);
    });
  });
}
