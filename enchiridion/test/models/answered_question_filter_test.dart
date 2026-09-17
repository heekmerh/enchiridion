import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/models/answered_question_filter.dart';
import 'package:enchiridion/models/question.dart';

UserAnswer _answer(String id, {required bool isCorrect}) => UserAnswer(
      questionId: id,
      selectedOption: isCorrect ? 'a' : 'b',
      isCorrect: isCorrect,
      answeredAt: DateTime(2026, 1, 1),
    );

void main() {
  // A mixed set of answers — some correct, some wrong — used to assert the
  // partition property rather than individually-hand-picked cases, so this
  // keeps catching regressions if a fifth filter value is ever added.
  final answers = [
    _answer('q-1', isCorrect: true),
    _answer('q-2', isCorrect: false),
    _answer('q-3', isCorrect: true),
    _answer('q-4', isCorrect: false),
    _answer('q-5', isCorrect: false),
  ];

  group('AnsweredQuestionFilter.matches', () {
    test('correct and wrong partition the answer set', () {
      var partitionedCount = 0;
      for (final answer in answers) {
        final matchesCorrect =
            AnsweredQuestionFilter.correct.matches(answer);
        final matchesWrong = AnsweredQuestionFilter.wrong.matches(answer);

        // Exactly one of the two predicates holds for every answer.
        expect(matchesCorrect ^ matchesWrong, isTrue);
        if (matchesCorrect) partitionedCount++;
        if (matchesWrong) partitionedCount++;
      }
      expect(partitionedCount, answers.length);
    });

    test('answered matches every answer, correct or wrong', () {
      for (final answer in answers) {
        expect(AnsweredQuestionFilter.answered.matches(answer), isTrue);
      }
    });

    test('points matches exactly the same answers as correct', () {
      for (final answer in answers) {
        expect(
          AnsweredQuestionFilter.points.matches(answer),
          AnsweredQuestionFilter.correct.matches(answer),
        );
      }
    });
  });

  group('AnsweredQuestionFilter labels', () {
    test('every value exposes a non-empty label and title', () {
      for (final filter in AnsweredQuestionFilter.values) {
        expect(filter.label, isNotEmpty, reason: '$filter.label');
        expect(filter.title, isNotEmpty, reason: '$filter.title');
      }
    });
  });
}
