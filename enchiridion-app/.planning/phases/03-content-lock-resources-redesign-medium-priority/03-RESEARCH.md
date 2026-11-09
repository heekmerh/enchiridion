# Phase 3: Content Lock & Resources Redesign — Research

**Researched:** 2026-05-26
**Domain:** Flutter freemium gating, PageView carousel, tab rename
**Confidence:** HIGH

---

## Summary

Phase 3 has two independent tracks that can be planned as separate waves:

**Track A — Content Lock:** The freemium gate is already partially implemented. `_LockedChapterOverlay` already exists in `reader_screen.dart` and `kFreeChapterCount = 1` is already defined in `freemium_config.dart`. The ReaderScreen already checks `bookProvider.currentIndex < kFreeChapterCount` and shows the overlay. The primary task in this track is to verify the existing gate fires correctly and add widget tests for it — most of the "implement content lock" work is already shipped.

**Track B — Resources Redesign:** The "Tools" tab (`_ToolsTab` class in `library_screen.dart`) must be renamed to "Resources" and gutted, replacing the calculator list with a `PageView` carousel of 4 category cards backed by `assets/resources/` images. Four JPEG images are already present: `calculators.jpeg`, `exam_prep.jpeg`, `instrumentation.jpeg`, `osce.jpeg`. The existing `_LibraryTab` already has a working page-indicator-dots pattern (right-side vertical dots) that can be cloned for the Resources carousel. Tapping a card routes to the appropriate screen.

**Primary recommendation:** Treat Track A as a verification + test task (1 wave), and Track B as a new UI component task (1–2 waves). No new dependencies required.

---

## Project Constraints (from CLAUDE.md)

- Flutter application lives in `enchiridion/` subdirectory. All source under `enchiridion/lib/`, assets under `enchiridion/assets/`, pubspec at `enchiridion/pubspec.yaml`.
- No Flutter source files at repository root.
- All Flutter commands run from `enchiridion/` directory.
- Architecture: `lib/screens/`, `lib/widgets/`, `lib/models/`, `lib/services/`, `lib/providers/`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chapter freemium gate | Frontend (ReaderScreen) | AccessService + freemium_config | Access check is async, done in widget's `initState`; overlay rendered in the widget tree |
| Resources carousel UI | Frontend (LibraryScreen) | — | Pure UI within existing screen; no new service layer needed |
| Tab rename | Frontend (LibraryScreen) | — | String-only change in `TabBar` widget |
| Page indicator dots | Frontend (_ResourcesTab) | — | Widget state, mirrors _LibraryTab pattern |
| Category → screen routing | Frontend (Navigator) | — | `Navigator.push` from card tap, same pattern used throughout |
| Asset loading | Flutter asset system | pubspec.yaml | Images are already in `assets/resources/` directory |

---

## Standard Stack

No new packages required for this phase. Everything is satisfied by Flutter core widgets and the existing project dependencies.

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter/material.dart` | SDK | PageView, TabBar, indicator dots | Built-in; no dep needed |
| `provider` | ^6.1.1 | Access to AccessService, StorageService | Already used throughout |

### Flutter Widgets Used

| Widget | Purpose | Where Already Used |
|--------|---------|-------------------|
| `PageView` | Horizontal carousel | `_LibraryTab` (vertical scroll) — same API, change axis |
| `PageController` | Tracks current page | `_LibraryTab._pageController` |
| `AnimatedContainer` | Indicator dot animation | `_LibraryTab` lines 368–385 |
| `Image.asset` | Load resource images | `_BookPage`, splash screen |
| `TabBar` / `TabBarView` | Tab navigation | `LibraryScreen` lines 262–285 |

**Installation:** No new packages to install.

---

## Package Legitimacy Audit

No new packages are introduced in this phase. All Flutter SDK widgets are used.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
User taps "Resources" tab
        │
        ▼
LibraryScreen._ResourcesTab (StatefulWidget)
        │
        ├── PageController (tracks current page 0–3)
        │
        ├── PageView (horizontal, 4 pages)
        │       ├── Page 0: Calculators card  ──────► CalculatorListScreen (existing)
        │       ├── Page 1: Exam Prep card    ──────► QuestionListScreen (existing, needs bookId)
        │       ├── Page 2: Instrumentation card ───► placeholder / TBD
        │       └── Page 3: OSCE card         ──────► placeholder / TBD
        │
        └── Positioned indicator dots (right side, vertical)
                └── AnimatedContainer per dot (mirrors _LibraryTab pattern)

ReaderScreen content gating (Track A):
User navigates to chapter N (N >= kFreeChapterCount=1)
        │
        ├── _hasAccess == true  ──► ReaderContent (full content)
        └── _hasAccess == false ──► _LockedChapterOverlay (already exists)
                                          └── "Unlock" button → UnlockScreen
```

