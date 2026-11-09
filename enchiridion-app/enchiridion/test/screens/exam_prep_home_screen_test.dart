// Widget tests for the Exam Prep home screen's Access card.
// Regression guard for batch item 260917-ndx: the whole-bank list screen
// (ExamPrepQuestionListScreen) and its "Browse Full Bank" entry point were
// deleted. These tests prove that removal without a route into the full
// bank while the rest of the screen — Performance, Access with the
// Unlock path, and Mock Exam — still renders.
// Uses ExamPrepHomeScreen.testQuestions to inject a fixed bank so tests
// never touch rootBundle / platform channels, and
// AccessService.testAccessOverride to avoid a Supabase connection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/providers/study_stats_provider.dart';
import 'package:enchiridion/screens/exam_prep_home_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';

List<Question> _makeBank() => List.generate(
      25,
      (index) {
        final number = index + 1;
        return Question(
          id: 'q-$number',
          questionText: 'Question text $number',
          options: const {'a': 'Option A', 'b': 'Option B', 'c': 'Option C'},
          correctOption: 'a',
          explanation: 'Explanation $number',
          questionNumber: number,
        );
      },
    );

Widget _buildSubject(StorageService storage) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<StudyStatsProvider>(
        create: (_) => StudyStatsProvider(storage),
      ),
    ],
    child: MaterialApp(
      home: ExamPrepHomeScreen(testQuestions: _makeBank()),
    ),
  );
}

void main() {
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  tearDown(() {
    AccessService.testAccessOverride = null;
  });

  testWidgets(
    'free user sees the three cards, an Unlock button, and no bank-browsing affordance',
    (tester) async {
      AccessService.testAccessOverride = false;

      await tester.pumpWidget(_buildSubject(storageService));
      await tester.pumpAndSettle();

      expect(find.text('PLAB'), findsOneWidget);
      expect(find.text('PLAB Performance'), findsOneWidget);
      expect(find.text('PLAB Access'), findsOneWidget);
      expect(find.text('PLAB Mock Exam'), findsOneWidget);

      expect(find.text('Unlock'), findsOneWidget);

      expect(find.text('Browse Full Bank'), findsNothing);
      expect(find.byIcon(Icons.list_alt_outlined), findsNothing);
    },
  );

  testWidgets(
    'paid user sees the three cards, no Unlock button, and no bank-browsing affordance',
    (tester) async {
      AccessService.testAccessOverride = true;

      await tester.pumpWidget(_buildSubject(storageService));
      await tester.pumpAndSettle();

      expect(find.text('PLAB'), findsOneWidget);
      expect(find.text('PLAB Performance'), findsOneWidget);
      expect(find.text('PLAB Access'), findsOneWidget);
      expect(find.text('PLAB Mock Exam'), findsOneWidget);

      expect(find.text('Unlock'), findsNothing);

      expect(find.text('Browse Full Bank'), findsNothing);
      expect(find.byIcon(Icons.list_alt_outlined), findsNothing);
    },
  );
}
