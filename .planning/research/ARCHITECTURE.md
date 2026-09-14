# Architecture Patterns

**Domain:** Flutter mobile medical reference app (multi-book library, calculators, freemium, auth, offline)
**Researched:** 2026-04-11
**Confidence:** HIGH — based on direct inspection of existing codebase, full feature specs in Ideas/, and established Flutter Provider patterns

---

## Recommended Architecture

The app follows a layered architecture with Provider-based state management. The existing single-book reader already demonstrates the correct layer separation. The work ahead is to scale that pattern across 7 books, add an auth/entitlement layer, build a calculator engine, and introduce a question bank.

```
┌─────────────────────────────────────────────────────────┐
│                       UI Layer                          │
│  screens/  ←→  widgets/  (consume providers via context)│
└──────────────────────┬──────────────────────────────────┘
                       │ reads / calls
┌──────────────────────▼──────────────────────────────────┐
│                    Provider Layer                       │
│  AuthProvider  LibraryProvider  BookProvider            │
│  EntitlementProvider  CalculatorProvider                │
│  BookmarkProvider  SettingsProvider  NotesProvider      │
└──────────────────────┬──────────────────────────────────┘
                       │ delegates to
┌──────────────────────▼──────────────────────────────────┐
│                   Service Layer                         │
│  AuthService  BookService  StorageService               │
│  EntitlementService  CalculatorRegistry                 │
└──────────────────────┬──────────────────────────────────┘
                       │ operates on
┌──────────────────────▼──────────────────────────────────┐
│                    Model Layer                          │
│  Book  Chapter  ChapterSection  ChapterSubsection       │
│  ContentGroup  ContentBlock (polymorphic)               │
│  Calculator  CalculatorInput  CalculatorResult          │
│  User  Entitlement  Bookmark  UserSettings  Note        │
└─────────────────────────────────────────────────────────┘
```

**Rule:** Data flows down from services through providers into widgets. User actions flow up from widgets through providers into services. No widget ever calls a service directly. No model contains business logic.

---

## Component Boundaries

### 1. Auth Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Register, log in, persist session, log out, password reset |
| Lives in | `lib/services/auth_service.dart`, `lib/providers/auth_provider.dart` |
| Exposes | `currentUser`, `isAuthenticated`, `login()`, `logout()`, `register()` |
| Communicates with | Firebase Auth (or Supabase); EntitlementProvider depends on it |
| Does NOT do | Access control decisions — that belongs to EntitlementService |

**Why a dedicated service not embedded in a provider:** Auth state management involves async token refresh, stream listening, and error recovery. Keeping it in a service lets the provider stay thin (observe and expose state only).

---

### 2. Entitlement Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Decide what a user may access based on their subscription/purchase state |
| Lives in | `lib/services/entitlement_service.dart`, `lib/providers/entitlement_provider.dart` |
| Exposes | `canReadBook(bookId)`, `canReadChapter(bookId, chapterIndex)`, `canUseCalculator(calcId)`, `canAccessQuestion(bookId, questionIndex)`, `userTier` |
| Communicates with | AuthProvider (user ID), in-app purchase service (purchase receipts), StorageService (cached entitlement state) |
| Does NOT do | UI — it returns true/false; screens decide how to render the gate |

**Freemium rules (from new_features.md):**
- Free: first chapter per book, first 10 questions per book, one calculator per category
- Paid: full book, all questions, all calculators
- Notes/annotations: all authenticated users

**Enforcement pattern — use a thin wrapper widget, not scattered if-blocks:**

```dart
// widgets/gates/content_gate.dart
class ContentGate extends StatelessWidget {
  final bool hasAccess;
  final Widget child;
  final Widget locked;          // paywall / upgrade prompt
  const ContentGate({required this.hasAccess, required this.child, required this.locked});

  @override
  Widget build(BuildContext context) => hasAccess ? child : locked;
}
```

