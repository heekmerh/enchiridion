import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/answered_question_filter.dart';
import '../models/question.dart';
import '../models/question_review.dart';
import '../models/resource_topic.dart';
import '../services/storage_service.dart';
import 'question_screen.dart';

/// Points a correct answer is worth. Duplicates `StudyStatsService
/// .recordAnswer`'s value rather than importing it, so this screen doesn't
/// need a `StudyStatsService` instance just to read a constant — keep both
/// in sync if it ever changes.
const int kCorrectAnswerPoints = 10;

/// Browses the questions the user has already answered in Exam Prep,
/// filtered by [AnsweredQuestionFilter]. Rows are built strictly from the
/// intersection of [questions] and stored answers, so this screen can never
/// leak unanswered (and therefore possibly locked) bank content.
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

  /// Drives both the segmented control and the row filter. Seeded from
  /// [AnsweredQuestionsScreen.initialFilter]; since the segmented control
  /// only offers answered/correct/wrong and points/correct describe the same
  /// set, an initial points filter starts on the correct segment. The
  /// app-bar heading stays fixed to the opening filter regardless, so
  /// switching segments doesn't relabel the page.
  late AnsweredQuestionFilter _activeFilter;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter == AnsweredQuestionFilter.points
        ? AnsweredQuestionFilter.correct
        : widget.initialFilter;
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
      return answer != null && _activeFilter.matches(answer);
    }).toList()
      ..sort((a, b) =>
          _answers[b.id]!.answeredAt.compareTo(_answers[a.id]!.answeredAt));
    return rows;
  }

  /// All-time count across every question ever answered in this bank,
  /// independent of the active segment. Counts distinct questions, unlike
  /// the dashboard tiles which count answers given (a re-served question
  /// counts again) — the two are expected to disagree once anything has
  /// been re-answered; the summary line says so explicitly.
  int get _totalAnsweredCount =>
      widget.questions.where((q) => _answers.containsKey(q.id)).length;

  int get _totalCorrectCount => widget.questions
      .where((q) => _answers[q.id]?.isCorrect == true)
      .length;

  int get _totalWrongCount => _totalAnsweredCount - _totalCorrectCount;

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
          backLabel: 'Back to answers',
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All time: $_totalAnsweredCount questions answered, '
                  '$_totalCorrectCount correct, $_totalWrongCount wrong '
                  '(distinct questions — the dashboard counts every answer '
                  'given, so re-answered questions make that total higher).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (widget.initialFilter == AnsweredQuestionFilter.points) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Every correct answer is worth $kCorrectAnswerPoints '
                    'points.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SegmentedButton<AnsweredQuestionFilter>(
                  segments: const [
                    ButtonSegment(
                      value: AnsweredQuestionFilter.answered,
                      label: Text('Answered'),
                    ),
                    ButtonSegment(
                      value: AnsweredQuestionFilter.correct,
                      label: Text('Correct'),
                    ),
                    ButtonSegment(
                      value: AnsweredQuestionFilter.wrong,
                      label: Text('Wrong'),
                    ),
                  ],
                  selected: {_activeFilter},
                  onSelectionChanged: (selection) {
                    setState(() => _activeFilter = selection.first);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
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
                            color:
                                answer.isCorrect ? Colors.green : Colors.red,
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
          ),
        ],
      ),
    );
  }
}
