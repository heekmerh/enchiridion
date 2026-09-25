class PricingPlan {
  final String id;
  final String label;
  final int amount;
  final int accessDays;
  final bool autoRenewing;
  final String billingPeriodLabel;

  const PricingPlan({
    required this.id,
    required this.label,
    required this.amount,
    required this.accessDays,
    required this.autoRenewing,
    required this.billingPeriodLabel,
  });

  // Google Play requires the renewal terms to be visible at the point of
  // purchase, not only in the Terms and Conditions.
  String get renewalNotice => autoRenewing
      ? 'Renews automatically every $billingPeriodLabel until you cancel. '
          'Cancel any time in Profile → Subscription.'
      : 'One-time payment for $accessDays days. Does not renew.';
}

const kBookUnlockPlan = PricingPlan(
  id: 'book_monthly',
  label: 'Unlock — ₦1,000 for 30 days',
  amount: 1000,
  accessDays: 30,
  autoRenewing: false,
  billingPeriodLabel: 'month',
);

const kSubscriptionMonthlyPlan = PricingPlan(
  id: 'sub_monthly',
  label: 'Monthly — ₦1,000/month',
  amount: 1000,
  accessDays: 30,
  autoRenewing: true,
  billingPeriodLabel: 'month',
);

const kSubscriptionYearlyPlan = PricingPlan(
  id: 'sub_yearly',
  label: 'Yearly — ₦10,000/year',
  amount: 10000,
  accessDays: 365,
  autoRenewing: true,
  billingPeriodLabel: 'year',
);