All gating in the app flows through `ContentGate`. The provider resolves `hasAccess`, the gate renders the outcome. This prevents entitlement logic from leaking into screens.

---

### 3. Library Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Display all available books; track recently opened; route into BookProvider for selected book |
| Lives in | `lib/screens/library_screen.dart`, `lib/providers/library_provider.dart` |
| Exposes | `books` (list of BookMeta), `recentBooks`, `selectBook(bookId)` |
| Communicates with | EntitlementProvider (which books are unlocked), BookProvider (loads selected book) |
| Does NOT do | Load full book content — that is BookProvider's job |

**BookMeta vs Book distinction:** The library works with lightweight metadata (id, title, coverAsset, category). Full Book objects (with all chapters and blocks) are only loaded when the user opens a book. This prevents loading 7 large JSON files simultaneously.

```dart
// models/book_meta.dart  — NEW, lightweight
class BookMeta {
  final String id;
  final String title;
  final String coverAsset;   // asset path to book cover image
  final String description;
  final int chapterCount;
}
```

---

### 4. Book / Reader Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Load a single book's JSON, navigate chapters, track reading progress |
| Lives in | `lib/services/book_service.dart` (already exists), `lib/providers/book_provider.dart` (already exists) |
| Evolves to | Accept `bookId` parameter so it can load any of the 7 books, not just `book.json` |
| Exposes | `currentChapter`, `navigate()`, `progress` |
| Communicates with | StorageService (per-book last-read + visited chapters), EntitlementProvider (chapter access check) |

**Key evolution from current state:** BookProvider currently hardcodes a single book. It needs to become:

```dart
class BookProvider extends ChangeNotifier {
  BookProvider(this._storageService, this._bookId);  // bookId injected
  final String _bookId;
  ...
}
```

And `BookService.loadBook()` becomes `BookService.loadBook(String bookId)` which resolves `assets/data/$bookId.json`.

**Per-book storage keys:** StorageService keys must be namespaced by bookId:
```dart
// BEFORE (current, single-book):
static const _lastReadKey = 'enchiridion_last_read_chapter';

// AFTER (multi-book):
String _lastReadKey(String bookId) => 'enchiridion_${bookId}_last_read_chapter';
```

---

### 5. Calculator Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Define calculators as data, execute formulas, validate inputs, format results |
| Lives in | `lib/calculators/` (new top-level feature directory), `lib/providers/calculator_provider.dart` |
| Core types | `CalculatorDefinition`, `CalculatorInput`, `CalculatorResult`, `CalculatorField` |
| Registry | `lib/calculators/calculator_registry.dart` — single source of truth listing all calculators |
| Communicates with | EntitlementProvider (access check), StorageService (saved results / favorites) |

**Calculator as data (not code per-calculator):**

Each calculator is a `CalculatorDefinition` struct. The formula, validation, and interpretation are registered as functions — not subclasses.

```dart
// models/calculator.dart
class CalculatorDefinition {
  final String id;
  final String title;
  final String category;
  final String description;
  final String disclaimer;
  final List<CalculatorField> fields;
  final CalculatorResult Function(Map<String, dynamic> values) compute;
  final String? caution;  // shown as banner for high-risk calculators
}

class CalculatorField {
  final String id;
  final String label;
  final FieldType type;             // numeric, date, select, toggle
  final List<UnitOption>? units;    // e.g. kg / lb; mg/dL / umol/L
  final String? hint;
  final String? validationError;
  final bool Function(dynamic value) validate;
}

class CalculatorResult {
  final String primaryValue;    // "27.3"
  final String primaryUnit;     // "kg/m²"
  final String interpretation;  // "Overweight"
  final String explanation;     // "BMI 27.3 falls in the overweight range..."
  final String? nextStep;
  final List<String> pitfalls;
  final List<String> osceTips;
}
```

The `CalculatorProvider` holds the active calculator, current field values, and computed result. Each calculator's `compute()` function is pure — no side effects, no provider access.

