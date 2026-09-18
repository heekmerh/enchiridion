import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resource_topic.dart';
import '../models/study_day_stats.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class StudyStatsService {
  final StorageService _storage;

  /// Test-only seam for substituting the remote push. Defaults to [_sync].
  /// Tests use this to prove [recordAnswer] returns without waiting on a
  /// never-completing future, standing in for an offline/hanging Supabase
  /// client.
  final Future<void> Function(StudyDayStats stats)? _syncOverride;

  const StudyStatsService(this._storage, {
    Future<void> Function(StudyDayStats stats)? syncOverride,
  }) : _syncOverride = syncOverride;

  static String dateKeyFor(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  /// Records one answer's contribution to the day's stats.
  ///
  /// [isFirstAttempt] must be the caller's `QuestionReview.attempts == 1`
  /// check (true only the very first time this question is ever answered in
  /// this scope) — spaced repetition deliberately re-serves the same
  /// question days or weeks later, and a repeat answer must not inflate
  /// `questionsAnswered`/`performancePoints` a second time. When false, this
  /// is a no-op that returns the day's stats unchanged.
  Future<StudyDayStats> recordAnswer({
    String scope = kStandaloneExamPrepScope,
    required bool isCorrect,
    required bool isFirstAttempt,
    DateTime? answeredAt,
  }) async {
    final timestamp = answeredAt ?? DateTime.now();
    final dateKey = dateKeyFor(timestamp);
    final current = _storage.getDailyStudyStats(scope, dateKey);
    if (!isFirstAttempt) return current;
    final updated = current.copyWith(
      questionsAnswered: current.questionsAnswered + 1,
      correctAnswers: current.correctAnswers + (isCorrect ? 1 : 0),
      performancePoints: current.performancePoints + (isCorrect ? 10 : 0),
      updatedAt: timestamp,
    );
    await _storage.saveDailyStudyStats(updated);
    // The local write above is already durable — do not gate the return (and
    // therefore the caller's UI update) on a network round-trip. A slow or
    // hanging Supabase client must never delay the dashboard.
    unawaited((_syncOverride ?? _sync)(updated));
    return updated;
  }

  StudyDayStats getTodayStats([String scope = kStandaloneExamPrepScope]) {
    return _storage.getDailyStudyStats(scope, dateKeyFor(DateTime.now()));
  }

  /// Sums every stored day's stats for [scope] into lifetime totals.
  ///
  /// Unlike [getTodayStats], this is not scoped to the local calendar date —
  /// it is the "accumulated" figure the dashboard's headline metrics show,
  /// unaffected by local midnight.
  StudyStatsTotals getLifetimeTotals([String scope = kStandaloneExamPrepScope]) {
    return StudyStatsTotals.fold(_storage.getAllDailyStudyStats(scope));
  }

  /// The whole body — including the `currentUser` read — is inside the try
  /// block on purpose, matching `QuestionReviewSyncService.push`:
  /// `Supabase.instance` asserts (not throws a catchable exception via a
  /// normal Future) if `Supabase.initialize()` hasn't run yet, which is the
  /// case in every widget/unit test and briefly during real app cold-start.
  /// Treating that the same as "offline" is the correct behavior here, not a
  /// special case to route around.
  Future<void> _sync(StudyDayStats stats) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('daily_study_stats').upsert({
        'user_id': user.id,
        'scope': stats.scope,
        'study_date': stats.dateKey,
        'questions_answered': stats.questionsAnswered,
        'correct_answers': stats.correctAnswers,
        'performance_points': stats.performancePoints,
        'updated_at': stats.updatedAt.toIso8601String(),
      });
    } catch (_) {
      // Preserve the local cache as the fallback source when the network or
      // Supabase configuration is unavailable.
    }
  }
}
