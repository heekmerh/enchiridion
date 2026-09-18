---
quick_id: 260918-dqy
batch_id: 260918-dqw
subsystem: ui
tags: [flutter, dart, coming-soon, osce, library, resource-topics]

# Dependency graph
requires: [260918-dqx]
provides:
  - "enchiridion/lib/widgets/common/coming_soon.dart: kComingSoonLabel re-export, ComingSoonStyle, ComingSoonBadge, ComingSoonDim"
  - "ResourceTopic.isComingSoon / CatalogBook.isComingSoon getters"
  - "OsceScreen station list, ResourceTopicListScreen cards, and LibraryScreen book pages all render the shared grayed treatment"
affects: [260918-dqz, 260918-dr0, 260918-dr3]

# Actuals (#2632)
actuals:
  tokens: 7064
  tasks: 3
  commits: 2
plan_head_before: 0b99c306862465f7def495afc6ec4d19e63eeb15

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ComingSoonDim(dimmed: bool, child): no-op wrapper when not dimmed (zero extra render objects), ColorFiltered saturation-zero matrix + Opacity when dimmed"
    - "ComingSoonBadge: single pill widget (Container, not AnimatedContainer) every screen renders instead of inlining the label"
    - "isComingSoon getter (== !hasContent) as the presentation predicate, parallel to dqx's hasContent ordering predicate"

key-files:
  created:
    - enchiridion/lib/widgets/common/coming_soon.dart
    - enchiridion/test/widgets/coming_soon_test.dart
    - enchiridion/test/screens/resource_topic_list_screen_test.dart
  modified:
    - enchiridion/lib/models/resource_topic.dart
    - enchiridion/lib/models/book_catalog.dart
    - enchiridion/lib/screens/osce_screen.dart
    - enchiridion/lib/screens/resource_topic_list_screen.dart
    - enchiridion/lib/screens/library_screen.dart
    - enchiridion/test/models/content_availability_test.dart
    - enchiridion/test/screens/osce_screen_test.dart
    - enchiridion/test/screens/library_screen_test.dart

key-decisions:
  - "kComingSoonLabel is NOT redeclared in coming_soon.dart — it is re-exported from content_availability.dart (sibling 260918-dqx's file) to avoid an ambiguous-import compile error in any file that imports both modules. See 'Shared pattern for siblings' below."
  - "isComingSoon on both models is implemented as `!hasContent` rather than re-deriving from dataAssetPath/dataFile directly, since 260918-dqx already added hasContent to both models as the canonical availability predicate — isComingSoon is purely a presentation-facing alias of the same fact."
  - "ComingSoonBadge is a plain Container (not AnimatedContainer) specifically to avoid colliding with the library screen test's AnimatedContainer dot-count assertion (5)."
  - "OSCE rows stay tappable when grayed — the outline checklist behind them is real, useful content — only the trailing chevron is replaced by the badge."

patterns-established:
  - "Any new topic/resource/book list adopts the coming-soon treatment by importing widgets/common/coming_soon.dart and branching on the model's isComingSoon getter — no local alpha literals, no local badge text."
  - "Tap-guard pattern: unavailable rows show a SnackBar with '${title} — $kComingSoonLabel' instead of navigating into a screen that would error (established in library_screen.dart's _openBook, now mirrored in resource_topic_list_screen.dart)."

requirements-completed: []

