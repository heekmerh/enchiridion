---
phase: quick-260918-dr3
plan: 01
quick_id: 260918-dr3
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, dart, resource-topics, medical-instrumentation, grouping, section-header]
status: complete

dependency-graph:
  requires:
    - 260918-dr0 (85-entry kSurgicalInstrumentationTopics catalog, card/dense presentation modes)
    - 260918-dr1 (Suture Material rename — consumed transitively, not directly touched)
  provides:
    - "ResourceTopic.group (optional) + groupTopicsForDisplay() — the grouping primitive mirroring calculator_definition.dart's groupedCalculatorsInDisplayOrder"
    - "widgets/common/section_header.dart — the Calculators header style factored into a reusable widget"
    - "ResourceTopicListScreen renders grouped section headers for any topics list carrying groups, with zero headers for group-less lists"
    - "48-entry kMedicalInstrumentationTopics catalog, transcribed from scripts/content/medical_instrumentation.md across its 9 authored groups"
  affects:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart

tech-stack:
  added: []
  patterns:
    - "groupTopicsForDisplay mirrors groupedCalculatorsInDisplayOrder exactly: putIfAbsent buckets in first-appearance order, then availableFirst at both the group-key level and the within-group level"
    - "Flattened header-and-row list driving a single ListView.builder, so headers and rows share one lazy-build pass instead of a nested ListView-inside-ListView"
    - "SectionHeader widget factored out of calculator_list_screen.dart's private _sectionHeader rather than editing that file, avoiding a merge collision with sibling 260918-dqz in the same batch"

key-files:
  created:
    - enchiridion/lib/widgets/common/section_header.dart
    - enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
    - enchiridion/test/models/resource_topic_group_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart

decisions:
  - "Refactored ResourceTopicListScreen's card presentation from ListView.separated to ListView.builder over a flattened sealed _ListEntry list (_HeaderEntry | _TopicEntry), since headers need their own vertical padding rather than the uniform inter-row separator ListView.separated provides."
  - "Card-mode topic rows moved their horizontal 16px inset from the outer ListView padding into a per-item Padding, so SectionHeader's own built-in horizontal padding lines up with topic rows instead of doubling up (mirrors how Calculators' zero-horizontal-padding ListView plus per-row padding already works)."
  - "dr4 had not yet landed in this worktree when Task 2 ran (kMedicalInstrumentationTopics held only the pre-existing iv-cannula entry), so Task 2 added all 47 remaining bullets directly rather than annotating pre-existing entries."
  - "The ENT 'Laryngoscope' bullet is disambiguated as medical-laryngoscope since Surgical Instrumentation already owns the bare laryngoscope id — flagged explicitly in interface_notes and confirmed via the cross-catalog id-uniqueness test."

actuals:
  tokens: 9740
  tasks: 3
  commits: 3
  plan_head_before: b609593ec8cc6ddf6e43be61fe246865c6cb9120

metrics:
  duration: "~40 minutes"
  completed: 2026-09-19
---

# Phase quick-260918-dr3 Plan 01: Group Medical Instrumentation under category headers Summary

Added an optional `ResourceTopic.group` field and a `groupTopicsForDisplay` helper mirroring the Calculators screen's grouping, then transcribed all 48 bullets of `scripts/content/medical_instrumentation.md` into `kMedicalInstrumentationTopics` across its 9 authored groups — so Medical Instrumentation now reads as a browsable, section-headed catalog while Surgical Instrumentation renders exactly as before.

## What Was Built

