import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resource_topic.dart';
import '../models/study_day_stats.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class StudyStatsService {
  final StorageService _storage;

  const StudyStatsService(this._storage);

  static String dateKeyFor(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

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
    await _sync(updated);
    return updated;
  }

  StudyDayStats getTodayStats([String scope = kStandaloneExamPrepScope]) {
    return _storage.getDailyStudyStats(scope, dateKeyFor(DateTime.now()));
  }

  Future<void> _sync(StudyDayStats stats) async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
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