coverage:
  - id: D1
    description: "ComingSoonBadge renders the exact label 'Coming Soon' and is never an AnimatedContainer"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/widgets/coming_soon_test.dart#ComingSoonBadge"
        status: pass
    human_judgment: false
  - id: D2
    description: "ComingSoonDim is a no-op when dimmed:false and wraps child in ColorFiltered+Opacity when dimmed:true"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/widgets/coming_soon_test.dart#ComingSoonDim"
        status: pass
    human_judgment: false
  - id: D3
    description: "ComingSoonStyle alphas match the calculator-locked family (title 0.5, body 0.35, icon 0.4)"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/widgets/coming_soon_test.dart#ComingSoonStyle"
        status: pass
    human_judgment: false
  - id: D4
    description: "ResourceTopic.isComingSoon / CatalogBook.isComingSoon return the expected values for named catalog entries"
    verification:
      - kind: unit
        ref: "enchiridion/test/models/content_availability_test.dart#isComingSoon"
        status: pass
    human_judgment: false
  - id: D5
    description: "OSCE list shows a badge on content-less stations and none on Abdominal Examination; tapping a grayed station still opens the tabbed detail view"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#coming-soon stations show a badge and available stations do not"
        status: pass
      - kind: automated_ui
        ref: "enchiridion/test/screens/osce_screen_test.dart#tapping a grayed coming-soon station still opens the tabbed detail view"
        status: pass
    human_judgment: false
  - id: D6
    description: "Resource topic cards: available card has no badge/ColorFiltered, unavailable card has both; tapping unavailable shows a SnackBar instead of pushing the error-prone detail screen"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/resource_topic_list_screen_test.dart"
        status: pass
    human_judgment: false
  - id: D7
    description: "Library book shelf shows a ComingSoonBadge on placeholder book pages; all six pre-existing library screen tests (including the AnimatedContainer dot-count trap) still pass"
    verification:
      - kind: automated_ui
        ref: "enchiridion/test/screens/library_screen_test.dart"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-09-18
status: complete
---

# Quick Task 260918-dqy: All coming-soon topics should be grayed out Summary

**Shared `coming_soon.dart` module (label, alphas, badge, desaturation wrapper) wired through OSCE stations, resource-topic cards, and library book pages — unavailable resource topics no longer route to the "Could not load this topic" error screen.**

## Performance

- **Duration:** 22 min
- **Tasks:** 3 (2 produced commits; Task 3 was a verification-only sweep — see below)
- **Files changed:** 11 (3 created, 8 modified)

## Accomplishments

