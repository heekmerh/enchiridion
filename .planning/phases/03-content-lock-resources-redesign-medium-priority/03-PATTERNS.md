# Phase 3: Content Lock & Resources Redesign - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 4 (2 modified, 2 new test files)
**Analogs found:** 4 / 4

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `enchiridion/lib/screens/library_screen.dart` (modify `_ToolsTab` → `_ResourcesTab`) | component | request-response | `enchiridion/lib/screens/library_screen.dart` `_LibraryTab` class | exact |
| `enchiridion/lib/screens/reader_screen.dart` (verify gate only, no structural change) | component | request-response | same file — `_LockedChapterOverlay` + `_checkAccess` already in place | exact |
| `enchiridion/test/screens/library_screen_test.dart` (new) | test | — | `enchiridion/test/services/storage_service_test.dart` | role-match |
| `enchiridion/test/screens/reader_screen_test.dart` (new) | test | — | `enchiridion/test/services/storage_service_test.dart` | role-match |

---

## Pattern Assignments

### `enchiridion/lib/screens/library_screen.dart` — _ResourcesTab (replace _ToolsTab)

**Analog:** `_LibraryTab` class and `_BookPage` class, same file (lines 297–506)

**Imports pattern** (lines 1–16 — one new import required: `calculator_list_screen.dart` is not yet imported):
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/calculator_list_screen.dart';  // ADD — not yet present
import '../screens/calculator_screen.dart';
import '../screens/question_list_screen.dart';
import '../screens/unlock_screen.dart';
import '../services/access_service.dart';
import '../config/freemium_config.dart';
```

**Tab rename — single change location** (line 267):
```dart
// BEFORE (line 267):
Tab(icon: Icon(Icons.medical_services_outlined), text: 'Tools'),
// AFTER:
Tab(icon: Icon(Icons.medical_services_outlined), text: 'Resources'),
// Also update line 282: const _ToolsTab() → const _ResourcesTab()
// Also rename the class definition at line 510 and its State class at line 517.
```

**Resource category data model — define at top of file (private to library_screen.dart)**:
```dart
// Place near the top of library_screen.dart, alongside _backgrounds list.
// Mirrors the pattern of using a plain const list for static data.

class _ResourceCategory {
  final String title;
  final String assetPath;
  final void Function(BuildContext) onTap;

  const _ResourceCategory({
    required this.title,
    required this.assetPath,
    required this.onTap,
  });
}
```

**StatefulWidget + PageController lifecycle pattern** (lines 316–334 — clone from `_LibraryTabState`):
```dart
class _ResourcesTabState extends State<_ResourcesTab> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();  // critical — mirrors line 332
    super.dispose();
  }
  // ...
}
```

**PageView + Stack layout pattern** (lines 344–388 — clone from `_LibraryTabState.build`):
```dart
// Key difference from _LibraryTab: use default Axis.horizontal (not Axis.vertical)
// to visually distinguish Resources from Library.
return Stack(
  children: [
    PageView.builder(
      controller: _pageController,
      // scrollDirection: Axis.horizontal,  ← default, omit the parameter
      itemCount: _categories.length,
      itemBuilder: (_, i) => _ResourceCard(
        category: _categories[i],
        onTap: () => _categories[i].onTap(context),
      ),
    ),
    // Page indicator dots — RIGHT side, vertical column (lines 360–385)
    Positioned(
      right: 10,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_categories.length, (i) {
            final active = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 3),
              width: 6,
              height: active ? 18 : 6,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    ),
  ],
);
```

**Resource card widget — image + gradient + label + tap** (lines 391–506 — adapt from `_BookPage`):
```dart
class _ResourceCard extends StatelessWidget {
  final _ResourceCategory category;
  final VoidCallback onTap;

