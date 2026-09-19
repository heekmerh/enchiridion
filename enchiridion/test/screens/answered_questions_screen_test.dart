import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/answered_question_filter.dart';
import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/providers/study_stats_provider.dart';
import 'package:enchiridion/screens/answered_questions_screen.dart';
import 'package:enchiridion/services/storage_service.dart';

const _questionOne = Question(
  id: 'q-1',
  questionText:
      'A patient presents with a wound. What is the best initial dressing?',
  options: {'a': 'Gauze', 'b': 'Alginate', 'c': 'Hydrocolloid'},
  correctOption: 'b',
  explanation: 'Alginate suits a heavily exuding wound.',
  questionNumber: 1,
);

const _questionTwo = Question(
  id: 'q-2',
  questionText: 'Which nerve is most at risk during an appendectomy incision?',
  options: {'a': 'Ilioinguinal', 'b': 'Femoral', 'c': 'Obturator'},
  correctOption: 'a',
  explanation: 'The ilioinguinal nerve runs near the incision site.',
  questionNumber: 2,
);

const _questionThree = Question(
  id: 'q-3',
  questionText: 'What is the normal resting heart rate range for an adult?',
  options: {'a': '60-100 bpm', 'b': '40-60 bpm', 'c': '100-140 bpm'},
  correctOption: 'a',
  explanation: 'A normal adult resting heart rate is 60-100 bpm.',
  questionNumber: 3,
);

const _questions = [_questionOne, _questionTwo, _questionThree];

Widget _buildSubject(
  StorageService storage,
  AnsweredQuestionFilter filter, {
  List<Question> questions = _questions,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<StudyStatsProvider>(
        create: (_) => StudyStatsProvider(storage),
      ),
    ],
    child: MaterialApp(
      home: AnsweredQuestionsScreen(
        questions: questions,
        initialFilter: filter,
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
    'Wrong filter lists only the missed questions, identified by preview text',
    (tester) async {
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionOne.id,
          selectedOption: 'a', // wrong — correct is 'b'
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 1),
        ),
      );
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionTwo.id,
          selectedOption: 'b', // wrong — correct is 'a'
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 2),
        ),
      );
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionThree.id,
          selectedOption: 'a', // correct
          isCorrect: true,
          answeredAt: DateTime(2026, 1, 3),
        ),
      );

      await tester.pumpWidget(
        _buildSubject(storageService, AnsweredQuestionFilter.wrong),
      );
      await tester.pumpAndSettle();

      expect(find.text(_questionOne.previewText()), findsOneWidget);
      expect(find.text(_questionTwo.previewText()), findsOneWidget);
      expect(find.text(_questionThree.previewText()), findsNothing);
    },
  );

  testWidgets(
    'Tapping a missed row opens the question with answering enabled, and '
    'answering it correctly then popping moves it out of the Wrong filter',
    (tester) async {
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionOne.id,
          selectedOption: 'a', // wrong — correct is 'b'
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 1),
        ),
      );
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionTwo.id,
          selectedOption: 'b', // wrong — correct is 'a'
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 2),
        ),
      );

      await tester.pumpWidget(
        _buildSubject(storageService, AnsweredQuestionFilter.wrong),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(_questionOne.previewText()));
      await tester.pumpAndSettle();

      // Answering is enabled — a Submit control is present, not the
      // read-only view.
      expect(find.text('Submit'), findsOneWidget);

      await tester.tap(find.text('Alginate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);

      await tester.tap(find.text('Back to answers'));
      await tester.pumpAndSettle();

      // The retried question left the Wrong filter; the untouched one is
      // still there.
      expect(find.text(_questionOne.previewText()), findsNothing);
      expect(find.text(_questionTwo.previewText()), findsOneWidget);

      expect(
        storageService.getAnswers('exam_prep')[_questionOne.id]?.isCorrect,
        isTrue,
      );
    },
  );

  testWidgets(
    'A filter with no matching answers renders an empty-state message',
    (tester) async {
      await storageService.recordAnswer(
        'exam_prep',
        UserAnswer(
          questionId: _questionOne.id,
          selectedOption: 'a', // wrong
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        // Nothing correct has been recorded yet.
        _buildSubject(storageService, AnsweredQuestionFilter.correct),
      );
      await tester.pumpAndSettle();

      expect(find.text(_questionOne.previewText()), findsNothing);
      expect(find.text('No questions in this list yet.'), findsOneWidget);
    },
  );
}
