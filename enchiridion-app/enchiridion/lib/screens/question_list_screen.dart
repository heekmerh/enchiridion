import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question.dart';
import '../models/book_catalog.dart';
import '../services/storage_service.dart';
import '../services/access_service.dart';
import '../services/question_visibility.dart';
import '../config/freemium_config.dart';
import '../utils/bottom_inset.dart';
import 'question_screen.dart';
import 'unlock_screen.dart';

class QuestionListScreen extends StatefulWidget {
  final String bookId;

  const QuestionListScreen({super.key, required this.bookId});

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  List<Question> _questions = [];
  final Map<String, UserAnswer> _answers = {};
  bool _loading = true;
  bool _hasAccess = false;
  String? _error;

  String get _bookTitle => kBooks
      .firstWhere((b) => b.id == widget.bookId, orElse: () => kBooks.first)
      .title;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final access = await AccessService.instance.hasBookAccess(widget.bookId);

      final qRows = await Supabase.instance.client
          .from('questions')
          .select()
          .eq('book_id', widget.bookId)
          .order('question_number');

      final questions = (qRows as List)
          .map((r) => Question.fromJson(r as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      final storage = context.read<StorageService>();
      final answers = storage.getAnswers(widget.bookId);

      setState(() {
        _questions = questions;
        _answers.addAll(answers);
        _hasAccess = access;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  int get _answeredCount => _answers.length;
  int get _correctCount => _answers.values.where((a) => a.isCorrect).length;

  List<Question> get _reviewable => reviewableQuestions(
        bank: _questions,
        answeredIds: _answers.keys.toSet(),
      );

  bool _isLocked(Question q) =>
      !_hasAccess && q.questionNumber > kFreeQuestionCount;

  int _optionSeedFor(Question q) {
    final storage = context.read<StorageService>();
    final review = storage.getQuestionReviews(widget.bookId)[q.id];
    return Object.hash(q.id, review?.attempts ?? 0);
  }

  void _openQuestion(Question q) {
    if (_isLocked(q)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UnlockScreen(),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionScreen(
          question: q,
          bookId: widget.bookId,
          previousAnswer: _answers[q.id],
          trackDailyStudyStats: true,
          optionSeed: _optionSeedFor(q),
          onAnswered: (answer) {
            setState(() => _answers[q.id] = answer);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('$_bookTitle — Review'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(cs)
              : _reviewable.isEmpty
                  ? _buildEmpty(theme)
                  : Column(
                      children: [
                        _buildProgressBanner(theme, cs),
                        Expanded(child: _buildList(theme, cs)),
                      ],
                    ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not load questions. Make sure Supabase is configured.\n\n$_error',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.error),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('You have not answered anything in this book yet.',
              style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(ThemeData theme, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cs.primaryContainer,
      child: Text(
        answeredProgressLabel(answered: _answeredCount, correct: _correctCount),
        style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildList(ThemeData theme, ColorScheme cs) {
    final reviewable = _reviewable;
    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottomViewportInset(context)),
      itemCount: reviewable.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final q = reviewable[i];
        final answer = _answers[q.id];
        final locked = _isLocked(q);

        return ListTile(
          leading: _statusIcon(answer, locked, cs),
          title: Text(
            q.previewText(maxLength: 60),
            style: locked
                ? theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurface.withValues(alpha: 0.4))
                : theme.textTheme.bodyMedium,
          ),
          trailing: locked
              ? Icon(Icons.lock_outline,
                  size: 18, color: cs.onSurface.withValues(alpha: 0.4))
              : const Icon(Icons.chevron_right),
          onTap: () => _openQuestion(q),
        );
      },
    );
  }

  Widget _statusIcon(UserAnswer? answer, bool locked, ColorScheme cs) {
    if (locked) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(Icons.lock_outline,
            size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
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
      backgroundColor: answer.isCorrect
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.red.withValues(alpha: 0.15),
      child: Icon(
        answer.isCorrect ? Icons.check : Icons.close,
        size: 14,
        color: answer.isCorrect ? Colors.green : Colors.red,
      ),
    );
  }
}
