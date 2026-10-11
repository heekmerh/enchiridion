import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/pricing_config.dart';
import '../constants/billing_copy.dart';
import '../services/access_service.dart';
import '../services/play_billing_service.dart';
import 'legal_document_screen.dart';

String? annualSavingsLabel(List<PremiumOffer> offers) {
  ProductDetails? detailsFor(PremiumInterval interval) {
    for (final offer in offers) {
      if (offer.plan.interval == interval) return offer.details;
    }
    return null;
  }

  final monthly = detailsFor(PremiumInterval.monthly);
  final annual = detailsFor(PremiumInterval.annual);
  if (monthly == null || annual == null) return null;
  if (monthly.currencyCode != annual.currencyCode) return null;
  return annual.rawPrice < monthly.rawPrice * 12
      ? 'Save compared with twelve monthly payments.'
      : null;
}

class UnlockScreen extends StatefulWidget {
  final PlayBillingService? billing;

  const UnlockScreen({super.key, this.billing});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen>
    with WidgetsBindingObserver {
  late final PlayBillingService _billing =
      widget.billing ?? PlayBillingService.instance;
  bool _alreadyPremium = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _billing.addListener(_onBillingChanged);
    _refreshAccess(silent: true);
    _billing.loadOffers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _billing.removeListener(_onBillingChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshAccess(silent: true);
    }
  }

  void _onBillingChanged() {
    if (!mounted) return;
    setState(() {});
    if (_billing.state == PurchaseFlowState.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(BillingCopy.purchaseVerified)),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _refreshAccess({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await AccessService.instance.loadAccess();
    } catch (_) {}
    final premium = await AccessService.instance.hasFullAccess();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _alreadyPremium = premium;
    });
    if (!silent && !premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Premium access was found for this account yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restore() async {
    await _billing.restore();
    await _refreshAccess();
  }

  bool get _busy => const {
        PurchaseFlowState.loading,
        PurchaseFlowState.purchasing,
        PurchaseFlowState.verifying,
      }.contains(_billing.state);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final savings = annualSavingsLabel(_billing.offers);

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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          children: [
            Icon(Icons.lock_open_outlined, size: 64, color: cs.primary),
            const SizedBox(height: 20),
            Text(
              'Unlock Enchiridion Premium',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Get more from Enchiridion with Premium.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _BenefitsCard(),
            const SizedBox(height: 20),
            if (_alreadyPremium)
              _Notice(
                  text: BillingCopy.existingSubscription,
                  color: cs.primaryContainer)
            else if (!_billing.isAvailableOnThisPlatform)
              _Notice(
                  text: BillingCopy.purchaseUnavailableHere,
                  color: cs.surfaceContainerHighest)
            else ...[
              if (_billing.state == PurchaseFlowState.loading)
                const Center(child: CircularProgressIndicator()),
              for (final offer in _billing.offers) ...[
                _PlanButton(
                  title: '${offer.plan.title} — ${offer.price}',
                  note: offer.plan.interval == PremiumInterval.annual
                      ? (savings ?? offer.plan.summary)
                      : offer.plan.summary,
                  label: offer.plan.subscribeLabel,
                  tonal: offer.plan.interval == PremiumInterval.annual,
                  onPressed: _busy ? null : () => _billing.buy(offer),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                BillingCopy.googlePlayProcessing,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (_billing.message != null &&
                _billing.state != PurchaseFlowState.success) ...[
              const SizedBox(height: 12),
              _Notice(
                text: _billing.message!,
                color: _billing.state == PurchaseFlowState.failed
                    ? cs.errorContainer
                    : cs.secondaryContainer,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _checking || _busy ? null : _restore,
              icon: _checking
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined, size: 18),
              label: Text(_checking
                  ? 'Checking…'
                  : 'Already subscribed? Restore access'),
            ),
            TextButton(
              onPressed: () =>
                  LegalDocumentScreen.open(context, LegalDocument.terms),
              child: const Text('Terms, renewal and cancellation'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Premium includes:',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final item in kFullAccessBenefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;

  const _Notice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}

class _PlanButton extends StatelessWidget {
  final String title;
  final String note;
  final String label;
  final bool tonal;
  final VoidCallback? onPressed;

  const _PlanButton({
    required this.title,
    required this.note,
    required this.label,
    required this.tonal,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(note,
            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 6),
        tonal
            ? FilledButton.tonal(
                onPressed: onPressed, style: style, child: Text(label))
            : FilledButton(
                onPressed: onPressed, style: style, child: Text(label)),
      ],
    );
  }
}
