import 'package:flutter/material.dart';
import '../models/book_catalog.dart';

class UnlockScreen extends StatelessWidget {
  final String? bookId;

  const UnlockScreen({super.key, this.bookId});

  String _bookTitle() {
    if (bookId == null) return 'All Access';
    try {
      return kBooks.firstWhere((b) => b.id == bookId).title;
    } catch (_) {
      return 'Enchiridion';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBookSpecific = bookId != null;
    final title = isBookSpecific ? 'Unlock ${_bookTitle()}' : 'Unlock All Access';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Maybe later',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.lock_open_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // What's included
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What you get:',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...(_unlockBullets(isBookSpecific))
                        .map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 18, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(item,
                                          style:
                                              theme.textTheme.bodyMedium)),
                                ],
                              ),
                            )),
                  ],
                ),
              ),

              const Spacer(),

              // Book-specific unlock CTA
              if (isBookSpecific) ...[
                FilledButton(
                  onPressed: () => _showComingSoon(context),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text('Unlock ${_bookTitle()} — price TBD'),
                ),
                const SizedBox(height: 12),
              ],

              // Full subscription CTA
              FilledButton.tonal(
                onPressed: () => _showComingSoon(context),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Full Subscription — price TBD'),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe later'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _unlockBullets(bool bookSpecific) {
    if (bookSpecific) {
      return [
        'Full book content — all chapters',
        'All question bank questions for this book',
        'Notes and annotations',
      ];
    }
    return [
      'Full content for all 8 specialty books',
      'Complete question banks for every book',
      'All clinical calculators',
      'Notes and annotations',
    ];
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Payment coming soon — thank you for your interest!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
