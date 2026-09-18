---
phase: quick-260918-dqx
plan: 01
subsystem: ui
tags: [flutter, dart, ordering, osce, library, resource-topics]

# Dependency graph
requires: []
provides:
  - "enchiridion/lib/utils/content_availability.dart: shared availableFirst<T> stable partition helper + kComingSoonLabel constant"
  - "ResourceTopic.hasContent + kOsceTopicsInDisplayOrder"
  - "CatalogBook.hasContent (pre-existing) consumed by booksInDisplayOrder"
  - "booksInDisplayOrder(history) pure helper in book_catalog.dart"
  - "ResourceTopicListScreen self-orders its topics input via availableFirst"
  - "test/guards/available_before_coming_soon_guard_test.dart repo-wide invariant"
affects: [260918-dqy, 260918-dqz, 260918-dr0, 260918-dr3]

# Actuals (#2632)
actuals:
  tokens: 4990
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "availableFirst<T>(items, isAvailable): stable two-bucket partition (never List.sort) for any mixed available/placeholder list"
    - "Derived display-order list pattern: keep the authored source-of-truth list (e.g. kOsceTopics) untouched, publish a separate *InDisplayOrder list for UI to read"
    - "List screens order their own input (ResourceTopicListScreen), not their call sites, so future sibling lists inherit the rule for free"

key-files:
  created:
    - enchiridion/lib/utils/content_availability.dart
    - enchiridion/test/models/content_availability_test.dart
    - enchiridion/test/guards/available_before_coming_soon_guard_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/models/book_catalog.dart
    - enchiridion/lib/screens/osce_screen.dart
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart
    - enchiridion/test/screens/osce_screen_test.dart

key-decisions:
  - "availableFirst is a stable two-bucket partition, not a comparator sort, so authored curation order inside each group is never scrambled"
  - "kOsceTopics stays in its authored order as the source of truth; kOsceTopicsInDisplayOrder is a separate derived list that UI reads, so future edits to the authored list don't need to think about display order"
  - "ResourceTopicListScreen orders its own `topics` input at the top of build(), not at each call site, so 260918-dr0 (Surgical Instrumentation) and 260918-dr3 (Medical Instrumentation) inherit the rule with zero code changes"
  - "booksInDisplayOrder keeps availability as the OUTER sort key and recency as the inner key, so a placeholder book can never outrank a readable one no matter how recently a user 'opened' its coming-soon snackbar"

patterns-established:
  - "Shared ordering rule lives in one pure, Flutter-free file (content_availability.dart) that both model and widget layers can import without a widget-test dependency"
  - "Guard test convention (test/guards/): one invariant per file, table-driven over named catalogs, failure reason names the offending catalog and index"

requirements-completed: [RANK-260918-DQX]

coverage:
  - id: D1
    description: "OSCE list leads with the only station that has real written content (Abdominal Examination), placeholder stations follow"
    requirement: RANK-260918-DQX
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#OSCE opens as a list, then shows tabs at the selected station"
        status: pass
    human_judgment: false
  - id: D2
    description: "OSCE tab strip reads the same ordered list as the OSCE list, so tapping a station opens that same station (index desync impossible)"
    requirement: RANK-260918-DQX
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#OSCE opens as a list, then shows tabs at the selected station"
        status: pass
    human_judgment: false
  - id: D3
    description: "Surgical/Medical Instrumentation topic lists (and any future ResourceTopicListScreen caller) rank topics with content ahead of outline-only topics"
    requirement: RANK-260918-DQX
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/models/content_availability_test.dart#ResourceTopicListScreen orders its own input so a topic with content renders as the first tile even when given first without content"
        status: pass
      - kind: unit
        ref: "enchiridion/test/guards/available_before_coming_soon_guard_test.dart#every display-order catalog ranks content ahead of placeholders"
        status: pass
    human_judgment: false
  - id: D4
    description: "Library book shelf ranks readable books ahead of placeholder books, with recency ordering applied only among readable books"
    requirement: RANK-260918-DQX
    verification:
      - kind: unit
        ref: "enchiridion/test/models/content_availability_test.dart#booksInDisplayOrder with no history, readable books rank ahead of every placeholder"
        status: pass
      - kind: unit
        ref: "enchiridion/test/models/content_availability_test.dart#booksInDisplayOrder with history on a readable book, that book ranks first and readable books still rank above placeholders"
        status: pass
    human_judgment: false
  - id: D5
    description: "A single shared availableFirst ordering helper exists in lib/utils/, stable and Flutter-free, so a future list adopts the rule by calling one function"
    requirement: RANK-260918-DQX
    verification:
      - kind: unit
        ref: "enchiridion/test/models/content_availability_test.dart#availableFirst partitions available items ahead of pending items, stably"
        status: pass
      - kind: unit
        ref: "enchiridion/test/models/content_availability_test.dart#availableFirst is idempotent on an already-ordered list"
        status: pass
    human_judgment: false

