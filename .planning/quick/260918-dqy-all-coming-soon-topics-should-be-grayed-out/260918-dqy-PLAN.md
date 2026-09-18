---
quick_id: 260918-dqy
batch_id: 260918-dqw
type: execute
autonomous: true
depends_on: []
files_modified:
  - enchiridion/lib/widgets/common/coming_soon.dart
  - enchiridion/lib/models/resource_topic.dart
  - enchiridion/lib/models/book_catalog.dart
  - enchiridion/lib/screens/osce_screen.dart
  - enchiridion/lib/screens/resource_topic_list_screen.dart
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/test/widgets/coming_soon_test.dart
  - enchiridion/test/screens/osce_screen_test.dart
  - enchiridion/test/screens/resource_topic_list_screen_test.dart
  - enchiridion/test/screens/library_screen_test.dart

must_haves:
  truths:
    - "A user scanning any topic/resource list can tell at a glance which rows have no content yet, because those rows render muted (grayed text, muted icon/avatar, desaturated hero image) while available rows render at full strength."
    - "Every not-yet-available row carries the same visible 'Coming Soon' badge text, in the same style, on every screen that has such rows."
    - "Tapping a not-yet-available resource-topic card never lands the user on a 'Could not load this topic' error screen."
    - "A sibling task can gray out a new list it is building by importing one shared module, without copying alpha values or re-deciding the label."
  artifacts:
    - enchiridion/lib/widgets/common/coming_soon.dart
    - enchiridion/test/widgets/coming_soon_test.dart
    - enchiridion/test/screens/resource_topic_list_screen_test.dart
  key_links:
    - "ResourceTopic.isComingSoon (dataAssetPath == null) -> OsceScreen list tile + ResourceTopicListScreen card styling"
    - "CatalogBook.isComingSoon (!hasContent) -> _BookPage cover desaturation + badge"
    - "ComingSoonStyle/ComingSoonBadge/ComingSoonDim -> the single source of truth every current and future list consumes"
---

<objective>
Make every not-yet-available ("Coming Soon") topic, book, and resource row in the app render
visibly grayed out, driven by one shared status + style module rather than per-screen ad-hoc
styling.

Purpose: today the app has three unrelated notions of "no content yet"
(`CatalogBook.hasContent`, `ResourceTopic.dataAssetPath == null`, and the freemium `locked`
styling in the calculator list) and only the library book page dims at all. OSCE lists 11
content-less stations that look identical to the one real station, and the resource topic
lists have no treatment at all. A user cannot tell available from unavailable at a glance.

Output: `lib/widgets/common/coming_soon.dart` (shared label, alpha constants, badge, and
desaturating wrapper), `isComingSoon` getters on the two content models, and the grayed
treatment applied to every list that currently renders such rows.
</objective>

<context>
@.planning/STATE.md
@CLAUDE.md
@enchiridion/lib/models/resource_topic.dart
@enchiridion/lib/models/book_catalog.dart
@enchiridion/lib/screens/osce_screen.dart
@enchiridion/lib/screens/resource_topic_list_screen.dart
@enchiridion/lib/screens/library_screen.dart
@enchiridion/lib/screens/calculator_list_screen.dart
@enchiridion/test/screens/osce_screen_test.dart
@enchiridion/test/screens/library_screen_test.dart

**Codebase facts established during planning (do not re-derive):**

- The Flutter app is under `enchiridion/`. All `flutter` commands run from that directory.
- `lib/widgets/common/` exists but is empty — the new shared module is its first occupant.
- `withValues(alpha: ...)` is the codebase convention for translucent colors (107 call sites);
  `Color.withOpacity` is not used and must not be introduced.
- The muted-row alpha values already proven in `calculator_list_screen.dart` (`_calcTile`,
  freemium-locked branch) are: title `0.5`, subtitle `0.35`, icon `0.4`. Reuse those numbers as
  the canonical constants so locked rows and unavailable rows read as one visual family.
- `_BookPage` in `library_screen.dart` already dims unavailable books with a flat black overlay
  at alpha `0.35` and prints a lowercase `'Coming soon'` subtitle. That is the ad-hoc treatment
  this plan replaces.
- `ResourceTopicDetailScreen._load()` sets `_error = StateError(...)` when `dataAssetPath` is
  null, so a content-less topic opened from `ResourceTopicListScreen` currently renders
  "Could not load this topic." — an error page, not a coming-soon page.
- OSCE is deliberately different: a content-less station still shows a genuinely useful outline
  checklist (`_OutlinePlaceholder`), so OSCE rows stay tappable while grayed.
- **Trap:** `test/screens/library_screen_test.dart` cases (c) and (d) assert
  `find.byType(AnimatedContainer)` has exactly 5 matches (the page-indicator dots). Any new
  widget added to the library tree must not be an `AnimatedContainer`.

