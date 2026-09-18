import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/models/question_review.dart';

void main() {
  group('QuestionReview.applyAnswer', () {
    test('a wrong answer resets to stage 0 and requeues no sooner than a day',
        () {
      final start = DateTime(2026, 1, 1, 12);
      final review = QuestionReview.initial('q1')
          .applyAnswer(
            isCorrect: true,
            selectedOption: 'a',
            at: start,
          )
          .applyAnswer(
            isCorrect: true,
            selectedOption: 'a',
            at: start,
          ); // stage 2, still a lapses == 0

      for (var i = 0; i < 50; i++) {
        final lapsed = review.applyAnswer(
          isCorrect: false,
          selectedOption: 'b',
          at: start,
          random: Random(i),
        );

        expect(lapsed.stage, 0);
        expect(lapsed.lapses, 1);
        expect(lapsed.lastCorrect, isFalse);
        expect(lapsed.retired, isFalse);
        final delta = lapsed.dueAt.difference(start);
        expect(delta, greaterThanOrEqualTo(const Duration(days: 1)));
        expect(
            delta, lessThanOrEqualTo(const Duration(hours: 24, minutes: 173)));
      }
    });

    test('a confident correct answer climbs the ladder', () {
      final start = DateTime(2026, 1, 1, 12);
      var review = QuestionReview.initial('q1');
      expect(review.isNew, isTrue);

      review = review.applyAnswer(
        isCorrect: true,
        selectedOption: 'a',
        at: start,
      );
      expect(review.stage, 1);
      expect(review.retired, isFalse);
      expect(review.dueAt.difference(start).inHours, greaterThan(20));
    });

    test('climbing off the top of the ladder retires the question', () {
      var review = QuestionReview.initial('q1');
      final start = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < QuestionReview.stageIntervals.length; i++) {
        review = review.applyAnswer(
          isCorrect: true,
          selectedOption: 'a',
          at: start,
        );
        expect(review.retired, isFalse);
      }

      review = review.applyAnswer(
        isCorrect: true,
        selectedOption: 'a',
        at: start,
      );
      expect(review.retired, isTrue);
      expect(review.isDue(start.add(const Duration(days: 400))), isFalse);
    });

    test('a lapse un-retires a previously retired question', () {
      var review = QuestionReview.initial('q1');
      final start = DateTime(2026, 1, 1, 12);
      for (var i = 0; i <= QuestionReview.stageIntervals.length; i++) {
        review = review.applyAnswer(
          isCorrect: true,
          selectedOption: 'a',
          at: start,
        );
      }
      expect(review.retired, isTrue);

      review = review.applyAnswer(
        isCorrect: false,
        selectedOption: 'b',
        at: start,
      );
      expect(review.retired, isFalse);
      expect(review.stage, 0);
      expect(review.lapses, 1);
    });

    test('a guessed-correct answer holds stage instead of promoting', () {
      final start = DateTime(2026, 1, 1, 12);
      final review = QuestionReview.initial('q1').applyAnswer(
        isCorrect: true,
        selectedOption: 'a',
        confident: false,
        at: start,
      );

      expect(review.stage, 0);
      expect(review.lastCorrect, isTrue);
      final delta = review.dueAt.difference(start);
      // Symmetric jitter spans +/-25% around 8 hours (360..600 min).
      expect(delta.inMinutes, greaterThanOrEqualTo(360));
      expect(delta.inMinutes, lessThanOrEqualTo(600));
    });
  });

  group('QuestionReview.fromLegacyAnswer', () {
    test('derives ladder state from a pre-existing UserAnswer', () {
      final answeredAt = DateTime(2026, 1, 1, 9);
      final wrongAnswer = UserAnswer(
        questionId: 'q1',
        selectedOption: 'c',
        isCorrect: false,
        answeredAt: answeredAt,
      );

      final review = QuestionReview.fromLegacyAnswer(wrongAnswer);

      expect(review.stage, 0);
      expect(review.lapses, 1);
      expect(review.attempts, 1);
      // A past miss should already be due by the time "now" is checked.
      expect(review.isDue(DateTime(2026, 1, 3)), isTrue);
    });
  });

  group('QuestionReview.isDue', () {
    test('a retired question is never due', () {
      final review = QuestionReview.initial('q1').copyWith(
        retired: true,
        dueAt: DateTime(2020),
      );
      expect(review.isDue(DateTime(2030)), isFalse);
    });
  });
}