- **`ResourceTopic.group`** (optional, defaults to null) and **`groupTopicsForDisplay(topics)`** in `resource_topic.dart`: buckets topics by `group` in first-appearance order (`putIfAbsent`, same primitive as `groupByCategory`), then applies `availableFirst` at both the group-key level and the within-group level — a group holding real content outranks a group holding none, and content-bearing topics lead within each group. A group-less list (every topic's `group` is null) collapses to one bucket keyed `null`, whose flattened order is identical to plain `availableFirst` — proven directly by a unit test.
- **`widgets/common/section_header.dart`**: a small `SectionHeader({required String title})` widget reproducing the Calculators header style verbatim (uppercase, 1.2 letter-spacing, primary-coloured, bold `labelSmall`, `EdgeInsets.fromLTRB(16, 12, 16, 4)`). `calculator_list_screen.dart` itself was left untouched, per the batch's scope boundary (sibling 260918-dqz owns that file this batch).
- **`ResourceTopicListScreen`** refactored to flatten `groupTopicsForDisplay(topics)` into a single list of header/topic entries (a private `sealed class _ListEntry`), driving both the card and dense presentations off one `ListView.builder` so a 48-row catalog builds its hero images lazily. The card presentation moved its horizontal inset from the outer `ListView` padding to a per-row `Padding` so header and topic-row indentation line up; the dense presentation was a straightforward `orderedTopics` → `items` swap.
- **`kMedicalInstrumentationTopics`** grown from 1 entry to 48, one per bullet in `scripts/content/medical_instrumentation.md`, each carrying its authored group (`Cardiovascular Instrumentation` (8), `Respiratory Instrumentation` (8), `Neurological Instrumentation` (4), `Diagnostic and Monitoring Equipment` (8), `Imaging Equipment` (5), `Ophthalmic Instruments` (4), `ENT Instruments` (4), `Biomedical Sensors and Transducers` (5), `Therapeutic Equipment` (2)). The pre-existing `iv-cannula` entry (the catalog's only real content) was annotated in place under Diagnostic and Monitoring Equipment rather than duplicated. The ENT `Laryngoscope` bullet was slugged `medical-laryngoscope` to avoid colliding with Surgical Instrumentation's `laryngoscope` id.
- **Tests**: `resource_topic_list_screen_grouping_test.dart` (10 cases) covers group ordering, within-group ordering, the null-group degenerate case, header rendering on local fixtures, navigation/coming-soon behavior, and two real-catalog cases (Medical Instrumentation opens on Diagnostic and Monitoring Equipment with IV Cannula first; Surgical Instrumentation renders zero headers, before and after scrolling to its last row). `resource_topic_group_test.dart` (6 cases) pins the 48-entry count, the 9-group set and per-group counts, `categoryTitle`, cross-catalog id uniqueness (computed over all three catalog constants, not a hardcoded id list), `iv-cannula` preservation, and the display helper's leading group/topic.

## Deviations from Plan

### Auto-fixed Issues

None — no bugs, missing functionality, or blocking issues were encountered. Both the card-list `ListView.separated` → `ListView.builder` refactor and the horizontal-padding relocation were explicitly instructed by the plan's Task 1 `<action>` text ("Flatten headers and rows into one list and drive it with `ListView.builder`... give headers their own vertical padding rather than an inter-row separator"), not unplanned fixes.

### Worktree infrastructure catch-up (not a plan deviation, execution-environment note)

This worktree was branched before siblings 260918-dr0 and 260918-dr1 (both declared in this plan's `depends_on`) had landed on `main` — `git merge-base HEAD main` equaled the worktree's own HEAD with zero unique commits, meaning the branch was a strict ancestor of `main`. Before starting Task 1, the worktree branch was fast-forwarded to `main`'s tip (`b609593`) via `git merge --ff-only main` — a pure fast-forward, no local divergent commits, no conflicts — per this plan's own constraints. This brought in the already-landed 85-entry Surgical Instrumentation catalog and the Suture Material rename, so Task 1 and Task 2 operated on the real landed `resource_topic.dart` rather than a stale single-entry snapshot.

Sibling 260918-dr4 (which owns leading Medical Instrumentation with IV Cannula, and which this plan's Task 2 says "may already have populated the catalog") had **not** landed by the time this plan ran: `kMedicalInstrumentationTopics` on disk still held only the original `iv-cannula` entry. Task 2 therefore added all 47 remaining bullets directly, per the plan's explicit fallback instruction for this case ("if dr4 landed as ordering-only and the catalog is still short of the source file, Task 2 adds the missing topics so the stated end state holds either way").

## Verification

1. `cd enchiridion && flutter analyze lib/models/resource_topic.dart lib/screens/resource_topic_list_screen.dart lib/widgets/common/section_header.dart` — clean, no issues.
2. `cd enchiridion && flutter test` — full suite green, 233 tests, including `test/guards/available_before_coming_soon_guard_test.dart` (unedited) and `test/screens/resource_topic_list_screen_test.dart` (unedited).
3. `git status --short` after all three tasks shows only the five `files_modified` paths touched across the plan's commits; `enchiridion/lib/screens/library_screen.dart`, `enchiridion/lib/screens/calculator_list_screen.dart`, and `test/guards/available_before_coming_soon_guard_test.dart` are absent from every diff.
4. Read-back of `kMedicalInstrumentationTopics` against `scripts/content/medical_instrumentation.md`: 9 groups in file order, 48 topics, the "IV cannulation" bullet represented by the preserved `iv-cannula` entry — pinned by `resource_topic_group_test.dart`.

## Self-Check: PASSED

- FOUND: enchiridion/lib/models/resource_topic.dart
- FOUND: enchiridion/lib/screens/resource_topic_list_screen.dart
- FOUND: enchiridion/lib/widgets/common/section_header.dart
- FOUND: enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
- FOUND: enchiridion/test/models/resource_topic_group_test.dart
- FOUND commit 1f9a5cf (Task 1: grouped topic list end to end)
- FOUND commit 576084f (Task 2: 48-entry Medical Instrumentation catalog)
- FOUND commit 2159e44 (Task 3: real-catalog regression tests)

---
*Phase: quick-260918-dr3*
*Completed: 2026-09-19*
