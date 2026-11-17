import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import 'rich_text.dart';

const _bullets = ['•', '◦', '▪'];

class ListBlockWidget extends StatelessWidget {
  final ListBlock block;
  final double fontSize;
  final double lineHeight;

  const ListBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: theme.colorScheme.onSurface,
    );
    final markerStyle = textStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final title = block.title;

    return Padding(
      padding: EdgeInsets.only(bottom: fontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: fontSize * 0.4),
              child: EmphasisText(
                title,
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          for (final item in block.items)
            Padding(
              padding: EdgeInsets.only(
                left: fontSize * 1.4 * item.level,
                bottom: fontSize * 0.35,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fontSize * (item.label == null ? 1.3 : 2.0),
                    child: Text(
                      item.label ?? _bullets[item.level % _bullets.length],
                      style: markerStyle,
                    ),
                  ),
                  Expanded(child: EmphasisText(item.text, style: textStyle)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
