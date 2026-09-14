/// A purchasable access window. Enchiridion does not use Flutterwave's
/// recurring/subscription billing — every purchase is a one-time charge
/// that grants access for [accessDays], tracked via
/// `user_book_access.expires_at`; the user pays again to renew. Amounts are
/// in [flutterwaveCurrency] (see flutterwave_config.dart).
///
/// [id] is sent to the verify-flutterwave-payment Edge Function as a hint
/// for which plan was intended — the function's own hardcoded price table
/// is what's actually trusted, so [id] here MUST match a key there (see
/// supabase/functions/verify-flutterwave-payment/index.ts).
class PricingPlan {
  final String id;
  final String label;
  final int amount;
  final int accessDays;

  const PricingPlan({
    required this.id,
    required this.label,
    required this.amount,
    required this.accessDays,
  });
}

const kBookUnlockPlan = PricingPlan(
  id: 'book_monthly',
  label: 'Unlock — ₦1,000/month',
  amount: 1000,
  accessDays: 30,
);

const kSubscriptionMonthlyPlan = PricingPlan(
  id: 'sub_monthly',
  label: 'Monthly — ₦1,000',
  amount: 1000,
  accessDays: 30,
);

const kSubscriptionYearlyPlan = PricingPlan(
  id: 'sub_yearly',
  label: 'Yearly — ₦10,000',
  amount: 10000,
  accessDays: 365,
);
