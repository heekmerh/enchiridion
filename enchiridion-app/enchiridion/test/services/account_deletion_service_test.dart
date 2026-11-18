import 'dart:convert';

import 'package:enchiridion/services/account_deletion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status);

void main() {
  test('a 200 response means the account was deleted', () {
    final result = accountDeletionResultFrom(_json(200, {'deleted': true}));
    expect(result.isDeleted, isTrue);
    expect(result.message, kAccountDeleted);
  });

  test('a renewing Google Play subscription asks the user to cancel first', () {
    final result = accountDeletionResultFrom(_json(409, {
      'detail': {
        'code': 'cancel_google_play_first',
        'message': 'Cancel it in Google Play first.',
        'url': 'https://play.google.com/store/account/subscriptions',
      }
    }));
    expect(result.outcome, AccountDeletionOutcome.cancelGooglePlayFirst);
    expect(result.message, 'Cancel it in Google Play first.');
    expect(result.manageUrl, contains('play.google.com'));
  });

  test('other refusals pass the server message through', () {
    final result = accountDeletionResultFrom(_json(409, {
      'detail': {'code': 'payouts_on_record', 'message': 'Email support.'}
    }));
    expect(result.outcome, AccountDeletionOutcome.refused);
    expect(result.message, 'Email support.');
  });

  test('server errors fall back to a retry message', () {
    final result = accountDeletionResultFrom(http.Response('oops', 500));
    expect(result.outcome, AccountDeletionOutcome.failed);
    expect(result.message, kAccountDeletionFailed);
  });
}
