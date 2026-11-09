---
phase: quick-260918-dr4
plan: 01
quick_id: 260918-dr4
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, dart, resource-topics, medical-instrumentation, ordering, availability]
status: complete

dependency-graph:
  requires:
    - 260918-dr3 (ResourceTopic.group, groupTopicsForDisplay, 48-entry kMedicalInstrumentationTopics catalog)
    - 260918-dr0 (85-entry kSurgicalInstrumentationTopics catalog, shared list screen row styling)
  provides:
    - "availableFirstByGroup<T>(items, {groupOf, isAvailable}) — a generic, pure-Dart, group-contiguous ordering helper in utils/content_availability.dart"
    - "kMedicalInstrumentationTopicsInDisplayOrder — a top-level derived list mirroring the kOsceTopicsInDisplayOrder precedent"
    - "library_screen.dart's Medical Instrumentation call site reading the derived list explicitly, rather than relying only on screen-level reordering"
  affects:
    - enchiridion/lib/utils/content_availability.dart
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/screens/library_screen.dart

tech-stack:
  added: []
  patterns:
    - "availableFirstByGroup composes entirely from availableFirst (bucket by group with putIfAbsent, partition each block, partition the blocks by 'has any available member', flatten) so its stability guarantee is inherited rather than re-derived — same idiom groupByCategory/groupedCalculatorsInDisplayOrder use in calculator_definition.dart, now generalized to a flat-list-returning, Flutter-free utility."
    - "kMedicalInstrumentationTopicsInDisplayOrder mirrors kOsceTopicsInDisplayOrder's declaration shape: authored const list stays the source of truth, a top-level final derived list is what UI reads."

key-files:
  created:
    - enchiridion/test/models/medical_instrumentation_display_order_test.dart
  modified:
    - enchiridion/lib/utils/content_availability.dart
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/test/guards/available_before_coming_soon_guard_test.dart

decisions:
  - "Worktree branch was a strict ancestor of main (zero unique commits) when this plan started, so it was fast-forwarded to main's tip (60a8622) via `git merge --ff-only main` before any edits, per this plan's constraints. This brought in dr3's full 48-entry catalog, dr0's Surgical Instrumentation work, and dr5/dr6, so all tasks ran against the real landed state."
  - "Confirmed before writing any code that sibling dr3 had already populated the full 48-entry kMedicalInstrumentationTopics catalog with the group field (dr3's own fallback, since dr4 had not landed when dr3 ran) — this plan's precondition (catalog >1 entry AND group field present) was satisfied, so no catalog population happened here."
  - "dr3 also refactored resource_topic_list_screen.dart to call groupTopicsForDisplay(topics) directly inside build(), which already re-groups and availableFirst-orders any input at render time — a stronger operation than the flat availableFirst pass this plan's interface_notes described (that flat pass no longer exists; it was replaced by dr3). Because groupTopicsForDisplay's own passes are idempotent on an input that is already group-ordered, feeding it kMedicalInstrumentationTopicsInDisplayOrder produces the exact same rendered order without fighting or duplicating that logic. This plan therefore adds the model-layer, unit-testable derived list and helper on top of dr3's screen-level grouping rather than replacing it — resource_topic_list_screen.dart was not edited, per the plan's explicit constraint."
  - "Widget test needed a larger-than-default test surface (800x3000 via tester.view.physicalSize, reset via addTearDown) to get a second card built for the position comparison — the default 800x600 test surface only lays out one full hero-image card in Medical Instrumentation's card presentation, so nothing else would have been in the tree to compare against."

actuals:
  tokens: 4110
  tasks: 3
  commits: 2
  plan_head_before: 60a8622fbf2e5c8e899f3d6fadac00b9f621de55

metrics:
  duration: "~25 minutes"
  completed: 2026-09-19
---

# Phase quick-260918-dr4 Plan 01: IV Cannula leads Medical Instrumentation Summary

Added `availableFirstByGroup`, a group-contiguous ordering helper in `content_availability.dart`, and a derived `kMedicalInstrumentationTopicsInDisplayOrder` list that the Library screen's Medical Instrumentation call site now reads — so opening Medical Instrumentation renders IV Cannula, its only topic with real written content, as the first tile on screen, produced by availability rather than a hand-placed index.

## What Was Built

