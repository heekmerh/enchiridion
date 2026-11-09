import 'package:flutter/material.dart';

class BrandDivision extends StatelessWidget {
  const BrandDivision({super.key, this.textAlign = TextAlign.start});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'A division of ultramedikx nigeria limited',
      textAlign: textAlign,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10,
        height: 1.35,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
