import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ReaderProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0

  const ReaderProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: Theme.of(context).dividerColor,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          color: AppColors.brandPink,
        ),
      ),
    );
  }
}