### Recommended Project Structure

No new directories needed. Changes are confined to:

```
enchiridion/lib/
├── screens/
│   └── library_screen.dart      ← rename _ToolsTab → _ResourcesTab, replace body
├── config/
│   └── freemium_config.dart     ← no change (kFreeChapterCount=1 already correct)
└── (reader_screen.dart)         ← verify existing gate, no structural change

enchiridion/assets/
└── resources/                   ← already present, 4 images already there
    ├── calculators.jpeg
    ├── exam_prep.jpeg
    ├── instrumentation.jpeg
    └── osce.jpeg

enchiridion/pubspec.yaml         ← verify assets/resources/ entry exists (it does)
```

### Pattern 1: Existing Page Indicator Dots (clone from _LibraryTab)

**What:** Vertical dots on the right side tracking PageView position.
**When to use:** Resources carousel — same visual style as Library tab.

```dart
// Source: enchiridion/lib/screens/library_screen.dart lines 360-388
// (Already implemented in _LibraryTab — copy this pattern to _ResourcesTab)

Positioned(
  right: 10,
  top: 0,
  bottom: 0,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_resources.length, (i) {
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
```

### Pattern 2: Existing Freemium Gate (already implemented)

**What:** Chapter index check with `_LockedChapterOverlay` fallback.
**When to use:** Verifying existing gate is correct — no new code needed.

```dart
// Source: enchiridion/lib/screens/reader_screen.dart lines 222-233
// (Already correct — kFreeChapterCount=1 → only index 0 is free)

SliverToBoxAdapter(
  child: _hasAccess ||
          bookProvider.currentIndex < kFreeChapterCount
      ? ReaderContent(...)
      : _LockedChapterOverlay(
          bookId: widget.bookId,
          chapter: chapter,
        ),
),
```

### Pattern 3: Resource Card with Image Background

**What:** Full-screen card with image + text overlay, taps to route.
**When to use:** Each page in the Resources PageView carousel.

