import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'package:enchiridion/config/pricing_config.dart';

SubscriptionOfferDetailsWrapper playOffer({
  required String basePlanId,
  required String formattedPrice,
  required int priceMicros,
  String? offerId,
  String billingPeriod = 'P1M',
}) {
  return SubscriptionOfferDetailsWrapper(
    basePlanId: basePlanId,
    offerId: offerId,
    offerTags: const [],
    offerIdToken: 'token-$basePlanId-${offerId ?? 'base'}',
    pricingPhases: [
      PricingPhaseWrapper(
        billingCycleCount: 0,
        billingPeriod: billingPeriod,
        formattedPrice: formattedPrice,
        priceAmountMicros: priceMicros,
        priceCurrencyCode: 'NGN',
        recurrenceMode: RecurrenceMode.infiniteRecurring,
      ),
    ],
  );
}

List<GooglePlayProductDetails> premiumPlayProducts({
  int monthlyMicros = 1500000000,
  int annualMicros = 15000000000,
  bool includeIntroductoryOffer = true,
}) {
  return GooglePlayProductDetails.fromProductDetails(
    ProductDetailsWrapper(
      description: 'Enchiridion Premium',
      name: 'Premium',
      productId: kPlayPremiumProductId,
      productType: ProductType.subs,
      title: 'Premium (Enchiridion)',
      subscriptionOfferDetails: [
        if (includeIntroductoryOffer)
          playOffer(
            basePlanId: 'premium-monthly',
            offerId: 'intro',
            formattedPrice: 'NGN 500.00',
            priceMicros: 500000000,
          ),
        playOffer(
          basePlanId: 'premium-monthly',
          formattedPrice: 'NGN 1,500.00',
          priceMicros: monthlyMicros,
        ),
        playOffer(
          basePlanId: 'premium-annual',
          formattedPrice: 'NGN 15,000.00',
          priceMicros: annualMicros,
          billingPeriod: 'P1Y',
        ),
      ],
    ),
  );
}