**Why not a class hierarchy per calculator:** There are 8+ v1 calculators and 50+ planned. A data-driven registry with registered compute functions scales without adding files per calculator. New calculators are registered in `calculator_registry.dart`, not in a new `*.dart` file each time.

---

### 6. Question Bank Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Serve MCQ questions per book, track progress, enforce freemium gate |
| Lives in | `lib/providers/question_provider.dart`, `lib/services/question_service.dart` |
| Exposes | `questionsForBook(bookId)`, `submitAnswer()`, `progress` |
| Communicates with | EntitlementProvider (10-question free gate), StorageService (answered/score persistence) |
| Data source | `assets/data/questions_{bookId}.json` — separate file per book, loaded on demand |

---

### 7. Notes / Annotations Component

| Aspect | Detail |
|--------|--------|
| Responsibility | Store and retrieve per-topic user notes (collapsible side notes, floating clip-ins) |
| Lives in | `lib/providers/notes_provider.dart`, within StorageService (local) or cloud sync (future) |
| Scope | Available to all authenticated users (no freemium gate) |
| Key on | `bookId + chapterId + subsectionId` — notes attach to the deepest content unit |

---

### 8. Navigation / Routing

The app has two distinct navigation trees that share auth and entitlement:

```
Root
├── Unauthenticated
│   ├── SplashScreen
│   ├── LoginScreen
│   └── RegisterScreen
│
└── Authenticated
    ├── LibraryScreen (bottom tab: Library)
    │   └── BookScreen(bookId)
    │       └── ReaderScreen(bookId, chapterId)
    │           └── TopicScreen (optional deep link)
    ├── CalculatorListScreen (bottom tab: Calculators)
    │   └── CalculatorCategoryScreen(category)
    │       └── CalculatorScreen(calculatorId)
    └── ProfileScreen (bottom tab: Profile)
```

**Use `go_router` for named routes.** The current app has no router — it uses `Navigator.push`. With 3 navigation trees and deep-linking needs (e.g. a question linking to a book section), named routes with path parameters are required.

---

## Data Flow

### Flow 1: User Opens a Book Chapter

```
User taps book card (LibraryScreen)
  → LibraryProvider.selectBook(bookId)
  → Navigate to BookScreen(bookId)
  → BookProvider(bookId) created with ProxyProvider
    → BookService.loadBook(bookId) reads assets/data/{bookId}.json
    → StorageService.getLastReadChapter(bookId) restores position
  → EntitlementProvider.canReadChapter(bookId, chapterIndex) checked in ReaderScreen
    → If false: ContentGate shows PaywallWidget
    → If true: ReaderContent renders chapter blocks via BlockRenderer
```

### Flow 2: User Runs a Calculator

```
User taps calculator in list
  → EntitlementProvider.canUseCalculator(calcId) checked
    → If false: ContentGate shows UpgradeWidget
    → If true: Navigate to CalculatorScreen(calcId)
  → CalculatorProvider.load(calcId) pulls CalculatorDefinition from CalculatorRegistry
  → User fills fields
    → CalculatorProvider.updateField(fieldId, value)
    → Each update: validate all fields, if valid call definition.compute(values)
    → Notifies listeners with new CalculatorResult
  → UI renders result block reactively
  → User taps Copy: Clipboard.setData(result.formatted())
```

### Flow 3: Auth Gate on App Start

```
SplashScreen mounts
  → AuthProvider.initialize() — restores persisted session
  → If authenticated: Navigate to LibraryScreen
  → If not: Navigate to LoginScreen
  → AuthProvider stream: any auth state change auto-redirects via go_router redirect
```

### Flow 4: Content Access Check (Entitlement)

```
EntitlementProvider observes AuthProvider.currentUser
  → On user change: fetch entitlement state (from local cache or backend)
  → Exposes canRead*/canUse* getters derived from entitlementState
  → ContentGate widgets observe these getters
  → No polling — entitlement state is reactive (ChangeNotifier)
```

---

## How lib/ Structure Should Evolve

