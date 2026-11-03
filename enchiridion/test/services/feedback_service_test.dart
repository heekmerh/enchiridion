import 'dart:async';

import 'package:enchiridion/services/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _validMessage = 'The reader crashes when I open chapter two.';

void main() {
  group('FeedbackService.validateMessage', () {
    const blankCopy = 'Please write your feedback.';
    const shortCopy =
        'Please add a little more detail (at least 10 characters).';
    const longCopy = 'Please keep it to 2000 characters or fewer.';

    test('rejects null, empty and whitespace-only input as blank', () {
      expect(FeedbackService.validateMessage(null), blankCopy);
      expect(FeedbackService.validateMessage(''), blankCopy);
      expect(FeedbackService.validateMessage(' \n\t \n '), blankCopy);
    });

    test('rejects 9 characters and accepts exactly 10', () {
      expect(FeedbackService.validateMessage('a' * 9), shortCopy);
      expect(FeedbackService.validateMessage('a' * 10), isNull);
    });

    test('accepts exactly 2000 characters and rejects 2001', () {
      expect(FeedbackService.validateMessage('a' * 2000), isNull);
      expect(FeedbackService.validateMessage('a' * 2001), longCopy);
    });

    test('counts code points rather than UTF-16 units', () {
      expect(FeedbackService.validateMessage('😀' * 5), shortCopy);
      expect(FeedbackService.validateMessage('😀' * 10), isNull);
    });

    test('measures the trimmed message', () {
      expect(FeedbackService.validateMessage('   ${'a' * 9}   '), shortCopy);
    });
  });

  group('FeedbackService.submit', () {
    late List<Map<String, dynamic>> rows;

    setUp(() => rows = []);

    FeedbackService buildService({
      String? userId = 'user-1',
      Future<void> Function(Map<String, dynamic> row)? insertRow,
      Duration submitTimeout = const Duration(seconds: 15),
    }) {
      return FeedbackService(
        insertRow: insertRow ?? (row) async => rows.add(row),
        currentUserId: () => userId,
        platform: () => 'android',
        submitTimeout: submitTimeout,
      );
    }

    test('reports sign-in state from the current user id', () {
      expect(buildService().isSignedIn, isTrue);
      expect(buildService(userId: null).isSignedIn, isFalse);
    });

    test('throws sign-in required without a user and inserts nothing', () async {
      final service = buildService(userId: null);

      await expectLater(
        service.submit(
          category: FeedbackCategory.complaint,
          message: _validMessage,
        ),
        throwsA(isA<FeedbackSignInRequiredException>()),
      );
      expect(rows, isEmpty);
    });

    test('throws ArgumentError for an invalid message and inserts nothing',
        () async {
      final service = buildService();

      await expectLater(
        service.submit(category: FeedbackCategory.other, message: 'short'),
        throwsArgumentError,
      );
      expect(rows, isEmpty);
    });

    test('maps every category to its storage value and trims the message',
        () async {
      final service = buildService();

      for (final category in FeedbackCategory.values) {
        await service.submit(
          category: category,
          message: '  $_validMessage  ',
        );
      }

      expect(rows.map((row) => row['category']), [
        'complaint',
        'feature_request',
        'other',
      ]);
      expect(rows.every((row) => row['message'] == _validMessage), isTrue);
      expect(rows.first, {
        'user_id': 'user-1',
        'category': 'complaint',
        'message': _validMessage,
        'platform': 'android',
      });
    });

    test('propagates an insert failure', () async {
      final service = buildService(
        insertRow: (_) async => throw StateError('insert failed'),
      );

      await expectLater(
        service.submit(
          category: FeedbackCategory.complaint,
          message: _validMessage,
        ),
        throwsStateError,
      );
    });

    test('throws TimeoutException when the insert never completes', () async {
      final service = buildService(
        insertRow: (_) => Completer<void>().future,
        submitTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.submit(
          category: FeedbackCategory.complaint,
          message: _validMessage,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
