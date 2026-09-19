import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/freemium_config.dart';
import '../models/answered_question_filter.dart';
import '../models/question.dart';
import '../models/resource_topic.dart';
import '../providers/study_stats_provider.dart';
import '../services/access_service.dart';
import '../services/exam_prep_repository.dart';
import '../services/next_question_selector.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';
import 'answered_questions_screen.dart';
import 'leaderboard_screen.dart';
import 'question_screen.dart';
import 'unlock_screen.dart';

class ExamPrepHomeScreen extends StatefulWidget {
  /// For widget tests only. When non-null, the home screen skips
  /// `ExamPrepRepository.loadQuestions()` (which hangs in the widget-test
  /// environment — see `ReaderScreen.testBookProvider` for the same
  /// constraint on `rootBundle`) and uses this list directly.
  @visibleForTesting
  final List<Question>? testQuestions;

  const ExamPrepHomeScreen({super.key, this.testQuestions});

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

  // The in-flight record-and-re-pick work kicked off from the "Start Mock
  // Exam" QuestionScreen's `onAnswered` callback (which is `void`, so this
  // future is otherwise unawaited). `_serveNextQuestion` awaits it before
  // reading the re-picked `_randomQuestion`, so the advance never hands the
  // user back the question they just answered.
  Future<void>? _pendingAnswerWrite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final storage = context.read<StorageService>();
      final questions =
          widget.testQuestions ?? await _repository.loadQuestions();
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

  Future<void> _openAnsweredQuestions(AnsweredQuestionFilter filter) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnsweredQuestionsScreen(
          questions: _questions,
          initialFilter: filter,
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  /// Called after `QuestionScreen` has already recorded the answer (storage,
  /// stats, notification scheduling, and the remote push all happen there —
  /// see its `_submit`). This is genuinely this screen's own job only:
  /// tracking the answer locally for the "previously answered" state and
  /// picking the next mock exam question.
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

  /// Supplies `QuestionScreen.onRequestNext` for the "Start Mock Exam"
  /// entry point: awaits the answer-recording + re-pick already kicked off
  /// by [_handleStudyCardAnswer], then hands over the question it already
  /// picked. Deliberately does NOT call `NextQuestionSelector.next()` again
  /// here — that would burn a second serve-log entry and skip a question.
  Future<NextQuestionResult?> _serveNextQuestion() async {
    await _pendingAnswerWrite;
    if (!mounted || _randomQuestion == null) return null;
    return (question: _randomQuestion!, optionSeed: _randomQuestionOptionSeed);
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
    final totals = statsProvider.totals;

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
                      title: 'Performance',
                      subtitle: 'Tracked on this device — always accurate '
                          'and up to date, online or offline.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _MetricPill(
                                label: 'Answered',
                                value: '${totals.questionsAnswered}',
                                onTap: () => _openAnsweredQuestions(
                                  AnsweredQuestionFilter.answered,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _MetricPill(
                                label: 'Correct',
                                value: '${totals.correctAnswers}',
                                onTap: () => _openAnsweredQuestions(
                                  AnsweredQuestionFilter.correct,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _MetricPill(
                                label: 'Wrong',
                                value: '${totals.wrongAnswers}',
                                onTap: () => _openAnsweredQuestions(
                                  AnsweredQuestionFilter.wrong,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _MetricPill(
                                label: 'Points',
                                value: '${totals.performancePoints}',
                                onTap: () => _openAnsweredQuestions(
                                  AnsweredQuestionFilter.points,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Today: ${today.questionsAnswered} answered, '
                            '${today.performancePoints} points',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.64),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ExamMetricCard(
                      title: 'Access',
                      subtitle: _hasAccess
                          ? 'Full access is active.'
                          : 'You get $kFreeQuestionCount free practice questions. Unlock for unlimited practice.',
                      child: _hasAccess
                          ? null
                          : OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UnlockScreen(
                                    bookId: kStandaloneExamPrepScope,
                                  ),
                                ),
                              ),
                              child: const Text('Unlock'),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _ExamMetricCard(
                      title: 'Mock Exam',
                      subtitle:
                          'Take a mock exam drawn from your unlocked questions. Your answers feed the performance stats above.',
                      child: _randomQuestion == null
                          ? const Text(
                              'No unlocked questions are available yet.')
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
                                          backLabel: 'Back to Exam Prep',
                                          onAnswered: (answer) {
                                            _pendingAnswerWrite =
                                                _handleStudyCardAnswer(answer);
                                          },
                                          onRequestNext: _serveNextQuestion,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.quiz_outlined),
                                    label: const Text('Start Mock Exam'),
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
  final Widget? child;

  const _ExamMetricCard({
    required this.title,
    required this.subtitle,
    this.child,
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
          if (child != null) ...[
            const SizedBox(height: 14),
            child!,
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  /// When set, the pill is tappable — wrapped so the tap produces a visible
  /// ripple and exposes a button to the semantics tree.
  final VoidCallback? onTap;

  const _MetricPill({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: onTap != null,
          label: '$label $value',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          ),
        ),
      ),
    );
  }
}
