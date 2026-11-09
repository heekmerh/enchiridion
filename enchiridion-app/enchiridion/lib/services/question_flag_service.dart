import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Submits a user's report that a question's content looks wrong. See
/// `enchiridion-web/docs/database.md` for the table and the maintainer query
/// — there is no in-app admin surface yet. Unlike
/// `QuestionReviewSyncService`/`StudyStatsService`, there is no local
/// fallback: failures are rethrown so the caller can tell the user the
/// report didn't go through.
class QuestionFlagService {
  static const _table = 'flagged_questions';

  Future<void> submit({
    required String scope,
    required String questionId,
    required String reason,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to flag a question.');
    }
    await Supabase.instance.client.from(_table).insert({
      'user_id': user.id,
      'scope': scope,
      'question_id': questionId,
      'reason': reason.trim().isEmpty ? 'No details provided' : reason.trim(),
    });
  }
}
