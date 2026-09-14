class StudyDayStats {
  final String scope;
  final String dateKey;
  final int questionsAnswered;
  final int correctAnswers;
  final int performancePoints;
  final DateTime updatedAt;

  const StudyDayStats({
    required this.scope,
    required this.dateKey,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.performancePoints,
    required this.updatedAt,
  });

  StudyDayStats.empty({
    required this.scope,
    required this.dateKey,
  })  : questionsAnswered = 0,
        correctAnswers = 0,
        performancePoints = 0,
        updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  double get accuracy =>
      questionsAnswered == 0 ? 0 : correctAnswers / questionsAnswered;

  factory StudyDayStats.fromJson(Map<String, dynamic> json) {
    return StudyDayStats(
      scope: json['scope']?.toString() ?? '',
      dateKey: json['date_key']?.toString() ?? '',
      questionsAnswered: (json['questions_answered'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correct_answers'] as num?)?.toInt() ?? 0,
      performancePoints: (json['performance_points'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'date_key': dateKey,
        'questions_answered': questionsAnswered,
        'correct_answers': correctAnswers,
        'performance_points': performancePoints,
        'updated_at': updatedAt.toIso8601String(),
      };

  StudyDayStats copyWith({
    String? scope,
    String? dateKey,
    int? questionsAnswered,
    int? correctAnswers,
    int? performancePoints,
    DateTime? updatedAt,
  }) {
    return StudyDayStats(
      scope: scope ?? this.scope,
      dateKey: dateKey ?? this.dateKey,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      performancePoints: performancePoints ?? this.performancePoints,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