duration: 16min
completed: 2026-09-18
status: complete
---

# Quick Task 260918-dqx: Available-content-ranks-first ordering Summary

**Shared `availableFirst` stable-partition helper wired through OSCE, Instrumentation, and Library — with a repo-wide guard test locking the invariant in place.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-09-18T14:02:00+01:00 (approx.)
- **Completed:** 2026-09-18T14:09:15+01:00
- **Tasks:** 3
- **Files modified:** 9 (3 created, 6 modified)

## Accomplishments
- Created `enchiridion/lib/utils/content_availability.dart`: a pure-Dart, Flutter-free `availableFirst<T>` stable two-bucket partition helper plus the `kComingSoonLabel` constant, documented as the app-wide ordering rule.
- `ResourceTopic.hasContent` now mirrors `CatalogBook.hasContent`; `kOsceTopicsInDisplayOrder` is the derived, availability-ordered list both `OsceScreen`'s list and `_OsceDetailScreen`'s `TabController`/`TabBar`/`TabBarView` read — eliminating the index-desync risk between list and tabs.
- `booksInDisplayOrder(history)` in `book_catalog.dart` replaces `library_screen.dart`'s inline `_sortedBooks` comparator: availability is the outer sort key, recency is the inner key.
- `ResourceTopicListScreen` orders its own `topics` input via `availableFirst` at the top of `build()`, so Surgical/Medical Instrumentation lists (and any future caller) inherit the rule without their own sort code.
- Added a table-driven repo-wide guard test (`test/guards/available_before_coming_soon_guard_test.dart`) asserting the invariant across every current display-order catalog; fails the suite if any catalog regresses to interleaved order.
- Full `flutter test` suite (71 tests) and `flutter analyze` on all six changed source files are clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: Shared availability ordering helper, proven end-to-end on OSCE** - `591f891` (feat)
2. **Task 2: Apply the rule to the instrumentation lists and the Library shelf** - `45508b7` (feat)
3. **Task 3: Repo-wide guard test for the ordering invariant** - `9cc0cc2` (test)

## Files Created/Modified
- `enchiridion/lib/utils/content_availability.dart` - New shared `availableFirst<T>` stable partition helper + `kComingSoonLabel`
- `enchiridion/lib/models/resource_topic.dart` - `ResourceTopic.hasContent` getter; `kOsceTopicsInDisplayOrder` derived list
- `enchiridion/lib/models/book_catalog.dart` - `booksInDisplayOrder(history)` pure helper
- `enchiridion/lib/screens/osce_screen.dart` - List, `TabController`, `TabBar`, and `TabBarView` all read `kOsceTopicsInDisplayOrder`
- `enchiridion/lib/screens/library_screen.dart` - `_sortedBooks` delegates to `booksInDisplayOrder(_history)`
- `enchiridion/lib/screens/resource_topic_list_screen.dart` - Orders its own `topics` input via `availableFirst` before rendering
- `enchiridion/test/screens/osce_screen_test.dart` - Updated for available-first order; resolves expected tab index from the ordered list instead of a hardcoded literal
- `enchiridion/test/models/content_availability_test.dart` - New: `availableFirst` edge cases, `booksInDisplayOrder` recency/availability interaction, `ResourceTopicListScreen` render-order widget test
- `enchiridion/test/guards/available_before_coming_soon_guard_test.dart` - New: repo-wide ordering invariant guard, table-driven over all current catalogs

## Shared utility for siblings

Siblings 260918-dqy, 260918-dqz, 260918-dr0, and 260918-dr3 should consume the
following rather than re-declaring their own ordering or status handling:

- **File:** `enchiridion/lib/utils/content_availability.dart` (pure Dart, no
  Flutter import — safe to use from models, services, or widgets).
