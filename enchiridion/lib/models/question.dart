class Question {
  final String id;
  final String bookId;
  final String chapterId;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // 'a' | 'b' | 'c' | 'd'
  final String explanation;
  final String? osceTip;
  final int questionNumber;

  const Question({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.explanation,
    this.osceTip,
    required this.questionNumber,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      chapterId: json['chapter_id'] as String,
      questionText: json['question_text'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      correctOption: json['correct_option'] as String,
      explanation: json['explanation'] as String,
      osceTip: json['osce_tip'] as String?,
      questionNumber: json['question_number'] as int,
    );
  }

  String optionText(String option) {
    switch (option.toLowerCase()) {
      case 'a': return optionA;
      case 'b': return optionB;
      case 'c': return optionC;
      case 'd': return optionD;
      default: return '';
    }
  }
}

class UserAnswer {
  final String questionId;
  final String selectedOption;
  final bool isCorrect;
  final DateTime answeredAt;

  const UserAnswer({
    required this.questionId,
    required this.selectedOption,
    required this.isCorrect,
    required this.answeredAt,
  });

  factory UserAnswer.fromJson(Map<String, dynamic> json) {
    return UserAnswer(
      questionId: json['question_id'] as String,
      selectedOption: json['selected_option'] as String,
      isCorrect: json['is_correct'] as bool,
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'selected_option': selectedOption,
    'is_correct': isCorrect,
    'answered_at': answeredAt.toIso8601String(),
  };
}