- Created `enchiridion/lib/widgets/common/coming_soon.dart`: `ComingSoonStyle` (the muted title/body/icon alphas lifted verbatim from `calculator_list_screen.dart`'s freemium-locked branch), `ComingSoonBadge` (a plain `Container` pill, never an `AnimatedContainer`), and `ComingSoonDim` (a `ColorFiltered` saturation-zero matrix + `Opacity` wrapper that is a true no-op when not dimmed).
- Added `isComingSoon` getters to `ResourceTopic` and `CatalogBook`, both implemented as `!hasContent` to stay in lock-step with sibling 260918-dqx's `hasContent` predicate.
- Wired all three surfaces named in the plan end to end:
  - `osce_screen.dart`: content-less stations render a grayed avatar/title/subtitle and a compact `ComingSoonBadge` trailing widget in place of the chevron, while staying tappable (the outline checklist behind them is real content).
  - `resource_topic_list_screen.dart`: unavailable cards desaturate their hero image, mute title/description, show a badge, and route taps to a `SnackBar` instead of `ResourceTopicDetailScreen` — closing the path to the "Could not load this topic." error page.
  - `library_screen.dart`: the ad-hoc flat black scrim and lowercase `'Coming soon'` subtitle were replaced with `ComingSoonDim` on the cover art and a shared `ComingSoonBadge`; all `book.hasContent` checks in this file now read `book.isComingSoon`.
- Task 3 swept `lib/` for "coming soon", `hasContent`, `dataAssetPath == null`, and `isComingSoon` and found no additional surface needing the treatment: `pinned_notes_screen.dart`'s `!book.hasContent` check is a defensive tap-guard for stale pinned notes (not a rendered "coming soon" row), `resource_topic_detail_screen.dart`'s error branch and `osce_screen.dart`'s `_OutlinePlaceholder` prose were both explicitly left alone per the plan, and `exam_prep_home_screen.dart` / `question_list_screen.dart` / the drawer widgets have no coming-soon logic at all. `calculator_list_screen.dart` was not touched.
- Full `flutter test` suite (161 tests) and `flutter analyze lib test` are clean of any issue introduced by this plan (see Known Pre-existing Issues below for the 9 unrelated analyzer findings already present before this plan started).

## Task Commits

1. **Task 1: Shared coming-soon module wired end-to-end through the OSCE list** - `6366669` (feat)
2. **Task 2: Apply the shared treatment to resource topic cards and library book pages** - `ee9ce15` (feat)
3. **Task 3: Sweep the remaining list surfaces and prove the rule holds app-wide** - no commit; verification-only (see Deviations)

## Files Created/Modified

- `enchiridion/lib/widgets/common/coming_soon.dart` - New: `ComingSoonStyle`, `ComingSoonBadge`, `ComingSoonDim`, re-exports `kComingSoonLabel`
- `enchiridion/lib/models/resource_topic.dart` - `isComingSoon` getter (`!hasContent`)
- `enchiridion/lib/models/book_catalog.dart` - `isComingSoon` getter (`!hasContent`)
- `enchiridion/lib/screens/osce_screen.dart` - Grayed avatar/title/subtitle + `ComingSoonBadge` trailing for content-less stations
- `enchiridion/lib/screens/resource_topic_list_screen.dart` - `ComingSoonDim` on hero image, muted text, badge, SnackBar tap-guard for unavailable topics
- `enchiridion/lib/screens/library_screen.dart` - `ComingSoonDim` on cover art, `ComingSoonBadge` subtitle, `book.hasContent` → `book.isComingSoon`
- `enchiridion/test/widgets/coming_soon_test.dart` - New: badge/dim/style unit and widget tests
- `enchiridion/test/screens/resource_topic_list_screen_test.dart` - New: available-vs-unavailable card styling and tap-routing tests
- `enchiridion/test/models/content_availability_test.dart` - Extended: `isComingSoon` assertions for both models
- `enchiridion/test/screens/osce_screen_test.dart` - Extended: badge-presence and tap-still-works assertions
- `enchiridion/test/screens/library_screen_test.dart` - Extended: badge-presence assertion on a placeholder book page

## Shared pattern for siblings

Siblings 260918-dqz, 260918-dr0, and 260918-dr3 should consume the following
rather than restyling locally or re-declaring the label:

- **File:** `enchiridion/lib/widgets/common/coming_soon.dart`.
- **`kComingSoonLabel` lives in `enchiridion/lib/utils/content_availability.dart`
  (added by 260918-dqx), NOT in `coming_soon.dart`.** `coming_soon.dart`
  re-exports it (`export '../../utils/content_availability.dart' show
  kComingSoonLabel;`) purely so callers who only import `coming_soon.dart` for
  styling still get the constant. If your file imports BOTH
  `content_availability.dart` (for `availableFirst`/ordering) AND
  `coming_soon.dart` (for styling), you get exactly one `kComingSoonLabel` —
  the re-export makes this safe, not ambiguous. Do not declare a second
  `kComingSoonLabel` anywhere.
- **`ComingSoonStyle`** — `static const double` alphas `titleAlpha` (0.5),
  `bodyAlpha` (0.35), `iconAlpha` (0.4), `imageOpacity` (0.45), plus
  `title(ColorScheme)`, `body(ColorScheme)`, `icon(ColorScheme)`, and
  `container(ColorScheme)` helpers. Use these instead of hardcoding alpha
  literals.
- **`ComingSoonBadge({bool compact = false})`** — the one widget that renders
  the label as a pill. Use `compact: true` inside a dense `ListTile` trailing
  slot; the icon-bearing default elsewhere. Never an `AnimatedContainer`.
- **`ComingSoonDim({required Widget child, required bool dimmed})`** — wrap
  any hero image / cover art in this; it is a true no-op (returns `child`
  unchanged, no extra render objects) when `dimmed` is `false`.
- **`ResourceTopic.isComingSoon`** and **`CatalogBook.isComingSoon`** — both
  `!hasContent`. Branch your row/card styling on these, not on
  `dataAssetPath == null` / `dataFile.isEmpty` directly.
- **`calculator_list_screen.dart` was explicitly left untouched** for
  260918-dqz — its muted rows are a freemium paywall lock (content exists,
  gated behind payment), a different state from "not yet written", so it does
  not consume this module today. If dqz introduces genuinely unavailable
  (not just locked) calculators, that is the moment to wire this module in.

## Decisions Made

- `isComingSoon` on both models is a one-line `!hasContent` alias rather than
  re-deriving availability from `dataAssetPath`/`dataFile` — this keeps a
  single source of truth (`hasContent`, added by 260918-dqx) for "does this
  have real content", with `isComingSoon` existing purely so presentation
  code reads naturally (`if (topic.isComingSoon)` vs `if (!topic.hasContent)`).
- `ComingSoonBadge` is a `Container`, never `AnimatedContainer`, to avoid
  breaking `library_screen_test.dart`'s exact-5 `AnimatedContainer` dot-count
  assertion — flagged as a trap in the plan's `<context>` and confirmed still
  passing after this plan's changes.
- The resource-topic-card tap guard shows a `SnackBar` with
  `'${topic.title} — $kComingSoonLabel'`, mirroring the exact pattern already
  used by `library_screen.dart`'s `_openBook`, so unavailable-content taps
  behave identically everywhere in the app.

## Deviations from Plan

### Auto-fixed / adjusted (documented, non-architectural)

**1. [Instructed deviation] `kComingSoonLabel` re-exported, not redeclared**
- **Found during:** Before Task 1 (per the orchestrator's explicit deviation
  note for this run).
- **Issue:** Sibling 260918-dqx landed on `main` before this task started and
  already declared `kComingSoonLabel` in `lib/utils/content_availability.dart`.
  The plan as written told `coming_soon.dart` to declare its own top-level
  `const String kComingSoonLabel`, which would collide (ambiguous import) the
  moment a screen imports both files.
- **Fix:** `coming_soon.dart` imports `content_availability.dart` and
  re-exports `kComingSoonLabel` from it instead of declaring its own. See
  "Shared pattern for siblings" above.
- **Files modified:** `enchiridion/lib/widgets/common/coming_soon.dart`.
- **Commit:** `6366669`.

**2. [Rule 3 - blocking issue] Worktree was stale relative to `main`**
- **Found during:** Setup, before Task 1.
- **Issue:** This execution's git worktree branch
  (`worktree-agent-ad7c0bbb713e6773d`) was created before sibling 260918-dqx
  (and an unrelated batch, 260917-ndp) merged into `main`. The worktree's
  `enchiridion/lib/` tree therefore had neither `content_availability.dart`,
  `hasContent`, nor `kOsceTopicsInDisplayOrder` — all of which this plan's
  deviation note assumes are already present. Both the plan file and the
  dqx SUMMARY were also untracked/uncommitted on the main checkout and so
  were invisible from the worktree.
- **Fix:** Fast-forward merged `main` into the worktree branch
  (`git merge main --ff-only`; the worktree's history was a strict ancestor
  of `main`, so this was a clean fast-forward, not a rebase or three-way
  merge) to bring in dqx's landed work, then copied the plan file itself
  into the worktree's `.planning/quick/260918-dqy-.../` directory (mirroring
  the precedent dqx's own execution set for this same untracked-`.planning`
  situation).
