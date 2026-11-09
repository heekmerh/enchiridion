---
phase: quick-260918-dqx
quick_id: 260918-dqx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - enchiridion/lib/utils/content_availability.dart
  - enchiridion/lib/models/resource_topic.dart
  - enchiridion/lib/models/book_catalog.dart
  - enchiridion/lib/screens/osce_screen.dart
  - enchiridion/lib/screens/resource_topic_list_screen.dart
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/test/screens/osce_screen_test.dart
  - enchiridion/test/models/content_availability_test.dart
  - enchiridion/test/guards/available_before_coming_soon_guard_test.dart
autonomous: true
requirements: [RANK-260918-DQX]

estimate:
  tokens: 34000
  raw_tokens: 34000
  tasks: 3
  confidence: low

must_haves:
  truths:
    - Opening OSCE shows every station that has real written content above every station that has none.
    - The OSCE tab strip carries the same available-first order as the OSCE list, and tapping a station still lands on that same station.
    - Opening Surgical Instrumentation or Medical Instrumentation lists topics with real content above topics whose content has not been written.
    - The Library book shelf shows readable books ahead of books whose content has not landed, with recency ordering applied only among readable books.
    - A single shared ordering helper exists in lib/, so a list added later gets the rule by calling one function instead of re-implementing a sort.
  artifacts:
    - enchiridion/lib/utils/content_availability.dart (shared availableFirst helper + status label constant)
    - enchiridion/lib/models/resource_topic.dart (ResourceTopic.hasContent + shared OSCE display-order list)
    - enchiridion/lib/models/book_catalog.dart (pure booksInDisplayOrder helper)
    - enchiridion/test/guards/available_before_coming_soon_guard_test.dart (repo-wide ordering invariant)
  key_links:
    - The OSCE list and the OSCE TabController must read the SAME ordered list, or the initialIndex handed to the detail screen selects the wrong station.
    - ResourceTopicListScreen orders the topics it is given rather than its callers ordering them, so sibling-built instrumentation lists inherit the rule for free.
    - availableFirst is a stable partition (not a comparator sort), so each group keeps its authored order and existing curation is not scrambled.
---

<objective>
Make "content that exists ranks above content that does not" a real, single-source app rule
rather than an accident of authoring order. Today the OSCE station list visibly breaks it:
Abdominal Examination is the only station with written content and it sits third, below two
placeholder stations.

Purpose: one shared ordering helper that every mixed list in the app calls, so the rule holds
now and holds automatically for the Calculators / Surgical Instrumentation / Medical
Instrumentation lists that sibling items are about to build.
Output: a shared `availableFirst` helper, an explicit availability predicate on the topic model,
three list surfaces wired to it, and a guard test that fails if any catalog regresses.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

The Flutter app lives under `enchiridion/` — every path below is repo-relative and every
command runs from `enchiridion/`.

Existing availability signals already in the codebase (do not invent a second one):
- `CatalogBook.hasContent` in `enchiridion/lib/models/book_catalog.dart` — `dataFile.isNotEmpty`.
- `ResourceTopic.dataAssetPath == null` means "outline only, prose not written" — used by
  `_OsceTabBody` in `enchiridion/lib/screens/osce_screen.dart` to render `_OutlinePlaceholder`.

