import 'package:flutter_test/flutter_test.dart';

import 'package:enchiridion/services/exam_prep_repository.dart';

void main() {
  test(
      'normalizeLegacySource repairs malformed question source and preserves A-E options',
      () {
    const raw = '''
{{
  "question": "What is the next best step?",
  "options": {
    "A": "Observe",
    "B": "Treat",
    "C": "Image",
    "D": "Refer",
    "E": "Review"
  }
  "answer": "B",
  "explanation": "Start treatment."
}
{
  "question": "Choose the correct option",
  "options": {
    "A": "One",
    "B": "Two",
    "C": "Three",
    "D": "Four",
    "E": "Five"
  },
  "answer": "E",
  "explanation": "Five is correct."
}
''';

    final questions = ExamPrepRepository.normalizeLegacySource(raw);

    expect(questions, hasLength(2));
    expect(questions.first.correctOption, 'b');
    expect(questions.first.optionKeys, ['a', 'b', 'c', 'd', 'e']);
    expect(questions.last.optionText('e'), 'Five');
  });
}
