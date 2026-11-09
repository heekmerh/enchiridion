---
phase: quick-260919-kiy
plan: 01
quick_id: 260919-kiy
batch_id: 260919-kir
type: execute
wave: 1
depends_on: []
autonomous: true
subsystem: ui
tags: [flutter, dart, resource-topics, medical-instrumentation, list, dense]
files_modified:
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/lib/screens/resource_topic_list_screen.dart
  - enchiridion/test/screens/library_screen_test.dart
  - enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
  - enchiridion/test/models/medical_instrumentation_display_order_test.dart

must_haves:
  truths:
    - "Opening Resources -> Medical Instrumentation renders topics as OSCE/Surgical-style single-line rows, not hero-image cards."
    - "IV Cannula still leads the list and coming-soon topics still render dimmed with their badge."
    - "Surgical Instrumentation's presentation is byte-for-byte unchanged."
  artifacts:
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/test/screens/library_screen_test.dart
  key_links:
    - "library_screen.dart Medical Instrumentation _ResourceCategory.onTap -> ResourceTopicListScreen(dense: true)"
    - "ResourceTopicListScreen.dense -> _buildDenseList (ListTile rows) instead of _buildCardList (hero cards)"
---

<objective>
Make the Medical Instrumentation module listing render as a list, matching the
Surgical Instrumentation list UI exactly.

Purpose: Medical Instrumentation is currently the only instrumentation category
still rendering as full-bleed hero-image cards (one topic per screenful across a
48-entry catalog). Surgical Instrumentation already ships the dense,
OSCE-style row presentation. This item closes that inconsistency.

Output: The Medical Instrumentation call site opts into the ALREADY-EXISTING
`dense` presentation of the shared `ResourceTopicListScreen`, plus tests that
pin the shipped presentation end-to-end and realign two existing widget tests
that currently assert the outgoing card presentation.
</objective>

<execution_context>
@~/.claude/gsd-core/workflows/execute-plan.md
@~/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md

@enchiridion/lib/screens/library_screen.dart
@enchiridion/lib/screens/resource_topic_list_screen.dart
@enchiridion/test/screens/library_screen_test.dart
@enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
@enchiridion/test/models/medical_instrumentation_display_order_test.dart
</context>

<interface_notes>
**The list widget already exists — do not build a new one.** Prior quick item
260918-dr0 added an optional `bool dense` flag to the shared
`ResourceTopicListScreen` (`enchiridion/lib/screens/resource_topic_list_screen.dart`).
It selects between two private builders over the same flattened
`_ListEntry` list:

- `dense == false` (current default): `_buildCardList` -> `_cardTile`, an
  `InkWell`/`Ink` card with a 16:9 `Image.asset(topic.heroAssetPath)` hero
  wrapped in `ComingSoonDim`, title, description, and a full-size
  `ComingSoonBadge`.
- `dense == true`: `_buildDenseList`, a `ListTile` per topic with a
  `CircleAvatar` leading icon, dimmed title when coming soon, single-line
  description subtitle, and a trailing `Icon(Icons.chevron_right)` (available)
  or `ComingSoonBadge(compact: true)` (coming soon).

Both builders share one `_handleTap` closure (SnackBar for coming-soon,
`ResourceTopicDetailScreen` push otherwise), and `build()` calls
`groupTopicsForDisplay(topics)` BEFORE either builder — so grouping,
section headers, and available-first ordering are identical in both modes.

**This means the entire behavioral delta is the flag at the call site.**
In `enchiridion/lib/screens/library_screen.dart`, inside
`_ResourcesTabState.initState()`, the `_categories` list holds two adjacent
entries:

- `'Surgical Instrumentation'` (around line 585) already passes
  `topics: kSurgicalInstrumentationTopics` plus the dense flag set true.
- `'Medical Instrumentation'` (around line 596) passes
  `topics: kMedicalInstrumentationTopicsInDisplayOrder` and NO dense flag,
  so it falls through to the card default.

`kMedicalInstrumentationTopicsInDisplayOrder` (from 260918-dr4) is the derived,
`availableFirstByGroup`-ordered list that puts IV Cannula first. It is NOT in
scope here — ordering and availability logic are untouched by this plan.

**Two existing tests pump the real Medical Instrumentation catalog in card
mode and will silently become stale (still green, but asserting a presentation
the user no longer sees):**

