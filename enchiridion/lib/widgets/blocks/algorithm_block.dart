import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import '../../theme/app_colors.dart';

class AlgorithmBlockWidget extends StatelessWidget {
  final AlgorithmBlock block;
  final double fontSize;
  final double lineHeight;

  const AlgorithmBlockWidget({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...block.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == block.steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: fontSize * 2,
                    child: Column(
                      children: [
                        Container(
                          width: fontSize * 1.5,
                          height: fontSize * 1.5,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: fontSize * 0.8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: AppColors.gold.withValues(alpha: 0.25),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 8, bottom: isLast ? 0 : fontSize * 0.75),
                      child: Text(
                        step,
                        style: TextStyle(
                          fontSize: fontSize * 0.95,
                          height: lineHeight,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
