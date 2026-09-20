---
quick_id: 260919-kiz
batch_id: 260919-kir
type: execute
autonomous: true
depends_on: [260919-kiy]
files_modified:
  - enchiridion/lib/widgets/common/coming_soon.dart
  - enchiridion/lib/screens/library_screen.dart
  - enchiridion/test/widgets/coming_soon_test.dart
  - enchiridion/test/screens/library_screen_test.dart

must_haves:
  truths:
    - "A user paging through the Library shelf sees every book cover — read-ready or not-yet-available — in its original full colour; no cover renders desaturated or at reduced opacity."
    - "A not-yet-available book is still visibly distinguished: its cover sits under the same translucent black scrim the Library used before this regression, and it keeps its Coming Soon badge and its tap-guard snackbar."
    - "The grayscale desaturation treatment still applies, unchanged, to the non-cover surfaces that legitimately use it (resource topic hero thumbnails, OSCE station rows)."
    - "A future list rendering full-bleed colourful artwork has one documented widget to reach for, so this desaturation regression cannot recur by accident."
  artifacts:
    - enchiridion/lib/widgets/common/coming_soon.dart
    - enchiridion/test/widgets/coming_soon_test.dart
    - enchiridion/test/screens/library_screen_test.dart
  key_links:
    - "CatalogBook.isComingSoon -> _BookPage scrim layer (replacing the desaturating wrapper on the cover image)"
    - "ComingSoonScrim -> full-bleed cover art (Library book pages); ComingSoonDim -> non-cover tiles (resource topic thumbnails, OSCE rows)"
---

<objective>
Stop graying out Library book cover tiles. Book covers are colourful, full-bleed artwork and must
render at full colour; not-yet-available books go back to the translucent black scrim the Library
used before, keeping their Coming Soon badge.