1. `enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart`,
   the test named `the real kMedicalInstrumentationTopics catalog opens on the
   Diagnostic and Monitoring Equipment header with IV Cannula first` (around
   line 174). It locates the first topic row via
   `find.ancestor(of: find.text('IV Cannula'), matching: find.byType(Ink))` —
   an `Ink` exists only in `_cardTile`, so this finder cannot survive a switch
   to dense rows.
2. `enchiridion/test/models/medical_instrumentation_display_order_test.dart`,
   the `testWidgets` block around line 241 (`IV Cannula renders strictly above
   every other Medical Instrumentation topic tile in the first viewport`). It
   pumps card mode and carries an explanatory comment (around lines 244-249)
   about needing an 800x3000 surface because only one hero card fits the
   default viewport.

Both must be realigned in Task 2 so the suite tests what ships.

**Test harness for the end-to-end check:** `library_screen_test.dart` already
has a working Resources-carousel harness — `_buildSubject(_makeStorage())`,
`setUpAll` with `SharedPreferences.setMockInitialValues({})` +
`Supabase.initialize`, a `_FakeAuthProvider`, and the precedent test `tapping
Calculators card navigates to CalculatorListScreen` (around line 219) that taps
a carousel card and asserts the pushed screen. The carousel is a vertical
`PageView`; the existing swipe test advances it with
`tester.fling(find.byType(PageView).last, const Offset(0, -400), 800)` and
`.last` is required because the Library tab's own `PageView` is also in the
tree. Medical Instrumentation is the 4th of 5 cards.
</interface_notes>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Medical Instrumentation opens as a dense list, proven end-to-end from the Library carousel</name>
  <files>enchiridion/test/screens/library_screen_test.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/lib/screens/resource_topic_list_screen.dart</files>
  <read_first>
    enchiridion/test/screens/library_screen_test.dart (lines 1-235 — the
    `_FakeAuthProvider`, `_buildSubject`/`_makeStorage` helpers, `setUpAll`,
    and the two precedent tests: the `fling` swipe test and the Calculators
    tap-to-navigate test).
    enchiridion/lib/screens/library_screen.dart lines 555-615 (the
    `_categories` list in `_ResourcesTabState.initState()`).
    enchiridion/lib/screens/resource_topic_list_screen.dart lines 27-140 (the
    `dense` field and its doc comment, `build()`, `_buildDenseList`).
  </read_first>
  <behavior>
    New test in `library_screen_test.dart`, added to the existing
    `LibraryScreen — Resources tab` group, directly after the Calculators
    navigation test:
    - Pump `_buildSubject(_makeStorage())`, `pumpAndSettle`, tap
      `find.text('Resources')`, `pumpAndSettle` — same opening as the
      precedent tests.
    - Advance the Resources carousel to the Medical Instrumentation card with
      a BOUNDED loop (at most 6 iterations): while
      `find.text('Medical Instrumentation').evaluate().isEmpty`, do
      `tester.fling(find.byType(PageView).last, const Offset(0, -400), 800)`
      then `pumpAndSettle`. Fail with an explicit `reason` if the loop
      exhausts without finding the card, so a carousel-order change reports
      as a clear failure rather than a confusing tap error.
    - Tap the card, `pumpAndSettle`, and assert
      `find.byType(ResourceTopicListScreen)` finds one widget.
    - Presentation assertion 1 (positive, list rows present):
      `find.descendant(of: find.byType(ResourceTopicListScreen), matching:
      find.byType(ListTile))` finds widgets.
    - Presentation assertion 2 (the card presentation is gone): scoped with
      the SAME `find.descendant(of: find.byType(ResourceTopicListScreen), ...)`
      wrapper so the Library tab's own book-cover images underneath the pushed
      route cannot satisfy it, `matching: find.byType(Image)` finds nothing —
      a hero image is rendered ONLY by the card builder, never by a dense row
      (which uses `Icon` + `CircleAvatar`).
    - Preserved-behavior assertion: `find.text('IV Cannula')` finds at least
      one widget, confirming the available-first lead topic still renders in
      the new presentation.
    Write this test FIRST and watch it fail on the `Image` / `ListTile`
    assertions before changing `library_screen.dart` — that red run is the
    proof the flag is what moved the UI.
  </behavior>
  <action>
    Step 1 (RED): add the test described in `<behavior>` to
    `enchiridion/test/screens/library_screen_test.dart`. Reuse the file's
    existing `_buildSubject`/`_makeStorage` helpers and `setUpAll` as-is —
    declare no new fakes, no new mock class, and no second `Supabase.initialize`.
    Add whatever imports the new assertions need
    (`package:enchiridion/screens/resource_topic_list_screen.dart`) next to the
    file's existing `calculator_list_screen.dart` import. Run the file and
    confirm it fails on presentation, not on navigation.

    Step 2 (GREEN): in `enchiridion/lib/screens/library_screen.dart`, inside
    the `_ResourceCategory` whose title is `'Medical Instrumentation'` (around
    line 596), add `dense: true` to the `ResourceTopicListScreen(...)`
    invocation, placed on its own line immediately after the `topics:`
    argument — mirroring the Surgical Instrumentation entry ten lines above.
    Change NOTHING else in this file: not the `topics:` argument (it must stay
    `kMedicalInstrumentationTopicsInDisplayOrder`, which is 260918-dr4's
    available-first ordering), not the Surgical Instrumentation entry, not the
    `assetPath`, not the carousel order. The invocation is already non-`const`
    (its topics list is a top-level `final`), so no `const` keyword needs
    adding or removing.

    Step 3: in `enchiridion/lib/screens/resource_topic_list_screen.dart`,
    update ONLY the doc comment on the `dense` field (around lines 31-35) so
    it no longer names Medical Instrumentation as a caller that keeps the card
    presentation — it is now an opt-in caller alongside Surgical
    Instrumentation. Describe the default's purpose generically (callers that
    do not opt in keep the hero-card presentation). Do not change the field's
    type, its `= false` default, the constructor, or any builder body.

    Do NOT add a new list widget, a new row widget, a new ordering helper, or
    a Medical-Instrumentation-specific screen. The whole point is that
    260918-dr0's shared `dense` presentation is reused verbatim.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/library_screen_test.dart && flutter analyze lib/screens/library_screen.dart lib/screens/resource_topic_list_screen.dart test/screens/library_screen_test.dart && [ "$(grep -v '^[[:space:]]*//' lib/screens/library_screen.dart | grep -c 'dense: true')" = "2" ]</automated>
  </verify>
  <done>
    Tapping the Medical Instrumentation card in the Resources carousel pushes a
    `ResourceTopicListScreen` whose subtree contains `ListTile` rows and zero
    `Image` widgets, with IV Cannula present; `library_screen.dart` carries
    exactly two non-commented `dense: true` call sites (Surgical and Medical);
    analyze is clean on all three touched files.
  </done>
