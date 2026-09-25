import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Submits a user's report that a question's content looks wrong (a typo,
/// the wrong option marked correct, unclear wording, ...) to Supabase for a
/// maintainer to review later.
///
/// See `scripts/sql/999_MASTER_init.sql` for the table this writes to
/// and the query a maintainer runs from the Supabase SQL editor to see
/// what's been flagged — there is no in-app admin surface or outbound
/// notification yet.
///
/// Unlike `QuestionReviewSyncService`/`StudyStatsService`, there is no local
/// fallback state here — a flag either reaches the backend or it doesn't —
/// so failures are rethrown rather than swallowed. The caller is expected to
/// tell the user their report didn't go through.
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
