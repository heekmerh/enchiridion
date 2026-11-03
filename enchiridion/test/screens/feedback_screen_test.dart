import 'dart:async';

import 'package:enchiridion/screens/feedback_screen.dart';
import 'package:enchiridion/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _signInCopy = 'Sign in to send feedback.';
const _failureCopy =
    "Couldn't send your feedback. Check your connection and try again — "
    'your message is still here.';
const _validMessage = 'Please add a dark reading mode.';

Future<void> _openFeedback(WidgetTester tester, FeedbackService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedbackScreen(service: service),
                ),
              ),
              child: const Text('Open feedback'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open feedback'));
  await tester.pumpAndSettle();
}

Future<void> _chooseCategory(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Send'));
  await tester.tap(find.text('Send'));
}

void main() {
  late List<Map<String, dynamic>> rows;
  String? userId;

  setUp(() {
    rows = [];
    userId = 'user-1';
  });

  FeedbackService buildService({
    Future<void> Function(Map<String, dynamic> row)? insertRow,
  }) {
    return FeedbackService(
      insertRow: insertRow ?? (row) async => rows.add(row),
      currentUserId: () => userId,
    );
  }

  testWidgets('signed-in user sends feedback and the screen closes',
      (tester) async {
    await _openFeedback(tester, buildService());
    await _chooseCategory(tester, 'Feature request');
    await tester.enterText(find.byType(TextFormField), '  $_validMessage  ');
    await _tapSend(tester);
    await tester.pumpAndSettle();

    expect(rows, [
      {
        'user_id': 'user-1',
        'category': 'feature_request',
        'message': _validMessage,
        'platform': 'android',
      },
    ]);
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.text('Thanks — your feedback has been sent.'), findsOneWidget);
  });

  testWidgets('signed-out user sees the sign-in notice instead of the form',
      (tester) async {
    userId = null;
    await _openFeedback(tester, buildService());

    expect(find.text(_signInCopy), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Send'), findsNothing);
  });

  testWidgets('a session ending before send shows the sign-in message',
      (tester) async {
    await _openFeedback(tester, buildService());
    await _chooseCategory(tester, 'Complaint');
    await tester.enterText(find.byType(TextFormField), _validMessage);
    userId = null;
    await _tapSend(tester);
    await tester.pumpAndSettle();

    expect(find.text(_signInCopy), findsOneWidget);
    expect(find.text(_failureCopy), findsNothing);
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(rows, isEmpty);
  });

  testWidgets('an untouched form shows both errors and sends nothing',
      (tester) async {
    await _openFeedback(tester, buildService());
    await _tapSend(tester);
    await tester.pumpAndSettle();

    expect(find.text('Choose what this feedback is about.'), findsOneWidget);
    expect(find.text('Please write your feedback.'), findsOneWidget);
    expect(rows, isEmpty);
  });

  testWidgets('a too-short message shows the detail error and sends nothing',
      (tester) async {
    await _openFeedback(tester, buildService());
    await _chooseCategory(tester, 'Other');
    await tester.enterText(find.byType(TextFormField), 'a' * 9);
    await _tapSend(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Please add a little more detail (at least 10 characters).'),
      findsOneWidget,
    );
    expect(rows, isEmpty);
  });

  testWidgets('an insert failure keeps the screen, the text and the button',
      (tester) async {
    final service = buildService(
      insertRow: (_) async => throw StateError('insert failed'),
    );
    await _openFeedback(tester, service);
    await _chooseCategory(tester, 'Complaint');
    await tester.enterText(find.byType(TextFormField), _validMessage);
    await _tapSend(tester);
    await tester.pumpAndSettle();

    expect(find.text(_failureCopy), findsOneWidget);
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text(_validMessage), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('tapping Send twice while sending inserts once', (tester) async {
    final pendingInsert = Completer<void>();
    var insertCalls = 0;
    final service = buildService(
      insertRow: (_) {
        insertCalls++;
        return pendingInsert.future;
      },
    );
    await _openFeedback(tester, service);
    await _chooseCategory(tester, 'Other');
    await tester.enterText(find.byType(TextFormField), _validMessage);
    await _tapSend(tester);
    await tester.pump();
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    expect(insertCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingInsert.complete();
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackScreen), findsNothing);
    expect(insertCalls, 1);
  });
}
