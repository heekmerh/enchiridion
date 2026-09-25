import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_module.dart';
import '../models/leaderboard_entry.dart';

/// Fetches the cross-user leaderboard via the `get_leaderboard` RPC (see
/// the leaderboard section of scripts/sql/999_MASTER_init.sql) — a SECURITY DEFINER function, since
/// daily_study_stats' RLS policy otherwise only lets a user read their own
/// rows and a plain client-side select can't aggregate across everyone.
///
/// Module leaderboards go through `get_leaderboard_for_scope` (see
/// the same file), which filters the same
/// aggregation to one module's storage scope. When that function is missing
/// (migration not run yet) or the device is offline, the call falls back to
/// the aggregated board rather than failing.
class LeaderboardService {
  Future<List<LeaderboardEntry>> fetch({int limit = 20}) async {
    final rows = await Supabase.instance.client.rpc(
      'get_leaderboard',
      params: {'result_limit': limit},
    );
    return (rows as List)
        .map((row) => LeaderboardEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Module-specific board for [moduleId] (`plab`, …). Falls back to the
  /// aggregated board when the scoped RPC is unavailable.
  Future<List<LeaderboardEntry>> fetchForModule(
    String moduleId, {
    int limit = 20,
  }) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_leaderboard_for_scope',
        params: {
          'result_limit': limit,
          'scope_filter': examScopeForModule(moduleId),
        },
      );
      return (rows as List)
          .map((row) => LeaderboardEntry.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return fetch(limit: limit);
    }
  }
}