**Sibling coordination (batch 260918-dqw):**

- `260918-dqx` (available content ranks above coming soon) needs a sort key; the
  `isComingSoon` getters this plan adds are exactly that key. This plan is the foundation and
  waits on nothing.
- `260918-dqz` (calculators), `260918-dr0` (Surgical Instrumentation list), `260918-dr3`
  (Medical Instrumentation grouping) will build lists that need this treatment. This plan does
  NOT pre-build their lists and does NOT touch `calculator_list_screen.dart` — it publishes the
  shared module and documents it in the SUMMARY so they consume it.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Shared coming-soon module wired end-to-end through the OSCE list</name>
  <files>enchiridion/lib/widgets/common/coming_soon.dart, enchiridion/lib/models/resource_topic.dart, enchiridion/lib/models/book_catalog.dart, enchiridion/lib/screens/osce_screen.dart, enchiridion/test/widgets/coming_soon_test.dart, enchiridion/test/screens/osce_screen_test.dart</files>
  <behavior>
    - `coming_soon_test.dart`: `ComingSoonBadge` renders the text `Coming Soon` (that exact
      casing) and is not an `AnimatedContainer` anywhere in its subtree.
    - `coming_soon_test.dart`: `ComingSoonDim(dimmed: false, child: X)` returns a tree
      containing X with no `ColorFiltered` and no `Opacity` ancestor added by the wrapper.
    - `coming_soon_test.dart`: `ComingSoonDim(dimmed: true, child: X)` wraps X in both a
      `ColorFiltered` and an `Opacity`.
    - `coming_soon_test.dart`: `ComingSoonStyle.title/body/icon` return progressively fainter
      `onSurface`-derived colors (title alpha > body alpha is false — body is the faintest;
      assert exact alphas 0.5 / 0.35 / 0.4 against the `ColorScheme`).
    - `resource_topic.dart` model expectation: `isComingSoon` is `true` for the
      `cardiovascular-system` topic and `false` for `abdominal-examination`.
    - `book_catalog.dart` model expectation: `isComingSoon` is `false` for `paediatrics` and
      `true` for `surgery`.
    - `osce_screen_test.dart` (extend the existing single test file, keep its current case
      passing): in the OSCE station list, the `Cardiovascular System` row shows a
      `ComingSoonBadge` and the `Abdominal Examination` row does not; tapping the grayed
      `Cardiovascular System` row still opens the tabbed detail view.
  </behavior>
  <action>
Create `lib/widgets/common/coming_soon.dart` as the single source of truth for how the app
presents content that does not exist yet. It exports, with dartdoc on each public member
explaining that sibling lists are expected to consume these rather than restyle locally:

- `kComingSoonLabel` — top-level `const String` holding the canonical user-facing label, title
  case on both words. Every screen renders this constant; no screen writes the phrase inline.
- `ComingSoonStyle` — an abstract-final class of `static const double` alphas named
  `titleAlpha` (0.5), `bodyAlpha` (0.35), `iconAlpha` (0.4), `imageOpacity` (0.45), plus
  `static Color title(ColorScheme)`, `body(ColorScheme)`, `icon(ColorScheme)` returning
  `cs.onSurface.withValues(alpha: ...)` for the first three, and
  `static Color container(ColorScheme)` returning `cs.surfaceContainerHighest`. The first three
  alphas are lifted verbatim from the freemium-locked branch of
  `calculator_list_screen.dart._calcTile` so muted rows read as one family app-wide.
- `ComingSoonBadge` — a small `StatelessWidget` pill: rounded `Container` (NOT an
  `AnimatedContainer`; see the library test trap in `<context>`) filled with
  `ComingSoonStyle.container(cs)`, holding `Icons.schedule` at `ComingSoonStyle.icon(cs)` and a
  `Text(kComingSoonLabel)` in `labelSmall` at `ComingSoonStyle.title(cs)`. Accept an optional
  `compact` bool that drops the icon and tightens padding, for use inside a dense `ListTile`
  trailing slot.
- `ComingSoonDim` — a `StatelessWidget` taking `child` and `dimmed`. When `dimmed` is false it
  returns `child` untouched (no extra render objects at all — the test asserts this). When
  true it wraps `child` in `ColorFiltered` using `ColorFilter.matrix` with a saturation-zero
  luminance matrix (rows built from the 0.2126 / 0.7152 / 0.0722 luminance weights, alpha row
  passthrough), then in `Opacity` at `ComingSoonStyle.imageOpacity`. This is what desaturates
  hero images and cover art so an unavailable card reads as gray even though its artwork is
  colorful.

Add `bool get isComingSoon => dataAssetPath == null;` to `ResourceTopic` and
`bool get isComingSoon => !hasContent;` to `CatalogBook`, each with a one-line dartdoc pointing
at `ComingSoonStyle` as the presentation rule. These getters are the app-wide predicate —
sibling 260918-dqx will sort on them, so they are public API, not screen-local helpers.