</task>

<task type="auto">
  <name>Task 2: Realign the two existing Medical Instrumentation widget tests onto the shipped dense presentation</name>
  <files>enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart, enchiridion/test/models/medical_instrumentation_display_order_test.dart</files>
  <read_first>
    enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart
    lines 174-221 (the Medical Instrumentation grouping test and the Surgical
    Instrumentation test right below it, which already shows the dense-mode
    pump form).
    enchiridion/test/models/medical_instrumentation_display_order_test.dart
    lines 241-280 (the `testWidgets` ordering block, its viewport override,
    and its explanatory comment).
  </read_first>
  <action>
    Both of these tests pump `ResourceTopicListScreen` directly with the real
    Medical Instrumentation catalog and no dense flag, so they stay green
    after Task 1 while asserting a presentation the user no longer sees. Fix
    both to exercise what ships.

    File 1 —
    `enchiridion/test/screens/resource_topic_list_screen_grouping_test.dart`,
    the test named `the real kMedicalInstrumentationTopics catalog opens on the
    Diagnostic and Monitoring Equipment header with IV Cannula first`:
    add the dense flag set true to its `ResourceTopicListScreen(...)` pump,
    matching the Surgical Instrumentation test immediately below it. Then
    repoint its first-topic-row finder: the current
    `find.ancestor(of: find.text('IV Cannula'), matching: find.byType(Ink))`
    targets a widget only the card builder emits — replace the `matching:`
    argument with `find.byType(ListTile)`, which is what a dense row emits.
    Keep the rest of the test exactly as-is: the
    `find.text('DIAGNOSTIC AND MONITORING EQUIPMENT')` header assertion, the
    `find.byType(SectionHeader).first` finder, and the
    `expect(headerTop, lessThan(topicTop))` comparison all still hold, because
    `build()` runs `groupTopicsForDisplay` before choosing a builder — group
    headers are a shared behavior, not a card-mode behavior. Leave the
    Surgical Instrumentation test below it and every other test in the file
    untouched.

    File 2 —
    `enchiridion/test/models/medical_instrumentation_display_order_test.dart`,
    the `testWidgets` block `IV Cannula renders strictly above every other
    Medical Instrumentation topic tile in the first viewport`:
    add the dense flag set true to its `ResourceTopicListScreen(...)` pump.
    Keep the `tester.view.physicalSize` / `devicePixelRatio` override and both
    `addTearDown` resets exactly as they are — an enlarged surface is still
    harmless and still guarantees the comparison topic is laid out. Rewrite
    the explanatory comment above the override (around lines 244-249) so it
    describes the current reason for the enlarged surface in dense terms
    (enough rows build without scrolling for the position comparison to be
    meaningful) rather than the outdated hero-card rationale. Keep the
    assertion body — the `ivCannulaY` / `nextTopicY` `lessThan` comparison and
    its `reason` string — unchanged. Do NOT touch any of the eleven non-widget
    tests in this file: the `availableFirstByGroup` unit tests and the
    permutation / contiguity / content-preservation assertions over
    `kMedicalInstrumentationTopicsInDisplayOrder` are 260918-dr4's ordering
    contract and are out of scope for a presentation change.
  </action>
  <verify>
    <automated>cd enchiridion && flutter test test/screens/resource_topic_list_screen_grouping_test.dart test/models/medical_instrumentation_display_order_test.dart && flutter analyze test/screens/resource_topic_list_screen_grouping_test.dart test/models/medical_instrumentation_display_order_test.dart</automated>
  </verify>
  <done>
    Both realigned tests pass against the dense presentation; the grouping test
    still proves the Diagnostic and Monitoring Equipment header precedes the
    IV Cannula row; the display-order test still proves IV Cannula lays out
    above the next topic; analyze is clean on both files.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none crossed) | This plan changes local widget presentation only. No network call, no user input parsing, no persistence, no auth decision, and no new dependency is added or removed. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kiy-01 | Information Disclosure | ResourceTopicListScreen dense rows | low | accept | The dense presentation renders the same `ResourceTopic` fields (title, description) the card presentation already rendered, for the same already-bundled catalog. No field becomes newly visible. |
