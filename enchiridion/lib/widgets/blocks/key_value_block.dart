import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import '../../theme/app_colors.dart';

class KeyValueBlockWidget extends StatelessWidget {
  final KeyValueBlock block;
  final double fontSize;
  final double lineHeight;

  const KeyValueBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 1.5),
      decoration: BoxDecoration(
        border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.6)),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: block.items.asMap().entries.map((entry) {
          final isLast = entry.key == block.items.length - 1;
          final item = entry.value;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: fontSize * 7,
                      child: Text(
                        item.key,
                        style: TextStyle(
                          fontSize: fontSize * 0.9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPink,
                          height: lineHeight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: fontSize * 0.9,
                          height: lineHeight,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    color: theme.dividerColor.withValues(alpha: 0.4)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