Then wire the first surface end to end: in `osce_screen.dart`, the `ListView.builder` tile in
`OsceScreen.build` reads `topic.isComingSoon` and, when true, renders the `CircleAvatar`
background as `ComingSoonStyle.container(cs)` with its icon at `ComingSoonStyle.icon(cs)`, the
title `Text` at `ComingSoonStyle.title(cs)`, the subtitle `Text` at `ComingSoonStyle.body(cs)`,
and a compact `ComingSoonBadge` in place of the `Icons.chevron_right` trailing widget.
Available stations keep their current full-strength appearance and chevron. Keep the OSCE tap
target enabled for grayed stations: the outline checklist behind them is real, useful content
(explain that in a short comment above the branch). Leave `_OutlinePlaceholder` and the tab
bodies alone.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/widgets/coming_soon_test.dart test/screens/osce_screen_test.dart</automated>
  </verify>
  <done>`coming_soon.dart` exists with the label, style constants, badge, and dim wrapper; both
  models expose `isComingSoon`; the OSCE station list shows grayed rows with the badge for all
  11 content-less stations and an unchanged row for Abdominal Examination; the pre-existing
  OSCE test still passes.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Apply the shared treatment to resource topic cards and library book pages</name>
  <files>enchiridion/lib/screens/resource_topic_list_screen.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/test/screens/resource_topic_list_screen_test.dart, enchiridion/test/screens/library_screen_test.dart</files>
  <behavior>
    - `resource_topic_list_screen_test.dart` (new): given a two-item topic list built in the
      test — one with a `dataAssetPath`, one without — the available card renders no
      `ComingSoonBadge` and no `ColorFiltered`; the unavailable card renders both.
    - `resource_topic_list_screen_test.dart`: tapping the unavailable card does NOT push
      `ResourceTopicDetailScreen`; a `SnackBar` appears instead.
    - `resource_topic_list_screen_test.dart`: tapping the available card DOES push
      `ResourceTopicDetailScreen`.
    - `library_screen_test.dart` (extend; all six existing cases must still pass): on the
      Library tab, at least one `ComingSoonBadge` is present in the tree, and the existing
      `AnimatedContainer` dot counts in cases (c) and (d) are unchanged at 5.
  </behavior>
  <action>
In `resource_topic_list_screen.dart`, branch the card builder on `topic.isComingSoon`. For an
unavailable topic: wrap the hero `Image.asset` subtree in `ComingSoonDim(dimmed: true, ...)` so
the artwork desaturates, render the title at `ComingSoonStyle.title(cs)` and the description at
`ComingSoonStyle.body(cs)`, and add a `ComingSoonBadge` under the title inside the padded
`Column`. Available topics must go through `ComingSoonDim(dimmed: false, ...)` on the same code
path so there is one card builder, not two — the wrapper is a no-op when not dimmed.

Change the tap behaviour for unavailable topics: instead of pushing `ResourceTopicDetailScreen`
(which today renders "Could not load this topic." because `_load()` raises a `StateError` on a
null `dataAssetPath`), show a floating `SnackBar` reading `'${topic.title} — $kComingSoonLabel'`
via `ScaffoldMessenger.of(context)`, matching the pattern `_openBook` already uses in
`library_screen.dart`. Keep the `InkWell` present so the row still gives tap feedback; only the
destination changes. `ResourceTopicListScreen` is currently a `StatelessWidget` with a
`BuildContext` available in the item builder, so no state conversion is needed.

In `library_screen.dart`, replace the ad-hoc treatment in `_BookPage` with the shared one:
switch the `book.hasContent` checks to `book.isComingSoon`, wrap the cover `Image.asset` (and
its `errorBuilder` fallback) in `ComingSoonDim` keyed off that getter so the cover art
desaturates instead of merely sitting under a flat black scrim, delete the standalone black
overlay `Container` that provided the old scrim, and replace the plain `'Coming soon'` subtitle
string with a `ComingSoonBadge` so the wording and styling match every other screen. The title
`Text` stays white for legibility against the artwork — the desaturated cover plus the badge
carry the signal there. Leave the `Recent` pill, the gradient overlay, the indicator dots, and
`_openBook`'s existing snackbar untouched; do not add any `AnimatedContainer` to this tree.

Do not modify `_sortedBooks` or any ordering logic — ordering belongs to sibling 260918-dqx.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/screens/resource_topic_list_screen_test.dart test/screens/library_screen_test.dart test/screens/osce_screen_test.dart</automated>
  </verify>
  <done>Unavailable resource-topic cards render desaturated with a badge and route to a
  snackbar rather than an error screen; unavailable library books render a desaturated cover
  with the shared badge; all six pre-existing library screen tests still pass.</done>
