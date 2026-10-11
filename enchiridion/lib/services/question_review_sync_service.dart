import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/question_review.dart';
import 'auth_service.dart';
import 'storage_service.dart';

/// Best-effort sync of spaced-repetition state to and from Supabase. Local
/// `SharedPreferences` (via [StorageService]) stays authoritative, like
/// `StudyStatsService`'s relationship to `daily_study_stats`; every method
/// swallows network/Supabase failures so the app keeps working offline.
class QuestionReviewSyncService {
  static const _table = 'question_reviews';

  final StorageService _storage;

  const QuestionReviewSyncService(this._storage);

  /// Upserts one review row. Call right after
  /// [StorageService.recordQuestionReview] (or [StorageService.recordAnswer])
  /// with the value it returns.
  /// The whole body — including the `currentUser` read — is inside the try
  /// block on purpose: `Supabase.instance` asserts (not throws a catchable
  /// exception via a normal Future) if `Supabase.initialize()` hasn't run
  /// yet, which is the case in most widget tests and briefly during real
  /// app cold-start. Treating that the same as "offline" is the correct
  /// behavior here, not a special case to route around.
  Future<void> push(String scope, QuestionReview review) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from(_table).upsert({
        'user_id': user.id,
        'scope': scope,
        ...review.toJson(),
      });
    } catch (e) {
      developer.log('Could not push question review: $e',
          name: 'QuestionReviewSyncService');
    }
  }

  /// Pulls every review row for the signed-in user across all scopes and
  /// merges each into local storage. Intended for one call right after
  /// sign-in so a new or previously-offline device catches up before the
  /// user starts studying. See [push] for why `currentUser` is read inside
  /// the try block.
  Future<void> pullAndMergeAll() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final rows = await Supabase.instance.client
          .from(_table)
          .select()
          .eq('user_id', user.id);

      final byScope = <String, List<QuestionReview>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final scope = map['scope'] as String;
        (byScope[scope] ??= []).add(QuestionReview.fromJson(map));
      }

      for (final entry in byScope.entries) {
        await _storage.mergeQuestionReviews(entry.key, entry.value);
      }
    } catch (e) {
      developer.log('Could not pull question reviews: $e',
          name: 'QuestionReviewSyncService');
    }
  }
}
