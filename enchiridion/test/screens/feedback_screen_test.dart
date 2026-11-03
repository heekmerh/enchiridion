import 'package:enchiridion/screens/feedback_screen.dart';
import 'package:enchiridion/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('signed-in user sends feedback and the screen closes',
      (tester) async {
    final rows = <Map<String, dynamic>>[];
    final service = FeedbackService(
      insertRow: (row) async => rows.add(row),
      currentUserId: () => 'user-1',
    );

    await _openFeedback(tester, service);
    await tester.tap(find.text('Feature request'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField),
      '  Please add a dark reading mode.  ',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(rows, [
      {
        'user_id': 'user-1',
        'category': 'feature_request',
        'message': 'Please add a dark reading mode.',
        'platform': 'android',
      },
    ]);
    expect(find.byType(FeedbackScreen), findsNothing);
    expect(find.text('Thanks — your feedback has been sent.'), findsOneWidget);
  });
}
