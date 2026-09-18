import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/providers/study_stats_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/services/study_stats_service.dart';

void main() {
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  StudyStatsProvider buildProvider({bool hangRemotePush = false}) {
    final statsService = StudyStatsService(
      storageService,
      syncOverride: hangRemotePush
          ? (_) => Completer<void>().future // never completes
          : null,
    );
    return StudyStatsProvider(storageService, statsService: statsService);
  }

  group('StudyStatsProvider', () {
    test(
      'recordAnswer returns updated stats and notifies listeners without '
      'awaiting a never-completing remote push',
      () async {
        final provider = buildProvider(hangRemotePush: true);
        var notifyCount = 0;
        provider.addListener(() => notifyCount++);

        final updated = provider.recordAnswer(
          isCorrect: true,
          isFirstAttempt: true,
        );

        // If the push were awaited internally, this would hang forever and
        // the test framework would time out.
        final result = await updated;

        expect(result.questionsAnswered, 1);
        expect(result.performancePoints, 10);
        expect(notifyCount, 1);
      },
    );

    test('a correct answer raises points by exactly 10 and answered by 1',
        () async {
      final provider = buildProvider();
      final result = await provider.recordAnswer(
        isCorrect: true,
        isFirstAttempt: true,
      );

      expect(result.questionsAnswered, 1);
      expect(result.performancePoints, 10);
      expect(provider.today.performancePoints, 10);
      expect(provider.totals.performancePoints, 10);
    });

    test('a wrong answer raises answered by 1 and points by 0', () async {
      final provider = buildProvider();
      final result = await provider.recordAnswer(
        isCorrect: false,
        isFirstAttempt: true,
      );

      expect(result.questionsAnswered, 1);
      expect(result.correctAnswers, 0);
      expect(result.performancePoints, 0);
    });

    test('recording the same question a second time (not first attempt) '
        'changes nothing', () async {
      final provider = buildProvider();
      await provider.recordAnswer(isCorrect: true, isFirstAttempt: true);
      final second = await provider.recordAnswer(
        isCorrect: true,
        isFirstAttempt: false,
      );

      expect(second.questionsAnswered, 1);
      expect(second.performancePoints, 10);
    });

    test('listeners are notified exactly once per recorded answer',
        () async {
      final provider = buildProvider();
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.recordAnswer(isCorrect: true, isFirstAttempt: true);
      expect(notifyCount, 1);

      await provider.recordAnswer(isCorrect: true, isFirstAttempt: true);
      expect(notifyCount, 2);
    });

    test('listeners are notified before the background push resolves',
        () async {
      final pushStarted = Completer<void>();
      final allowPushToFinish = Completer<void>();
      final statsService = StudyStatsService(
        storageService,
        syncOverride: (_) async {
          pushStarted.complete();
          await allowPushToFinish.future;
        },
      );
      final provider =
          StudyStatsProvider(storageService, statsService: statsService);

      var notified = false;
      provider.addListener(() => notified = true);

      final future = provider.recordAnswer(
        isCorrect: true,
        isFirstAttempt: true,
      );

      // The push has started but is deliberately held open — proving
      // recordAnswer's notifyListeners already ran without waiting for the
      // push to resolve.
      await pushStarted.future;
      expect(notified, isTrue);

      allowPushToFinish.complete();
      await future;
    });

    test('totals accumulate across days (lifetime, not reset at midnight)',
        () async {
      await storageService.saveDailyStudyStats(
        (StudyStatsService(storageService).getTodayStats())
            .copyWith(dateKey: '2020-01-01', questionsAnswered: 3,
                correctAnswers: 2, performancePoints: 20),
      );
      final provider = buildProvider();
      provider.refresh();

      expect(provider.totals.questionsAnswered, 3);
      expect(provider.totals.performancePoints, 20);

      await provider.recordAnswer(isCorrect: true, isFirstAttempt: true);

      expect(provider.totals.questionsAnswered, 4);
      expect(provider.totals.performancePoints, 30);
      // Today's figure stays scoped to today, separate from the lifetime
      // total.
      expect(provider.today.questionsAnswered, 1);
    });
  });
}