- **No functional impact:** all subsequent reads/edits proceeded against the
  worktree's actual, now-current `enchiridion/` tree; every file referenced
  in the plan's `<important_deviation_from_plan>` note was verified present
  before editing.

**3. [Rule 2 - missing critical functionality] Model-level `isComingSoon`
   assertions and the badge-presence test needed test-file homes not listed
   in Task 1/2's `<files>`**
- **Found during:** Task 1 and Task 2.
- **Issue:** Task 1's behavior block requires asserting
  `ResourceTopic.isComingSoon` / `CatalogBook.isComingSoon` on named catalog
  entries, and Task 2's behavior block requires asserting "at least one
  `ComingSoonBadge` is present" on the Library tab — but neither task's
  `<files>` list named a model-level test file or an additional
  `library_screen_test.dart` case beyond the existing six.
- **Fix:** Added the model assertions to the existing
  `test/models/content_availability_test.dart` (already imports both models;
  this mirrors 260918-dqx's own precedent of extending that same file for an
  unlisted-but-required assertion), and added one new `testWidgets` case to
  `test/screens/library_screen_test.dart` (a file that WAS already listed for
  Task 2) that flings the Library tab's `PageView` to a placeholder book page
  and asserts `find.byType(ComingSoonBadge)` finds one.
