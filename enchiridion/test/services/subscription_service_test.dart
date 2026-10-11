import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/services/subscription_service.dart';

void main() {
  test('parses a Google Play subscription row from get_my_subscription', () {
    final status = SubscriptionStatus.fromRow({
      'plan_id': 'premium_annual',
      'provider': 'google_play',
      'internal_state': 'GRACE_PERIOD',
      'auto_renewing': true,
      'current_period_end': '2027-01-01T00:00:00Z',
      'access_expires_at': '2027-01-04T00:00:00Z',
      'product_id': 'enchiridion_premium',
    });

    expect(status.isGooglePlay, isTrue);
    expect(status.renewsAutomatically, isTrue);
    expect(status.endsOn, DateTime.utc(2027, 1, 4));
  });

  test(
      'a cancelled website subscription does not renew and a failed payment is flagged',
      () {
    final cancelled = SubscriptionStatus.fromRow({
      'provider': 'flutterwave',
      'internal_state': 'CANCELLED',
      'auto_renewing': false
    });
    final onHold = SubscriptionStatus.fromRow({
      'provider': 'google_play',
      'internal_state': 'PAYMENT_FAILED',
      'auto_renewing': true
    });

    expect(cancelled.isGooglePlay, isFalse);
    expect(cancelled.renewsAutomatically, isFalse);
    expect(onHold.renewsAutomatically, isFalse);
    expect(onHold.hasPaymentProblem, isTrue);
  });
}
