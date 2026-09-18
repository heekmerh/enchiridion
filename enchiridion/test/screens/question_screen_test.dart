import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/providers/study_stats_provider.dart';
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

const _question2 = Question(
  id: 'q-2',
  questionText: 'What is 3 + 3?',
  options: {'a': '5', 'b': '6', 'c': '7'},
  correctOption: 'b',
  explanation: 'More arithmetic.',
  questionNumber: 2,
);

/// Counts `Navigator.push` calls, so a test can assert an in-place advance
/// pushed no new route.
class _PushCounter extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

Widget _buildSubject(
  StorageService storage, {
  required bool readOnly,
  UserAnswer? previousAnswer,
  void Function(UserAnswer)? onAnswered,
  NextQuestionLoader? onRequestNext,
  bool trackDailyStudyStats = false,
  Question? question,
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<StudyStatsProvider>(
        create: (_) => StudyStatsProvider(storage),
      ),
    ],
    child: MaterialApp(
      navigatorObservers: navigatorObservers,
      home: QuestionScreen(
        question: question ?? _question,
        bookId: 'exam_prep',
        readOnly: readOnly,
        previousAnswer: previousAnswer,
        onAnswered: onAnswered ?? (_) {},
        onRequestNext: onRequestNext,
        trackDailyStudyStats: trackDailyStudyStats,
      ),
    ),
  );
}

/// Builds the screen behind a pushed route, so a test can pop it (dispose it)
/// mid-flow. Kept separate from `_buildSubject`, which always uses the
/// screen as the app's `home` (the only route) and so cannot be popped.
Widget _buildPushableSubject(
  StorageService storage, {
  required NextQuestionLoader onRequestNext,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<StudyStatsProvider>(
        create: (_) => StudyStatsProvider(storage),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuestionScreen(
                    question: _question,
                    bookId: 'exam_prep',
                    onAnswered: (_) {},
                    onRequestNext: onRequestNext,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
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

  group('next-question advance', () {
    testWidgets(
      'without a loader, the post-submit footer is unchanged and shows no next-question control',
      (tester) async {
        await tester.pumpWidget(_buildSubject(storageService, readOnly: false));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Next question'), findsNothing);
        expect(find.text('Back to question list'), findsOneWidget);
      },
    );

    testWidgets(
      'with a loader, no next-question control is shown before submitting',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async => (question: _question2, optionSeed: 7),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Next question'), findsNothing);
      },
    );

    testWidgets(
      'tapping Next question advances in place: new stem, cleared selection, '
      're-enabled options, hidden explanation',
      (tester) async {
        var loaderCalls = 0;
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async {
            loaderCalls++;
            return (question: _question2, optionSeed: 7);
          },
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Next question'), findsOneWidget);
        expect(find.text('Explanation'), findsOneWidget);

        await tester.tap(find.text('Next question'));
        await tester.pumpAndSettle();

        expect(loaderCalls, 1);
        expect(find.text('What is 3 + 3?'), findsOneWidget);
        expect(find.text('What is 2 + 2?'), findsNothing);
        expect(find.text('Explanation'), findsNothing);

        // Options re-enabled and selection cleared: submit hidden until an
        // option is picked, and it's un-selected (disabled) right now.
        expect(find.text('Submit'), findsOneWidget);

        await tester.tap(find.text('6'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Correct!'), findsOneWidget);
      },
    );

    testWidgets(
      'advancing does not push a new route',
      (tester) async {
        final observer = _PushCounter();
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async => (question: _question2, optionSeed: 7),
          navigatorObservers: [observer],
        ));
        await tester.pumpAndSettle();
        final pushesBeforeAnswering = observer.pushes;

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next question'));
        await tester.pumpAndSettle();

        expect(observer.pushes, pushesBeforeAnswering);
      },
    );
  });

  group('auto-advance', () {
    testWidgets(
      'an idle user is carried to the next question after the feedback pause',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async => (question: _question2, optionSeed: 7),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Next question in'), findsOneWidget);

        // Drive the periodic timer with `pump`, never `pumpAndSettle` — a
        // periodic timer never settles.
        await tester.pump(const Duration(seconds: 6));
        // Flush the loader's Future and the resulting rebuild.
        await tester.pump();
        await tester.pump();

        expect(find.text('What is 3 + 3?'), findsOneWidget);
      },
    );

    testWidgets(
      'Stay on this question cancels the pending advance',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async => (question: _question2, optionSeed: 7),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Scroll the body into view without `pumpAndSettle` — a periodic
        // timer is already running and would never let it settle.
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
        await tester.tap(find.text('Stay on this question'));
        await tester.pump();

        // Pump well past the pause: the same question stays on screen.
        await tester.pump(const Duration(seconds: 10));

        // The body is scrolled from the drag above, so the question stem is
        // geometrically offstage (outside the viewport) even though it's
        // still mounted — `skipOffstage: false` looks at the whole tree
        // rather than only what's currently painted.
        expect(find.text('What is 2 + 2?', skipOffstage: false), findsOneWidget);
        expect(find.text('Next question', skipOffstage: false), findsOneWidget);
        expect(find.textContaining('Next question in', skipOffstage: false),
            findsNothing);
      },
    );

    testWidgets(
      'tapping Next question manually cancels the pending timer so the '
      'advance happens exactly once',
      (tester) async {
        var loaderCalls = 0;
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async {
            loaderCalls++;
            return (question: _question2, optionSeed: 7);
          },
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Next question'));
        await tester.pumpAndSettle();

        // Well past the original pause: if the timer weren't cancelled by
        // the manual tap, this would fire a second advance.
        await tester.pump(const Duration(seconds: 10));

        expect(loaderCalls, 1);
      },
    );

    testWidgets(
      'an exhausted queue shows a caught-up message instead of advancing',
      (tester) async {
        await tester.pumpWidget(_buildSubject(
          storageService,
          readOnly: false,
          onRequestNext: () async => null,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
        await tester.pump();

        expect(find.text('Next question'), findsNothing);
        expect(find.textContaining('caught up'), findsOneWidget);
        expect(find.text('Back to question list'), findsOneWidget);
        expect(find.text('Explanation'), findsOneWidget);
      },
    );

    testWidgets(
      'popping the screen while a countdown is pending produces no '
      'setState-after-dispose error',
      (tester) async {
        await tester.pumpWidget(_buildPushableSubject(
          storageService,
          onRequestNext: () async => (question: _question2, optionSeed: 7),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        // Countdown pending; pop before it elapses.
        Navigator.of(tester.element(find.byType(QuestionScreen))).pop();
        await tester.pumpAndSettle();

        await tester.pump(const Duration(seconds: 10));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