- **Files modified:** `enchiridion/test/models/content_availability_test.dart`,
  `enchiridion/test/screens/library_screen_test.dart`.
- **Commits:** `6366669` (model assertions), `ee9ce15` (library badge test).

### Task 3: no additional commit

Task 3's action was a sweep-and-verify task. The sweep found no additional
list surface needing the coming-soon treatment (see Accomplishments above for
the full review), and the module dartdoc's "consumers" note (naming all three
wired screens and the calculator carve-out) was already written as part of
Task 1's `coming_soon.dart` creation, satisfying Task 3's dartdoc requirement
without further edits. `git status --short` after Task 2's commit showed no
source changes pending, so there is nothing to commit for Task 3 — only the
verification commands (`flutter analyze lib test`, full `flutter test`, and
the plan's exact grep check) were run, all passing.

## Known Pre-existing Issues (out of scope, not fixed)

`flutter analyze lib test` reports 9 issues, none in any file this plan
created or modified:

- `lib/screens/exam_prep_home_screen.dart:397` — unused `key` parameter
- `lib/screens/login_screen.dart:135`, `lib/screens/profile_screen.dart:51`,
  `lib/screens/register_screen.dart:202`,
  `lib/widgets/drawer/toc_drawer.dart:124` — missing curly braces on
  single-statement `if` bodies
- `lib/services/exam_prep_repository.dart:32,35` — unnecessary casts
- `test/screens/reader_notes_test.dart:16`,
  `test/screens/reader_screen_test.dart:32` — missing `const` on constructor
  invocations

All were last touched by an earlier, unrelated plan (`260917-ndt`, per
`git log`) and are out of scope per the executor's scope-boundary rule
(auto-fix only issues directly caused by the current task's changes). Not
added to a `deferred-items.md` file since this is a quick task rather than a
phase; recorded here instead so a future cleanup pass can find them.

## Threat Flags

None. No new trust boundary, network call, storage write, or dependency was
introduced — this plan is presentation-only, consistent with its
`<threat_model>` (`T-dqy-01` accept, `T-dqy-02` accept).

## Issues Encountered

See Deviation #2 above (stale worktree, resolved by fast-forward merge).

## Next Phase Readiness

- Siblings 260918-dqz, 260918-dr0, and 260918-dr3 can import
  `ComingSoonStyle`, `ComingSoonBadge`, `ComingSoonDim`, and
  `kComingSoonLabel` (via `coming_soon.dart`'s re-export) directly, and use
  `isComingSoon` on `ResourceTopic`/`CatalogBook` as their presentation
  predicate.
- `calculator_list_screen.dart` remains untouched and ready for
  260918-dqz to introduce genuinely unavailable calculators.
- No blockers.

---
*Quick task: 260918-dqy*
*Completed: 2026-09-18*

## Self-Check: PASSED

All 3 created files and 8 modified files confirmed present on disk. Both
task commits (`6366669`, `ee9ce15`) confirmed present in `git log`. Full
`flutter test` (161 tests) and `flutter analyze lib test` (9 pre-existing,
unrelated issues only) both ran clean of any regression from this plan.
