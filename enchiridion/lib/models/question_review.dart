import 'dart:math';

import 'question.dart';

/// Spaced-repetition state for one question within one scope.
///
/// This — not the [UserAnswer] map in `StorageService` — is the source of
/// truth for what may be served next. [UserAnswer] records *what the user
/// picked last time* and still drives the tick marks in the question lists;
/// [QuestionReview] records *when the question should come back*.
class QuestionReview {
  /// Applied after a wrong answer: bring the question back while the day is
  /// still young, so the correction is re-tested rather than just read once.
  static const Duration relearnInterval = Duration(hours: 3);

  /// Applied to a correct-but-guessed answer. A 1-in-5 guess on a five-option
  /// MCQ is not evidence of retention, so it does not graduate the question —
  /// but it is weaker evidence of failure than a wrong answer, so the interval
  /// sits above [relearnInterval].
  static const Duration guessedInterval = Duration(hours: 8);

  /// Interval applied on a confident correct answer, indexed by the stage the
  /// question is *leaving*. Answering correctly at the top stage retires it.
  static const List<Duration> stageIntervals = <Duration>[
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 21),
  ];

  final String questionId;

  /// Position on the [stageIntervals] ladder, `0..stageIntervals.length`.
  final int stage;
  final int attempts;

  /// How many times this question has been answered wrong. Drives urgency in
  /// `NextQuestionSelector`: a question the user has actually missed outranks
  /// one that is merely due.
  final int lapses;

  final bool? lastCorrect;
  final String? lastOption;
  final DateTime lastSeenAt;
  final DateTime dueAt;

  /// Graduated off the ladder. Retired questions are not served ambiently.
  final bool retired;

  const QuestionReview({
    required this.questionId,
    required this.stage,
    required this.attempts,
    required this.lapses,
    required this.lastCorrect,
    required this.lastOption,
    required this.lastSeenAt,
    required this.dueAt,
    required this.retired,
  });

  /// State for a question the user has never been shown. [lastSeenAt] is the
  /// epoch so that "least recently seen" ordering naturally prefers new items.
  factory QuestionReview.initial(String questionId) => QuestionReview(
        questionId: questionId,
        stage: 0,
        attempts: 0,
        lapses: 0,
        lastCorrect: null,
        lastOption: null,
        lastSeenAt: DateTime.fromMillisecondsSinceEpoch(0),
        dueAt: DateTime.fromMillisecondsSinceEpoch(0),
        retired: false,
      );

  /// Rebuilds ladder state from a pre-spaced-repetition [UserAnswer]. Because
  /// the answer is in the past, the resulting [dueAt] is usually already
  /// elapsed — the user's answer history becomes their review backlog, which
  /// is the intended semantic.
  factory QuestionReview.fromLegacyAnswer(UserAnswer answer, {Random? random}) {
    return QuestionReview.initial(answer.questionId).applyAnswer(
      isCorrect: answer.isCorrect,
      selectedOption: answer.selectedOption,
      at: answer.answeredAt,
      random: random,
    );
  }

  bool get isNew => attempts == 0;

  bool isDue(DateTime now) => !retired && !dueAt.isAfter(now);

  /// Folds one answer into the ladder and returns the next state.
  ///
  /// [confident] is the user's own signal that they knew the answer rather
  /// than guessed it; see [guessedInterval].
  QuestionReview applyAnswer({
    required bool isCorrect,
    required String selectedOption,
    bool confident = true,
    DateTime? at,
    Random? random,
  }) {
    final now = at ?? DateTime.now();
    final rng = random ?? Random();

    if (!isCorrect) {
      // A lapse resets the ladder from any stage, including a retired one.
      return copyWith(
        stage: 0,
        attempts: attempts + 1,
        lapses: lapses + 1,
        lastCorrect: false,
        lastOption: selectedOption,
        lastSeenAt: now,
        dueAt: now.add(_jittered(relearnInterval, rng)),
        retired: false,
      );
    }

    if (!confident) {
      // Holds position: a guess is neither promotion nor demotion evidence.
      return copyWith(
        attempts: attempts + 1,
        lastCorrect: true,
        lastOption: selectedOption,
        lastSeenAt: now,
        dueAt: now.add(_jittered(guessedInterval, rng)),
        retired: false,
      );
    }

    if (stage >= stageIntervals.length) {
      return copyWith(
        attempts: attempts + 1,
        lastCorrect: true,
        lastOption: selectedOption,
        lastSeenAt: now,
        // Retired questions are filtered out before dueAt is consulted; this
        // value only keeps the field monotonic and out of the way.
        dueAt: now.add(const Duration(days: 365)),
        retired: true,
      );
    }

    return copyWith(
      stage: stage + 1,
      attempts: attempts + 1,
      lastCorrect: true,
      lastOption: selectedOption,
      lastSeenAt: now,
      dueAt: now.add(_jittered(stageIntervals[stage], rng)),
      retired: false,
    );
  }

  /// Spreads scheduled reviews out so that a study session with six misses
  /// does not queue six prompts for the same minute three hours later.
  static Duration _jittered(Duration base, Random random) {
    final spread = base < const Duration(hours: 12) ? base * 0.25 : base * 0.12;
    final offset = (random.nextDouble() * 2 - 1) * spread.inMilliseconds;
    return base + Duration(milliseconds: offset.round());
  }

  QuestionReview copyWith({
    int? stage,
    int? attempts,
    int? lapses,
    bool? lastCorrect,
    String? lastOption,
    DateTime? lastSeenAt,
    DateTime? dueAt,
    bool? retired,
  }) {
    return QuestionReview(
      questionId: questionId,
      stage: stage ?? this.stage,
      attempts: attempts ?? this.attempts,
      lapses: lapses ?? this.lapses,
      lastCorrect: lastCorrect ?? this.lastCorrect,
      lastOption: lastOption ?? this.lastOption,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      dueAt: dueAt ?? this.dueAt,
      retired: retired ?? this.retired,
    );
  }

  factory QuestionReview.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(Object? value) =>
        DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return QuestionReview(
      questionId: json['question_id'].toString(),
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      lastCorrect: json['last_correct'] as bool?,
      lastOption: json['last_option'] as String?,
      lastSeenAt: parseTime(json['last_seen_at']),
      dueAt: parseTime(json['due_at']),
      retired: json['retired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'stage': stage,
        'attempts': attempts,
        'lapses': lapses,
        'last_correct': lastCorrect,
        'last_option': lastOption,
        'last_seen_at': lastSeenAt.toIso8601String(),
        'due_at': dueAt.toIso8601String(),
        'retired': retired,
      };
}