| T-kiy-02 | Elevation of Privilege | `_handleTap` gating of coming-soon topics | low | mitigate | Both builders share the one `_handleTap` closure, which is untouched — the SnackBar guard blocking navigation into a content-less topic is inherited, not reimplemented. Task 1 leaves `_handleTap` unmodified. |
| T-kiy-SC | Tampering | npm/pub/cargo installs | n/a | n/a | No package-manager install task exists in this plan; `pubspec.yaml` is not in `files_modified`. |
</threat_model>

<verification>
1. `cd enchiridion && flutter test` — the full suite is green (baseline 249
   tests as of `b379387`), including
   `test/guards/available_before_coming_soon_guard_test.dart` (available-before-
   coming-soon ordering) and `test/screens/resource_topic_list_screen_test.dart`
   (Surgical Instrumentation dense rows), neither of which this plan edits.
2. `cd enchiridion && flutter analyze lib/ test/` — no issues found.
3. Surgical-Instrumentation-untouched check:
   `git diff --stat -- enchiridion/lib/screens/resource_topic_list_screen.dart`
   shows only doc-comment lines changed, and
   `git diff -- enchiridion/lib/screens/library_screen.dart` shows exactly one
   added line inside the Medical Instrumentation entry.
4. Scope check: `git diff --name-only` against this plan's base lists exactly
   the five paths in `files_modified` — `lib/models/resource_topic.dart`,
   `lib/utils/content_availability.dart`, and
   `lib/screens/resource_topic_detail_screen.dart` must all be absent
   (ordering/availability logic and module-content scrolling are owned by
   260918-dr4 and sibling 260919-kiw respectively).
</verification>

<success_criteria>
- Resources -> Medical Instrumentation renders single-line rows with a leading
  circle icon and trailing chevron or compact badge — the same presentation
  Surgical Instrumentation ships.
- No hero-image card renders anywhere in the Medical Instrumentation listing.
- IV Cannula still leads, group headers still render, and coming-soon topics
  still render dimmed with a badge and still refuse navigation with a SnackBar.
- Zero new list/row/ordering widgets were introduced: the delta is the shared
  `dense` flag plus test realignment.
</success_criteria>

<output>
Create `.planning/quick/260919-kiy-medical-instrumentation-display-medical-instrumentation-modu/260919-kiy-SUMMARY.md` when done.
</output>