### Current structure (single-book reader)

```
lib/
  main.dart
  constants/
  models/          book.dart  chapter.dart  content_block.dart  bookmark.dart  user_settings.dart  search_result.dart
  providers/       book_provider.dart  bookmark_provider.dart  settings_provider.dart
  screens/         reader_screen.dart  splash_screen.dart
  services/        book_service.dart  storage_service.dart
  theme/           app_colors.dart  app_theme.dart
  widgets/         blocks/  drawer/  icons/  reader/
```

### Target structure (full product)

```
lib/
  main.dart
  router.dart                         ← go_router configuration

  constants/
    app_strings.dart
    book_registry.dart                ← NEW: list of all 7 books with metadata

  models/
    book.dart                         KEEP (rename internal fields if needed)
    book_meta.dart                    NEW: lightweight library card model
    chapter.dart                      KEEP
    content_block.dart                KEEP
    bookmark.dart                     KEEP
    user_settings.dart                KEEP
    search_result.dart                KEEP
    user.dart                         NEW: auth user model
    entitlement.dart                  NEW: user tier + unlocked items
    calculator.dart                   NEW: CalculatorDefinition, CalculatorField, CalculatorResult
    question.dart                     NEW: MCQ model
    note.dart                         NEW: user annotation model

  providers/
    auth_provider.dart                NEW
    entitlement_provider.dart         NEW
    library_provider.dart             NEW
    book_provider.dart                EVOLVE: accept bookId param
    bookmark_provider.dart            EVOLVE: namespace by bookId
    settings_provider.dart            KEEP
    calculator_provider.dart          NEW
    question_provider.dart            NEW
    notes_provider.dart               NEW

  services/
    auth_service.dart                 NEW
    book_service.dart                 EVOLVE: loadBook(String bookId)
    storage_service.dart              EVOLVE: namespace keys by bookId
    entitlement_service.dart          NEW
    question_service.dart             NEW

  calculators/
    calculator_registry.dart          NEW: all CalculatorDefinitions in one place
    definitions/
      weight_dose_calculator.dart     NEW (one file per calculator definition)
      iv_infusion_calculator.dart
      gcs_calculator.dart
      bmi_calculator.dart
      edd_ega_calculator.dart
      anion_gap_calculator.dart
      creatinine_clearance_calculator.dart
      holliday_segar_calculator.dart

  screens/
    splash_screen.dart                KEEP
    auth/
      login_screen.dart               NEW
      register_screen.dart            NEW
      password_reset_screen.dart      NEW
    library/
      library_screen.dart             NEW
    reader/
      reader_screen.dart              EVOLVE: accept bookId
    calculators/
      calculator_list_screen.dart     NEW
      calculator_screen.dart          NEW
    questions/
      question_screen.dart            NEW
    profile/
      profile_screen.dart             NEW

  theme/
    app_colors.dart                   KEEP
    app_theme.dart                    KEEP

  widgets/
    blocks/                           KEEP all existing block widgets
    drawer/                           KEEP
    icons/                            KEEP
    reader/                           KEEP
    gates/
      content_gate.dart               NEW
      paywall_widget.dart             NEW
    calculator/
      calculator_field_widget.dart    NEW
      calculator_result_widget.dart   NEW
      unit_selector_widget.dart       NEW
    library/
      book_card_widget.dart           NEW
    common/
      error_state_widget.dart         NEW
      loading_widget.dart             NEW
```

---

## Patterns to Follow

### Pattern 1: ProxyProvider for Book-Scoped Providers

The BookProvider needs both StorageService and the selected bookId. Use `ProxyProvider` so it rebuilds when bookId changes:

```dart
// In main.dart MultiProvider
ProxyProvider2<StorageService, LibraryProvider, BookProvider>(
  update: (_, storage, library, previous) {
    if (library.selectedBookId == null) return previous ?? BookProvider.empty();
    return BookProvider(storage, library.selectedBookId!);
  },
)
```

