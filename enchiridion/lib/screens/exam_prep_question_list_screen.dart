import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/freemium_config.dart';
import '../models/question.dart';
import '../models/question_review.dart';
import '../models/resource_topic.dart';
import '../services/access_service.dart';
import '../services/exam_prep_repository.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';
import 'question_screen.dart';
import 'unlock_screen.dart';

class ExamPrepQuestionListScreen extends StatefulWidget {
  const ExamPrepQuestionListScreen({super.key});

  @override
  State<ExamPrepQuestionListScreen> createState() =>
      _ExamPrepQuestionListScreenState();
}

class _ExamPrepQuestionListScreenState
    extends State<ExamPrepQuestionListScreen> {
  final Map<String, UserAnswer> _answers = {};
  Map<String, QuestionReview> _reviews = {};
  final ExamPrepRepository _repository = ExamPrepRepository();
  List<Question> _questions = [];
  bool _loading = true;
  bool _hasAccess = false;
  Object? _error;

  String _searchQuery = '';
  bool _dueOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = context.read<StorageService>();
      final access = await AccessService.instance.hasExamPrepAccess();
      final questions = await _repository.loadQuestions();
      if (!mounted) return;
      setState(() {
        _hasAccess = access;
        _questions = questions;
        _answers
          ..clear()
          ..addAll(storage.getAnswers(kStandaloneExamPrepScope));
        _reviews = storage.getQuestionReviews(kStandaloneExamPrepScope);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool _isLocked(Question question) =>
      !_hasAccess && question.questionNumber > kFreeQuestionCount;

  bool _isDue(Question question) {
    final review = _reviews[question.id];
    return review != null && review.isDue(DateTime.now());
  }

  int _optionSeedFor(Question question) {
    final review = _reviews[question.id];
    return Object.hash(question.id, review?.attempts ?? 0);
  }

  List<Question> get _visibleQuestions {
    final query = _searchQuery.trim().toLowerCase();
    return _questions.where((question) {
      if (_dueOnly && !_isDue(question)) return false;
      if (query.isEmpty) return true;
      // Locked questions can't be matched by search — otherwise free users
      // could read the full bank's question text via the search box.
      if (_isLocked(question)) return false;
      return question.questionText.toLowerCase().contains(query);
    }).toList();
  }

  void _openQuestion(Question question) {
    if (_isLocked(question)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const UnlockScreen(bookId: kStandaloneExamPrepScope),
        ),
      );
      return;
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => QuestionScreen(
          question: question,
          bookId: kStandaloneExamPrepScope,
          previousAnswer: _answers[question.id],
          trackDailyStudyStats: true,
          optionSeed: _optionSeedFor(question),
          onAnswered: (answer) {
            setState(() => _answers[question.id] = answer);
          },
        ),
      ),
    )
        .then((_) {
      if (!mounted) return;
      final storage = context.read<StorageService>();
      setState(() {
        _answers
          ..clear()
          ..addAll(storage.getAnswers(kStandaloneExamPrepScope));
        _reviews = storage.getQuestionReviews(kStandaloneExamPrepScope);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Prep Question Bank')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load the exam prep bank.\n\n$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: cs.primaryContainer,
                      child: Text(
                        '${_answers.length} of ${_questions.length} answered — ${_answers.values.where((answer) => answer.isCorrect).length} correct',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search questions',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilterChip(
                          label: const Text('Due for review'),
                          selected: _dueOnly,
                          onSelected: (selected) =>
                              setState(() => _dueOnly = selected),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Builder(builder: (context) {
                        final visible = _visibleQuestions;
                        if (visible.isEmpty) {
                          return Center(
                            child: Text(
                              'No questions match your search.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.only(
                            bottom: bottomViewportInset(context),
                          ),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final question = visible[index];
                            final answer = _answers[question.id];
                            final locked = _isLocked(question);
                            return ListTile(
                              leading: _QuestionStatusIcon(
                                answer: answer,
                                locked: locked,
                                due: !locked && _isDue(question),
                              ),
                              title: Text(
                                locked
                                    ? 'Q${question.questionNumber} — Locked'
                                    : 'Q${question.questionNumber}. ${question.previewText()}',
                                style: locked
                                    ? theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.42),
                                        fontStyle: FontStyle.italic,
                                      )
                                    : theme.textTheme.bodyMedium,
                              ),
                              trailing: locked
                                  ? Icon(
                                      Icons.lock_outline,
                                      color:
                                          cs.onSurface.withValues(alpha: 0.42),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () => _openQuestion(question),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
    );
  }
}

class _QuestionStatusIcon extends StatelessWidget {
  final UserAnswer? answer;
  final bool locked;

  /// Whether this question's spaced-repetition review is due now. Shown as
  /// a small badge over the base status icon rather than replacing it, so
  /// "due" and "previously wrong" stay visually distinguishable.
  final bool due;

  const _QuestionStatusIcon({
    required this.answer,
    required this.locked,
    this.due = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = _buildBase(context);
    if (!due) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBase(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (locked) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(
          Icons.lock_outline,
          size: 14,
          color: cs.onSurface.withValues(alpha: 0.42),
        ),
      );
    }
    if (answer == null) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(Icons.circle_outlined, size: 14, color: cs.outline),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: answer!.isCorrect
          ? Colors.green.withValues(alpha: 0.14)
          : Colors.red.withValues(alpha: 0.14),
      child: Icon(
        answer!.isCorrect ? Icons.check : Icons.close,
        size: 14,
        color: answer!.isCorrect ? Colors.green : Colors.red,
      ),
    );
  }
}
