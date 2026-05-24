import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import '../../theme/app_colors.dart';

class ClinicalPearlsBlockWidget extends StatelessWidget {
  final ClinicalPearlsBlock block;
  final double fontSize;
  final double lineHeight;

  const ClinicalPearlsBlockWidget({
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
        color: AppColors.neonTeal.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.neonTeal.withValues(alpha: 0.3)),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      padding: EdgeInsets.all(fontSize * 0.875),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppColors.neonTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Clinical Pearls',
                style: TextStyle(
                  fontSize: fontSize * 0.85,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonTeal,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.neonTeal.withValues(alpha: 0.7),
                      ),
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
