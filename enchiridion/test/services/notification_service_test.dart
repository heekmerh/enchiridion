import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/models/question_review.dart';
import 'package:enchiridion/services/notification_service.dart';

void main() {
  group('notificationTeaser', () {
    test('flattens multiline stems', () {
      expect(notificationTeaser('A 5 year old boy.\nWhat is the\n\nnext step?'),
          'A 5 year old boy. What is the next step?');
    });

    test('returns short text unchanged', () {
      expect(notificationTeaser('Short question?'), 'Short question?');
    });

    test('caps long text at 160 characters and appends ellipsis', () {
      expect(notificationTeaser('a' * 160), 'a' * 160);
      expect(notificationTeaser('a' * 161), '${'a' * 160}…');
    });

    test('measures length after flattening', () {
      expect(notificationTeaser('${'a' * 158}\n\nb'), '${'a' * 158} b');
    });
  });

  test(
      'scheduleFollowUp and cancelFollowUp no-op before initialize() has '
      'run', () async {
    // NotificationService is a process-wide singleton whose initialize()
    // touches real platform channels that flutter_test never mocks. Every
    // call site in the app — QuestionScreen, the Quick Check sheet,
    // ExamPrepHomeScreen — calls scheduleFollowUp() right after recording an
    // answer regardless of whether initialize() ever succeeded, exactly as
    // it never does under flutter_test. If the internal `_initialized`
    // guard were ever removed, this test would hang or throw instead of
    // completing.
    const question = Question(
      id: 'q-1',
      questionText: 'Test question',
      options: {'a': '1', 'b': '2'},
      correctOption: 'a',
      explanation: 'Because.',
      questionNumber: 1,
    );
    final review = QuestionReview.initial('q-1');

    await NotificationService.instance.scheduleFollowUp(
      scope: 'exam_prep',
      question: question,
      review: review,
    );
    await NotificationService.instance.cancelFollowUp('exam_prep', 'q-1');
  });
}
