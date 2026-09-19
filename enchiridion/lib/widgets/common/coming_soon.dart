/// App-wide "not yet available" presentation rule: the shared label, muted
/// text/icon alphas, badge, and desaturation wrapper every not-yet-available
/// topic, book, or resource row in the app renders through.
///
/// Consumers wired to this module: `osce_screen.dart` (station list),
/// `resource_topic_list_screen.dart` (topic cards), `library_screen.dart`
/// (book shelf pages), and `calculator_list_screen.dart` (calculator list).
/// Any new topic or resource list should route through this module rather
/// than restyling locally.
///
/// `calculator_list_screen.dart` consumes this module for genuinely unbuilt
/// calculators (no working form exists yet), while keeping the freemium
/// paywall lock as a separate state that takes lower precedence — an
/// unbuilt calculator is never shown as locked/purchasable, since a
/// coming-soon row wins whenever both states could apply.
library;

import 'package:flutter/material.dart';

import '../../utils/content_availability.dart';

// `kComingSoonLabel` lives in `content_availability.dart` (added by sibling
// 260918-dqx) — re-exported here so callers who only import this module for
// styling still get the label without an ambiguous-import collision if they
// also import `content_availability.dart` directly for ordering.
export '../../utils/content_availability.dart' show kComingSoonLabel;

/// Shared muted styling for content that has not been written yet.
///
/// The alphas below are lifted verbatim from the freemium-locked branch of
/// `calculator_list_screen.dart._calcTile`, so a locked row and an
/// unavailable row read as one visual family even though they represent
/// different states.
abstract final class ComingSoonStyle {
  static const double titleAlpha = 0.5;
  static const double bodyAlpha = 0.35;
  static const double iconAlpha = 0.4;
  static const double imageOpacity = 0.45;

  static Color title(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: titleAlpha);

  static Color body(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: bodyAlpha);

  static Color icon(ColorScheme cs) =>
      cs.onSurface.withValues(alpha: iconAlpha);

  static Color container(ColorScheme cs) => cs.surfaceContainerHighest;
}

/// A small pill badge stating that content is not yet available.
///
/// Every screen renders this widget rather than writing the phrase inline,
/// so the wording and styling stay identical everywhere.
class ComingSoonBadge extends StatelessWidget {
  /// When true, drops the icon and tightens padding for use inside a dense
  /// `ListTile` trailing slot.
  final bool compact;

  const ComingSoonBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: ComingSoonStyle.container(cs),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Icon(Icons.schedule, size: 14, color: ComingSoonStyle.icon(cs)),
            const SizedBox(width: 4),
          ],
          Text(
            kComingSoonLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ComingSoonStyle.title(cs),
                ),
          ),
        ],
      ),
    );
  }
}

/// Desaturates [child] when [dimmed] is true; a no-op otherwise.
///
/// Used to gray out hero images and cover art so an unavailable card reads
/// as gray even though its artwork is colorful.
class ComingSoonDim extends StatelessWidget {
  final Widget child;
  final bool dimmed;

  const ComingSoonDim({super.key, required this.child, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    if (!dimmed) return child;

    // Luminance weights (Rec. 601-ish, matching the codebase's existing
    // grayscale usage elsewhere) with the alpha row passed through untouched.
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;
    return Opacity(
      opacity: ComingSoonStyle.imageOpacity,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          lr, lg, lb, 0, 0,
          lr, lg, lb, 0, 0,
          lr, lg, lb, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      ),
    );
  }
}
