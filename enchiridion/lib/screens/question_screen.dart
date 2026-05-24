import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../services/storage_service.dart';

class QuestionScreen extends StatefulWidget {
  final Question question;
  final String bookId;
  final UserAnswer? previousAnswer;
  final void Function(UserAnswer) onAnswered;

  const QuestionScreen({
    super.key,
    required this.question,
    required this.bookId,
    required this.onAnswered,
    this.previousAnswer,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  String? _selectedOption;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Start fresh even if previously answered (retake support)
  }

  bool get _isCorrect =>
      _selectedOption?.toLowerCase() ==
      widget.question.correctOption.toLowerCase();

  Future<void> _submit() async {
    if (_selectedOption == null) return;
    setState(() => _submitted = true);

    final answer = UserAnswer(
      questionId: widget.question.id,
      selectedOption: _selectedOption!,
      isCorrect: _isCorrect,
      answeredAt: DateTime.now(),
    );
    widget.onAnswered(answer);

    final storage = context.read<StorageService>();
    await storage.saveAnswer(widget.bookId, answer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final q = widget.question;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${q.questionNumber}'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
          ...['a', 'b', 'c', 'd'].map((opt) => _OptionTile(
                option: opt,
                text: q.optionText(opt),
                selected: _selectedOption == opt,
                submitted: _submitted,
                isCorrect: opt == q.correctOption.toLowerCase(),
                onTap: _submitted ? null : () => setState(() => _selectedOption = opt),
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
                      color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Explanation
            Text('Explanation',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.bold)),
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
                  border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3)),
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
                child: Text(text,
                    style: Theme.of(context).textTheme.bodyMedium),
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
