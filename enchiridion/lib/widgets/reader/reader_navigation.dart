import 'package:flutter/material.dart';
import '../icons/custom_icons.dart';
import '../../constants/app_strings.dart';

class ReaderNavigation extends StatelessWidget {
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;

  const ReaderNavigation({
    super.key,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (hasPrevious)
            ElevatedButton.icon(
              onPressed: onPreviousPressed,
              icon: CustomIcons.chevronLeft(size: 20),
              label: const Text(AppStrings.previousChapter),
            )
          else
            const SizedBox.shrink(),
          if (hasNext)
            ElevatedButton.icon(
              onPressed: onNextPressed,
              icon: CustomIcons.chevronRight(size: 20),
              label: const Text(AppStrings.nextChapter),
              iconAlignment: IconAlignment.end,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
