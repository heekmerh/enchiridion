import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/config/purchasing_policy.dart';

void main() {
  test('Android uses Google Play Billing with every external route disabled',
      () {
    final policy =
        purchasingPolicyFor(isWeb: false, platform: TargetPlatform.android);

    expect(policy.googlePlayBilling, isTrue);
    expect(policy.flutterwaveInApp, isFalse);
    expect(policy.externalCheckoutLink, isFalse);
    expect(policy.externalOffersEnrolled, isFalse);
    expect(policy.externalAccountManagementLink, isFalse);
  });

  test('platforms without an approved billing integration cannot purchase', () {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.linux
    ]) {
      expect(
          purchasingPolicyFor(isWeb: false, platform: platform)
              .allowsInAppPurchase,
          isFalse);
    }
    expect(
        purchasingPolicyFor(isWeb: true, platform: TargetPlatform.android)
            .allowsInAppPurchase,
        isFalse);
  });
}
