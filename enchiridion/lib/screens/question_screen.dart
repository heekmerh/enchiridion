import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../providers/study_stats_provider.dart';
import '../services/notification_service.dart';
import '../services/question_flag_service.dart';
import '../services/question_review_sync_service.dart';
import '../services/storage_service.dart';
import '../utils/bottom_inset.dart';

class QuestionScreen extends StatefulWidget {
  final Question question;
  final String bookId;
  final UserAnswer? previousAnswer;
  final void Function(UserAnswer) onAnswered;
  final bool trackDailyStudyStats;

  /// Shows [previousAnswer] as already submitted and disables answering.
  ///
  /// Used when a caller (e.g. the ambient Quick Check sheet's "Review fully")
  /// already recorded an answer elsewhere and just wants to show the full
  /// explanation and OSCE tip. Without this, reopening the screen let the
  /// user pick again and silently overwrite — including flipping a wrong
  /// answer to correct and cancelling its spaced-repetition rebound.
  final bool readOnly;

  /// Seeds the on-screen option order. Two questions with the same seed
  /// render in the same order; omit it to derive one from the question id.
  /// Callers vary this with how many times the question has been attempted
  /// so the correct answer doesn't always land in the same visual slot.
  final int? optionSeed;

  const QuestionScreen({
    super.key,
    required this.question,
    required this.bookId,
    required this.onAnswered,
    this.previousAnswer,
    this.trackDailyStudyStats = false,
    this.readOnly = false,
    this.optionSeed,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  String? _selectedOption;
  bool _submitted = false;
  late final List<String> _optionOrder;

  @override
  void initState() {
    super.initState();
    if (widget.readOnly && widget.previousAnswer != null) {
      _selectedOption = widget.previousAnswer!.selectedOption;
      _submitted = true;
    }
    // Start fresh otherwise, even if previously answered (retake support).
    _optionOrder = widget.question.optionKeys
      ..shuffle(Random(widget.optionSeed ?? widget.question.id.hashCode));
  }

  bool get _isCorrect =>
      _selectedOption?.toLowerCase() ==
      widget.question.correctOption.toLowerCase();

  Future<void> _submit() async {
    if (widget.readOnly || _selectedOption == null) return;
    setState(() => _submitted = true);

    final answer = UserAnswer(
      questionId: widget.question.id,
      selectedOption: _selectedOption!,
      isCorrect: _isCorrect,
      answeredAt: DateTime.now(),
    );

    // Read providers before the first `await` — reading `context` after an
    // async gap risks resolving against a widget tree that has since
    // changed (or disposed) this element.
    final storage = context.read<StorageService>();
    final statsProvider =
        widget.trackDailyStudyStats ? context.read<StudyStatsProvider>() : null;

    // Local write first — it's authoritative and fast. The review must be
    // recorded before `onAnswered` fires so callers that pick the next
    // question (e.g. the Exam Prep home screen's Quick Check card) see this
    // answer already reflected.
    final review = await storage.recordAnswer(widget.bookId, answer);

    // This is the sole place `StudyDayStats` are recorded for this answer —
    // callers must not also record through their own `onAnswered` handler.
    if (statsProvider != null) {
      await statsProvider.recordAnswer(
        scope: widget.bookId,
        isCorrect: _isCorrect,
        isFirstAttempt: review.attempts == 1,
        answeredAt: answer.answeredAt,
      );
    }

    widget.onAnswered(answer);

    // Notification scheduling and the remote review push are best-effort
    // background work — never gate the answer flow on the network.
    unawaited(NotificationService.instance.scheduleFollowUp(
      scope: widget.bookId,
      question: widget.question,
      review: review,
    ));
    unawaited(QuestionReviewSyncService(storage).push(widget.bookId, review));
  }

  Future<void> _flagQuestion() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _FlagQuestionDialog(),
    );
    if (reason == null || !mounted) return;

    try {
      await QuestionFlagService().submit(
        scope: widget.bookId,
        questionId: widget.question.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — this question has been flagged for review.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't submit the flag — check your connection and try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = widget.question;
    final options = _optionOrder;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${q.questionNumber}'),
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Flag this question',
            onPressed: _flagQuestion,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + bottomViewportInset(context),
        ),
        children: [
          // Question text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(q.questionText, style: theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 20),

          // Options
          ...options.map((opt) => _OptionTile(
                option: opt,
                text: q.optionText(opt),
                selected: _selectedOption == opt,
                submitted: _submitted,
                isCorrect: opt == q.correctOption.toLowerCase(),
                onTap: _submitted
                    ? null
                    : () => setState(() => _selectedOption = opt),
              )),

          const SizedBox(height: 16),

          // Submit / result feedback
          if (!_submitted)
            FilledButton(
              onPressed: _selectedOption == null ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Submit'),
            ),

          if (_submitted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCorrect
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isCorrect ? 'Correct!' : 'Incorrect',
                    style: TextStyle(
                      color: _isCorrect
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Explanation
            Text('Explanation',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(q.explanation, style: theme.textTheme.bodyMedium),

            // OSCE tip
            if (q.osceTip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.school_outlined,
                          size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text('OSCE Tip',
                          style: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 6),
                    Text(q.osceTip!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.teal.shade700)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Back to question list'),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String option;
  final String text;
  final bool selected;
  final bool submitted;
  final bool isCorrect;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.option,
    required this.text,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bgColor = cs.surface;
    Color borderColor = cs.outline.withValues(alpha: 0.4);

    if (submitted) {
      if (isCorrect) {
        bgColor = Colors.green.withValues(alpha: 0.12);
        borderColor = Colors.green;
      } else if (selected && !isCorrect) {
        bgColor = Colors.red.withValues(alpha: 0.12);
        borderColor = Colors.red;
      }
    } else if (selected) {
      bgColor = cs.primaryContainer;
      borderColor = cs.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: borderColor.withValues(alpha: 0.2),
                child: Text(
                  option.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: borderColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ),
              if (submitted && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (submitted && selected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collects optional details for a question flag. Returns the entered text
/// (possibly empty) via [Navigator.pop], or null if the user cancelled.
class _FlagQuestionDialog extends StatefulWidget {
  @override
  State<_FlagQuestionDialog> createState() => _FlagQuestionDialogState();
}

class _FlagQuestionDialogState extends State<_FlagQuestionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Flag this question'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Let us know what's wrong — a typo, the wrong answer marked "
            'correct, unclear wording, anything.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Details (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
