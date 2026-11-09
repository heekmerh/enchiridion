import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import '../../models/chapter.dart';
import '../../providers/book_provider.dart';
import '../blocks/block_renderer.dart';

class ReaderContent extends StatelessWidget {
  final Chapter chapter;
  final String bookId;
  final bool asSliver;
  final AutoScrollController? autoScrollController;
  final void Function(Map<String, int> itemIndexes)? onItemIndexesReady;
  final void Function(
    Map<String, GlobalKey> sectionKeys,
    Map<String, GlobalKey> subsectionKeys,
  )? onKeysReady;
  final void Function(Map<String, double> offsets)? onOffsetsReady;
  final void Function(Map<String, GlobalKey> anchorKeys)? onAnchorKeysReady;

  const ReaderContent({
    super.key,
    required this.chapter,
    this.bookId = '',
    this.asSliver = false,
    this.autoScrollController,
    this.onItemIndexesReady,
    this.onKeysReady,
    this.onOffsetsReady,
    this.onAnchorKeysReady,
  });

  @override
  Widget build(BuildContext context) {
    if (asSliver) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        sliver: SliverMainAxisGroup(slivers: [
          if (chapter.tags.isNotEmpty)
            SliverToBoxAdapter(child: _KeywordChips(tags: chapter.tags)),
          BlockRenderer(
            chapter: chapter,
            bookId: bookId,
            asSliver: true,
            autoScrollController: autoScrollController,
            onItemIndexesReady: onItemIndexesReady,
            onKeysReady: onKeysReady,
            onOffsetsReady: onOffsetsReady,
            onAnchorKeysReady: onAnchorKeysReady,
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chapter.tags.isNotEmpty) _KeywordChips(tags: chapter.tags),
          BlockRenderer(
            chapter: chapter,
            bookId: bookId,
            onKeysReady: onKeysReady,
            onOffsetsReady: onOffsetsReady,
            onAnchorKeysReady: onAnchorKeysReady,
          ),
        ],
      ),
    );
  }
}

class _KeywordChips extends StatelessWidget {
  final List<String> tags;

  const _KeywordChips({required this.tags});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RELATED TOPICS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: cs.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: tags.map((tag) {
              return ActionChip(
                label: Text(tag, style: theme.textTheme.bodySmall),
                onPressed: () {
                  final bookProvider = context.read<BookProvider>();
                  final match = bookProvider.chapters
                      .where((c) =>
                          c.id == tag ||
                          c.title.toLowerCase() == tag.toLowerCase())
                      .firstOrNull;
                  if (match != null) {
                    bookProvider.navigateToChapter(match.id);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
