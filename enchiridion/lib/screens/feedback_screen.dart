import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../utils/bottom_inset.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.service});

  final FeedbackService? service;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  late final FeedbackService _service = widget.service ?? FeedbackService();
  FeedbackCategory? _category;
  bool _categoryMissing = false;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showMessage(ScaffoldMessengerState messenger, String text) {
    messenger.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _send() async {
    if (_sending) return;
    final messageValid = _formKey.currentState!.validate();
    final category = _category;
    setState(() => _categoryMissing = category == null);
    if (!messageValid || category == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await _service.submit(
        category: category,
        message: _messageController.text,
      );
      _showMessage(messenger, 'Thanks — your feedback has been sent.');
      navigator.maybePop();
    } catch (_) {
      _showMessage(
        messenger,
        "Couldn't send your feedback. Check your connection and try again — "
        'your message is still here.',
      );
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + bottomViewportInset(context),
          ),
          children: [
            const Text(
              'Tell us what is not working or what you would like to see next.',
            ),
            const SizedBox(height: 20),
            Text('What is this about?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final option in FeedbackCategory.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: _category == option,
                    onSelected: (_) => setState(() {
                      _category = option;
                      _categoryMissing = false;
                    }),
                  ),
              ],
            ),
            if (_categoryMissing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Choose what this feedback is about.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _messageController,
              minLines: 5,
              maxLines: 10,
              maxLength: FeedbackService.maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Your message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: FeedbackService.validateMessage,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