Purpose: the user report in `TESTING_REPORT.md` (### Library) reads: "The books are colourful and
beautiful, these are images so dont gray them out, the previous implementation dim out those tiles
and we need that continued in this case." Quick task `260918-dqy` replaced the Library's flat black
scrim with the shared `ComingSoonDim` wrapper, which applies a saturation-zero colour matrix AND a
0.45 `Opacity`. That is the right treatment for a small hero thumbnail on a text card, but on a
full-screen cover it destroys the artwork the user is asking to keep. Seven of the eight catalog
books have `dataFile: ''`, so seven of eight Library pages are currently grayscale.

Output: a `ComingSoonScrim` widget in the shared coming-soon module (the documented treatment for
full-bleed colourful artwork), `_BookPage` switched onto it, and regression tests proving Library
covers carry no colour filter while the other surfaces keep desaturating.
</objective>

<context>
@.planning/STATE.md
@CLAUDE.md
@.planning/quick/260918-dqy-all-coming-soon-topics-should-be-grayed-out/260918-dqy-SUMMARY.md
@enchiridion/lib/widgets/common/coming_soon.dart
@enchiridion/lib/screens/library_screen.dart
@enchiridion/lib/models/book_catalog.dart
@enchiridion/test/widgets/coming_soon_test.dart
@enchiridion/test/screens/library_screen_test.dart

**Codebase facts established during planning (do not re-derive, do not re-read to confirm):**

- The Flutter app is the nested `enchiridion/` directory. Every `flutter` command runs from there.
- **Root cause, already located.** `library_screen.dart` `_BookPage.build` (around line 447) wraps
  the cover `Image.asset` in `ComingSoonDim(dimmed: book.isComingSoon, ...)`. `ComingSoonDim`
  (`lib/widgets/common/coming_soon.dart`, around line 98) applies `ColorFilter.matrix` with
  saturation-zero luminance rows **and** `Opacity(opacity: ComingSoonStyle.imageOpacity /* 0.45 */)`.
  That wrapper is what grays the covers. No other mechanism dims Library book tiles.
- **The exact "previous implementation" the user wants back** is in `git show
  ee9ce15^:enchiridion/lib/screens/library_screen.dart`. In that version, `_BookPage`'s `Stack`
  children were, in order: a plain `Image.asset` cover (no wrapper, full colour), the readability
  gradient `DecoratedBox`, then a scrim layer written as
  `if (!book.hasContent) Container(color: Colors.black.withValues(alpha: 0.35))`, then the
  `Positioned` bottom text, then the tap-to-read hint. The scrim sat ABOVE the gradient and BELOW
  the bottom text, so title and badge stayed full strength.
- `withValues(alpha: ...)` is the codebase convention for translucent colours. `Color.withOpacity`
  is not used anywhere and must not be introduced.
- `book.isComingSoon` (`== !hasContent`, `book_catalog.dart:22`) is the availability predicate.
  `hasContent` is used for ordering (`booksInDisplayOrder`); presentation code reads `isComingSoon`.
- Book display order at first paint: `availableFirst` puts `paediatrics` (the only book with a
  `dataFile`) on page 0; page 1 is `internal-medicine`, asset `assets/books/Internal Medicine.jpeg`,
  a placeholder. `PageView` here has no cache extent, so only the visible page is in the tree —
  this is why the existing library test flings once before asserting on a placeholder page.
- `ComingSoonDim` has exactly two production call sites: `library_screen.dart:448` (the one this
  plan removes) and `resource_topic_list_screen.dart:195` (a 16:9 thumbnail inside a text card —
  **keep it**, it is the "other tile types may still dim as before" case).
- OSCE station rows never used `ComingSoonDim`; they mute text/icon colours via `ComingSoonStyle`.
  Nothing in this plan touches them.
- **Trap:** `test/screens/library_screen_test.dart` cases (c) and (d) assert
  `find.byType(AnimatedContainer)` is exactly 5 (the page-indicator dots). The new scrim must not
  be an `AnimatedContainer`.
- **Trap:** `test/widgets/coming_soon_test.dart` asserts `ComingSoonDim(dimmed: true)` renders both
  a `ColorFiltered` and an `Opacity`, and `test/screens/resource_topic_list_screen_test.dart`
  asserts an unavailable topic card has a `ColorFiltered` descendant. `ComingSoonDim` itself must
  not change behaviour — only the Library's use of it goes away.

**Scope boundary:** this is a narrow restoration of Library book cover rendering. Do not remove the
`ComingSoonBadge`, the `_openBook` snackbar tap-guard, or any other "not yet available" signal —
unavailable books must stay distinguishable. Do not touch `resource_topic_list_screen.dart`,
`osce_screen.dart`, `calculator_list_screen.dart`, ordering logic, or the `_ResourcesTab` cards.

**Sibling coordination (batch 260919-kir):** `260919-kiy` (Medical Instrumentation as a list) is the
only sibling likely to edit `library_screen.dart` — its `_ResourcesTab._categories` entry, a
different region of the file from `_BookPage`. `depends_on: [260919-kiy]` serialises the two so this
plan's edit lands on top of a settled file rather than racing it.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: Full-colour Library covers via a shared scrim, end to end</name>
  <files>enchiridion/lib/widgets/common/coming_soon.dart, enchiridion/lib/screens/library_screen.dart, enchiridion/test/widgets/coming_soon_test.dart, enchiridion/test/screens/library_screen_test.dart</files>
  <behavior>
    - `coming_soon_test.dart` (extend; every existing case must still pass unchanged): a pumped
      `ComingSoonScrim` renders a `ColoredBox` whose colour equals
      `Colors.black.withValues(alpha: ComingSoonStyle.scrimAlpha)`.
    - `coming_soon_test.dart`: `ComingSoonStyle.scrimAlpha` equals `0.35`.
    - `coming_soon_test.dart`: a pumped `ComingSoonScrim` contains no `ColorFiltered`, no `Opacity`,
      and no `AnimatedContainer` anywhere in its subtree — it darkens, it never desaturates.
    - `library_screen_test.dart` (extend; all seven existing cases must still pass): on the Library
      tab, after one upward fling of the first `PageView` onto the `internal-medicine` placeholder
      page, the cover `Image` widget for `assets/books/Internal Medicine.jpeg` has NO `ColorFiltered`
      ancestor and NO `ComingSoonDim` ancestor.
    - `library_screen_test.dart`: on that same placeholder page, exactly one `ComingSoonScrim` is
      present, and the existing `ComingSoonBadge` assertion still holds.
    - `library_screen_test.dart`: on the initially-visible page 0 (`paediatrics`, the readable book),
      `ComingSoonScrim` is absent.
    - `library_screen_test.dart`: the case (c)/(d) `AnimatedContainer` count on the Resources tab is
      still exactly 5.
  </behavior>
  <action>
Add `ComingSoonScrim` to `lib/widgets/common/coming_soon.dart` as the module's second, distinct
treatment — the one for full-bleed colourful artwork, where desaturating the image destroys the very
thing that makes the tile worth looking at.

- Add `static const double scrimAlpha = 0.35;` to `ComingSoonStyle`, alongside the existing alphas.
  Use `0.35` exactly: it is the value the Library shelf used before the regression, recovered from
  `git show ee9ce15^:enchiridion/lib/screens/library_screen.dart`.
- `ComingSoonScrim` is a `const`-constructible `StatelessWidget` taking only `key`. Its `build`
  returns a single `ColoredBox` filled with `Colors.black.withValues(alpha: ComingSoonStyle.scrimAlpha)`
  and no child. It must not be an `AnimatedContainer` (see the dot-count trap in `<context>`), and it
  must not introduce a colour filter or an opacity layer of any kind. Callers gate it themselves with
  `if (model.isComingSoon)` inside their `Stack`, which keeps "is it showing?" directly assertable in
  a widget test.
- Dartdoc both the new members with the choosing rule, since this distinction is the whole point of
  the change: artwork-forward tiles whose image IS the content (full-bleed book covers) darken under
  the scrim and keep their colour; icon/text rows and small thumbnails inside text cards keep using
  the desaturating wrapper. Extend the library-level dartdoc's consumers note so the Library shelf is
  listed as the scrim's consumer while the resource topic cards and OSCE list stay listed under the
  existing treatment.

Then fix the Library shelf in `library_screen.dart` `_BookPage.build`:

- Unwrap the cover: the `Image.asset(book.assetPath, ...)` (with its existing `errorBuilder`
  fallback `Container`) becomes a direct child of the `Stack` again, exactly as it was before
  `ee9ce15`. Delete the wrapper widget that sat around it and drop the now-unused import symbol only
  if nothing else in the file needs it. Both available and unavailable books take this identical
  full-colour path — there is no longer any per-book branching on the cover image itself. Comment the
  layer as full-colour cover art; do not name the removed wrapper in any comment you write in this
  file.
- Restore the scrim layer: immediately after the readability gradient `DecoratedBox` and immediately
  before the `Positioned` bottom-text block, add `if (book.isComingSoon) const ComingSoonScrim(),`.
  Ordering matters — above the gradient so the darkening reads as a deliberate veil over the whole
  page, below the text so the title and badge stay legible at full strength.
- Change nothing else in `_BookPage`: the `ComingSoonBadge` stays exactly where it is (it is the real
  "not yet available" signal and the user did not ask for its removal), the `Recent` pill, the
  gradient, the specialty text branch, and the tap-to-read hint icon are all untouched.
- Leave `_openBook`'s snackbar guard, `_sortedBooks`, `_LibraryTab`, `_ResourcesTab`, and
  `_ResourceCard` alone.

For the test additions, find the cover image with a widget predicate on the `Image` widget's
`AssetImage.assetName` rather than by index — the asset does not load under `flutter test`, so the
`errorBuilder` child renders, but the `Image` widget itself is still in the tree and still findable.
Assert absence of the desaturating ancestors with `find.ancestor(of: coverFinder, matching: ...)`,
which is the precise property under repair; do not assert on a bare tree-wide `Opacity` count, since
unrelated framework widgets can contribute those.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/widgets/coming_soon_test.dart test/screens/library_screen_test.dart</automated>
  </verify>
  <done>`ComingSoonScrim` and `ComingSoonStyle.scrimAlpha` exist and are dartdoc'd with the
  scrim-vs-desaturate rule; `_BookPage` renders every cover at full colour and veils only
  not-yet-available books with the 0.35 black scrim; the placeholder page still shows its
  `ComingSoonBadge`; all previously existing cases in both test files still pass.</done>
</task>

<task type="auto">
  <name>Task 2: Prove the other tile types still dim and the app is green</name>
  <files>enchiridion/lib/widgets/common/coming_soon.dart</files>
  <action>
Confirm the fix stayed inside the Library shelf and that nothing else lost its treatment.

Check that `resource_topic_list_screen.dart` still wraps its 16:9 hero thumbnail in the desaturating
wrapper keyed off `topic.isComingSoon`, and that `osce_screen.dart` still mutes its station rows
through `ComingSoonStyle` — both were correct before this plan and neither is in this plan's
`files_modified`, so the expected outcome is that they are byte-identical to `HEAD`. If either has
drifted, stop and report rather than editing it: that would mean a sibling task changed it and the
two changes need reconciling.

Then run the analyzer and the full suite. The suite is the real guard here: `resource_topic_list_screen_test.dart`
asserts an unavailable topic card still renders a `ColorFiltered`, and `coming_soon_test.dart` asserts
the desaturating wrapper still produces `ColorFiltered` + `Opacity` when asked — together they prove
"other tile types may still dim as before" survived Task 1 intact, while Task 1's new Library cases
prove the covers no longer do.

Note in the SUMMARY (not in code) any analyzer findings that predate this plan; `260918-dqy`'s
SUMMARY lists nine known pre-existing findings in files this plan does not touch, and those are out
of scope.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib test &amp;&amp; flutter test</automated>
  </verify>
  <done>`flutter analyze lib test` reports nothing new beyond the nine findings `260918-dqy` already
  recorded, the full `flutter test` suite passes, and the resource-topic and coming-soon module tests
  confirm the desaturating treatment is unchanged for non-cover tiles.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| none introduced | Presentation-only change: no new input parsing, no network call, no storage write, no dependency. Everything rendered is compile-time `const` catalog data already in the binary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-kiz-01 | Information disclosure | `_BookPage` cover rendering for not-yet-available books | low | accept | Removing desaturation exposes no new fact: the cover art asset already ships in the bundle and already rendered (grayscale) on the same page, and the `ComingSoonBadge` continues to state availability. No count, roadmap detail, or bank size is disclosed. |
| T-kiz-02 | Tampering | npm/pip/cargo installs | n/a | accept | No package installs in this plan — `pubspec.yaml` is untouched and every widget used comes from `flutter/material`. |
</threat_model>

<verification>
1. `cd enchiridion && flutter analyze lib test` — no new findings.
2. `cd enchiridion && flutter test` — full suite green, including the seven pre-existing library
   screen cases and the resource-topic card cases.
3. Read-through of `_BookPage`: the cover `Image.asset` has no wrapper widget between it and the
   `Stack`, and the only availability-driven layers are the scrim, the badge, and the tap-to-read
   hint.
4. `ComingSoonDim` retains exactly one production call site (the resource topic card thumbnail).
</verification>

<success_criteria>
- Every Library book cover renders in full colour; none is desaturated or run at reduced opacity.
- Not-yet-available books stay distinguishable: 0.35 black scrim plus the shared Coming Soon badge,
  with the snackbar tap-guard unchanged.
- Resource topic cards and OSCE rows keep the treatment `260918-dqy` gave them, proven by their
  existing tests passing untouched.
- The shared module documents which treatment a new tile type should pick, so a future list cannot
  reintroduce desaturation on colourful artwork by reaching for the wrong widget.
</success_criteria>

<output>
Write `.planning/quick/260919-kiz-library-stop-dimming-graying-out-library-book-cover-tiles-si/260919-kiz-SUMMARY.md`
when done. Record the scrim-vs-desaturate rule and `ComingSoonScrim`'s call site under a "Shared
pattern for siblings" section, since batch siblings building new tile surfaces need to know which of
the module's two treatments applies to them.
</output>
