import 'package:flutter/foundation.dart';

class PurchasingPolicy {
  final bool googlePlayBilling;
  final bool flutterwaveInApp;
  final bool externalCheckoutLink;
  final bool externalOffersEnrolled;
  final bool externalAccountManagementLink;

  const PurchasingPolicy({
    required this.googlePlayBilling,
    required this.flutterwaveInApp,
    required this.externalCheckoutLink,
    required this.externalOffersEnrolled,
    required this.externalAccountManagementLink,
  });

  bool get allowsInAppPurchase => googlePlayBilling;
}

// External purchasing stays off everywhere until Play programme enrolment is verified; device region, SIM or IP never enable it.
const kGooglePlayPurchasingPolicy = PurchasingPolicy(
  googlePlayBilling: true,
  flutterwaveInApp: false,
  externalCheckoutLink: false,
  externalOffersEnrolled: false,
  externalAccountManagementLink: false,
);

const kNoPurchasingPolicy = PurchasingPolicy(
  googlePlayBilling: false,
  flutterwaveInApp: false,
  externalCheckoutLink: false,
  externalOffersEnrolled: false,
  externalAccountManagementLink: false,
);

PurchasingPolicy purchasingPolicyFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb || platform != TargetPlatform.android) return kNoPurchasingPolicy;
  return kGooglePlayPurchasingPolicy;
}

PurchasingPolicy get currentPurchasingPolicy =>
    purchasingPolicyFor(isWeb: kIsWeb, platform: defaultTargetPlatform);