```dart
// Mirrors _BookPage pattern from library_screen.dart lines 391-506
// Adapt for horizontal PageView:

class _ResourceCard extends StatelessWidget {
  final ResourceCategory category;
  final VoidCallback onTap;

  const _ResourceCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            category.assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.category_outlined, size: 80),
            ),
          ),
          // Gradient overlay
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
          // Bottom label
          Positioned(
            left: 20, right: 40, bottom: 28,
            child: Text(
              category.title,
              style: const TextStyle(
                color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **Do not add a second `ReaderContent` widget inside `_LockedChapterOverlay`:** The existing overlay correctly uses an empty `Container` instead of `ReaderContent` to avoid duplicate `GlobalKey` crash. The comment in the code at line 530 explains this. Do not "improve" the preview by rendering actual content there.
- **Do not create a new `PageView` with `Axis.vertical` for the Resources carousel:** The Library tab already uses vertical scroll for books. The Resources carousel should use the default `Axis.horizontal` to visually distinguish the two tabs.
- **Do not hardcode image paths as strings scattered in build methods:** Define a `_ResourceCategory` data class or constant list at the top of the file, analogous to `_backgrounds` list in `LibraryScreen`.
- **Do not re-check `kFreeChapterCount` in multiple places:** It is already the single source of truth in `freemium_config.dart`. Do not duplicate it.
- **Do not forget to update the TabController length** if adding more tabs — though in this phase the count stays at 2 (Library + Resources).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Page indicators | Custom indicator widget | Clone `_LibraryTab` dot pattern | Already pixel-perfect, tested |
| Image loading with error fallback | Custom image widget | `Image.asset` with `errorBuilder` | Flutter built-in handles missing assets gracefully |
| Freemium gate logic | New gate implementation | Existing `_hasAccess` + `kFreeChapterCount` | Gate is already implemented and working |
| Access check async pattern | New async pattern | Clone `_checkAccess()` in ReaderScreen | Identical pattern to what already works |

**Key insight:** The vast majority of this phase is UI surgery on one file (`library_screen.dart`) and verification of existing code (`reader_screen.dart`). The patterns needed all exist within this codebase already.

---

## Common Pitfalls

### Pitfall 1: Duplicate GlobalKey Crash in Locked Overlay

**What goes wrong:** If `_LockedChapterOverlay` were to render a full `ReaderContent` widget (for a "blurred preview" effect), Flutter would register duplicate `GlobalKey` values since `BlockRenderer` in `ReaderContent` creates keys for each section.

**Why it happens:** `BlockRenderer` is a `StatefulWidget` that generates `GlobalKey` anchors. Two instances for the same chapter data would create the same key IDs.

**How to avoid:** The existing overlay already handles this correctly with an empty `Container`. Never replace it with `ReaderContent`.

**Warning signs:** `Duplicate GlobalKey detected` exception at runtime when navigating to a locked chapter.

### Pitfall 2: Tab Rename Breaks _ToolsTab State

**What goes wrong:** When renaming `_ToolsTab` to `_ResourcesTab` (class name change), any `const _ToolsTab()` reference in `LibraryScreen.build` must also be updated.

**Why it happens:** Simple refactor miss — the class reference in `TabBarView.children` at line 282 must be updated alongside the class definition.

**How to avoid:** Grep for all `_ToolsTab` references before committing.

**Warning signs:** Compile error `_ToolsTab is not defined`.

### Pitfall 3: assets/resources/ Already Registered — But Individual Files May Not Be

**What goes wrong:** `pubspec.yaml` already has `- assets/resources/` as a directory entry (line 67). This means Flutter will include all files in that directory automatically. However, if new files are added to the directory later, a `flutter pub get` is needed for them to appear in the asset bundle.

**Why it happens:** Flutter asset discovery happens at build time via pubspec.

**How to avoid:** The 4 JPEG files are already present. No pubspec change is needed for them. Confirm with `flutter pub get` before running.

**Warning signs:** `Unable to load asset: assets/resources/calculators.jpeg` at runtime despite the file existing on disk.

### Pitfall 4: Routing from Resources Cards — `exam_prep` and `osce` Have No Dedicated Screen

**What goes wrong:** `CalculatorListScreen` and `CalculatorScreen` exist. But tapping "Exam Prep" or "OSCE" or "Instrumentation" cards may have no clearly defined destination screen. The roadmap says "Tap category → open section (Calculators → CalculatorScreen, etc.)" — the "etc." is undefined.

**Why it happens:** The category → screen mapping was underspecified.

**How to avoid:** Define a routing decision before implementation. Two safe options:
1. Route Exam Prep → `QuestionListScreen` (with a specific `bookId`), others → placeholder snackbar.
2. Route all unimplemented categories to a "Coming Soon" snackbar (same pattern as books with `hasContent == false`).

**Warning signs:** Tap handler referencing a screen class that does not exist causes compile error.

### Pitfall 5: PageController Disposed While PageView Still Active

**What goes wrong:** If `_ResourcesTab` is a `StatefulWidget` and its `dispose()` does not call `_pageController.dispose()`, a memory leak or "controller was used after being disposed" error occurs on hot restart.

**Why it happens:** PageController holds a native listener.

**How to avoid:** Always override `dispose()` and call `_pageController.dispose()`. The `_LibraryTab` does this correctly at line 331 — mirror the pattern exactly.

---

## Code Examples

### Existing Content Gate (verified — no changes needed)

```dart
// Source: enchiridion/lib/screens/reader_screen.dart lines 222-233
// kFreeChapterCount = 1 means index 0 (Chapter 1) is free, all others locked.
SliverToBoxAdapter(
  child: _hasAccess ||
          bookProvider.currentIndex < kFreeChapterCount
      ? ReaderContent(...)
      : _LockedChapterOverlay(bookId: widget.bookId, chapter: chapter),
),
```

### Tab Rename — Single Change Location

```dart
// Source: enchiridion/lib/screens/library_screen.dart line 267
// BEFORE:
Tab(icon: Icon(Icons.medical_services_outlined), text: 'Tools'),
// AFTER:
Tab(icon: Icon(Icons.medical_services_outlined), text: 'Resources'),
// Also update: _ToolsTab → _ResourcesTab class name + reference at line 282
```

### Resource Category Data Model

```dart
// Recommended — define at top of library_screen.dart or in models/

class _ResourceCategory {
  final String title;
  final String assetPath;
  final VoidCallback? Function(BuildContext) routeBuilder;

  const _ResourceCategory({
    required this.title,
    required this.assetPath,
    required this.routeBuilder,
  });
}
```

### PageView Carousel Skeleton

```dart
// Mirrors _LibraryTab structure — horizontal scroll, same dot indicator

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
    _pageController.dispose();  // critical
    super.dispose();
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `withOpacity()` | `withValues(alpha:)` | Flutter 3.x | Already used in codebase — continue using `withValues` |
| Separate navigator for each tab | Single MaterialApp + Navigator.push | N/A | Used throughout app — follow same push/pop pattern |

