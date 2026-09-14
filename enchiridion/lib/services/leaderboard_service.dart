import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_entry.dart';

/// Fetches the cross-user leaderboard via the `get_leaderboard` RPC (see
/// scripts/sql/003_leaderboard.sql) — a SECURITY DEFINER function, since
/// daily_study_stats' RLS policy otherwise only lets a user read their own
/// rows and a plain client-side select can't aggregate across everyone.
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
}
