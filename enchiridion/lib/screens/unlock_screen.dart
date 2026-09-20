import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/pricing_config.dart';
import '../models/book_catalog.dart';
import '../models/exam_module.dart';
import '../services/access_service.dart';
import '../services/auth_service.dart';

/// Paywall. Subscriptions are sold on the website, not in-app: each plan
/// button opens the subscribe page in the device browser with the account
/// and intended plan attached, and this screen re-checks access when the
/// user returns (or when they tap "I've paid").
class UnlockScreen extends StatefulWidget {
  final String? bookId;

  const UnlockScreen({super.key, this.bookId});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

/// Website checkout. Query parameters let the site tie the payment to this
/// account and pre-select the plan/scope; the site grants access through
/// the verify-flutterwave-payment Edge Function afterwards.
const String kSubscribeUrl = 'https://enchiridion.site/app/subscribe';

Uri subscribeUri({
  required String userId,
  required String email,
  required String planId,
  required String scope,
}) {
  return Uri.parse(kSubscribeUrl).replace(queryParameters: {
    'user_id': userId,
    'email': email,
    'plan': planId,
    'scope': scope,
  });
}

class _UnlockScreenState extends State<UnlockScreen>
    with WidgetsBindingObserver {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user paid on the website and came back — re-check silently and
    // close the paywall if access is now granted.
    if (state == AppLifecycleState.resumed && mounted) {
      _checkAccess(silent: true);
    }
  }

  String _bookTitle() {
    if (widget.bookId == null) return 'All Access';
    final moduleLabel =
        examModuleLabelForScope(widget.bookId ?? kPlabModuleId);
    if (moduleLabel != null) return moduleLabel;
    try {
      return kBooks.firstWhere((b) => b.id == widget.bookId).title;
    } catch (_) {
      return 'Enchiridion';
    }
  }

  /// Scope the website should grant: the specific book/module, or `*` for
  /// full access.
  String get _scope => widget.bookId ?? '*';

  Future<void> _subscribe(PricingPlan plan) async {
    final user = AuthService.currentUser;
    if (user == null || !mounted) return;
    final uri = subscribeUri(
      userId: user.id,
      email: user.email ?? '',
      planId: plan.id,
      scope: _scope,
    );
    try {
      final opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        await Clipboard.setData(ClipboardData(text: uri.toString()));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open the browser — the link was copied instead.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the browser. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Re-reads entitlements from Supabase. Pops with success when access is
  /// granted; otherwise (manual tap only) explains nothing changed yet.
  Future<void> _checkAccess({bool silent = false}) async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      await AccessService.instance.loadAccess();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _checking = false);
    final granted = widget.bookId == null
        ? await AccessService.instance.hasFullAccess()
        : await AccessService.instance.hasScopeAccess(_scope);
    if (!mounted) return;
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You're unlocked! Enjoy.")),
      );
      Navigator.of(context).pop(true);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No new access found yet — if you just paid, give it a moment '
            'and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

              Text(
                'Payment is completed securely on our website — '
                'tap a plan to continue there.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 12),

              // Book-specific unlock CTA
              if (isBookSpecific) ...[
                _PlanButton(
                  label:
                      'Unlock ${_bookTitle()} — ${kBookUnlockPlan.label.split('— ').last}',
                  tonal: false,
                  onPressed: () => _subscribe(kBookUnlockPlan),
                ),
                const SizedBox(height: 12),
              ],

              // Full subscription CTAs
              _PlanButton(
                label: kSubscriptionMonthlyPlan.label,
                tonal: isBookSpecific,
                onPressed: () => _subscribe(kSubscriptionMonthlyPlan),
              ),
              const SizedBox(height: 12),
              _PlanButton(
                label: kSubscriptionYearlyPlan.label,
                tonal: true,
                onPressed: () => _subscribe(kSubscriptionYearlyPlan),
              ),
              const SizedBox(height: 12),

              // Returns from the website checkout go through here too (see
              // didChangeAppLifecycleState), but a manual check covers the
              // case where the grant lands while this screen is open.
              OutlinedButton.icon(
                onPressed: _checking ? null : () => _checkAccess(),
                icon: _checking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined, size: 18),
                label: Text(
                    _checking ? 'Checking…' : "I've paid — check access"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
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
  final String label;
  final bool tonal;
  final VoidCallback onPressed;

  const _PlanButton({
    required this.label,
    required this.tonal,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
    );

    return tonal
        ? FilledButton.tonal(
            onPressed: onPressed, style: style, child: Text(label))
        : FilledButton(
            onPressed: onPressed, style: style, child: Text(label));
  }
}