**Deprecated/outdated:**
- `withOpacity()`: The codebase consistently uses `withValues(alpha: ...)` everywhere. Do not introduce `withOpacity()` in new code.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | "Instrumentation" and "OSCE" categories have no dedicated screen yet — they should route to a "coming soon" snackbar | Common Pitfalls #4, Code Examples | If a screen exists that we missed, routing to snackbar is unnecessarily conservative |
| A2 | The page indicator dots should be on the right side (vertical column), same as Library tab | Architecture Patterns | User may want horizontal dots at bottom — planner should confirm with user before coding |
| A3 | `exam_prep` card should route to `QuestionListScreen` | Architecture Patterns diagram | May need a specific `bookId` or could be a standalone screen |

---

## Open Questions (RESOLVED)

1. **Unimplemented carousel destinations** — RESOLVED: "Instrumentation" and "OSCE" cards navigate to a "Coming soon" `ScaffoldMessenger.showSnackBar` (same pattern as books without content). Routing is deferred pending dedicated screens.

2. **Exam Prep bookId** — RESOLVED: Route to `QuestionListScreen(bookId: 'paediatrics')` as the only book with content; annotated as TODO for multi-book support when additional books are added.

---

## Environment Availability

Step 2.6: No new external tools required. All dependencies are already in `pubspec.yaml`. Assets already present at `assets/resources/`.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | All tasks | Confirmed (existing project builds) | >=3.0.0 | — |
| assets/resources/*.jpeg | Carousel images | Confirmed (4 files present) | — | errorBuilder fallback |
| `provider` package | AccessService lookup | Confirmed (pubspec.yaml ^6.1.1) | 6.1.x | — |

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + mockito ^5.4.4 |
| Config file | `enchiridion/pubspec.yaml` dev_dependencies |
| Quick run command | `cd enchiridion && flutter test test/` |
| Full suite command | `cd enchiridion && flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| — | Free user sees Chapter 1 content | Widget test | `flutter test test/screens/reader_screen_test.dart` | No — Wave 0 gap |
| — | Free user sees overlay on Chapter 2+ | Widget test | `flutter test test/screens/reader_screen_test.dart` | No — Wave 0 gap |
| — | Paid user sees content on all chapters | Widget test | `flutter test test/screens/reader_screen_test.dart` | No — Wave 0 gap |
| — | Resources tab title shows "Resources" | Widget test | `flutter test test/screens/library_screen_test.dart` | No — Wave 0 gap |
| — | Carousel renders 4 pages | Widget test | `flutter test test/screens/library_screen_test.dart` | No — Wave 0 gap |
| — | Page indicator dots update on swipe | Widget test | `flutter test test/screens/library_screen_test.dart` | No — Wave 0 gap |
| — | Tapping Calculators card opens CalculatorListScreen | Widget test | `flutter test test/screens/library_screen_test.dart` | No — Wave 0 gap |
| — | Resource images load without crash | Widget test | `flutter test test/screens/library_screen_test.dart` | No — Wave 0 gap |

### Sampling Rate
- **Per task commit:** `cd enchiridion && flutter test test/ --name "reader\|resources\|library"`
- **Per wave merge:** `cd enchiridion && flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `enchiridion/test/screens/reader_screen_test.dart` — covers freemium gating
- [ ] `enchiridion/test/screens/library_screen_test.dart` — covers tab rename + carousel

---

## Security Domain

This phase has no authentication, authorization changes, or data handling. The freemium gate reads from an existing cached access service (no new Supabase queries). No ASVS categories are newly applicable.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth changes |
| V3 Session Management | No | No session changes |
| V4 Access Control | Existing only | AccessService (already reviewed) |
| V5 Input Validation | No | No user input in this phase |
| V6 Cryptography | No | No crypto in this phase |

---

## Sources

### Primary (HIGH confidence)
- Codebase — `enchiridion/lib/screens/reader_screen.dart` — verified existing gate implementation [VERIFIED: codebase]
- Codebase — `enchiridion/lib/screens/library_screen.dart` — verified Tools tab structure and dot indicator pattern [VERIFIED: codebase]
- Codebase — `enchiridion/lib/config/freemium_config.dart` — verified `kFreeChapterCount = 1` [VERIFIED: codebase]
- Codebase — `enchiridion/pubspec.yaml` — verified `assets/resources/` already declared [VERIFIED: codebase]
- Filesystem — `enchiridion/assets/resources/` — verified 4 JPEG files exist: calculators.jpeg, exam_prep.jpeg, instrumentation.jpeg, osce.jpeg [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- Flutter SDK documentation — PageView, PageController, AnimatedContainer behavior [ASSUMED — based on training knowledge of Flutter SDK]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against codebase; no new packages
- Architecture: HIGH — all patterns traced to existing code in the repo
- Pitfalls: HIGH — derived from direct code reading (GlobalKey comment in reader_screen.dart, dispose pattern in _LibraryTab)

**Research date:** 2026-05-26
**Valid until:** 2026-06-26 (stable Flutter SDK, no fast-moving dependencies)