</task>

<task type="auto">
  <name>Task 3: Sweep the remaining list surfaces and prove the rule holds app-wide</name>
  <files>enchiridion/lib/screens/osce_screen.dart, enchiridion/lib/screens/resource_topic_list_screen.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/lib/widgets/common/coming_soon.dart</files>
  <action>
Sweep for any remaining surface that renders a not-yet-available row without the shared
treatment. Search `lib/` for the case-insensitive phrase "coming soon", for `hasContent`, for
`dataAssetPath == null`, and for `isComingSoon`, then check every hit and every list-rendering
screen (`exam_prep_home_screen.dart`, `resource_topic_detail_screen.dart`,
`pinned_notes_screen.dart`, `question_list_screen.dart`, the drawer widgets) against these
rules:

- Any row or card representing content that does not exist yet must derive its state from an
  `isComingSoon` getter and style itself through `ComingSoonStyle` / `ComingSoonBadge` /
  `ComingSoonDim`. If you find one that does not, fix it in place.
- `calculator_list_screen.dart` is explicitly OUT of scope and must not be edited: its muted
  rows are freemium-locked (a paywall state), not unavailable content, and sibling 260918-dqz
  owns the change that introduces genuine unavailable calculators there. Note the distinction
  in the module dartdoc instead.
- `resource_topic_detail_screen.dart` keeps its error branch as-is; Task 2 stopped users from
  reaching it, and siblings 260918-dr0 / 260918-dr3 may reshape that screen.

Finish the module dartdoc in `coming_soon.dart` with a short "consumers" note listing the three
screens wired here and stating that any new topic or resource list must route through this
module — this is the hand-off the sibling tasks read.

Then run the whole suite and the analyzer to confirm nothing regressed anywhere in the app,
including the reader, exam prep, and calculator tests that this change routes near but does not
touch.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib test &amp;&amp; flutter test &amp;&amp; grep -rl "ComingSoonBadge" lib/screens | sort | tr '\n' ' ' | grep -q "library_screen.dart" &amp;&amp; grep -rL "withOpacity" lib/widgets/common/coming_soon.dart</automated>
  </verify>
  <done>`flutter analyze lib test` reports no issues, the full `flutter test` suite passes, all
  three wired screens import the shared module, and the module dartdoc names its consumers and
  the calculator carve-out.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| none introduced | Presentation-only change: no new input parsing, no network call, no storage write, no new dependency. All data rendered is compile-time `const` catalog data already in the binary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-dqy-01 | Information disclosure | `ComingSoonBadge` on locked vs unavailable rows | low | accept | The badge states only that content is not yet written — the same fact the existing library subtitle already discloses. No count, no roadmap detail, no question-bank size is exposed (consistent with the 260917-ndq/ndx decision to hide bank size). |
| T-dqy-02 | Tampering | npm/pip/cargo installs | n/a | accept | No package installs in this plan — no dependency is added to `pubspec.yaml`; every widget used is from `flutter/material`. |
</threat_model>

<verification>
1. `cd enchiridion && flutter analyze lib test` — clean.
2. `cd enchiridion && flutter test` — full suite green, including the six pre-existing library
   screen cases and the pre-existing OSCE case.
3. Manual read-through: every hit of `isComingSoon` in `lib/screens/` resolves to styling drawn
   from `ComingSoonStyle`, `ComingSoonBadge`, or `ComingSoonDim` — no screen-local alpha
   literals and no screen-local spelling of the label.
</verification>

<success_criteria>
- One shared module owns the coming-soon label, alphas, badge, and desaturation wrapper.
- Both content models expose a public `isComingSoon` predicate that sibling 260918-dqx can sort
  on without further refactoring.
- OSCE stations, resource topic cards, and library books all render unavailable entries grayed
  with the identical badge; available entries are visually unchanged from today.
- No user can reach the "Could not load this topic." error screen by tapping an unavailable
  resource topic card.
- `calculator_list_screen.dart` is untouched, leaving sibling 260918-dqz a clean file.
</success_criteria>

<output>
Write `.planning/quick/260918-dqy-all-coming-soon-topics-should-be-grayed-out/260918-dqy-SUMMARY.md`
when done. The SUMMARY MUST include a "Shared pattern for siblings" section naming
`lib/widgets/common/coming_soon.dart`, its exported members (`kComingSoonLabel`,
`ComingSoonStyle`, `ComingSoonBadge`, `ComingSoonDim`), the `isComingSoon` getters on
`ResourceTopic` and `CatalogBook`, and the explicit note that `calculator_list_screen.dart` was
left untouched for 260918-dqz — siblings 260918-dqx, 260918-dqz, 260918-dr0, and 260918-dr3
consume this.
</output>
