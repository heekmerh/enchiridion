---
phase: 03-content-lock-resources-redesign-medium-priority
plan: "02"
subsystem: library-screen
tags: [resources-tab, carousel, pageview, widget-test]
dependency_graph:
  requires: []
  provides: [resources-tab-carousel, calculator-routing, exam-prep-routing]
  affects: [enchiridion/lib/screens/library_screen.dart, enchiridion/test/screens/library_screen_test.dart]
tech_stack:
  added: []
  patterns: [PageView-carousel, AnimatedContainer-dot-indicator, Navigator-push-routing, snackbar-coming-soon]
key_files:
  created:
    - enchiridion/test/screens/library_screen_test.dart
    - enchiridion/test/screens/library_screen_test.mocks.dart
  modified:
    - enchiridion/lib/screens/library_screen.dart
decisions:
  - Removed unused imports (access_service, calculator_screen, unlock_screen, freemium_config, calculator_definition) after replacing _ToolsTab
  - Used _FakeAuthProvider in tests to bypass Supabase constructor in AuthProvider
  - Initialized fake Supabase (stub credentials) in setUpAll so CalculatorListScreen.initState resolves AccessService.instance
  - Used find.byType(PageView).last in swipe test to disambiguate from Library tab's vertical PageView
  - Tested via full LibraryScreen (not private _ResourcesTab) since Dart privacy prevents direct import
metrics:
  duration: "~20 minutes"
  completed: "2026-05-26"
  tasks_completed: 2
  files_changed: 3
---

# Phase 03 Plan 02: Resources Tab Carousel Summary

Replaced the _ToolsTab calculator list with a horizontal 4-page carousel (_ResourcesTab) in library_screen.dart, mirroring the _LibraryTab vertical carousel pattern. Added 5 widget tests covering tab label, 4-page render, 4-dot indicator, page swipe, and CalculatorListScreen routing.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Build _ResourcesTab carousel and rename Tools tab | 87916da | enchiridion/lib/screens/library_screen.dart |
| 2 | Widget tests for Resources tab and carousel | b31022d | enchiridion/test/screens/library_screen_test.dart |
| - | Fix gotrue import lint warning | 443e125 | enchiridion/test/screens/library_screen_test.dart |

## What Was Built

**Task 1 — library_screen.dart changes:**
- Renamed "Tools" tab to "Resources" (line 267)
- Replaced `const _ToolsTab()` with `const _ResourcesTab()` in TabBarView
- Deleted `_ToolsTab`, `_ToolsTabState`, `_CalcTile` classes entirely (118 lines removed)
- Added `_ResourceCategory` data class (title, assetPath, onTap callback)
- Added `_ResourcesTabState` with PageController lifecycle cloned from `_LibraryTabState`:
  - `late final PageController _pageController; int _currentPage = 0;`
  - Listener rounds `page` and calls `setState` on change
  - `dispose()` calls `_pageController.dispose()` (mandatory per RESEARCH pitfall)
- Added 4 resource categories with correct routing:
  - Calculators → `CalculatorListScreen()`
  - Exam Prep → `QuestionListScreen(bookId: 'paediatrics')` (with TODO: multi-book comment)
  - Instrumentation → coming-soon SnackBar
  - OSCE → coming-soon SnackBar
- Added `_ResourceCard` StatelessWidget: GestureDetector → Stack → Image.asset (with errorBuilder) + gradient overlay + label
- Right-side dot indicator with `List.generate(_categories.length, ...)` — 4 AnimatedContainers
- Added import `calculator_list_screen.dart`; removed now-unused `access_service`, `calculator_screen`, `unlock_screen`, `freemium_config`, `calculator_definition` imports
- All opacity via `withValues(alpha:)` — zero `withOpacity()` calls

**Task 2 — library_screen_test.dart (new):**
- 5 testWidgets cases in `group('LibraryScreen — Resources tab', ...)`
- `_FakeAuthProvider` stub class bypasses `Supabase` in `AuthProvider` constructor
- `setUpAll` calls `SharedPreferences.setMockInitialValues({})` then `Supabase.initialize` with test credentials so `CalculatorListScreen.initState` resolves without crashing
- Test (a): tab label — `find.text('Resources')` one widget, `find.text('Tools')` nothing
- Test (b): carousel — first card 'Calculators' visible after tab switch
- Test (c): 4 indicator dots — explicit `tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).length == 4`
- Test (d): swipe — `find.byType(PageView).last` fling, then 'Exam Prep' visible and 4 dots remain
- Test (e): routing — tap 'Calculators', pumpAndSettle, `find.byType(CalculatorListScreen)` found

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing cleanup] Remove unused imports after _ToolsTab deletion**
- **Found during:** Task 1 (`flutter analyze` reported warning)
- **Issue:** `access_service.dart`, `calculator_screen.dart`, `unlock_screen.dart`, `freemium_config.dart`, `calculator_definition.dart` all became unused after removing _ToolsTab
- **Fix:** Removed all 5 unused imports
- **Files modified:** enchiridion/lib/screens/library_screen.dart
- **Commit:** 87916da

**2. [Rule 1 - Bug] Fix `prefer_const_constructors` lint for QuestionListScreen**
- **Found during:** Task 1 (`flutter analyze`)
- **Issue:** `QuestionListScreen(bookId: 'paediatrics')` missing `const` despite const constructor
- **Fix:** Added `const` keyword
- **Files modified:** enchiridion/lib/screens/library_screen.dart
- **Commit:** 87916da

**3. [Rule 1 - Bug] Fix `depend_on_referenced_packages` lint in test file**
- **Found during:** Task 2 final `flutter analyze` run
- **Issue:** Imported `package:gotrue/gotrue.dart` directly (transitive dep, not declared in pubspec)
- **Fix:** Replaced with `package:supabase_flutter/supabase_flutter.dart show Supabase, User`
- **Files modified:** enchiridion/test/screens/library_screen_test.dart
- **Commit:** 443e125

### Test Architecture Decision

The plan notes "If LibraryScreen cannot be pumped in isolation, narrow the test to pumping _ResourcesTab body directly." Since `_ResourcesTab` is private (Dart `_` prefix), it cannot be imported from test files in a different library. The decision was to pump `LibraryScreen` with stubbed providers instead. This required:
1. `_FakeAuthProvider` implementing `AuthProvider` without calling `Supabase`
2. Fake Supabase initialization in `setUpAll` with `SharedPreferences.setMockInitialValues({})`

This approach is documented here as an intentional narrowing decision per the plan.

## Known Stubs

None — the plan goal is fully achieved. Exam Prep routes to `QuestionListScreen(bookId: 'paediatrics')` with a TODO comment for future multi-book support; this is intentional per spec, not a stub.

## Verification Results

- `flutter analyze --no-pub`: No issues found
- `flutter test test/screens/library_screen_test.dart --no-pub`: 5/5 tests passed
- `flutter test --no-pub`: 11/11 tests passed (no regressions)
- Acceptance criteria: all 10 criteria from Task 1 and 4 criteria from Task 2 met

## Self-Check: PASSED

Files created/modified:
- [x] enchiridion/lib/screens/library_screen.dart — FOUND
- [x] enchiridion/test/screens/library_screen_test.dart — FOUND
- [x] enchiridion/test/screens/library_screen_test.mocks.dart — FOUND

Commits:
- [x] 87916da — feat(03-02): replace _ToolsTab with _ResourcesTab carousel
- [x] b31022d — test(03-02): add widget tests for Resources tab carousel
- [x] 443e125 — fix(03-02): import User from supabase_flutter instead of gotrue directly
