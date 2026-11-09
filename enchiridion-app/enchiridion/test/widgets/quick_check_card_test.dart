import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/providers/study_stats_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/services/study_stats_service.dart';
import 'package:enchiridion/widgets/exam_prep/quick_check_card.dart';

const _question = Question(
  id: 'q-bubble-1',
  questionText: 'Which value is even?',
  options: {'a': '1', 'b': '2', 'c': '3', 'd': '4'},
  correctOption: 'b',
  explanation: 'Two is even.',
  questionNumber: 1,
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
      home: QuickCheckCard(question: _question, onDismiss: () {}),
    ),
  );
}

/// Mirrors the bubble overlay engine (bubble_main.dart before the provider
/// was added there): only StorageService, no StudyStatsProvider.
Widget _buildProviderlessSubject(StorageService storage) {
  return Provider<StorageService>.value(
    value: storage,
    child: MaterialApp(
      home: QuickCheckCard(question: _question, onDismiss: () {}),
    ),
  );
}

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = StorageService(prefs);
  });

  testWidgets('avatar letters read A, B, C, D top to bottom', (tester) async {
    await tester.pumpWidget(_buildSubject(storage));
    await tester.pumpAndSettle();

    final letters = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.byType(Text),
        ))
        .map((w) => w.data!)
        .toList();
    expect(letters, orderedEquals(['A', 'B', 'C', 'D']));
  });

  testWidgets('tapping the correct-text row scores correct', (tester) async {
    await tester.pumpWidget(_buildSubject(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(
      find.text('Correct'),
      findsOneWidget,
      reason:
          'the verdict follows the option key, never the letter the shuffle handed the row',
    );
  });

  testWidgets('tapping a wrong-text row scores wrong', (tester) async {
    await tester.pumpWidget(_buildSubject(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not quite'),
      findsOneWidget,
      reason:
          'the verdict follows the option key, never the letter the shuffle handed the row',
    );
  });

  testWidgets(
      'without a StudyStatsProvider in the tree (bubble overlay) the answer '
      'still submits and still counts toward stats', (tester) async {
    // Regression: the bubble engine provided only StorageService, so the
    // provider read threw after the answer was stored — stats, the rebound
    // notification and the remote push never ran. A silently half-recorded
    // answer, invisible to the dashboard.
    await tester.pumpWidget(_buildProviderlessSubject(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final totals = StudyStatsService(storage).getLifetimeTotals();
    expect(totals.questionsAnswered, 1);
    expect(totals.correctAnswers, 1);
  });
}
