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

class SubscriptionStatus {
  final String scope;
  final String planId;
  final String status;
  final bool autoRenew;
  final DateTime? currentPeriodEnd;
  final DateTime? nextBillingAt;

  const SubscriptionStatus({
    required this.scope,
    required this.planId,
    required this.status,
    required this.autoRenew,
    this.currentPeriodEnd,
    this.nextBillingAt,
  });

  factory SubscriptionStatus.fromRow(Map<String, dynamic> row) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return SubscriptionStatus(
      scope: row['scope'] as String? ?? '*',
      planId: row['plan_id'] as String? ?? '',
      status: row['status'] as String? ?? 'active',
      autoRenew: row['auto_renew'] as bool? ?? false,
      currentPeriodEnd: parse(row['current_period_end']),
      nextBillingAt: parse(row['next_billing_at']),
    );
  }

  bool get renewsAutomatically => status == 'active' && autoRenew;

  DateTime? get endsOn => currentPeriodEnd;
}

/// Read-only view of `user_subscriptions`, which only the
/// flutterwave-webhook Edge Function ever writes. Billing itself happens on
/// the website, so the app's whole role is to poll this and tell the user
/// when their subscription renews and where to cancel it.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  Future<SubscriptionStatus?> current() async {
    final user = AuthService.currentUser;
    if (user == null) return null;
    try {
      final rows = await Supabase.instance.client
          .from('user_subscriptions')
          .select()
          .eq('user_id', user.id);
      final statuses = (rows as List)
          .map((row) =>
              SubscriptionStatus.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (statuses.isEmpty) return null;
      statuses.sort(_mostRelevantFirst);
      return statuses.first;
    } catch (_) {
      return null;
    }
  }

  int _mostRelevantFirst(SubscriptionStatus a, SubscriptionStatus b) {
    if (a.renewsAutomatically != b.renewsAutomatically) {
      return a.renewsAutomatically ? -1 : 1;
    }
    final aEnd = a.endsOn;
    final bEnd = b.endsOn;
    if (aEnd == null && bEnd == null) return 0;
    if (aEnd == null) return 1;
    if (bEnd == null) return -1;
    return bEnd.compareTo(aEnd);
  }
}
