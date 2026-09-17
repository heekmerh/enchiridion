import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/freemium_config.dart';
import '../models/question.dart';
import '../models/resource_topic.dart';
import '../providers/study_stats_provider.dart';
import '../services/access_service.dart';
import '../services/exam_prep_repository.dart';
import '../services/next_question_selector.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';
import 'exam_prep_question_list_screen.dart';
import 'leaderboard_screen.dart';
import 'question_screen.dart';
import 'unlock_screen.dart';

class ExamPrepHomeScreen extends StatefulWidget {
  const ExamPrepHomeScreen({super.key});

  @override
  State<ExamPrepHomeScreen> createState() => _ExamPrepHomeScreenState();
}

class _ExamPrepHomeScreenState extends State<ExamPrepHomeScreen> {
  final ExamPrepRepository _repository = ExamPrepRepository();
  final Map<String, UserAnswer> _answers = {};

  List<Question> _questions = [];
  Question? _randomQuestion;
  int _randomQuestionOptionSeed = 0;
  bool _loading = true;
  bool _hasAccess = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = context.read<StorageService>();
      final questions = await _repository.loadQuestions();
      final hasAccess = await AccessService.instance.hasExamPrepAccess();
      final answers = storage.getAnswers(kStandaloneExamPrepScope);
      final nextQuestion = await NextQuestionSelector(storage)
          .next(bank: questions, hasAccess: hasAccess);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _hasAccess = hasAccess;
        _answers
          ..clear()
          ..addAll(answers);
        _randomQuestion = nextQuestion;
        _randomQuestionOptionSeed = _optionSeedFor(storage, nextQuestion);
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

  int _optionSeedFor(StorageService storage, Question? question) {
    if (question == null) return 0;
    final review =
        storage.getQuestionReviews(kStandaloneExamPrepScope)[question.id];
    return Object.hash(question.id, review?.attempts ?? 0);
  }

  /// Called after `QuestionScreen` has already recorded the answer (storage,
  /// stats, notification scheduling, and the remote push all happen there —
  /// see its `_submit`). This is genuinely this screen's own job only:
  /// tracking the answer locally for the "previously answered" state and
  /// picking the next Quick Check question.
  Future<void> _handleStudyCardAnswer(UserAnswer answer) async {
    final storage = context.read<StorageService>();
    final nextQuestion = await NextQuestionSelector(storage)
        .next(bank: _questions, hasAccess: _hasAccess);
    if (!mounted) return;
    setState(() {
      _answers[answer.questionId] = answer;
      _randomQuestion = nextQuestion;
      _randomQuestionOptionSeed = _optionSeedFor(storage, nextQuestion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // `watch` (not `read`): every answer recorded anywhere in the app calls
    // `notifyListeners()` synchronously, so this screen repaints even though
    // it stays mounted beneath a pushed QuestionScreen/QuickCheckCard route.
    final statsProvider = context.watch<StudyStatsProvider>();
    final today = statsProvider.today;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Prep'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load exam prep.\n\n$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24 + bottomViewportInset(context),
                  ),
                  children: [
                    _ExamMetricCard(
                      title: 'Daily Performance',
                      subtitle:
                          'Tracked locally and synced to Supabase when available.',
                      child: Row(
                        children: [
                          _MetricPill(
                            label: 'Answered',
                            value: '${today.questionsAnswered}',
                          ),
                          const SizedBox(width: 10),
                          _MetricPill(
                            label: 'Correct',
                            value: '${today.correctAnswers}',
                          ),
                          const SizedBox(width: 10),
                          _MetricPill(
                            label: 'Points',
                            value: '${today.performancePoints}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ExamMetricCard(
                      title: 'Access',
                      subtitle: _hasAccess
                          ? 'All ${_questions.length} questions are unlocked.'
                          : 'Questions 1-$kFreeQuestionCount are free. Unlock for the full bank.',
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ExamPrepQuestionListScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.list_alt_outlined),
                              label: const Text('Browse Full Bank'),
                            ),
                          ),
                          if (!_hasAccess) ...[
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UnlockScreen(
                                    bookId: kStandaloneExamPrepScope,
                                  ),
                                ),
                              ),
                              child: const Text('Unlock'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ExamMetricCard(
                      title: 'Quick Check',
                      subtitle:
                          'Short question prompts now appear at random study intervals while you use the app.',
                      child: _randomQuestion == null
                          ? const Text(
                              'No unlocked quick-check question is available yet.')
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => QuestionScreen(
                                          question: _randomQuestion!,
                                          bookId: kStandaloneExamPrepScope,
                                          previousAnswer:
                                              _answers[_randomQuestion!.id],
                                          trackDailyStudyStats: true,
                                          optionSeed: _randomQuestionOptionSeed,
                                          onAnswered: (answer) {
                                            _handleStudyCardAnswer(answer);
                                          },
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.bolt_outlined),
                                    label: const Text('Practice one now'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _ExamMetricCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ExamMetricCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCard extends StatefulWidget {
  final Question question;
  final Future<void> Function(UserAnswer answer) onAnswered;

  const _StudyCard({
    super.key,
    required this.question,
    required this.onAnswered,
  });

  @override
  State<_StudyCard> createState() => _StudyCardState();
}

class _StudyCardState extends State<_StudyCard> {
  String? _selectedOption;
  bool _submitted = false;
  bool _saving = false;

  Future<void> _submit() async {
    if (_selectedOption == null || _saving) return;
    setState(() {
      _saving = true;
      _submitted = true;
    });
    final answer = UserAnswer(
      questionId: widget.question.id,
      selectedOption: _selectedOption!,
      isCorrect:
          _selectedOption!.toLowerCase() == widget.question.correctOption,
      answeredAt: DateTime.now(),
    );
    await widget.onAnswered(answer);
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cs.surfaceContainerHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${widget.question.questionNumber}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.question.questionText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.question.optionKeys.map((option) {
            final selected = _selectedOption == option;
            final isCorrect = option == widget.question.correctOption;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _submitted
                    ? null
                    : () => setState(() => _selectedOption = option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _submitted
                          ? isCorrect
                              ? Colors.green
                              : selected
                                  ? Colors.red
                                  : cs.outline.withValues(alpha: 0.35)
                          : selected
                              ? cs.primary
                              : cs.outline.withValues(alpha: 0.35),
                    ),
                    color: _submitted
                        ? isCorrect
                            ? Colors.green.withValues(alpha: 0.12)
                            : selected
                                ? Colors.red.withValues(alpha: 0.12)
                                : cs.surface
                        : selected
                            ? cs.primaryContainer
                            : cs.surface,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: cs.surfaceContainerHighest,
                        child: Text(
                          option.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(widget.question.optionText(option)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _selectedOption == null ? null : _submit,
            child: Text(_saving ? 'Saving…' : 'Submit Answer'),
          ),
          if (_submitted) ...[
            const SizedBox(height: 14),
            Text(
              _selectedOption?.toLowerCase() == widget.question.correctOption
                  ? 'Correct'
                  : 'Review',
              style: theme.textTheme.titleSmall?.copyWith(
                color: _selectedOption?.toLowerCase() ==
                        widget.question.correctOption
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.question.explanation),
          ],
        ],
      ),
    );
  }
}
