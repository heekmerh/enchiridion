import '../models/question.dart';

/// Returns the entries of [bank] whose id is in [answeredIds], preserving
/// the order they appear in [bank].
/// Unanswered questions are never returned. This is the single rule that
/// keeps unseen questions off every list surface — a user can only review
/// what they have already answered, never browse the rest of the bank.
List<Question> reviewableQuestions({
  required List<Question> bank,
  required Set<String> answeredIds,
}) {
  return bank.where((q) => answeredIds.contains(q.id)).toList();
}

/// Whether [answers] contains at least one recorded answer, i.e. whether
/// there is anything for the user to review.
bool hasReviewableQuestions(Map<String, UserAnswer> answers) {
  return answers.isNotEmpty;
}

/// Builds count-free progress copy from the user's own two counters.
/// Deliberately takes no bank and no list — its signature structurally
/// cannot receive a bank-size value, so it can never disclose one.
String answeredProgressLabel({required int answered, required int correct}) {
  return '$answered answered — $correct correct';
}
