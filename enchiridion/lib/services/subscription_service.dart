import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String formatRenewalDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]} ${local.year}';
}

enum SubscriptionProvider { googlePlay, website }

const Set<String> _renewingStates = {'ACTIVE', 'GRACE_PERIOD'};
const Set<String> _paymentProblemStates = {'PAYMENT_FAILED', 'PAUSED'};

class SubscriptionStatus {
  final String planId;
  final SubscriptionProvider provider;
  final String state;
  final bool autoRenewing;
  final DateTime? currentPeriodEnd;
  final DateTime? accessExpiresAt;
  final String? productId;

  const SubscriptionStatus({
    required this.planId,
    required this.provider,
    required this.state,
    required this.autoRenewing,
    this.currentPeriodEnd,
    this.accessExpiresAt,
    this.productId,
  });

  factory SubscriptionStatus.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return SubscriptionStatus(
      planId: row['plan_id'] as String? ?? '',
      provider: row['provider'] == 'google_play'
          ? SubscriptionProvider.googlePlay
          : SubscriptionProvider.website,
      state: row['internal_state'] as String? ?? 'EXPIRED',
      autoRenewing: row['auto_renewing'] as bool? ?? false,
      currentPeriodEnd: parse(row['current_period_end']),
      accessExpiresAt: parse(row['access_expires_at']),
      productId: row['product_id'] as String?,
    );
  }

  bool get renewsAutomatically =>
      autoRenewing && _renewingStates.contains(state);

  bool get hasPaymentProblem => _paymentProblemStates.contains(state);

  bool get hasEnded => state == 'EXPIRED' || state == 'REFUNDED';

  bool get isGooglePlay => provider == SubscriptionProvider.googlePlay;

  DateTime? get endsOn => accessExpiresAt ?? currentPeriodEnd;
}

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  Future<SubscriptionStatus?> current() async {
    if (AuthService.currentUser == null) return null;
    try {
      final rows =
          await Supabase.instance.client.rpc('get_my_subscription') as List;
      if (rows.isEmpty) return null;
      return SubscriptionStatus.fromRow(
          Map<String, dynamic>.from(rows.first as Map));
    } catch (_) {
      return null;
    }
  }
}
