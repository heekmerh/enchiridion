import 'package:flutter/material.dart';
import '../../models/content_block.dart';

class ChecklistBlockWidget extends StatelessWidget {
  final ChecklistBlock block;
  final double fontSize;
  final double lineHeight;

  const ChecklistBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title != null && block.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block.title!,
                style: TextStyle(
                  fontSize: fontSize * 0.9,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ...block.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline,
                          size: fontSize * 1.1, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: fontSize * 0.95,
                          height: lineHeight,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
