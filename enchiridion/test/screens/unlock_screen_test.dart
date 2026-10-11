import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:enchiridion/constants/billing_copy.dart';
import 'package:enchiridion/screens/unlock_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/play_billing_service.dart';

import '../support/play_products.dart';

class FakeStore extends Fake implements InAppPurchase {
  final List<ProductDetails> products;
  final bool available;

  FakeStore({required this.products, this.available = true});

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
          Set<String> identifiers) async =>
      ProductDetailsResponse(productDetails: products, notFoundIDs: const []);
}

class UnusedVerifier implements PurchaseVerifier {
  @override
  Future<PlayVerificationResult> verify(
          {required String purchaseToken, required String productId}) =>
      throw UnimplementedError();
}

PlayBillingService billingWith(FakeStore store) =>
    PlayBillingService(purchases: () => store, verifier: UnusedVerifier());

Future<void> pumpUnlock(WidgetTester tester, PlayBillingService billing) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: UnlockScreen(billing: billing)));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AccessService.testAccessOverride = null);

  testWidgets(
      'shows Google Play localized prices and Google Play billing terms',
      (tester) async {
    AccessService.testAccessOverride = false;
    await pumpUnlock(
        tester, billingWith(FakeStore(products: premiumPlayProducts())));

    expect(find.text('Monthly — NGN 1,500.00'), findsOneWidget);
    expect(find.text('Annual — NGN 15,000.00'), findsOneWidget);
    expect(find.text('Subscribe Monthly'), findsOneWidget);
    expect(find.text('Subscribe Annually'), findsOneWidget);
    expect(find.text('Save compared with twelve monthly payments.'),
        findsOneWidget);
    expect(find.text(BillingCopy.googlePlayProcessing), findsOneWidget);
    expect(find.textContaining('enchiridion.site'), findsNothing);
    expect(find.textContaining('Flutterwave'), findsNothing);
  });

  testWidgets(
      'an account that already has Premium is not offered another subscription',
      (tester) async {
    AccessService.testAccessOverride = true;
    await pumpUnlock(
        tester, billingWith(FakeStore(products: premiumPlayProducts())));

    expect(find.text(BillingCopy.existingSubscription), findsOneWidget);
    expect(find.text('Subscribe Monthly'), findsNothing);
  });

  testWidgets('explains when Google Play Billing is unavailable',
      (tester) async {
    AccessService.testAccessOverride = false;
    await pumpUnlock(
        tester, billingWith(FakeStore(products: const [], available: false)));

    expect(find.text(BillingCopy.billingUnavailable), findsOneWidget);
    expect(find.text('Subscribe Monthly'), findsNothing);
  });
}