This avoids a global singleton BookProvider that holds stale data from the previous book.

### Pattern 2: Calculator as Pure Function

Keep compute functions side-effect-free and synchronous. They receive a `Map<String, dynamic>` of field values and return a `CalculatorResult`. No async, no Provider access.

```dart
// calculators/definitions/bmi_calculator.dart
CalculatorDefinition buildBmiCalculator() => CalculatorDefinition(
  id: 'bmi',
  title: 'BMI',
  category: 'General Medicine',
  fields: [...],
  compute: (values) {
    final weightKg = _toKg(values['weight'], values['weight_unit']);
    final heightM = _toMeters(values['height'], values['height_unit']);
    final bmi = weightKg / (heightM * heightM);
    return CalculatorResult(
      primaryValue: bmi.toStringAsFixed(1),
      primaryUnit: 'kg/m²',
      interpretation: _interpretBmi(bmi),
      ...
    );
  },
);
```

### Pattern 3: Offline-First Asset Strategy

All 7 books are bundled as JSON assets. No network request for content. `flutter_cache_manager` is not needed for books — Flutter's asset system provides this.

For content that must be fetched (questions if hosted remotely), use a `cache-then-network` pattern: check local SQLite first, fetch remote on miss, store locally.

For the v1 scope where all content is in assets, the pattern is: `rootBundle.loadString(path)` on first access per book, then keep parsed objects in the provider's state for the session. Do not re-parse JSON on every navigation.

### Pattern 4: Entitlement Check as a Read-Only Derivation

Never store access flags in UI state. The single source of truth is `EntitlementProvider`. Any widget that needs to gate content calls:

```dart
final canRead = context.watch<EntitlementProvider>().canReadChapter(bookId, index);
```

This means the UI stays correct automatically when entitlement state changes (e.g. after purchase).

### Pattern 5: Scroll Position Restoration per Chapter

The current reader resets scroll to 0 on chapter change. For a full library where users return to a book mid-chapter, add per-chapter scroll offset persistence:

```dart
// StorageService
double getScrollOffset(String bookId, String chapterId);
void setScrollOffset(String bookId, String chapterId, double offset);
```

Persist on scroll stop (debounced), restore on chapter mount.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Entitlement Logic in Screen Code

**What it looks like:**
```dart
// BAD — in ReaderScreen build()
if (user.tier == 'free' && chapterIndex > 0) {
  return PaywallScreen();
}
```

**Why bad:** Entitlement rules are scattered across screens. When rules change, every screen needs updating. Business logic is tied to widget lifecycle.

**Instead:** All access decisions live in `EntitlementProvider` / `EntitlementService`. Screens only call `canRead*()` and pass the result to `ContentGate`.

---

### Anti-Pattern 2: Loading All 7 Books on Startup

**What it looks like:**
```dart
// BAD — in main() or a "preload" service
for (final bookId in bookIds) {
  await BookService.loadBook(bookId);
}
```

**Why bad:** 7 large JSON files parsed synchronously on startup. The existing `book.json` is already large; multiplied by 7 this creates a multi-second startup delay.

**Instead:** Load books lazily. The `LibraryProvider` holds `BookMeta` (lightweight). The `BookProvider` only loads the full JSON when the user opens a specific book.

---

### Anti-Pattern 3: Single Global BookProvider

**What it looks like:** One `BookProvider` in `MultiProvider` that gets `setBook(bookId)` called on navigation.

**Why bad:** Book state (current chapter, progress, visited chapters) leaks between books. Navigating back to the library and opening a different book requires manually clearing state, which is error-prone.

**Instead:** Use `ProxyProvider` to create a fresh `BookProvider` scoped to the selected book. Previous book state is naturally discarded.

---

### Anti-Pattern 4: A Subclass per Calculator

**What it looks like:** `BmiCalculator extends BaseCalculator`, `GcsCalculator extends BaseCalculator`...

