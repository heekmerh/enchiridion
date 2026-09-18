import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/models/serve_log.dart';
import 'package:enchiridion/services/next_question_selector.dart';
import 'package:enchiridion/services/storage_service.dart';

Question _question(int number) => Question(
      id: 'q$number',
      questionText: 'Question $number',
      options: const {'a': 'Yes', 'b': 'No'},
      correctOption: 'a',
      explanation: 'Because.',
      questionNumber: number,
    );

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  group('NextQuestionSelector', () {
    test('serves an unseen question when the bank is untouched', () async {
      final bank = List.generate(5, (i) => _question(i + 1));
      final selector = NextQuestionSelector(storage);

      final picked = await selector.next(bank: bank, hasAccess: true);

      expect(picked, isNotNull);
      expect(bank.map((q) => q.id), contains(picked!.id));
    });

    test('a question the user got wrong outranks everything else', () async {
      final bank = List.generate(5, (i) => _question(i + 1));
      final now = DateTime(2026, 1, 1, 12);

      // q1 was answered wrong long enough ago to be due for relearn.
      await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: now.subtract(const Duration(hours: 28)),
        ),
      );

      final selector = NextQuestionSelector(storage);
      final picked = await selector.next(
        bank: bank,
        hasAccess: true,
        now: now,
      );

      expect(picked?.id, 'q1');
    });

    test('a stored miss waits a full day then outranks unseen questions',
        () async {
      final bank = List.generate(5, (i) => _question(i + 1));
      final now = DateTime(2026, 1, 1, 12);
      final review = await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: now,
        ),
      );
      expect(review.dueAt.isBefore(now.add(const Duration(days: 1))), isFalse);

      final selector = NextQuestionSelector(storage);
      final early = await selector.next(
        bank: bank,
        hasAccess: true,
        now: now.add(const Duration(hours: 23)),
      );
      expect(early?.id, isNot('q1'));

      // Forward jitter can put the due time beyond 25 hours. Check the
      // recorded boundary rather than assuming a fixed post-day offset.
      final due = await selector.next(
        bank: bank,
        hasAccess: true,
        now: review.dueAt,
      );
      expect(due?.id, 'q1');
    });

    test('never re-serves the same question within the cooldown window',
        () async {
      final bank = [_question(1)];
      final selector = NextQuestionSelector(storage);
      final now = DateTime(2026, 1, 1, 12);

      final first = await selector.next(bank: bank, hasAccess: true, now: now);
      expect(first?.id, 'q1');

      // Immediately asking again with only one question available in the
      // bank has nothing else to fall back to, so the cooldown is bypassed
      // by the least-recently-seen floor rather than returning null.
      final second = await selector.next(
        bank: bank,
        hasAccess: true,
        now: now.add(const Duration(minutes: 5)),
      );
      expect(second?.id, 'q1');
    });

    test('floor skips a missed question while its lapse window is open',
        () async {
      final now = DateTime(2026, 1, 1, 12);
      await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: now,
        ),
      );
      final selector = NextQuestionSelector(storage);
      final bank = [_question(1), _question(2)];

      expect((await selector.next(bank: bank, hasAccess: true, now: now))?.id,
          'q2');
      final floorPick = await selector.next(
        bank: bank,
        hasAccess: true,
        now: now.add(const Duration(minutes: 5)),
      );
      expect(floorPick?.id, 'q2');
    });

    test('returns null if the only question is inside its lapse window',
        () async {
      final now = DateTime(2026, 1, 1, 12);
      await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: now,
        ),
      );

      final picked = await NextQuestionSelector(storage).next(
        bank: [_question(1)],
        hasAccess: true,
        now: now.add(const Duration(minutes: 5)),
      );
      expect(picked, isNull);
    });

    test('floor can serve a past miss that was since answered correctly',
        () async {
      final now = DateTime(2026, 1, 3, 12);
      await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: now.subtract(const Duration(days: 2)),
        ),
      );
      final review = await storage.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q1',
          selectedOption: 'a',
          isCorrect: true,
          answeredAt: now,
        ),
      );
      expect(review.lapses, 1);
      expect(review.lastCorrect, isTrue);

      final picked = await NextQuestionSelector(storage).next(
        bank: [_question(1)],
        hasAccess: true,
        now: now.add(const Duration(minutes: 5)),
      );
      expect(picked?.id, 'q1');
    });

    test('locked questions are excluded for a free-tier user', () async {
      // kFreeQuestionCount is 10; question 11 requires access.
      final bank = [_question(11)];
      final selector = NextQuestionSelector(storage);

      final picked = await selector.next(bank: bank, hasAccess: false);

      expect(picked, isNull);
    });

    test('returns null when nothing is unlocked', () async {
      final selector = NextQuestionSelector(storage);
      final picked = await selector.next(bank: const [], hasAccess: true);
      expect(picked, isNull);
    });

    test('records each serve so repeated calls rotate through the bank',
        () async {
      final bank = List.generate(6, (i) => _question(i + 1));
      final selector = NextQuestionSelector(storage);
      final now = DateTime(2026, 1, 1, 12);

      final served = <String>{};
      for (var i = 0; i < 6; i++) {
        final picked = await selector.next(
          bank: bank,
          hasAccess: true,
          now: now.add(Duration(minutes: i)),
        );
        expect(picked, isNotNull);
        served.add(picked!.id);
      }

      // With 6 unseen questions and a 12-slot recent-serve log, no id should
      // repeat before the whole bank has been offered once.
      expect(served, hasLength(6));
    });

    test('rotates through the free-tier bank without repeating a question',
        () async {
      final bank = List.generate(10, (i) => _question(i + 1));
      final selector = NextQuestionSelector(storage);
      final start = DateTime(2026, 1, 1, 12);
      final served = <String>[];

      for (var i = 0; i < 25; i++) {
        final picked = await selector.next(
          bank: bank,
          hasAccess: false,
          now: start.add(Duration(minutes: i)),
        );
        expect(picked, isNotNull);
        served.add(picked!.id);
      }

      for (var startIndex = 0; startIndex <= served.length - 10; startIndex++) {
        expect(
          served.skip(startIndex).take(10).toSet(),
          hasLength(10),
          reason: 'Serves $startIndex through ${startIndex + 9} repeated',
        );
      }
    });

    test('sees a serve recorded by another isolate', () async {
      final bank = List.generate(10, (i) => _question(i + 1));
      // setMockInitialValues replaces the backing store without updating the
      // preferences instance held by storage, like a separate isolate's write.
      SharedPreferences.setMockInitialValues({
        'serve_log_exam_prep': jsonEncode(ServeLog(
          recent: List.generate(9, (i) => 'q${i + 1}'),
          counter: 9,
        ).toJson()),
      });

      final picked =
          await NextQuestionSelector(storage, random: Random(1)).next(
        bank: bank,
        hasAccess: false,
        now: DateTime(2026, 1, 1, 12),
      );

      expect(picked?.id, 'q10');
    });
  });
}
