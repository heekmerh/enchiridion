---
phase: 02-reader-ux-polish
plan: "04"
subsystem: reader-screen
tags: [scroll-tracking, timer-removal, active-section, global-keys, callbacks]
dependency_graph:
  requires:
    - 02-03 (BlockRenderer callbacks onKeysReady/onOffsetsReady)
  provides:
    - reader-screen-no-auto-hide-timer
    - active-section-scroll-tracking
    - reader-screen-callback-wired
  affects:
    - lib/screens/reader_screen.dart (_ReaderShellState: D-05 timer removal, D-11 scroll tracking)
    - test/screens/reader_screen_test.dart (pill always-visible behavior test)
tech_stack:
  added: []
  patterns:
    - ScrollController.addListener dispatches to _updateActiveSection (no timer)
    - Linear scan over _sectionOffsets map per scroll event (O(sections))
    - ignore: unused_field comments for fields stored now, consumed in Plan 05
key_files:
  created:
    - lib/screens/reader_screen.dart
    - test/screens/reader_screen_test.dart
    - lib/screens/unlock_screen.dart (stub; pre-existing missing dependency)
  modified: []
decisions:
  - "ignore: unused_field on _sectionKeys and _subsectionKeys — fields intentionally stored now for Plan 05 TOC highlighting; compiler would exit 1 without suppression"
  - "unlock_screen.dart stub created to resolve pre-existing missing import in worktree (library_screen.dart also imports it); stub matches full interface"
  - "_showControls field retained as true; if (_showControls) guard on ReaderProgressBar left as harmless no-op per plan spec"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-23"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 0
---

# Phase 2 Plan 04: Remove Auto-Hide Timer and Add Active-Section Scroll Tracking Summary

**One-liner:** Removed 3-second auto-hide timer from _ReaderShellState (D-05) and added _currentSectionId scroll tracking via _updateActiveSection comparing offsets from BlockRenderer callbacks (D-11); both callback handlers wired into ReaderContent call site.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create reader screen test scaffolding | 7108a10 | test/screens/reader_screen_test.dart |
| 2 | Remove auto-hide timer, add scroll tracking, wire callbacks | 39813e5 | lib/screens/reader_screen.dart, lib/screens/unlock_screen.dart |

## What Was Built

### Task 1 — Test scaffolding

**`test/screens/reader_screen_test.dart`:**

- `_PillAlwaysVisibleStub`: self-contained `StatefulWidget` with `_visible = true`, no Timer, pill widget with `Key('pill')`
- Two tests:
  1. Advances time 4 seconds via `tester.pump(const Duration(seconds: 4))`; asserts `Key('pill')` still visible (D-05 behavior: no timer fires to hide it)
  2. Asserts pill visible on initial render with `_visible = true`
- Does NOT mount the real `ReaderScreen` (which requires Supabase and StorageService); tests the behavior pattern instead

### Task 2 — D-05 + D-11 changes to reader_screen.dart

**D-05 removals:**
- `import 'dart:async'` removed (Timer was the only consumer)
- `Timer? _hideControlsTimer` field removed
- `_resetHideControlsTimer()` method removed entirely
- All three call sites removed: `_onScroll()`, `_navigateToChapter()`, GestureDetector `onTap`
- `_hideControlsTimer?.cancel()` removed from `dispose()`
- `if (!_showControls) setState(() => _showControls = true)` removed from `_onScroll()`
- Back+TOC pill now permanently visible; no timer can hide it

**D-11 additions:**
- Fields: `String? _currentSectionId`, `Map<String, GlobalKey> _sectionKeys`, `Map<String, GlobalKey> _subsectionKeys`, `Map<String, double> _sectionOffsets`
- `_onScroll()` body replaced with single `_updateActiveSection()` call
- `_updateActiveSection()`: O(sections) scan; finds highest anchor offset <= scrollOffset + 100; `setState(() => _currentSectionId = activeId)` when changed
- `_onKeysReady(sectionKeys, subsectionKeys)`: stores key maps from BlockRenderer
- `_onOffsetsReady(offsets)`: stores offset map via setState
- `ReaderContent(...)` call site updated to pass `onKeysReady: _onKeysReady, onOffsetsReady: _onOffsetsReady`

## Verification Results

- `flutter analyze lib/screens/reader_screen.dart` — No issues found (exit 0)
- `flutter test` — 6/6 tests pass (2 new + 4 existing)
- `grep _hideControlsTimer lib/screens/reader_screen.dart` — 0 lines
- `grep _resetHideControlsTimer lib/screens/reader_screen.dart` — 0 lines
- `reader_screen.dart` contains: `_currentSectionId`, `_sectionOffsets`, `_updateActiveSection`, `_onKeysReady`, `_onOffsetsReady`, `onKeysReady: _onKeysReady`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing unlock_screen.dart in worktree**
- **Found during:** Task 2 — `flutter analyze lib/screens/reader_screen.dart` reported `Target of URI doesn't exist: 'unlock_screen.dart'`
- **Issue:** `unlock_screen.dart` is not present in this worktree (same as `profile_screen.dart`, `calculator_screen.dart`, `question_list_screen.dart` which are also missing — pre-existing worktree gap). The `_LockedChapterOverlay` class in reader_screen.dart imports and uses `UnlockScreen`.
- **Fix:** Created `lib/screens/unlock_screen.dart` stub matching the full interface (`UnlockScreen` with optional `bookId` parameter, same constructor as original). This is the minimal fix to unblock the analyzer on `reader_screen.dart`.
- **Files modified:** lib/screens/unlock_screen.dart (created)
- **Commit:** 39813e5

**2. [Rule 2 - Missing suppress] unused_field warnings on _sectionKeys/_subsectionKeys**
- **Found during:** Task 2 — analyzer exited 1 due to `unused_field` on `_sectionKeys` and `_subsectionKeys`
- **Issue:** Both fields are stored in `_onKeysReady()` but not yet consumed within reader_screen.dart (they will be used by Plan 05 when TocDrawerContent receives `currentSectionId`). Flutter analyzer treats stored-but-not-read fields as warnings causing non-zero exit.
- **Fix:** Added `// ignore: unused_field — stored for Plan 05 TOC highlighting` comments on both fields
- **Files modified:** lib/screens/reader_screen.dart
- **Commit:** 39813e5

## Known Stubs

- `lib/screens/unlock_screen.dart`: Stub created to resolve missing import. Full unlock/paywall functionality is not part of this plan; the stub provides the `UnlockScreen` class interface with placeholder UI body. The original `unlock_screen.dart` exists in the main `enchiridion/enchiridion/` project.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes. Changes are widget-state and scroll-listener infrastructure only.

## Self-Check: PASSED

- [x] `lib/screens/reader_screen.dart` — exists
- [x] `test/screens/reader_screen_test.dart` — exists
- [x] `reader_screen.dart` does NOT contain `_hideControlsTimer`
- [x] `reader_screen.dart` does NOT contain `_resetHideControlsTimer`
- [x] `reader_screen.dart` contains `_currentSectionId`, `_sectionOffsets`, `_updateActiveSection`, `_onKeysReady`, `_onOffsetsReady`
- [x] `reader_screen.dart` contains `onKeysReady: _onKeysReady` at ReaderContent call site
- [x] `flutter analyze lib/screens/reader_screen.dart` — No issues found (exit 0)
- [x] `flutter test` — 6/6 pass
- [x] Commit 7108a10 — Task 1 (test file)
- [x] Commit 39813e5 — Task 2 (reader_screen.dart + unlock_screen.dart stub)