@enchiridion/lib/models/resource_topic.dart
@enchiridion/lib/models/book_catalog.dart
@enchiridion/lib/screens/osce_screen.dart
@enchiridion/lib/screens/resource_topic_list_screen.dart
@enchiridion/test/screens/osce_screen_test.dart
@enchiridion/test/guards/bank_disclosure_guard_test.dart
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Shared availability ordering helper, proven end-to-end on OSCE</name>
  <files>enchiridion/lib/utils/content_availability.dart, enchiridion/lib/models/resource_topic.dart, enchiridion/lib/screens/osce_screen.dart, enchiridion/test/screens/osce_screen_test.dart</files>
  <read_first>enchiridion/lib/screens/osce_screen.dart, enchiridion/lib/models/resource_topic.dart, enchiridion/test/screens/osce_screen_test.dart</read_first>
  <behavior>
    - `availableFirst([a(false), b(true), c(false), d(true)], predicate)` returns `[b, d, a, c]` — both groups keep their input order.
    - `availableFirst` on an already-ordered list returns an equal list (idempotent).
    - `availableFirst` on an empty list returns an empty list; on an all-available or all-unavailable list it returns the input order unchanged.
    - Pumping `OsceScreen`: the first `ListTile` title is `Abdominal Examination`; `Cardiovascular System` and `Respiratory System` are still present, below it.
    - Tapping `Respiratory System` in the list opens the detail screen with `TabBar.controller!.index` pointing at the tab whose text is `Respiratory System` (the index shifts because Abdominal Examination moved to 0 — assert by resolving the index from the ordered list, not by hardcoding a literal, so a later content addition does not break the test).
    - The first tab in the detail `TabBar` is `Abdominal Examination`.
  </behavior>
  <action>
    Create `enchiridion/lib/utils/content_availability.dart` with no Flutter import (pure Dart, so
    model and test layers can use it):
    (a) `List&lt;T&gt; availableFirst&lt;T&gt;(Iterable&lt;T&gt; items, bool Function(T) isAvailable)` implemented as a
    STABLE two-bucket partition — walk once, push each item into an available bucket or a pending
    bucket, return available followed by pending. Do not use `List.sort` with a comparator; Dart's
    sort is not guaranteed stable and would scramble authored curation order inside each group.
    (b) `const String kComingSoonLabel = 'Coming Soon';` — the single spelling siblings 260918-dqy
    (grey-out styling) and 260918-dqz (calculator status chips) will reuse. Do not rewrite existing
    user-facing copy in this plan; only publish the constant.
    Document in the file's doc comment that this is the app-wide rule: content a user can actually
    open ranks above content that is still a placeholder.

    In `enchiridion/lib/models/resource_topic.dart`: add `bool get hasContent =&gt; dataAssetPath != null;`
    to `ResourceTopic` (mirrors `CatalogBook.hasContent`, so both models answer the same question the
    same way), and add a top-level `final List&lt;ResourceTopic&gt; kOsceTopicsInDisplayOrder` computed
    once as `availableFirst(kOsceTopics, (t) =&gt; t.hasContent)`. Leave `kOsceTopics` itself in its
    authored order — it stays the authoring source of truth; the derived list is what UI renders.

    In `enchiridion/lib/screens/osce_screen.dart`: replace every `kOsceTopics` read in BOTH
    `OsceScreen` (list builder) and `_OsceDetailScreen` (TabController length, preload loop, tabs,
    TabBarView children) with `kOsceTopicsInDisplayOrder`. Both surfaces MUST read the same list —
    the list passes `initialIndex: index` to the detail screen, so a mismatch between list order and
    tab order would open the wrong station.

    Update `enchiridion/test/screens/osce_screen_test.dart` for the new order and add the assertions
    in the behavior block above.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/screens/osce_screen_test.dart</automated>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/utils/content_availability.dart lib/models/resource_topic.dart lib/screens/osce_screen.dart</automated>
  </verify>
  <done>OSCE list and OSCE tab strip both lead with Abdominal Examination, tapping a station still opens that same station, and `availableFirst` exists as a stable, Flutter-free helper. Analyzer reports zero issues on the three changed source files.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Apply the rule to the instrumentation lists and the Library shelf</name>
  <files>enchiridion/lib/screens/resource_topic_list_screen.dart, enchiridion/lib/models/book_catalog.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/test/models/content_availability_test.dart</files>
  <read_first>enchiridion/lib/screens/resource_topic_list_screen.dart, enchiridion/lib/screens/library_screen.dart (lines 86-125)</read_first>
  <behavior>
    - `booksInDisplayOrder({})` with no read history returns readable books (non-empty `dataFile`) ahead of every placeholder book.
    - `booksInDisplayOrder` with history on a readable book ranks the most-recently-opened readable book first, and still ranks every readable book above every placeholder book.
    - Placeholder books keep their authored relative order among themselves.
    - `ResourceTopicListScreen` given a topics list whose first entry lacks `dataAssetPath` renders the entry that HAS content as its first tile.
  </behavior>
  <action>
    In `enchiridion/lib/models/book_catalog.dart`: add a pure top-level
    `List&lt;CatalogBook&gt; booksInDisplayOrder(Map&lt;String, DateTime&gt; history)` that (1) sorts a copy of
    `kBooks` by recency exactly as `library_screen`'s `_sortedBooks` does today (most recent first,
    books with history ahead of books without), then (2) runs the result through `availableFirst`
    with `(b) =&gt; b.hasContent`. Availability is the OUTER key; recency only orders within a group.
    Keep it pure (no Flutter, no provider) so the guard test can call it directly.

    In `enchiridion/lib/screens/library_screen.dart`: make `_sortedBooks` delegate to
    `booksInDisplayOrder(_history)` and delete the inline comparator. Change nothing else on that
    screen — the existing dim overlay and the tap-to-read affordance stay exactly as they are
    (grey-out styling belongs to sibling 260918-dqy).

    In `enchiridion/lib/screens/resource_topic_list_screen.dart`: order the incoming `topics`
    through `availableFirst(topics, (t) =&gt; t.hasContent)` at the top of `build`, and drive
    `itemCount`/`itemBuilder` from that ordered list. Ordering happens HERE, inside the shared list
    screen, not at each call site — that is what makes siblings 260918-dr0 (Surgical Instrumentation)
    and 260918-dr3 (Medical Instrumentation) inherit the rule without doing anything.

    Create `enchiridion/test/models/content_availability_test.dart` covering the `availableFirst`
    cases from Task 1's behavior block plus the `booksInDisplayOrder` cases above.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/models/content_availability_test.dart test/screens/library_screen_test.dart</automated>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/models/book_catalog.dart lib/screens/library_screen.dart lib/screens/resource_topic_list_screen.dart</automated>
  </verify>
  <done>Book shelf order is produced by one pure, unit-tested function that ranks readable books above placeholders; the shared topic list screen orders its own input; analyzer clean on the three changed source files.</done>
