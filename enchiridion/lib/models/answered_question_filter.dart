import 'question.dart';

/// The status a question row can be browsed by on [AnsweredQuestionsScreen].
///
/// Kept free of Flutter widget imports so it stays unit-testable in
/// isolation from the widget tree — it depends only on [Question] /
/// [UserAnswer].
enum AnsweredQuestionFilter {
  answered,
  correct,
  wrong,
  points;

  /// The dashboard tile caption for this filter.
  String get label {
    switch (this) {
      case AnsweredQuestionFilter.answered:
        return 'Answered';
      case AnsweredQuestionFilter.correct:
        return 'Correct';
      case AnsweredQuestionFilter.wrong:
        return 'Wrong';
      case AnsweredQuestionFilter.points:
        return 'Points';
    }
  }

  /// The browse-screen app-bar heading for this filter.
  String get title {
    switch (this) {
      case AnsweredQuestionFilter.answered:
        return 'Answered questions';
      case AnsweredQuestionFilter.correct:
        return 'Correct answers';
      case AnsweredQuestionFilter.wrong:
        return 'Missed questions';
      case AnsweredQuestionFilter.points:
        return 'Questions that earned points';
    }
  }

  /// Whether [answer] belongs in this filter's browse list.
  ///
  /// [points] deliberately shares the [correct] predicate: points are only
  /// ever awarded for a correct answer, so the set of point-earning
  /// questions is exactly the set of correctly-answered ones.
  bool matches(UserAnswer answer) {
    switch (this) {
      case AnsweredQuestionFilter.answered:
        return true;
      case AnsweredQuestionFilter.correct:
        return answer.isCorrect;
      case AnsweredQuestionFilter.wrong:
        return !answer.isCorrect;
      case AnsweredQuestionFilter.points:
        return answer.isCorrect;
    }
  }
}
