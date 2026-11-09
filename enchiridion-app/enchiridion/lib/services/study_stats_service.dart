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

  /// Records one answer's contribution to the day's stats. Every submitted
  /// answer counts once, including a re-served question — the user genuinely
  /// did the work again. `QuestionReview.attempts` is deliberately not
  /// consulted (it can carry a non-zero count unrelated to this call);
  /// double-counting protection is structural instead — exactly one surface
  /// (`QuestionScreen._submit` or `QuickCheckCard._submit`) calls this per
  /// submission.
  Future<StudyDayStats> recordAnswer({
    String scope = kStandaloneExamPrepScope,
    required bool isCorrect,
    DateTime? answeredAt,
  }) async {
    final timestamp = answeredAt ?? DateTime.now();
    final dateKey = dateKeyFor(timestamp);
    final current = _storage.getDailyStudyStats(scope, dateKey);
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
  /// Unlike [getTodayStats], this is not scoped to the local calendar date —
  /// it is the "accumulated" figure the dashboard's headline metrics show,
  /// unaffected by local midnight.
  StudyStatsTotals getLifetimeTotals([String scope = kStandaloneExamPrepScope]) {
    return StudyStatsTotals.fold(_storage.getAllDailyStudyStats(scope));
  }

  /// Folds lifetime totals across several scopes — the aggregated,
  /// cross-module figure the exam-modules screen shows. Scopes with no stored
  /// days contribute nothing, so coming-soon modules never skew the total.
  StudyStatsTotals getLifetimeTotalsForScopes(Iterable<String> scopes) {
    final days = <StudyDayStats>[];
    for (final scope in scopes) {
      days.addAll(_storage.getAllDailyStudyStats(scope));
    }
    return StudyStatsTotals.fold(days);
  }

  /// The whole body, including the `currentUser` read, is inside the try
  /// block on purpose (matching `QuestionReviewSyncService.push`):
  /// `Supabase.instance` asserts rather than throwing a catchable exception
  /// if `Supabase.initialize()` hasn't run yet (every widget/unit test, and
  /// briefly at real app cold-start), and treating that the same as
  /// "offline" is correct here, not a special case to route around.
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
