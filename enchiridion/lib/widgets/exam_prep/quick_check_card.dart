import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question.dart';
import '../../models/resource_topic.dart';
import '../../services/notification_service.dart';
import '../../services/question_review_sync_service.dart';
import '../../services/storage_service.dart';
import '../../services/study_stats_service.dart';
import 'explanation_text.dart';

/// Full-screen "answer one question" card shown inside the Android bubble
/// window (see `lib/bubble_main.dart`). Picks a random option order seeded by
/// the question's review attempt count (so repeats aren't memorized by
/// position), submits the answer through the same services the rest of the
/// app uses, then lets the caller decide what "done" means via [onDismiss].
class QuickCheckCard extends StatefulWidget {
  final Question question;
  final VoidCallback onDismiss;

  const QuickCheckCard({
    super.key,
    required this.question,
    required this.onDismiss,
  });

  @override
  State<QuickCheckCard> createState() => _QuickCheckCardState();
}

class _QuickCheckCardState extends State<QuickCheckCard> {
  String? _selectedOption;
  bool _submitted = false;
  bool _saving = false;
  late final List<String> _optionOrder;

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    final review = storage
        .getQuestionReviews(kStandaloneExamPrepScope)[widget.question.id];
    final seed = Object.hash(widget.question.id, review?.attempts ?? 0);
    _optionOrder = widget.question.optionKeys..shuffle(Random(seed));
  }

  bool get _isCorrect =>
      _selectedOption?.toLowerCase() == widget.question.correctOption;

  Future<void> _submit() async {
    if (_selectedOption == null || _saving) return;
    setState(() {
      _saving = true;
      _submitted = true;
    });

    final answer = UserAnswer(
      questionId: widget.question.id,
      selectedOption: _selectedOption!,
      isCorrect: _isCorrect,
      answeredAt: DateTime.now(),
    );

    final storage = context.read<StorageService>();
    final review =
        await storage.recordAnswer(kStandaloneExamPrepScope, answer);
    await NotificationService.instance.scheduleFollowUp(
      scope: kStandaloneExamPrepScope,
      question: widget.question,
      review: review,
    );
    await QuestionReviewSyncService(storage)
        .push(kStandaloneExamPrepScope, review);
    await StudyStatsService(storage).recordAnswer(
      isCorrect: _isCorrect,
      isFirstAttempt: review.attempts == 1,
      scope: kStandaloneExamPrepScope,
      answeredAt: answer.answeredAt,
    );

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Check',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Answer one short question, then get back to what you were doing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.question.questionText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              ..._optionOrder.map((option) {
                final selected = _selectedOption == option;
                final isCorrect = option == widget.question.correctOption;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _submitted
                        ? null
                        : () => setState(() => _selectedOption = option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _submitted
                            ? isCorrect
                                ? Colors.green.withValues(alpha: 0.12)
                                : selected
                                    ? Colors.red.withValues(alpha: 0.12)
                                    : cs.surface
                            : selected
                                ? cs.primaryContainer
                                : cs.surface,
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
              if (_submitted) ...[
                const SizedBox(height: 8),
                Text(
                  _isCorrect ? 'Correct' : 'Not quite',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _isCorrect
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ExplanationText(text: widget.question.explanation),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (!_submitted)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDismiss,
                        child: const Text('Skip'),
                      ),
                    ),
                  if (!_submitted) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitted
                          ? widget.onDismiss
                          : (_selectedOption == null ? null : _submit),
                      child: Text(
                        _submitted ? 'Close' : (_saving ? 'Saving…' : 'Submit'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
