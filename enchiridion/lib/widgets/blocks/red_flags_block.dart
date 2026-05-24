import 'package:flutter/material.dart';
import '../../models/content_block.dart';

class RedFlagsBlockWidget extends StatelessWidget {
  final RedFlagsBlock block;
  final double fontSize;
  final double lineHeight;

  const RedFlagsBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const redColor = Color(0xFFE53935);

    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 1.5),
      decoration: BoxDecoration(
        color: redColor.withValues(alpha: 0.06),
        border: Border.all(color: redColor.withValues(alpha: 0.3)),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      padding: EdgeInsets.all(fontSize * 0.875),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: redColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Red Flags',
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight: FontWeight.bold,
                  color: redColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...block.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 6, color: redColor),
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