</task>

<task type="auto">
  <name>Task 3: Repo-wide guard test for the ordering invariant</name>
  <files>enchiridion/test/guards/available_before_coming_soon_guard_test.dart</files>
  <read_first>enchiridion/test/guards/bank_disclosure_guard_test.dart</read_first>
  <action>
    Create `enchiridion/test/guards/available_before_coming_soon_guard_test.dart` following the
    existing guard-test convention in `test/guards/`: one invariant, named clearly, with a failure
    `reason` that names the offending list and the offending entry.

    Assert the invariant on every display-order catalog the app ships today:
    `kOsceTopicsInDisplayOrder`; `availableFirst(kSurgicalInstrumentationTopics, ...)`;
    `availableFirst(kMedicalInstrumentationTopics, ...)`; `booksInDisplayOrder(const {})` and
    `booksInDisplayOrder` with a synthetic history entry on a readable book. For each, assert that
    the index of the last entry with content is less than the index of the first entry without
    content (vacuously true when a list is all-available or all-placeholder).

    Drive the assertions from a table of `(listName, orderedEntries, hasContentPredicate)` records
    so that adding a future catalog is a one-line addition. Note in the file's header comment that a
    list which is entirely available or entirely placeholder passes trivially, and that the guard
    checks runtime order, not source text.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/guards/available_before_coming_soon_guard_test.dart</automated>
    <automated>cd enchiridion &amp;&amp; flutter test</automated>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/utils/content_availability.dart lib/models/resource_topic.dart lib/models/book_catalog.dart lib/screens/osce_screen.dart lib/screens/library_screen.dart lib/screens/resource_topic_list_screen.dart</automated>
  </verify>
  <done>The guard passes on every current catalog, and the full `flutter test` suite is green with no new failures. Analyzer reports zero issues across all six changed source files (the repo's analyzer baseline for `lib/` as a whole is non-empty, so analysis is scoped to changed files).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none new) | This plan reorders locally-bundled, compile-time-constant catalogs. No new input crosses a trust boundary; no network, storage-schema, or auth surface is touched. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-dqx-01 | Tampering | `_OsceDetailScreen` initialIndex | low | mitigate | List and TabController read one shared ordered list; widget test asserts the tapped station is the selected tab, so an index desync cannot ship silently. |
| T-dqx-SC | Tampering | package installs | low | accept | No npm/pip/cargo/pub package is added by this plan — no install step exists to audit. |
</threat_model>

<verification>
1. `cd enchiridion && flutter test` — full suite green, no new failures.
2. `cd enchiridion && flutter test test/guards/available_before_coming_soon_guard_test.dart` — invariant holds on all current catalogs.
3. `cd enchiridion && flutter analyze` scoped to the six changed source files — zero issues.
4. Manual read-through: OSCE list leads with Abdominal Examination; tapping Respiratory System still opens Respiratory System.
</verification>

<success_criteria>
- Every list in the app that mixes real content with placeholder content renders the real content first, via one shared helper rather than per-screen sorts.
- `availableFirst` is stable: authored order survives inside each group.
- The OSCE list/tab index link is proven by a widget test, not by inspection.
- A guard test fails the suite if any catalog regresses to interleaved order.
- No user-facing copy, styling, or grey-out treatment is changed here — that is sibling 260918-dqy's scope, and this plan deliberately leaves it untouched to avoid a merge conflict.
</success_criteria>

<output>
Create `.planning/quick/260918-dqx-also-note-that-across-the-entire-app-available-content-ranks/260918-dqx-SUMMARY.md` when done.

The SUMMARY MUST include a short "Shared utility for siblings" section naming
`enchiridion/lib/utils/content_availability.dart`, the exact signature of `availableFirst`, the
`kComingSoonLabel` constant, `ResourceTopic.hasContent`, and `booksInDisplayOrder` — siblings
260918-dqy, 260918-dqz, 260918-dr0 and 260918-dr3 are expected to consume these rather than write
their own ordering or status handling.
</output>