**Why bad:** 50+ calculators means 50+ files with shared boilerplate. Adding a field to the base requires touching all subclasses. Adding a new calculator requires creating a class.

**Instead:** Data-driven registry (see Pattern 2). New calculators are data entries, not class definitions.

---

### Anti-Pattern 5: SharedPreferences Keys as Magic Strings

**What it looks like:**
```dart
prefs.getString('last_read');            // which book?
prefs.setString('bookmarks', json);      // which book's bookmarks?
```

**Why bad:** Single-book assumption baked into persistence layer. When multi-book is added, existing users' data collides or is lost.

**Instead:** All StorageService keys are namespaced from day one:
```dart
'enchiridion_{bookId}_last_read_chapter'
'enchiridion_{bookId}_visited_chapters'
'enchiridion_{bookId}_bookmarks'
```

---

## Suggested Build Order

Dependencies determine order. Each layer must exist before what depends on it.

```
Phase 1: Models (no dependencies)
  → BookMeta, User, Entitlement, Calculator, Question, Note
  → Evolve: Book, Chapter (add bookId field where needed)

Phase 2: Core Services (depend on models)
  → AuthService (no other service dependencies)
  → StorageService evolution (namespace keys by bookId)
  → EntitlementService (depends on auth state but not service-layer auth)

Phase 3: Auth + Library Providers (depend on services)
  → AuthProvider (wraps AuthService, exposes stream)
  → LibraryProvider (loads BookMeta list, tracks recently opened)

Phase 4: Entitlement Provider (depends on AuthProvider)
  → EntitlementProvider (observes AuthProvider.currentUser)

Phase 5: Auth + Library Screens (depend on providers 3-4)
  → LoginScreen, RegisterScreen, LibraryScreen
  → go_router setup with auth redirect
  → ContentGate widget

Phase 6: Multi-Book Reader (depends on phases 1-4)
  → BookProvider evolution (bookId-parameterized)
  → BookService evolution (loadBook(bookId))
  → ReaderScreen evolution (bookId route param)
  → Freemium gate in reader via ContentGate + EntitlementProvider

Phase 7: Calculator Engine (depends on phases 1-4)
  → CalculatorDefinition models
  → CalculatorRegistry with 8 v1 calculators
  → CalculatorProvider (load, updateField, compute)
  → CalculatorScreen + CalculatorListScreen
  → Entitlement gate for calculators

Phase 8: Question Bank (depends on phases 1-4, 6)
  → Question model + QuestionService
  → QuestionProvider
  → QuestionScreen
  → Entitlement gate (10-question free limit)

Phase 9: Notes / Annotations (depends on phases 1-4, 6)
  → Note model
  → NotesProvider + StorageService extension
  → CollapsibleNotePanel widget in ReaderContent
```

---

## Scalability Considerations

| Concern | Now (1 book) | After v1 (7 books) | Future (50+ calculators) |
|---------|-------------|-------------------|------------------------|
| Content loading | Single JSON in memory | Lazy-load per book, evict on close | Same pattern, no change |
| State size | One BookProvider | One per open book (ProxyProvider) | CalculatorProvider is stateless between sessions |
| Storage keys | Single namespace | Per-book namespacing required | Per-calculator save namespace |
| Entitlement | Not present | In-memory derivation from user tier | Same; server-side verification on purchase |
| Search | Within current chapter | Must search across chapters lazily | Consider pre-built index per book |

---

## Sources

- Direct inspection of `enchiridion/lib/` codebase (all existing providers, services, models, screens, widgets)
- `Ideas/new_features.md` — complete feature specification for auth, library, calculators, question bank, freemium model
- `Ideas/ideas.md` — detailed calculator specifications (8 v1 calculators with formulas, validation rules, field definitions)
- `FLUTTER_IMPLEMENTATION_PLAN.md` — existing build phase history (Phases 1-7 complete)
- Established Flutter Provider architecture conventions (HIGH confidence — widely documented, consistent with existing codebase patterns)