- **`availableFirst` signature:**
  ```dart
  List<T> availableFirst<T>(Iterable<T> items, bool Function(T) isAvailable)
  ```
  Stable two-bucket partition: returns every item for which `isAvailable`
  returns `true`, in their original relative order, followed by every item
  for which it returns `false`, also in their original relative order.
  Empty input returns an empty list; an all-available or all-unavailable
  input is returned unchanged.
- **`kComingSoonLabel` constant:**
  ```dart
  const String kComingSoonLabel = 'Coming Soon';
  ```
  The single spelling for "not yet written" status copy — 260918-dqy
  (grey-out styling) and 260918-dqz (calculator status chips) should reuse
  this exact string rather than hardcoding their own.
- **`ResourceTopic.hasContent`** (in `enchiridion/lib/models/resource_topic.dart`):
  ```dart
  bool get hasContent => dataAssetPath != null;
  ```
  Already used by `kOsceTopicsInDisplayOrder` and by `ResourceTopicListScreen`,
  which self-orders any `topics` list it's given — so 260918-dr0 (Surgical
  Instrumentation) and 260918-dr3 (Medical Instrumentation) get available-first
  ordering automatically as long as they route through `ResourceTopicListScreen`,
  with no additional code.
- **`booksInDisplayOrder`** (in `enchiridion/lib/models/book_catalog.dart`):
  ```dart
  List<CatalogBook> booksInDisplayOrder(Map<String, DateTime> history)
  ```
  Pure function: recency-sorts a copy of `kBooks` by `history` (most-recent
  first, history-bearing books ahead of history-less ones — the same
  comparator `library_screen.dart`'s old `_sortedBooks` used), then runs the
  result through `availableFirst` keyed on `CatalogBook.hasContent`.
  Availability is the OUTER key; recency only orders within a group.

## Decisions Made
- `availableFirst` implemented as an explicit two-bucket walk rather than
  `List.sort` with a comparator, because Dart's `sort` is not guaranteed
  stable and could scramble authored curation order inside each availability
  group.
- `kOsceTopics` was left untouched in its authored order; a new derived
  `kOsceTopicsInDisplayOrder` list was added instead of reordering
  `kOsceTopics` in place, so the authored list remains the single source of
  truth for content structure and future edits to it don't need to reason
  about display order.
- Ordering was placed inside `ResourceTopicListScreen.build()` (not at each
  call site) specifically so sibling plans building new instrumentation
  lists inherit the rule without writing any ordering code themselves.

## Deviations from Plan

None - plan executed exactly as written. One task-owned addition beyond the
literal action text: the plan's Task 2 behavior block required a
`ResourceTopicListScreen` widget-level assertion ("given a topics list whose
first entry lacks `dataAssetPath` renders the entry that HAS content as its
first tile") but Task 2's file list only named
`test/models/content_availability_test.dart` as the test file to create; that
widget test was added inside `content_availability_test.dart` alongside the
model-level tests to fulfill the stated behavior without introducing an
unlisted file — consistent with the plan's intent, not a scope change.

## Issues Encountered

The executor's git worktree branch (`worktree-agent-a8aaf8982b03df20e`) was
based on an older point of `main` than the one where this quick task's own
`.planning/quick/260918-dqx-.../260918-dqx-PLAN.md` was authored (it was
untracked/uncommitted on the main checkout, so it wasn't visible from the
worktree at all). The plan file and directory were copied into the worktree
before execution began; all source-file reads and edits proceeded normally
against the worktree's actual `enchiridion/` tree once that was in place. No
functional impact — the worktree's `enchiridion/lib/` and `enchiridion/test/`
trees matched what the plan described (verified by reading each file before
editing).

## Next Phase Readiness
- Siblings 260918-dqy, 260918-dqz, 260918-dr0, and 260918-dr3 can now import
  `availableFirst`, `kComingSoonLabel`, `ResourceTopic.hasContent`, and
  `booksInDisplayOrder` directly instead of writing their own ordering or
  status-label logic.
- The guard test at `enchiridion/test/guards/available_before_coming_soon_guard_test.dart`
  will fail the suite the moment any future catalog change reintroduces
  interleaved (placeholder-before-content) ordering — add a one-line entry to
  its `_catalogs()` table when a new display-order catalog ships.
- No blockers.

---
*Quick task: 260918-dqx*
*Completed: 2026-09-18*

## Self-Check: PASSED

All 9 created/modified files confirmed present on disk. All 3 task commits
(`591f891`, `45508b7`, `9cc0cc2`) confirmed present in `git log`.
