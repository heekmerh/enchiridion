class Question {
  final String id;
  final String? bookId;
  final String? chapterId;
  final String questionText;
  final Map<String, String> options;
  final String correctOption;
  final String explanation;
  final String? osceTip;
  final int questionNumber;
  final String? topic;

  const Question({
    required this.id,
    this.bookId,
    this.chapterId,
    required this.questionText,
    required this.options,
    required this.correctOption,
    required this.explanation,
    this.osceTip,
    required this.questionNumber,
    this.topic,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = <String, String>{};
    if (rawOptions is Map<String, dynamic>) {
      for (final entry in rawOptions.entries) {
        options[entry.key.toLowerCase()] = entry.value.toString();
      }
    } else {
      for (final key in ['a', 'b', 'c', 'd', 'e']) {
        final value = json['option_$key'];
        if (value != null && value.toString().trim().isNotEmpty) {
          options[key] = value.toString();
        }
      }
    }

    return Question(
      id: json['id'] as String,
      bookId: json['book_id'] as String?,
      chapterId: json['chapter_id'] as String?,
      questionText: json['question_text'] as String,
      options: options,
      correctOption: (json['correct_option'] as String).toLowerCase(),
      explanation: json['explanation'] as String,
      osceTip: json['osce_tip'] as String?,
      questionNumber: json['question_number'] as int,
      topic: json['topic'] as String?,
    );
  }

  String optionText(String option) {
    return options[option.toLowerCase()] ?? '';
  }

  List<String> get optionKeys {
    final keys = options.keys.toList()..sort();
    return keys;
  }

  /// Display letter for a rendered option slot.
  ///
  /// The letter belongs to the rendered slot, not to the option — a
  /// shuffled repeat must reassign A/B/C by position so the letter cannot
  /// be memorized alongside the option text.
  static String displayLabel(int position) {
    assert(position >= 0 && position < 26);
    return String.fromCharCode(0x41 + position);
  }

  /// A list-row preview of [questionText], up to [maxLength] characters.
  ///
  /// Takes the *end* of the stem rather than the start: these are clinical
  /// vignettes — several sentences of scene-setting followed by the actual
  /// question ("...What is the most likely diagnosis?") — so truncating from
  /// the front produces a list where nearly every row reads the same
  /// ("A 32 year old woman presents to the Emergency Department with a
  /// sudden…") and tells the reader nothing about which question is which.
  String previewText({int maxLength = 90}) {
    final flatText = questionText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flatText.length <= maxLength) return flatText;
    final tail = flatText.substring(flatText.length - maxLength);
    final firstSpace = tail.indexOf(' ');
    final trimmed = firstSpace == -1 ? tail : tail.substring(firstSpace + 1);
    return '…$trimmed';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'question_text': questionText,
        'options': options,
        'correct_option': correctOption,
        'explanation': explanation,
        'osce_tip': osceTip,
        'question_number': questionNumber,
        'topic': topic,
      };
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
