import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import '../../theme/app_colors.dart';

class TableBlockWidget extends StatelessWidget {
  final TableBlock block;
  final double fontSize;
  final double lineHeight;
  final Color? headerTintColor;

  const TableBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    required this.lineHeight,
    this.headerTintColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 1.5),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: theme.dividerColor),
            verticalInside: BorderSide(color: theme.dividerColor),
          ),
          children: [
            if (block.columns.isNotEmpty)
              TableRow(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.inkCharcoal
                      : AppColors.brandPink.withValues(alpha: 0.08),
                ),
                children: block.columns
                    .map((col) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Text(
                            col,
                            style: TextStyle(
                              fontSize: fontSize * 0.85,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ...block.rows.map((row) => TableRow(
                  children: row
                      .map((cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Text(
                              cell,
                              style: TextStyle(
                                fontSize: fontSize * 0.9,
                                height: lineHeight,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ))
                      .toList(),
                )),
          ],
        ),
      ),
    );
  }
}
