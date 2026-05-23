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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_open_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Full access to all chapters and features.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
