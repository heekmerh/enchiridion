import 'package:flutter/material.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/flutterwave_config.dart';
import '../config/pricing_config.dart';
import 'access_service.dart';
import 'auth_service.dart';

enum PaymentOutcome { success, cancelled, failed }

/// Runs a Flutterwave checkout for [PricingPlan] and grants access on
/// success.
///
/// This client never grants access itself — `user_book_access` has no
/// client-writable INSERT/UPDATE policy on purpose (see the note in
/// scripts/sql/000_init_database.sql), because a client that could grant
/// its own access wouldn't need to pay at all. [purchase] only launches the
/// checkout, then hands the resulting transaction id to the
/// verify-flutterwave-payment Edge Function, which is the only thing that
/// actually writes `user_book_access` — using Flutterwave's own SECRET-key
/// verification of what was actually paid, not anything this client claims.
class PaymentService {
  Future<PaymentOutcome> purchase({
    required BuildContext context,
    required PricingPlan plan,
    required String bookId,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) return PaymentOutcome.failed;

    final txRef = 'enchiridion-${user.id}-${plan.id}-$bookId-'
        '${DateTime.now().millisecondsSinceEpoch}';

    final flutterwave = Flutterwave(
      publicKey: flutterwavePublicKey,
      currency: flutterwaveCurrency,
      redirectUrl: flutterwaveRedirectUrl,
      txRef: txRef,
      amount: plan.amount.toString(),
      customer: Customer(email: user.email ?? ''),
      paymentOptions: 'card,banktransfer,ussd',
      customization: Customization(title: 'Enchiridion'),
      isTestMode: flutterwaveIsTestMode,
      // A hint for the Edge Function, not a trusted source of pricing — see
      // its own price table. user_id lets it sanity-check the grant target
      // against the authenticated caller, but the caller's own verified
      // session (via the Authorization header it forwards) is what the
      // function actually grants access to.
      meta: {'plan_id': plan.id, 'book_id': bookId, 'user_id': user.id},
    );

    final response = await flutterwave.charge(context);
    if (response.success != true || response.transactionId == null) {
      return response.status == 'cancelled'
          ? PaymentOutcome.cancelled
          : PaymentOutcome.failed;
    }

    try {
      final result = await Supabase.instance.client.functions.invoke(
        'verify-flutterwave-payment',
        body: {'transaction_id': response.transactionId},
      );
      final data = result.data;
      final granted = data is Map && data['granted'] == true;
      if (granted) {
        // The just-granted row won't be in the cache yet; force a reload so
        // AccessService reflects it before the caller checks again.
        await AccessService.instance.loadAccess();
      }
      return granted ? PaymentOutcome.success : PaymentOutcome.failed;
    } catch (_) {
      return PaymentOutcome.failed;
    }
  }
}
