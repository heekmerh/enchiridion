import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/backend_config.dart';
import '../config/pricing_config.dart';
import '../config/purchasing_policy.dart';
import '../constants/billing_copy.dart';
import 'access_service.dart';
import 'auth_service.dart';

enum PurchaseFlowState {
  idle,
  loading,
  ready,
  purchasing,
  verifying,
  pending,
  success,
  failed
}

class PremiumOffer {
  final PremiumPlan plan;
  final ProductDetails details;

  const PremiumOffer({required this.plan, required this.details});

  String get price => details.price;
}

class PlayVerificationResult {
  final String status;
  final bool premium;
  final String message;

  const PlayVerificationResult({
    required this.status,
    required this.premium,
    required this.message,
  });

  bool get isPending => status == 'pending';
}

class PlayVerificationException implements Exception {
  final String message;
  final bool belongsToAnotherAccount;

  const PlayVerificationException(this.message,
      {this.belongsToAnotherAccount = false});
}

abstract class PurchaseVerifier {
  Future<PlayVerificationResult> verify({
    required String purchaseToken,
    required String productId,
  });
}

class BackendPurchaseVerifier implements PurchaseVerifier {
  static const Duration _timeout = Duration(seconds: 20);
  static const int _conflictStatus = 409;

  final http.Client _client;

  BackendPurchaseVerifier(this._client);

  @override
  Future<PlayVerificationResult> verify({
    required String purchaseToken,
    required String productId,
  }) async {
    final accessToken = AuthService.currentSession?.accessToken;
    if (accessToken == null) {
      throw const PlayVerificationException(BillingCopy.verificationFailed);
    }
    final response = await _client
        .post(
          Uri.parse('$kBackendBaseUrl/api/v1/payments/google/verify'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(
              {'purchase_token': purchaseToken, 'product_id': productId}),
        )
        .timeout(_timeout);
    if (response.statusCode == _conflictStatus) {
      throw const PlayVerificationException(
        BillingCopy.belongsToAnotherAccount,
        belongsToAnotherAccount: true,
      );
    }
    if (response.statusCode != 200) {
      throw const PlayVerificationException(BillingCopy.verificationFailed);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PlayVerificationResult(
      status: body['status'] as String? ?? 'pending',
      premium: body['premium'] as bool? ?? false,
      message: body['message'] as String? ?? BillingCopy.paymentProcessing,
    );
  }
}

String? basePlanIdOf(ProductDetails details) {
  if (details is! GooglePlayProductDetails) return null;
  final index = details.subscriptionIndex;
  final offers = details.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index >= offers.length) return null;
  final offer = offers[index];
  return offer.offerId == null ? offer.basePlanId : null;
}

List<PremiumOffer> premiumOffersFrom(
  Iterable<ProductDetails> products, {
  String? Function(ProductDetails) basePlanOf = basePlanIdOf,
}) {
  final offers = <PremiumOffer>[];
  for (final plan in kPremiumPlans) {
    for (final product in products) {
      if (product.id == kPlayPremiumProductId &&
          basePlanOf(product) == plan.basePlanId) {
        offers.add(PremiumOffer(plan: plan, details: product));
        break;
      }
    }
  }
  return offers;
}

class PlayBillingService extends ChangeNotifier {
  static final PlayBillingService instance = PlayBillingService(
    purchases: () => InAppPurchase.instance,
    verifier: BackendPurchaseVerifier(http.Client()),
  );

  final InAppPurchase Function() _purchases;
  final PurchaseVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _purchaseUpdates;
  bool _reportOutcome = false;

  PurchaseFlowState state = PurchaseFlowState.idle;
  String? message;
  List<PremiumOffer> offers = const [];

  PlayBillingService({
    required InAppPurchase Function() purchases,
    required PurchaseVerifier verifier,
  })  : _purchases = purchases,
        _verifier = verifier;

  bool get isAvailableOnThisPlatform =>
      currentPurchasingPolicy.allowsInAppPurchase;

  void start() {
    if (_purchaseUpdates != null || !isAvailableOnThisPlatform) return;
    _purchaseUpdates = _purchases().purchaseStream.listen(
          handlePurchaseUpdates,
          onError: (_) =>
              _update(PurchaseFlowState.failed, BillingCopy.verificationFailed),
        );
  }

  Future<void> loadOffers() async {
    if (!isAvailableOnThisPlatform) return;
    _update(PurchaseFlowState.loading, null);
    try {
      final store = _purchases();
      if (!await store.isAvailable()) {
        _update(PurchaseFlowState.failed, BillingCopy.billingUnavailable);
        return;
      }
      final response = await store.queryProductDetails({kPlayPremiumProductId});
      offers = premiumOffersFrom(response.productDetails);
      _update(
        offers.isEmpty ? PurchaseFlowState.failed : PurchaseFlowState.ready,
        offers.isEmpty ? BillingCopy.billingUnavailable : null,
      );
    } catch (_) {
      _update(PurchaseFlowState.failed, BillingCopy.billingUnavailable);
    }
  }

  Future<void> buy(PremiumOffer offer) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    _reportOutcome = true;
    _update(PurchaseFlowState.purchasing, null);
    try {
      final started = await _purchases().buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: offer.details,
          applicationUserName: user.id,
        ),
      );
      if (!started) {
        _update(PurchaseFlowState.failed, BillingCopy.billingUnavailable);
      }
    } catch (_) {
      _update(PurchaseFlowState.failed, BillingCopy.billingUnavailable);
    }
  }

  Future<void> restore({bool reportOutcome = true}) async {
    final user = AuthService.currentUser;
    if (user == null || !isAvailableOnThisPlatform) return;
    _reportOutcome = reportOutcome;
    try {
      await _purchases().restorePurchases(applicationUserName: user.id);
    } catch (_) {
      if (reportOutcome) {
        _update(PurchaseFlowState.failed, BillingCopy.billingUnavailable);
      }
    }
  }

  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kPlayPremiumProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _report(PurchaseFlowState.pending, BillingCopy.paymentProcessing);
        case PurchaseStatus.canceled:
          _report(PurchaseFlowState.ready, null);
        case PurchaseStatus.error:
          _report(PurchaseFlowState.failed,
              purchase.error?.message ?? BillingCopy.billingUnavailable);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(purchase);
      }
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    if (AuthService.currentUser == null) return;
    _report(PurchaseFlowState.verifying, BillingCopy.paymentProcessing);
    try {
      final result = await _verifier.verify(
        purchaseToken: purchase.verificationData.serverVerificationData,
        productId: purchase.productID,
      );
      if (result.isPending) {
        _report(PurchaseFlowState.pending, BillingCopy.paymentProcessing);
        return;
      }
      // Only completed after the server has verified and recorded the purchase, so an unverified one is never acknowledged.
      if (purchase.pendingCompletePurchase) {
        await _purchases().completePurchase(purchase);
      }
      await AccessService.instance.loadAccess();
      _report(
        result.premium ? PurchaseFlowState.success : PurchaseFlowState.failed,
        result.premium ? BillingCopy.purchaseVerified : result.message,
      );
    } on PlayVerificationException catch (error) {
      _report(PurchaseFlowState.failed, error.message);
    } catch (_) {
      _report(PurchaseFlowState.failed, BillingCopy.verificationFailed);
    }
  }

  void _report(PurchaseFlowState next, String? text) {
    if (_reportOutcome) _update(next, text);
  }

  void _update(PurchaseFlowState next, String? text) {
    state = next;
    message = text;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseUpdates?.cancel();
    super.dispose();
  }
}
