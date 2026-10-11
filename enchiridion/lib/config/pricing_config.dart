enum PremiumInterval { monthly, annual }

class PremiumPlan {
  final String id;
  final String basePlanId;
  final PremiumInterval interval;
  final String title;
  final String subscribeLabel;
  final String summary;

  const PremiumPlan({
    required this.id,
    required this.basePlanId,
    required this.interval,
    required this.title,
    required this.subscribeLabel,
    required this.summary,
  });
}

// Must match the subscription and base plans in Play Console and billing.provider_plan_mappings on the server.
const String kPlayPremiumProductId = 'enchiridion_premium';

const kPremiumMonthlyPlan = PremiumPlan(
  id: 'premium_monthly',
  basePlanId: 'premium-monthly',
  interval: PremiumInterval.monthly,
  title: 'Monthly',
  subscribeLabel: 'Subscribe Monthly',
  summary: 'Flexible monthly billing.',
);

const kPremiumAnnualPlan = PremiumPlan(
  id: 'premium_annual',
  basePlanId: 'premium-annual',
  interval: PremiumInterval.annual,
  title: 'Annual',
  subscribeLabel: 'Subscribe Annually',
  summary: 'Billed once a year.',
);

const List<PremiumPlan> kPremiumPlans = [
  kPremiumMonthlyPlan,
  kPremiumAnnualPlan
];

const String kPremiumFeature = 'premium';

const List<String> kFullAccessBenefits = [
  'Every chapter of all 8 specialty books',
  'Complete question banks and PLAB exam prep with spaced repetition',
  'All clinical calculators',
  'OSCE stations and instrumentation guides',
  'Notes, bookmarks and clips synced across your devices',
];
