import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/study_day_stats.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/services/study_stats_service.dart';

const _scope = 'exam_prep';

StudyDayStats _day(
  String dateKey, {
  required int answered,
  required int correct,
  required int points,
}) {
  return StudyDayStats(
    scope: _scope,
    dateKey: dateKey,
    questionsAnswered: answered,
    correctAnswers: correct,
    performancePoints: points,
    updatedAt: DateTime.parse('${dateKey}T12:00:00'),
  );
}

void main() {
  late StorageService storageService;
  late StudyStatsService statsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    statsService = StudyStatsService(storageService);
  });

  group('StudyStatsTotals.fold', () {
    test('folding three separate days sums every field', () {
      final totals = StudyStatsTotals.fold([
        _day('2026-01-01', answered: 5, correct: 3, points: 30),
        _day('2026-01-02', answered: 2, correct: 2, points: 20),
        _day('2026-01-03', answered: 4, correct: 1, points: 10),
      ]);

      expect(totals.questionsAnswered, 11);
      expect(totals.correctAnswers, 6);
      expect(totals.performancePoints, 60);
      expect(totals.wrongAnswers, 5);
    });

    test('an empty iterable folds to zero rather than throwing', () {
      final totals = StudyStatsTotals.fold(const []);

      expect(totals.questionsAnswered, 0);
      expect(totals.correctAnswers, 0);
      expect(totals.performancePoints, 0);
      expect(totals.wrongAnswers, 0);
    });

    test('wrongAnswers is never negative even for an inconsistent day', () {
      // correctAnswers > questionsAnswered should not happen, but a corrupt
      // or hand-edited stored day must not render a negative Wrong count.
      final totals = StudyStatsTotals.fold([
        _day('2026-01-01', answered: 1, correct: 5, points: 10),
      ]);

      expect(totals.wrongAnswers, 0);
    });
  });

  group('StorageService.getAllDailyStudyStats', () {
    test('returns every stored day for a scope', () async {
      await storageService.saveDailyStudyStats(
        _day('2026-01-01', answered: 1, correct: 1, points: 10),
      );
      await storageService.saveDailyStudyStats(
        _day('2026-01-02', answered: 2, correct: 0, points: 0),
      );

      final days = storageService.getAllDailyStudyStats(_scope);

      expect(days.length, 2);
      expect(
        days.map((d) => d.dateKey).toSet(),
        {'2026-01-01', '2026-01-02'},
      );
    });

    test('returns empty (never throws) when nothing is stored', () {
      expect(storageService.getAllDailyStudyStats(_scope), isEmpty);
    });
  });

  group('StudyStatsService.getLifetimeTotals', () {
    test(
      'accumulates across days — unaffected by the local clock crossing '
      'midnight (a day recorded yesterday still contributes)',
      () async {
        // "Yesterday" relative to now, expressed as a stored day distinct
        // from whatever StudyStatsService.dateKeyFor(DateTime.now()) is.
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yesterdayKey = StudyStatsService.dateKeyFor(yesterday);
        await storageService.saveDailyStudyStats(
          _day(yesterdayKey, answered: 3, correct: 2, points: 20),
        );

        // Record a fresh answer today through the service.
        final today = await statsService.recordAnswer(
          scope: _scope,
          isCorrect: true,
        );

        final totals = statsService.getLifetimeTotals(_scope);

        expect(today.questionsAnswered, 1);
        expect(totals.questionsAnswered, 4);
        expect(totals.correctAnswers, 3);
        expect(totals.performancePoints, 30);
      },
    );

    test('lifetime totals are zero when nothing has been recorded', () {
      final totals = statsService.getLifetimeTotals(_scope);

      expect(totals.questionsAnswered, 0);
      expect(totals.performancePoints, 0);
      expect(totals.wrongAnswers, 0);
    });

    test(
      'four recorded answers, two of them repeats of already-answered '
      'questions, fold to four answered — reproduces the reported '
      '"answered 4, counted 2" bug at the service level',
      () async {
        // Two distinct questions, each answered twice in the same run. The
        // service takes no question identity at all — it is the caller
        // (QuestionScreen._submit) that is the single point of truth for
        // "this is a new submission" — so two answers to the same question
        // are indistinguishable from two answers to different questions
        // here, exactly as intended: attempts/review state plays no part.
        // syncOverride keeps this test off the network regardless.
        final noNetworkStatsService = StudyStatsService(
          storageService,
          syncOverride: (_) async {},
        );
        await noNetworkStatsService.recordAnswer(
            scope: _scope, isCorrect: true);
        await noNetworkStatsService.recordAnswer(
            scope: _scope, isCorrect: true);
        await noNetworkStatsService.recordAnswer(
            scope: _scope, isCorrect: true);
        await noNetworkStatsService.recordAnswer(
            scope: _scope, isCorrect: false);

        final totals = noNetworkStatsService.getLifetimeTotals(_scope);

        expect(totals.questionsAnswered, 4);
        expect(totals.correctAnswers, 3);
        expect(totals.wrongAnswers, 1);
        expect(totals.performancePoints, 30);
      },
    );
  });
}
