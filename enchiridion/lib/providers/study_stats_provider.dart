import 'package:flutter/foundation.dart';

import '../models/resource_topic.dart';
import '../models/study_day_stats.dart';
import '../services/storage_service.dart';
import '../services/study_stats_service.dart';

/// Owns the exam-prep points/stats state for the whole app.
///
/// Writes locally through [StudyStatsService] (which itself never awaits the
/// Supabase push) and calls [notifyListeners] synchronously on the same
/// turn, so every screen watching this provider repaints the instant an
/// answer is recorded — no network wait, and no dependency on which screen
/// happened to record the answer.
class StudyStatsProvider with ChangeNotifier {
  final StorageService _storageService;
  final StudyStatsService _statsService;
  late StudyDayStats _today;
  late StudyStatsTotals _totals;

  StudyStatsProvider(
    StorageService storageService, {
    StudyStatsService? statsService,
  })  : _storageService = storageService,
        _statsService = statsService ?? StudyStatsService(storageService) {
    // Load the initial value from storage synchronously so the first frame
    // is already correct — no flash of zeroed metrics.
    _today = _statsService.getTodayStats();
    _totals = _statsService.getLifetimeTotals();
  }

  StorageService get storageService => _storageService;

  /// Today's stats, in the local calendar sense `StudyStatsService` uses.
  StudyDayStats get today => _today;

  /// Lifetime totals across every stored day — the accumulated headline
  /// numbers the dashboard shows, unaffected by local midnight.
  StudyStatsTotals get totals => _totals;

  /// Records one answer's contribution, persists it locally, and notifies
  /// listeners synchronously — before the background Supabase push (owned by
  /// [StudyStatsService]) has any chance to resolve.
  Future<StudyDayStats> recordAnswer({
    String scope = kStandaloneExamPrepScope,
    required bool isCorrect,
    DateTime? answeredAt,
  }) async {
    final updated = await _statsService.recordAnswer(
      scope: scope,
      isCorrect: isCorrect,
      answeredAt: answeredAt,
    );
    _today = updated;
    _totals = _statsService.getLifetimeTotals(scope);
    notifyListeners();
    return updated;
  }

  /// Re-reads from storage and notifies — for callers that recorded an
  /// answer elsewhere (or merged remote state) and need this provider's
  /// cached values brought back in sync.
  void refresh([String scope = kStandaloneExamPrepScope]) {
    _today = _statsService.getTodayStats(scope);
    _totals = _statsService.getLifetimeTotals(scope);
    notifyListeners();
  }
}