- **`availableFirstByGroup<T>(items, {required groupOf, required isAvailable})`** in `enchiridion/lib/utils/content_availability.dart`, beside (not modifying) `availableFirst`. Buckets items into blocks keyed by `groupOf` using `putIfAbsent` (block order = first appearance), partitions each block with `availableFirst` so an openable item leads its own block, then partitions the block list itself with `availableFirst` on "does this block hold any available item," and flattens. Every step delegates to `availableFirst`, so the stability guarantee (original relative order preserved inside each partition) is inherited rather than re-derived. Pure Dart, no Flutter import, matching the file's existing `library;` convention.
- **`kMedicalInstrumentationTopicsInDisplayOrder`** in `enchiridion/lib/models/resource_topic.dart`, declared immediately after the authored `const kMedicalInstrumentationTopics` block, mirroring the `kOsceTopicsInDisplayOrder` precedent exactly: the authored list stays the untouched source of truth, this derived `final` list is what UI reads. Computed via `availableFirstByGroup` keyed on `t.group` and `t.hasContent`.
- **`library_screen.dart`**: the Medical Instrumentation `_ResourceCategory`'s `ResourceTopicListScreen` invocation now passes `kMedicalInstrumentationTopicsInDisplayOrder` instead of the raw authored list, and lost its `const` keyword (a `final` top-level list is not a const expression). The Surgical Instrumentation invocation four lines above is untouched, `const` and all.
- **`test/models/medical_instrumentation_display_order_test.dart`** (new, 11 tests): four tests on `availableFirstByGroup` using small local `ResourceTopic` fixtures (group-contiguity with a partially-available catalog, degenerate null-group case matching plain `availableFirst`, within-block ordering, idempotency on already-ordered input); seven tests on `kMedicalInstrumentationTopicsInDisplayOrder` against the real catalog (leads with `iv-cannula`; is a strict permutation of the authored list — same length, same id multiset, no duplicates; every group occupies one contiguous run; the group-key set and non-lead groups' relative order match the authored list; the first block is `iv-cannula`'s group with `iv-cannula` first in it; `iv-cannula`'s `dataAssetPath`/`description` survive unchanged and it remains the catalog's only `hasContent` entry; a widget test confirming the IV Cannula tile lays out strictly above the next topic tile).
- **`test/guards/available_before_coming_soon_guard_test.dart`**: replaced the ad-hoc `availableFirst(kMedicalInstrumentationTopics, ...)` recomputation in the third `_Catalog` entry with `kMedicalInstrumentationTopicsInDisplayOrder` — the guard now checks the order that actually reaches the screen. Left a note above the entry recording that this catalog is group-ordered and pointing at the group-aware assertions in the new test file if a second category ever gains content. The other four `_Catalog` entries, `_checkCatalogs`, and the guard's invariant logic are untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking issue] Widget test needed an enlarged viewport to have a second tile to compare against**
- **Found during:** Task 1
- **Issue:** The plan's widget assertion (`tester.getTopLeft(find.text('IV Cannula')).dy` compared against the next topic title) failed with `findsOneWidget` returning 0 matches at the default 800x600 test surface size — Medical Instrumentation renders in card mode (hero image + title + description), and only one full card fits in that viewport before the second is not laid out by `ListView.builder`.
- **Fix:** Set `tester.view.physicalSize = const Size(800, 3000)` and `devicePixelRatio = 1.0` before pumping, resetting both via `addTearDown`. This only changes how much of the list builds, not the order under test.
- **Files modified:** enchiridion/test/models/medical_instrumentation_display_order_test.dart
- **Commit:** c8bc0a0

### Non-bug deviations

**Plan's `interface_notes` were stale on one point, harmlessly.** The plan stated `ResourceTopicListScreen` "currently opens with `final orderedTopics = availableFirst(topics, (t) => t.hasContent);` — a flat pass." That pass no longer exists: sibling 260918-dr3 replaced it with `groupTopicsForDisplay(topics)`, called directly in `build()`, which already re-groups and `availableFirst`-orders any input list at render time (both at the group level and within each group). This is a stronger operation than a flat pass, but it is idempotent on an input that is already group-ordered — so feeding it `kMedicalInstrumentationTopicsInDisplayOrder` produces an identical rendered result to feeding it the raw authored list, with no conflict. `resource_topic_list_screen.dart` was not edited, per the plan's explicit constraint; this plan's contribution is the model-layer, unit-testable derived list and the generic helper that produces it, wired explicitly at the Library call site rather than relying implicitly on the screen's own internal reordering.

**Task ordering across commits.** Task 2's five hardening assertions (permutation, contiguity, group-order preservation, lead-block/content-preservation checks) were written into `test/models/medical_instrumentation_display_order_test.dart` in the same editing pass as Task 1's six behaviors, before Task 1's commit was made — so they ended up bundled into the Task 1 commit (`c8bc0a0`) rather than a separate Task 2 commit. Task 2's other required change — replacing the guard test's third `_Catalog` entry — was committed separately (`4da8a08`) as intended. No functional or test-coverage gap resulted; this is a commit-boundary bookkeeping deviation only, noted here for traceability.

## Verification

1. `cd enchiridion && flutter test test/models/medical_instrumentation_display_order_test.dart test/guards/available_before_coming_soon_guard_test.dart` — 12 tests, all pass.
2. `cd enchiridion && flutter analyze lib/utils/content_availability.dart lib/models/resource_topic.dart lib/screens/library_screen.dart` — no issues found.
3. `cd enchiridion && flutter test` — full suite green, 249 tests, including `test/models/content_availability_test.dart` (dqx's helper suite) with zero edits to it.
4. `git diff --name-only 60a8622..HEAD` lists exactly the five `files_modified` paths — `resource_topic_list_screen.dart` and `osce_screen.dart` are absent.
5. Read-back: `kMedicalInstrumentationTopics` (the authored `const` list) is byte-identical to what dr3 left; only the new derived list orders it.

## Self-Check: PASSED

- FOUND: enchiridion/lib/utils/content_availability.dart
- FOUND: enchiridion/lib/models/resource_topic.dart
- FOUND: enchiridion/lib/screens/library_screen.dart
- FOUND: enchiridion/test/models/medical_instrumentation_display_order_test.dart
- FOUND: enchiridion/test/guards/available_before_coming_soon_guard_test.dart
- FOUND commit c8bc0a0 (Task 1: availableFirstByGroup, derived list, call-site wiring, new test file)
- FOUND commit 4da8a08 (Task 2: guard test registers the shipped display-order catalog)

---
*Phase: quick-260918-dr4*
*Completed: 2026-09-19*
