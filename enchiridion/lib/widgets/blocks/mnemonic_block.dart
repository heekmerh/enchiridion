import 'package:flutter/material.dart';
import '../../models/content_block.dart';
import '../../theme/app_colors.dart';

class MnemonicBlockWidget extends StatelessWidget {
  final MnemonicBlock block;
  final double fontSize;
  final double lineHeight;

  const MnemonicBlockWidget({
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
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.brandPink, width: 3),
        ),
        color: Color(0x0FFF66A3), // brandPink @ 6%
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              block.mnemonic,
              style: TextStyle(
                fontSize: fontSize * 1.1,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPink,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Divider(
              height: 1,
              color: AppColors.brandPink,
              indent: 16,
              endIndent: 16),
          ...block.items.map((item) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: fontSize * 1.6,
                      height: fontSize * 1.6,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x2600D2FF), // neonTeal @ 15%
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Text(
                        item.key,
                        style: TextStyle(
                          fontSize: fontSize * 0.85,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: fontSize * 0.95,
                              height: lineHeight,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.value != null && item.value!.isNotEmpty)
                            Text(
                              item.value!,
                              style: TextStyle(
                                fontSize: fontSize * 0.85,
                                height: lineHeight,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
