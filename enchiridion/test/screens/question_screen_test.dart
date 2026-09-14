import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/screens/question_screen.dart';
import 'package:enchiridion/services/storage_service.dart';

const _question = Question(
  id: 'q-1',
  questionText: 'What is 2 + 2?',
  options: {'a': '3', 'b': '4', 'c': '5'},
  correctOption: 'b',
  explanation: 'Basic arithmetic.',
  questionNumber: 1,
);

Widget _buildSubject(
  StorageService storage, {
  required bool readOnly,
  UserAnswer? previousAnswer,
  void Function(UserAnswer)? onAnswered,
}) {
  return MultiProvider(
    providers: [Provider<StorageService>.value(value: storage)],
    child: MaterialApp(
      home: QuestionScreen(
        question: _question,
        bookId: 'exam_prep',
        readOnly: readOnly,
        previousAnswer: previousAnswer,
        onAnswered: onAnswered ?? (_) {},
      ),
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

  testWidgets(
    'readOnly mode shows the prior answer and cannot overwrite it',
    (tester) async {
      // Simulates reopening "Review fully" after a wrong answer already
      // recorded elsewhere (the Quick Check sheet). Before the readOnly
      // fix this screen started blank and let the user re-answer, silently
      // overwriting a wrong answer with a correct one.
      final priorWrongAnswer = UserAnswer(
        questionId: 'q-1',
        selectedOption: 'a',
        isCorrect: false,
        answeredAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(_buildSubject(
        storageService,
        readOnly: true,
        previousAnswer: priorWrongAnswer,
      ));
      await tester.pumpAndSettle();

      // Already shows the result — no Submit button to tap.
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Incorrect'), findsOneWidget);

      // The correct answer ('4') is visible in the explanation view, but
      // tapping it must not be possible: readOnly disables all option taps.
      final correctOptionFinder = find.text('4');
      expect(correctOptionFinder, findsOneWidget);
      await tester.tap(correctOptionFinder);
      await tester.pumpAndSettle();

      // Nothing was written back to storage — the original wrong answer
      // survives untouched, and the ladder was not re-scored.
      final storedAnswers = storageService.getAnswers('exam_prep');
      expect(storedAnswers, isEmpty);
      expect(find.text('Incorrect'), findsOneWidget);
    },
  );

  testWidgets(
    'normal (non-readOnly) mode lets the user answer and records the review',
    (tester) async {
      UserAnswer? reported;
      await tester.pumpWidget(_buildSubject(
        storageService,
        readOnly: false,
        onAnswered: (answer) => reported = answer,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(reported?.isCorrect, isTrue);
      expect(storageService.getAnswers('exam_prep')['q-1']?.isCorrect, isTrue);

      final review = storageService.getQuestionReviews('exam_prep')['q-1'];
      expect(review, isNotNull);
      expect(review!.stage, 1);
    },
  );
}