  const _ResourceCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen cover image (mirrors lines 414–422)
          Image.asset(
            category.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: cs.primaryContainer,
              child: Icon(Icons.category_outlined, size: 80, color: cs.onPrimaryContainer),
            ),
          ),
          // Gradient overlay (mirrors lines 424–437)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.5, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          // Bottom label (mirrors lines 441–483)
          Positioned(
            left: 20,
            right: 40,
            bottom: 28,
            child: Text(
              category.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Routing — "coming soon" snackbar for unimplemented destinations** (lines 94–100 — existing pattern in `_openBook`):
```dart
// Use for Instrumentation and OSCE cards (no screen exists yet):
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('Instrumentation — content coming soon'),
  behavior: SnackBarBehavior.floating,
));
```

**Routing — Navigator.push for implemented destinations** (lines 102–105):
```dart
// Calculators card:
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => const CalculatorListScreen(),
));

// Exam Prep card (QuestionListScreen requires bookId):
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => QuestionListScreen(bookId: 'paediatrics'), // TODO: multi-book
));
```

---

### `enchiridion/lib/screens/reader_screen.dart` — Freemium gate (verify only)

**Analog:** Same file — existing implementation is already correct. No code changes needed.

**Existing gate location** (lines 221–233 — verified correct):
```dart
SliverToBoxAdapter(
  child: _hasAccess ||
          bookProvider.currentIndex < kFreeChapterCount
      ? ReaderContent(
          chapter: chapter,
          bookId: widget.bookId,
          onKeysReady: _onKeysReady,
          onOffsetsReady: _onOffsetsReady,
        )
      : _LockedChapterOverlay(
          bookId: widget.bookId,
          chapter: chapter,
        ),
),
```

**Access check async pattern** (lines 67–69 — already in `_ReaderShellState.initState`):
```dart
Future<void> _checkAccess() async {
  final access = await AccessService.instance.hasBookAccess(widget.bookId);
  if (mounted) setState(() => _hasAccess = access);
}
```

**_LockedChapterOverlay — do not modify** (lines 511–579): The overlay correctly uses an empty `Container` (not `ReaderContent`) to avoid duplicate `GlobalKey` crash. The comment at line 530 explains this. Do not add blurred preview content.

---

### `enchiridion/test/screens/library_screen_test.dart` (new)

**Analog:** `enchiridion/test/services/storage_service_test.dart`

**Test file structure pattern** (lines 1–51 of storage_service_test.dart):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
// For widget tests, add:
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:enchiridion/screens/library_screen.dart';

void main() {
  group('LibraryScreen — Resources tab', () {
    testWidgets('tab title shows Resources', (tester) async {
      // pump widget with required providers
      // find Tab with text 'Resources'
      // expect(find.text('Resources'), findsOneWidget)
    });

    testWidgets('carousel renders 4 pages', (tester) async { /* ... */ });
    testWidgets('page indicator dots update on swipe', (tester) async { /* ... */ });
    testWidgets('tapping Calculators card navigates to CalculatorListScreen', (tester) async { /* ... */ });
    testWidgets('resource images load without crash', (tester) async { /* ... */ });
  });
}
```

**Mock setup pattern** (lines 8–18 of storage_service_test.dart):
```dart
// For widget tests that need AccessService, mock it or use a stub:
@GenerateNiceMocks([MockSpec<AccessService>()])
import 'library_screen_test.mocks.dart';

setUp(() {
  // Provide mock services via MultiProvider wrapping the widget under test
});
```

---

### `enchiridion/test/screens/reader_screen_test.dart` (new)

**Analog:** `enchiridion/test/services/storage_service_test.dart`

**Test file structure pattern:**
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:enchiridion/screens/reader_screen.dart';

void main() {
  group('ReaderScreen — freemium gating', () {
    testWidgets('free user sees ReaderContent on chapter index 0', (tester) async { /* ... */ });
    testWidgets('free user sees _LockedChapterOverlay on chapter index 1+', (tester) async { /* ... */ });
    testWidgets('paid user sees ReaderContent on all chapters', (tester) async { /* ... */ });
  });
}
```

---

## Shared Patterns

### withValues(alpha:) — NOT withOpacity()
**Source:** Throughout `library_screen.dart` (lines 231, 376, 433, 477, 494, 496, 565, 638, 644)
**Apply to:** All new color opacity calls in `_ResourcesTab` and `_ResourceCard`
```dart
// Correct (project standard):
Colors.white.withValues(alpha: 0.4)
Colors.black.withValues(alpha: 0.75)

// Forbidden (deprecated, do not introduce):
// Colors.white.withOpacity(0.4)
```

### Navigator.push pattern
**Source:** `enchiridion/lib/screens/library_screen.dart` lines 102–106, 136–140
**Apply to:** All card tap handlers in `_ResourcesTab`
```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => TargetScreen(...),
));
```

### AccessService async check
**Source:** `enchiridion/lib/screens/reader_screen.dart` lines 67–69; also `library_screen.dart` `_ToolsTabState._load` lines 527–535
**Apply to:** Any widget that needs to check paid access before showing content
```dart
Future<void> _checkAccess() async {
  final access = await AccessService.instance.hasBookAccess(bookId);
  if (mounted) setState(() => _hasAccess = access);
}
// Call from initState via WidgetsBinding.instance.addPostFrameCallback or directly.
```

### Provider read pattern (one-shot in callback)
**Source:** `enchiridion/lib/screens/library_screen.dart` lines 62–63, 530–531
**Apply to:** Any `initState`-triggered async load
```dart
// Correct (context.read inside callback, avoids listen during build):
WidgetsBinding.instance.addPostFrameCallback((_) => _load());

Future<void> _load() async {
  final storage = context.read<StorageService>();
  // ...
}
```

---

## No Analog Found

All files in this phase have close analogs in the codebase. No entries.

---

## Metadata

**Analog search scope:** `enchiridion/lib/screens/`, `enchiridion/lib/config/`, `enchiridion/lib/services/`, `enchiridion/test/`
**Files scanned:** 6 source files, 3 test files
**Pattern extraction date:** 2026-05-26

**Key constraints confirmed:**
- `kFreeChapterCount = 1` is already correct in `freemium_config.dart` — no change needed
- `assets/resources/` is already declared in `pubspec.yaml` (line 67) — no change needed
- 4 JPEG files already present: `calculators.jpeg`, `exam_prep.jpeg`, `instrumentation.jpeg`, `osce.jpeg`
- No new packages required
- `_LockedChapterOverlay` at lines 511–579 of `reader_screen.dart` must not be modified
