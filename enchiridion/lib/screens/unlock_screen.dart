import 'package:flutter/material.dart';

import '../config/pricing_config.dart';
import '../models/book_catalog.dart';
import '../services/payment_service.dart';

class UnlockScreen extends StatefulWidget {
  final String? bookId;

  const UnlockScreen({super.key, this.bookId});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _paymentService = PaymentService();

  /// Which plan is currently mid-purchase, or null. Used to disable the
  /// other buttons and show a spinner on just the one being paid for.
  PricingPlan? _purchasing;

  String _bookTitle() {
    if (widget.bookId == null) return 'All Access';
    try {
      return kBooks.firstWhere((b) => b.id == widget.bookId).title;
    } catch (_) {
      return 'Enchiridion';
    }
  }

  Future<void> _purchase(PricingPlan plan) async {
    if (_purchasing != null) return;
    setState(() => _purchasing = plan);

    final outcome = await _paymentService.purchase(
      context: context,
      plan: plan,
      bookId: widget.bookId ?? '*',
    );

    if (!mounted) return;
    setState(() => _purchasing = null);

    switch (outcome) {
      case PaymentOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're unlocked! Enjoy.")),
        );
        Navigator.of(context).pop(true);
        return;
      case PaymentOutcome.cancelled:
        return;
      case PaymentOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "That payment didn't go through. No charge was made — "
              'please try again.',
            ),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBookSpecific = widget.bookId != null;
    final title =
        isBookSpecific ? 'Unlock ${_bookTitle()}' : 'Unlock All Access';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Maybe later',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.lock_open_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // What's included
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What you get:',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...(_unlockBullets(isBookSpecific)).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 18, color: cs.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(item,
                                      style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const Spacer(),

              // Book-specific unlock CTA
              if (isBookSpecific) ...[
                _PlanButton(
                  plan: kBookUnlockPlan,
                  label: 'Unlock ${_bookTitle()} — ${kBookUnlockPlan.label.split('— ').last}',
                  tonal: false,
                  purchasing: _purchasing,
                  onPressed: () => _purchase(kBookUnlockPlan),
                ),
                const SizedBox(height: 12),
              ],

              // Full subscription CTAs
              _PlanButton(
                plan: kSubscriptionMonthlyPlan,
                label: kSubscriptionMonthlyPlan.label,
                tonal: isBookSpecific,
                purchasing: _purchasing,
                onPressed: () => _purchase(kSubscriptionMonthlyPlan),
              ),
              const SizedBox(height: 12),
              _PlanButton(
                plan: kSubscriptionYearlyPlan,
                label: kSubscriptionYearlyPlan.label,
                tonal: true,
                purchasing: _purchasing,
                onPressed: () => _purchase(kSubscriptionYearlyPlan),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: _purchasing != null
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Maybe later'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _unlockBullets(bool bookSpecific) {
    if (bookSpecific) {
      return [
        'Full book content — all chapters',
        'All question bank questions for this book',
        'Notes and annotations',
      ];
    }
    return [
      'Full content for all 8 specialty books',
      'Complete question banks for every book',
      'All clinical calculators',
      'Notes and annotations',
    ];
  }
}

class _PlanButton extends StatelessWidget {
  final PricingPlan plan;
  final String label;
  final bool tonal;
  final PricingPlan? purchasing;
  final VoidCallback onPressed;

  const _PlanButton({
    required this.plan,
    required this.label,
    required this.tonal,
    required this.purchasing,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isThisPurchasing = purchasing == plan;
    final disabled = purchasing != null && !isThisPurchasing;
    final child = isThisPurchasing
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);

    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
    final handler = disabled || purchasing != null ? null : onPressed;

    return tonal
        ? FilledButton.tonal(onPressed: handler, style: style, child: child)
        : FilledButton(onPressed: handler, style: style, child: child);
  }
}
