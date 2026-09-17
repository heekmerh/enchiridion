import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/answered_question_filter.dart';
import '../models/question.dart';
import '../models/question_review.dart';
import '../models/resource_topic.dart';
import '../services/storage_service.dart';
import 'question_screen.dart';

/// Browses the questions the user has already answered in Exam Prep,
/// filtered by [AnsweredQuestionFilter].
///
/// Rows are built strictly from the intersection of [questions] and the
/// stored answers for [kStandaloneExamPrepScope] — a question with no
/// recorded answer can never become a row, so this screen can never leak
/// unanswered (and therefore possibly locked) bank content.
class AnsweredQuestionsScreen extends StatefulWidget {
  final List<Question> questions;
  final AnsweredQuestionFilter initialFilter;

  const AnsweredQuestionsScreen({
    super.key,
    required this.questions,
    required this.initialFilter,
  });

  @override
  State<AnsweredQuestionsScreen> createState() =>
      _AnsweredQuestionsScreenState();
}

class _AnsweredQuestionsScreenState extends State<AnsweredQuestionsScreen> {
  final Map<String, UserAnswer> _answers = {};
  Map<String, QuestionReview> _reviews = {};

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _answers.addAll(storage.getAnswers(kStandaloneExamPrepScope));
    _reviews = storage.getQuestionReviews(kStandaloneExamPrepScope);
  }

  void _refreshFromStorage() {
    final storage = context.read<StorageService>();
    setState(() {
      _answers
        ..clear()
        ..addAll(storage.getAnswers(kStandaloneExamPrepScope));
      _reviews = storage.getQuestionReviews(kStandaloneExamPrepScope);
    });
  }

  int _optionSeedFor(Question question) {
    final review = _reviews[question.id];
    return Object.hash(question.id, review?.attempts ?? 0);
  }

  /// Rows matching the active filter, newest answer first.
  List<Question> get _rows {
    final rows = widget.questions.where((question) {
      final answer = _answers[question.id];
      return answer != null && widget.initialFilter.matches(answer);
    }).toList()
      ..sort((a, b) =>
          _answers[b.id]!.answeredAt.compareTo(_answers[a.id]!.answeredAt));
    return rows;
  }

  void _openQuestion(Question question) {
    final answer = _answers[question.id]!;
    // A correct row opens read-only: reviewing the explanation must not be
    // able to silently overwrite a correct answer and lapse the spaced
    // repetition ladder (T-nds-03). Only a wrong row is retryable.
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => QuestionScreen(
          question: question,
          bookId: kStandaloneExamPrepScope,
          previousAnswer: answer,
          trackDailyStudyStats: true,
          readOnly: answer.isCorrect,
          optionSeed: _optionSeedFor(question),
          onAnswered: (_) {},
        ),
      ),
    )
        .then((_) {
      if (!mounted) return;
      _refreshFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = _rows;

    return Scaffold(
      appBar: AppBar(title: Text(widget.initialFilter.title)),
      body: rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No questions in this list yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final question = rows[index];
                final answer = _answers[question.id]!;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: answer.isCorrect
                        ? Colors.green.withValues(alpha: 0.14)
                        : Colors.red.withValues(alpha: 0.14),
                    child: Icon(
                      answer.isCorrect ? Icons.check : Icons.close,
                      size: 14,
                      color: answer.isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(question.previewText()),
                  trailing: answer.isCorrect
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.replay),
                  onTap: () => _openQuestion(question),
                );
              },
            ),
    );
  }
}
