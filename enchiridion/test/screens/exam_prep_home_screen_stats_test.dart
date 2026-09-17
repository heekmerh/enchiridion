import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/models/study_day_stats.dart';
import 'package:enchiridion/providers/study_stats_provider.dart';
import 'package:enchiridion/screens/exam_prep_home_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/services/study_stats_service.dart';

const _testQuestions = [
  Question(
    id: 'q-1',
    questionText: 'What is 2 + 2?',
    options: {'a': '3', 'b': '4', 'c': '5'},
    correctOption: 'b',
    explanation: 'Basic arithmetic.',
    questionNumber: 1,
  ),
];

/// Pins the two defects the user reported and that Task 1/2 fixed:
/// the dashboard used to wait on the Supabase push before repainting, and an
/// answer could be recorded twice on the Quick Check path. Both regressions
/// would show up here as either a stale/zero metric after a single frame,
/// or a doubled Points/Answered value.
///
/// Uses `ExamPrepHomeScreen.testQuestions` to skip
/// `ExamPrepRepository.loadQuestions()` — like `ReaderScreen.testBookProvider`,
/// real asset loading via `rootBundle` hangs indefinitely in this project's
/// widget-test environment.
Widget _buildSubject(
  StorageService storage,
  StudyStatsProvider statsProvider,
) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<StudyStatsProvider>.value(value: statsProvider),
    ],
    child: const MaterialApp(
      home: ExamPrepHomeScreen(testQuestions: _testQuestions),
    ),
  );
}

void main() {
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    // Short-circuits the Supabase-backed access check the home screen's
    // _load() performs, matching this test's local-first, network-agnostic
    // subject.
    AccessService.testAccessOverride = true;
  });

  tearDown(() {
    AccessService.testAccessOverride = null;
  });

  testWidgets(
    'dashboard repaints with updated stats within a single frame while the '
    'remote push never resolves (standing in for offline/degraded network)',
    (tester) async {
      final statsProvider = StudyStatsProvider(
        storageService,
        statsService: StudyStatsService(
          storageService,
          syncOverride: (_) => Completer<void>().future, // never completes
        ),
      );

      await tester.pumpWidget(_buildSubject(storageService, statsProvider));
      await tester.pumpAndSettle();

      // Baseline: nothing recorded yet.
      expect(find.text('0'), findsWidgets);

      await statsProvider.recordAnswer(isCorrect: true, isFirstAttempt: true);
      // A single frame — NOT pumpAndSettle, which would mask a pending
      // network wait by draining timers/microtasks until everything (fake)
      // settles. A single `pump` proves the repaint happened synchronously
      // with the recorded answer, before the held-open push could resolve.
      await tester.pump();

      expect(find.text('10'), findsOneWidget); // Points
      expect(find.text('1'), findsNWidgets(2)); // Answered and Correct

      // Nothing pending — the test would otherwise fail with a
      // pending-timer/unsettled-future error at tearDown.
    },
  );

  testWidgets(
    'one recorded correct answer moves Points by exactly 10 and Answered by '
    'exactly 1 — the double-count guard',
    (tester) async {
      final statsProvider = StudyStatsProvider(storageService);

      await tester.pumpWidget(_buildSubject(storageService, statsProvider));
      await tester.pumpAndSettle();

      await statsProvider.recordAnswer(isCorrect: true, isFirstAttempt: true);
      await tester.pumpAndSettle();

      // Read the rendered text, not internal counters: if the wiring
      // double-recorded (the exact regression Task 1 fixed on the Quick
      // Check path), this would render 20/2 instead.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget); // Wrong stays zero
    },
  );

  testWidgets(
    'rendered Points sum a prior day plus today — accumulation survives a '
    'day boundary',
    (tester) async {
      await storageService.saveDailyStudyStats(
        StudyDayStats(
          scope: kStandaloneExamPrepScope,
          dateKey: '2020-01-01',
          questionsAnswered: 3,
          correctAnswers: 2,
          performancePoints: 20,
          updatedAt: DateTime(2020, 1, 1),
        ),
      );

      final statsProvider = StudyStatsProvider(storageService);
      await statsProvider.recordAnswer(isCorrect: true, isFirstAttempt: true);

      await tester.pumpWidget(_buildSubject(storageService, statsProvider));
      await tester.pumpAndSettle();

      expect(find.text('30'), findsOneWidget); // 20 (prior day) + 10 (today)
      expect(find.text('4'), findsOneWidget); // 3 (prior day) + 1 (today)
    },
  );
}
