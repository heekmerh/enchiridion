import 'dart:math';

import '../config/freemium_config.dart';
import '../models/question.dart';
import '../models/question_review.dart';
import '../models/serve_log.dart';
import '../models/resource_topic.dart';
import 'storage_service.dart';

/// The single place that decides which question a user sees next.
///
/// Every ambient surface — the exam-prep home card, the Quick Check prompt,
/// and (later) a scheduled notification — must go through here. Each of those
/// used to roll its own `Random` over the whole unlocked bank, which meant
/// two surfaces could serve the same question minutes apart and, once the
/// bank was exhausted, that repeats became arbitrary.
///
/// Priority order:
///   1. **Lapsed and due** — questions the user has actually got wrong.
///   2. **Due reviews and unseen questions, alternating** — so a large review
///      backlog cannot starve new material, and vice versa.
///   3. Whichever of those buckets is non-empty.
///   4. Least recently seen — a graceful floor for a bank too small to
///      satisfy the cooldown (notably the ten free-tier questions).
class NextQuestionSelector {
  /// A question is not re-served within this window regardless of its
  /// schedule, so a rebound never lands in the same sitting as the miss.
  static const Duration cooldown = Duration(minutes: 90);

  final StorageService _storage;
  final Random _random;

  NextQuestionSelector(this._storage, {Random? random})
      : _random = random ?? Random();

  /// Returns the question to serve, or null when nothing is unlocked.
  ///
  /// Records the choice in the shared serve log, so callers should invoke this
  /// only when they are about to show the question.
  Future<Question?> next({
    required List<Question> bank,
    required bool hasAccess,
    String scope = kStandaloneExamPrepScope,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    try {
      await _storage.refreshFromDisk();
    } catch (_) {
      // A platform read failure must not prevent serving from cached state.
    }
    final unlocked = bank
        .where((question) =>
            hasAccess || question.questionNumber <= kFreeQuestionCount)
        .toList();
    if (unlocked.isEmpty) return null;

    await _storage.ensureQuestionReviewsMigrated(scope);
    final reviews = _storage.getQuestionReviews(scope);
    final log = _storage.getServeLog(scope);

    final lapsedDue = <Question>[];
    final freshDue = <Question>[];
    final unseen = <Question>[];

    for (final question in unlocked) {
      final review = reviews[question.id];
      if (review == null || review.isNew) {
        unseen.add(question);
      } else if (review.isDue(moment)) {
        (review.lapses > 0 ? lapsedDue : freshDue).add(question);
      }
    }

    int byDueDate(Question a, Question b) =>
        reviews[a.id]!.dueAt.compareTo(reviews[b.id]!.dueAt);
    lapsedDue.sort(byDueDate);
    freshDue.sort(byDueDate);
    unseen.shuffle(_random);

    // Alternate the two non-urgent buckets on the shared counter.
    final unseenFirst = log.counter.isOdd;
    final buckets = <List<Question>>[
      lapsedDue,
      if (unseenFirst) unseen else freshDue,
      if (unseenFirst) freshDue else unseen,
    ];

    Question? pick;
    for (final bucket in buckets) {
      pick = _firstServable(bucket, reviews, log, moment);
      if (pick != null) break;
    }

    // Nothing is due and nothing is new, or everything eligible is still in
    // cooldown. Serving the least recently seen question is both a sensible
    // fallback and strictly better than the uniform random this replaced.
    pick ??= _leastRecentlySeen(unlocked, reviews, log);
    if (pick == null) return null;

    await _storage.saveServeLog(scope, log.record(pick.id));
    return pick;
  }

  Question? _firstServable(
    List<Question> bucket,
    Map<String, QuestionReview> reviews,
    ServeLog log,
    DateTime now,
  ) {
    for (final question in bucket) {
      if (log.recent.contains(question.id)) continue;
      final review = reviews[question.id];
      if (review != null &&
          now.difference(review.lastSeenAt).abs() < cooldown) {
        continue;
      }
      return question;
    }
    return null;
  }

  /// Prefers questions still in rotation; only falls back to retired ones when
  /// the entire unlocked bank has graduated, so that an explicit "practise one
  /// now" tap always has something to show.
  Question? _leastRecentlySeen(
    List<Question> unlocked,
    Map<String, QuestionReview> reviews,
    ServeLog log,
  ) {
    Question? best;
    Question? retiredBest;

    bool prefer(Question candidate, Question current) {
      final candidateIndex = log.recent.indexOf(candidate.id);
      final currentIndex = log.recent.indexOf(current.id);
      // An unserved question wins; otherwise the oldest serve wins.
      if (candidateIndex != currentIndex) {
        if (candidateIndex == -1) return true;
        if (currentIndex == -1) return false;
        return candidateIndex > currentIndex;
      }

      final candidateSeen = reviews[candidate.id]?.lastSeenAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final currentSeen = reviews[current.id]?.lastSeenAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (candidateSeen != currentSeen) {
        return candidateSeen.isBefore(currentSeen);
      }
      return _random.nextBool();
    }

    for (final question in unlocked) {
      final review = reviews[question.id];
      if (review?.retired ?? false) {
        if (retiredBest == null || prefer(question, retiredBest)) {
          retiredBest = question;
        }
      } else if (best == null || prefer(question, best)) {
        best = question;
      }
    }

    return best ?? retiredBest;
  }
}
