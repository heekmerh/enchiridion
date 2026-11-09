---
phase: quick-260919-kiz
plan: 01
subsystem: ui
tags: [flutter, dart, library, coming-soon, book-covers]
provides:
  - "ComingSoonScrim widget + ComingSoonStyle.scrimAlpha (0.35) for full-bleed colourful artwork"
  - "Library _BookPage renders covers at full colour with scrim veil for coming-soon books"
affects: [library_screen, coming_soon]
completed: 2026-09-19
status: complete
---

# Quick 260919-kiz: Library full-colour covers Summary

Library book covers render at full colour again. Not-yet-available books keep a 0.35 translucent black scrim plus the Coming Soon badge and snackbar tap-guard.

## Changes
- `enchiridion/lib/widgets/common/coming_soon.dart` — added `ComingSoonStyle.scrimAlpha = 0.35` and `ComingSoonScrim` (const StatelessWidget returning a single `ColoredBox` with `Colors.black.withValues(alpha: scrimAlpha)`; no ColorFiltered, Opacity, or AnimatedContainer). Updated module + `ComingSoonDim` dartdoc with the choosing rule.
- `enchiridion/lib/screens/library_screen.dart` — `_BookPage` cover `Image.asset` is a direct `Stack` child again (wrapper deleted); added `if (book.isComingSoon) const ComingSoonScrim()` above the gradient, below the bottom text. Badge, Recent pill, gradient, tap-guard untouched.
- `enchiridion/test/widgets/coming_soon_test.dart` — new `ComingSoonScrim` group: scrimAlpha == 0.35, veil colour check, no ColorFiltered/Opacity/AnimatedContainer.
- `enchiridion/test/screens/library_screen_test.dart` — readable page has no scrim; placeholder page (`Internal Medicine.jpeg`, found via AssetImage.assetName predicate) has no ColorFiltered/ComingSoonDim ancestor, exactly one scrim, badge still present.

## Verification
- `flutter test test/widgets/coming_soon_test.dart test/screens/library_screen_test.dart` — all 20 pass.
- `flutter analyze lib test` — 9 issues, all pre-existing in untouched files.
- `flutter test` — full suite 270 pass.
- `resource_topic_list_screen.dart` still wraps its thumbnail in `ComingSoonDim` (unchanged, byte-identical to HEAD); its ColorFiltered test passes.

## Shared pattern for siblings
- Full-bleed colourful artwork (image IS the content, e.g. Library book pages) → `ComingSoonScrim` (darken, keep colour).
- Small thumbnails inside text cards + icon/text rows (resource topic cards, OSCE rows, calculator rows) → `ComingSoonDim` / `ComingSoonStyle` muted colours (desaturate/mute).
- Future full-bleed artwork lists should reach for `ComingSoonScrim`, never `ComingSoonDim`.
