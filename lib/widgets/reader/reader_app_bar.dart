import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_colors.dart';
import '../icons/custom_icons.dart';

class ReaderAppBar extends StatelessWidget {
  final String title;
  final String currentChapterId;
  final VoidCallback onSettingsPressed;
  final VoidCallback onNotesPressed;

  const ReaderAppBar({
    super.key,
    required this.title,
    required this.currentChapterId,
    required this.onSettingsPressed,
    required this.onNotesPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      // Left padding so content clears the floating back+TOC pill
      titleSpacing: 56,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_note_outlined),
          onPressed: onNotesPressed,
          tooltip: 'Chapter notes',
        ),
        Consumer<BookmarkProvider>(
          builder: (context, bookmarkProvider, _) {
            final isBookmarked = bookmarkProvider.isBookmarked(currentChapterId);
            return IconButton(
              icon: CustomIcons.bookmark(
                filled: isBookmarked,
                color: isBookmarked
                    ? AppColors.brandPink
                    : Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                bookmarkProvider.toggleBookmark(
                  currentChapterId,
                  title,
                );
              },
            );
          },
        ),
        IconButton(
          icon: CustomIcons.settings(),
          onPressed: onSettingsPressed,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
