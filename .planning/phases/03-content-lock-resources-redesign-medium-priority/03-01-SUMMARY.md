---
plan: 03-01
phase: 03
status: complete
completed: 2026-05-27
tasks_completed: 2
tasks_total: 2
self_check: PASSED
---

# Plan 03-01 Summary — Freemium Content Gate: Verify & Test

## What Was Built

Verified the existing freemium gate in `ReaderScreen` and locked it with automated tests. Added two `@visibleForTesting` seams so widget tests run without Supabase or asset loading, and fixed a zero-height bug in `_LockedChapterOverlay` that made the lock UI invisible in both tests and production when rendered inside a `SliverToBoxAdapter`.

## Commits

| Commit | Message |
|--------|---------|
| `09384cc` | test(03-01): add unit test pinning kFreeChapterCount semantics |
| `82b6c4b` | feat(03-01): add AccessService test seam + BookProvider.withBook + overlay height fix |
| `d6200a2` | test(03-01): add widget tests for freemium gate in ReaderScreen |

## Key Files

### Created
- `enchiridion/test/config/freemium_config_test.dart` — 2 unit tests pinning `kFreeChapterCount = 1` and the gate boundary (index 0 free, index 1 locked)
- `enchiridion/test/screens/reader_screen_test.dart` — 3 widget tests: (a) free user at index 0 sees `ReaderContent`, (b) free user at index 1 sees lock overlay + Unlock button, (c) paid user at index 1 sees `ReaderContent`

### Modified
- `enchiridion/lib/services/access_service.dart` — added `@visibleForTesting static bool? testAccessOverride` field; when non-null, `hasBookAccess` returns it immediately without Supabase
- `enchiridion/lib/providers/book_provider.dart` — added `@visibleForTesting BookProvider.withBook(storage, book)` constructor; sets status to loaded immediately, bypasses `rootBundle`
- `enchiridion/lib/screens/reader_screen.dart` — two changes:
  1. Added `@visibleForTesting final BookProvider? testBookProvider` parameter; when set, uses `ChangeNotifierProvider.value` instead of `create` so tests can inject a pre-built provider
  2. Fixed `_LockedChapterOverlay`: wrapped the inner `Stack` in `SizedBox(height: screenHeight)` so it has bounded constraints; previously the Stack had zero height because `Container(color:)` with no child has no intrinsic height in `SliverToBoxAdapter`'s unbounded context

## Deviations from Plan

**Task 2 — testBookProvider seam added** (not in plan): The plan specified only `AccessService.testAccessOverride`. During implementation, discovered that `rootBundle.loadString` in Flutter 3.19+ uses `ui.ImmutableBuffer.fromAsset` which bypasses binary-messenger mocks. Widget tests that create `ReaderScreen` with a `dataFile` path would fail because the fake JSON is never served. Added `ReaderScreen.testBookProvider` and `BookProvider.withBook` to eliminate asset loading from tests entirely.

**`_LockedChapterOverlay` height fix** (not in plan): Discovered that the overlay rendered at 0×0 in `SliverToBoxAdapter` context (unbounded height). The `Stack`'s size was determined by `Container(color:)` which has zero intrinsic height; `Positioned.fill` cannot contribute to Stack size. Fixed with `SizedBox(height: screenHeight)`. This was a pre-existing bug that only surfaced when writing tests.

## Test Results

```
flutter test test/config/freemium_config_test.dart test/screens/reader_screen_test.dart
→ All 5 tests passed

flutter test  (full suite)
→ All 11 tests passed
```

## Self-Check: PASSED

- [x] `kFreeChapterCount = 1` pinned in unit test
- [x] Chapter 0 shows `ReaderContent` for free user
- [x] Chapter 1 shows `_LockedChapterOverlay` (lock icon + Unlock button) for free user
- [x] Chapter 1 shows `ReaderContent` for paid user
- [x] `AccessService.testAccessOverride` resets to null in `tearDown`
- [x] Full suite passes (11/11)
- [x] No modifications to `STATE.md` or `ROADMAP.md`
