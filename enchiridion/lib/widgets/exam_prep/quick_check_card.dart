import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/question.dart';
import '../../models/resource_topic.dart';
import '../../providers/study_stats_provider.dart';
import '../../services/diagnostics_log.dart';
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

  /// Exam module scope the answer is recorded under. Defaults to PLAB's
  /// scope; the bubble host forwards the scope from the launch route.
  final String scope;

  /// Called once the answer is durably recorded, whether or not the user then
  /// closes this card. The bubble host uses it to clear the prompt from the
  /// notification shade, so backing out afterwards cannot leave a prompt for
  /// an already-answered question.
  final VoidCallback? onAnswerRecorded;

  const QuickCheckCard({
    super.key,
    required this.question,
    required this.onDismiss,
    this.scope = kStandaloneExamPrepScope,
    this.onAnswerRecorded,
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
    final review =
        storage.getQuestionReviews(widget.scope)[widget.question.id];
    final seed = Object.hash(widget.question.id, review?.attempts ?? 0);
    _optionOrder = widget.question.optionKeys..shuffle(Random(seed));
  }

  bool get _isCorrect =>
      _selectedOption?.toLowerCase() == widget.question.correctOption;

  Future<void> _submit() async {
    if (_selectedOption == null || _saving) return;
    DiagnosticsLog.event(
        'answer_card_submit_start', {'question_id': widget.question.id});
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
    StudyStatsProvider? statsProvider;
    try {
      // The bubble overlay engine (bubble_main.dart) historically provided
      // only StorageService, so this read threw there: the answer was
      // already stored above, but stats, the rebound notification and the
      // remote push below never ran — a silently half-recorded answer.
      // Prefer the provider when present (it also notifies dashboard
      // listeners); otherwise record stats directly through the service.
      statsProvider = context.read<StudyStatsProvider>();
    } catch (_) {
      statsProvider = null;
    }

    // These are local disk writes (SharedPreferences), but under two-engine
    // contention (this bubble window plus the main app both alive) the prefs
    // platform channel can stall. Bounded so a stuck write can never leave
    // the user stuck on "Saving…" forever — cleared in `finally` regardless
    // of outcome, since the on-screen answer feedback is already correct
    // either way.
    try {
      final review = await DiagnosticsLog.track(
        'answer_card_record_answer',
        () => storage
            .recordAnswer(widget.scope, answer)
            .timeout(const Duration(seconds: 5)),
      );
      if (statsProvider != null) {
        await DiagnosticsLog.track(
          'answer_card_record_stats',
          () => statsProvider!
              .recordAnswer(
                scope: widget.scope,
                isCorrect: _isCorrect,
                answeredAt: answer.answeredAt,
              )
              .timeout(const Duration(seconds: 5)),
        );
      } else {
        await DiagnosticsLog.track(
          'answer_card_record_stats',
          () => StudyStatsService(storage)
              .recordAnswer(
                scope: widget.scope,
                isCorrect: _isCorrect,
                answeredAt: answer.answeredAt,
              )
              .timeout(const Duration(seconds: 5)),
        );
      }

      // Best-effort background work — never gate clearing the saving state
      // (or therefore the dashboard's already-updated numbers) on the
      // network.
      unawaited(NotificationService.instance.scheduleFollowUp(
        scope: widget.scope,
        question: widget.question,
        review: review,
      ));
      unawaited(QuestionReviewSyncService(storage)
          .push(widget.scope, review));
      widget.onAnswerRecorded?.call();
      DiagnosticsLog.event('answer_card_submit_end', {'ok': true});
    } catch (e) {
      // Swallow: the answer/correctness feedback is already on screen from
      // the setState above, so a stalled or failed local write shouldn't
      // block the user from closing the card.
      DiagnosticsLog.error('answer_card_submit', e);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
                'Practice Question',
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
              ..._optionOrder.asMap().entries.map((entry) {
                final option = entry.value;
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
                              Question.displayLabel(entry.key),
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
