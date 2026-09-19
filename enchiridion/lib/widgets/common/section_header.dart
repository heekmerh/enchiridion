/// Shared category section-header style for grouped topic/calculator lists.
///
/// The padding, uppercasing, and text style below are lifted verbatim from
/// `calculator_list_screen.dart`'s private `_sectionHeader` helper, so any
/// screen that renders this widget reads as the same visual system the
/// Calculators screen already established. Pointing the Calculators screen
/// itself at this widget (instead of its own private helper) is a
/// deliberate follow-up left for later — sibling 260918-dqz is editing that
/// file in this same batch, and duplicating the style here avoids a merge
/// collision on that file now.
library;

import 'package:flutter/material.dart';

/// An uppercase, letter-spaced, primary-coloured category heading.
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
