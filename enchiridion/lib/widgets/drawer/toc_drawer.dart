import 'package:flutter/material.dart';
import '../../models/chapter.dart';
import '../../models/content_block.dart';
import '../../models/bookmark.dart';
import '../../models/search_result.dart';
import '../../theme/app_colors.dart';
import '../icons/custom_icons.dart';
import '../../constants/app_strings.dart';

class TocDrawerContent extends StatefulWidget {
  final List<Chapter> chapters;
  final String currentChapterId;
  final List<Bookmark> bookmarks;
  final Set<String> visitedChapterIds;
  final Function(String) onChapterSelected;
  final Function(List<SearchResult>) onSearchResults;
  final String? currentSectionId;
  final Function(String sectionId, String subsectionId) onSectionSelected;

  const TocDrawerContent({
    super.key,
    required this.chapters,
    required this.currentChapterId,
    required this.bookmarks,
    required this.visitedChapterIds,
    required this.onChapterSelected,
    required this.onSearchResults,
    this.currentSectionId,
    required this.onSectionSelected,
  });

  @override
  State<TocDrawerContent> createState() => _TocDrawerContentState();
}

class _TocDrawerContentState extends State<TocDrawerContent> {
  String _searchQuery = '';
  List<SearchResult> _searchResults = [];
  final Set<String> _expandedChapters = {};

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });

    if (query.length < 3) {
      setState(() {
        _searchResults = [];
      });
      widget.onSearchResults([]);
      return;
    }

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    for (final chapter in widget.chapters) {
      final text = _chapterPlainText(chapter);
      final lowerText = text.toLowerCase();

      int index = lowerText.indexOf(lowerQuery);
      int matchCount = 0;

      while (index != -1 && matchCount < 3) {
        final start = (index - 40).clamp(0, text.length);
        final end = (index + query.length + 40).clamp(0, text.length);

        String snippet = text.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < text.length) snippet = '$snippet...';

        results.add(SearchResult(
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          snippet: snippet,
          matchIndex: index,
        ));

        matchCount++;
        index = lowerText.indexOf(lowerQuery, index + 1);
      }
    }

    setState(() {
      _searchResults = results;
    });
    widget.onSearchResults(results);
  }

  String _chapterPlainText(Chapter chapter) {
    final buffer = StringBuffer();
    for (final section in chapter.sections) {
      buffer.writeln(section.title);
      for (final subsection in section.subsections) {
        buffer.writeln(subsection.title);
        for (final group in subsection.contentGroups) {
          buffer.writeln(group.title);
          for (final block in group.blocks) {
            final blockText = switch (block.runtimeType.toString()) {
              _ => _blockText(block),
            };
            buffer.writeln(blockText);
          }
        }
      }
    }
    return buffer.toString();
  }

  String _blockText(dynamic block) {
    if (block is ParagraphBlock) return block.text;
    if (block is MnemonicBlock) {
      return '${block.mnemonic} ${block.items.map((i) => '${i.key} ${i.label}').join(' ')}';
    }
    if (block is TableBlock) {
      return '${block.columns.join(' ')} ${block.rows.map((r) => r.join(' ')).join(' ')}';
    }
    if (block is ChecklistBlock) {
      return '${block.title ?? ''} ${block.items.join(' ')}';
    }
    if (block is ClinicalPearlsBlock) return block.items.join(' ');
    if (block is RedFlagsBlock) return block.items.join(' ');
    if (block is AlgorithmBlock) {
      return '${block.title} ${block.steps.join(' ')}';
    }
    if (block is KeyValueBlock) {
      return '${block.title ?? ''} ${block.items.map((i) => '${i.key} ${i.value}').join(' ')}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        TextField(
          onChanged: _handleSearch,
          decoration: InputDecoration(
            hintText: AppStrings.queryDatabase,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            prefixIcon: CustomIcons.search(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20,
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? AppColors.inkCharcoal
                : AppColors.frost,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.brandPink,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Search Results
        if (_searchQuery.length >= 3) ...[
          _buildSectionHeader(AppStrings.resultsSection, theme),
          const SizedBox(height: 8),
          if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.noMatchingProtocols,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ..._searchResults.map((result) => _SearchResultItem(
                  result: result,
                  onTap: () => widget.onChapterSelected(result.chapterId),
                )),
          const SizedBox(height: 24),
        ],

        // Bookmarks
        if (widget.bookmarks.isNotEmpty && _searchQuery.isEmpty) ...[
          _buildSectionHeader(AppStrings.savedLocationsSection, theme),
          const SizedBox(height: 8),
          ...widget.bookmarks.map((bookmark) => _BookmarkItem(
                bookmark: bookmark,
                onTap: () => widget.onChapterSelected(bookmark.chapterId),
              )),
          const SizedBox(height: 24),
        ],

        // Chapter List — ExpansionTile tree (D-07, D-08, D-09, D-12)
        if (_searchQuery.isEmpty) ...[
          _buildSectionHeader(AppStrings.protocolsSection, theme),
          const SizedBox(height: 8),
          ...widget.chapters.map((chapter) {
            final isActiveChapter = chapter.id == widget.currentChapterId;
            final isExpanded = _expandedChapters.contains(chapter.id);
            return ExpansionTile(
              key: ValueKey('toc_${chapter.id}'),
              initiallyExpanded: false,
              onExpansionChanged: (expanded) {
                // Navigate only when expanding (tap to open), not on collapse.
                // Collapsing a tile should not trigger chapter navigation (D-07).
                if (expanded) {
                  widget.onChapterSelected(chapter.id);
                }
                setState(() {
                  if (expanded) {
                    _expandedChapters.add(chapter.id);
                  } else {
                    _expandedChapters.remove(chapter.id);
                  }
                });
              },
              leading: isActiveChapter
                  ? const Icon(Icons.circle,
                      size: 8, color: AppColors.brandPink)
                  : null,
              title: Text(
                chapter.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isActiveChapter ? FontWeight.w600 : FontWeight.normal,
                  color: isActiveChapter
                      ? AppColors.brandPink
                      : theme.colorScheme.onSurface,
                ),
              ),
              trailing: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              children: chapter.sections.map((section) {
                return ExpansionTile(
                  key: ValueKey('toc_${section.id}'),
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.only(left: 24, right: 16),
                  title: Text(
                    section.title,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onExpansionChanged: (expanded) {
                    // Navigate to section start when expanding; drawer stays open.
                    if (expanded) {
                      widget.onSectionSelected(section.id, '');
                    }
                  },
                  children: section.subsections.map((sub) {
                    final isActiveSub = sub.id == widget.currentSectionId;
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 48, right: 16),
                      title: Text(
                        sub.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActiveSub
                              ? AppColors.neonTeal
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8),
                          fontWeight: isActiveSub ? FontWeight.w600 : null,
                        ),
                      ),
                      onTap: () => widget.onSectionSelected(section.id, sub.id),
                    );
                  }).toList(),
                );
              }).toList(),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.chapterTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPink,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.neonTeal,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                '"${result.snippet}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontFamily: 'serif',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkItem extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;

  const _BookmarkItem({
    required this.bookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            CustomIcons.bookmark(
              size: 16,
              color: AppColors.brandPink,
              filled: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                bookmark.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
