import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:enchiridion/config/pricing_config.dart';
import 'package:enchiridion/screens/unlock_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/play_billing_service.dart';

import '../support/play_products.dart';

void main() {
  group('premiumOffersFrom', () {
    test('selects the plain base plan for each Premium plan, in display order',
        () {
      final offers = premiumOffersFrom(premiumPlayProducts());

      expect(offers.map((offer) => offer.plan),
          [kPremiumMonthlyPlan, kPremiumAnnualPlan]);
      expect(offers.first.price, 'NGN 1,500.00');
      expect(offers.last.price, 'NGN 15,000.00');
    });

    test('ignores products that are not the Premium subscription', () {
      final unrelated = ProductDetails(
        id: 'some_other_product',
        title: 'Other',
        description: '',
        price: 'NGN 1.00',
        rawPrice: 1,
        currencyCode: 'NGN',
      );

      expect(premiumOffersFrom([unrelated]), isEmpty);
    });

    test('omits a plan whose base plan is not configured in Play Console', () {
      final offers = premiumOffersFrom(premiumPlayProducts(),
          basePlanOf: (details) => basePlanIdOf(details) == 'premium-annual'
              ? null
              : basePlanIdOf(details));

      expect(offers.map((offer) => offer.plan), [kPremiumMonthlyPlan]);
    });
  });

  group('annualSavingsLabel', () {
    test('claims savings only when Google Play prices support it', () {
      expect(annualSavingsLabel(premiumOffersFrom(premiumPlayProducts())),
          'Save compared with twelve monthly payments.');
      expect(
        annualSavingsLabel(
            premiumOffersFrom(premiumPlayProducts(annualMicros: 18000000000))),
        isNull,
      );
    });
  });

  test('the server premium feature maps to full access', () {
    expect(scopeForFeature(kPremiumFeature), kFullAccessScope);
    expect(scopeForFeature('paediatrics'), 'paediatrics');
  });
}
