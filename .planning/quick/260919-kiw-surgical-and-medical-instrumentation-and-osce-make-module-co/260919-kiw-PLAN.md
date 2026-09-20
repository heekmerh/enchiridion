---
quick_id: 260919-kiw
batch_id: 260919-kir
type: execute
autonomous: true
subsystem: ui
tags: [flutter, scrollspy, tabbar, autoscrollcontroller, osce, instrumentation]

depends_on: []
files_modified:
  - enchiridion/lib/widgets/common/subtopic_tabs.dart
  - enchiridion/test/widgets/subtopic_tabs_test.dart
  - enchiridion/test/screens/osce_screen_test.dart

must_haves:
  truths:
    - "Opening a Surgical Instrumentation, Medical Instrumentation or OSCE topic and scrolling down carries the reader from the end of one sub-topic straight into the next without stopping, all the way to the end of the topic, with no tab tap anywhere in between."
    - "As the reader scrolls, the tab strip's selected tab follows along, always naming the sub-topic currently under the top of the content area."
    - "Tapping a tab still works: it scrolls the one content view to that sub-topic instead of swapping the content out."
    - "A sideways fling still moves one sub-topic forward or back, so the swipe affordance shipped by 260918-dr2 survives."
    - "A topic with no written content still shows one tab per outline entry, and those coming-soon bodies scroll continuously too."
  artifacts:
    - enchiridion/lib/widgets/common/subtopic_tabs.dart
  key_links:
    - "SubtopicTab.anchorId -> BlockRenderer._itemIndexes (onItemIndexesReady) -> AutoScrollController.scrollToIndex"
    - "AutoScrollController.tagMap -> topmost visible tag index -> TabController.animateTo (scrollspy)"
    - "ResourceTopicDetailScreen + _OsceDetailScreen -> the one shared SubtopicTabsView (no call-site change needed)"
---

<objective>
Make module content scroll continuously through every sub-topic of a topic, with the tab strip
demoted from a pager to a scrollspy indicator.

Purpose: today `SubtopicTabsView` renders a `TabBarView`, so each sub-topic is a separate page
with its own scroll view. Reaching the bottom of one sub-topic is a hard stop — the reader must
go back up and tap the next tab to keep reading. That is exactly the "abrupt halt" in the report.
This widget is the single mechanism behind all three affected surfaces (Surgical Instrumentation,
Medical Instrumentation, OSCE), so one fix covers all of them.

Output: one continuous scroll view per topic, a tab strip that tracks the scroll position, tab
taps that scroll rather than page, and the sideways-fling affordance preserved.
</objective>

<sibling_ordering>
`depends_on: []`. No other item in batch `260919-kir` touches this widget or its tests:
`260919-kis/kit/kiu/kiv` are exam-prep flow items, `260919-kix` re-extracts an instrumentation
DOCX into JSON (content, not rendering), `260919-kiy` changes the Medical Instrumentation *list*
screen (`lib/screens/resource_topic_list_screen.dart`), and `260919-kiz` changes library tile
dimming. This plan touches no list screen, no model, and no content JSON.

`260919-kiy` makes Medical Instrumentation reach `ResourceTopicDetailScreen` the same way Surgical
already does. That is a routing change; because this plan fixes the shared widget that detail
screen already renders, kiy inherits the fix with no coordination and in either merge order.
</sibling_ordering>

<context>
@.planning/STATE.md
@CLAUDE.md
@enchiridion/lib/widgets/common/subtopic_tabs.dart
@enchiridion/lib/screens/resource_topic_detail_screen.dart
@enchiridion/lib/screens/osce_screen.dart
@enchiridion/lib/widgets/reader/reader_content.dart
@enchiridion/lib/widgets/blocks/block_renderer.dart
@enchiridion/lib/screens/reader_screen.dart
@enchiridion/test/widgets/subtopic_tabs_test.dart
@enchiridion/test/screens/osce_screen_test.dart
@.planning/quick/260918-dr5-the-topics-are-implemented-nicely-but-the-tab-scroll-feature/260918-dr5-SUMMARY.md

**Codebase facts established during planning — these were read, not assumed. Do not re-derive.**

- The Flutter app is the nested `enchiridion/` directory. Every `flutter` command runs from there.
- **One widget, three surfaces.** `lib/widgets/common/subtopic_tabs.dart` is the only tabbed-content
  mechanism. `lib/screens/resource_topic_detail_screen.dart` renders it for BOTH Surgical and
  Medical Instrumentation (`library_screen.dart` pushes `ResourceTopicListScreen` for each, which
  pushes `ResourceTopicDetailScreen`, which builds `SubtopicTabsView`). `lib/screens/osce_screen.dart`
  renders the same widget for OSCE stations, passing `isSectionHeading: isOsceSubtopicHeading`.
  There is no duplicated copy to fix — the shared-widget extraction the constraints allow for is
  already done, by sibling `260918-dr2`.
- **The halt is `TabBarView`.** `_SubtopicTabsViewState.build` returns a `Column` of `TabBar` +
  `Expanded(TabBarView(...))`, and each `_SubtopicBody` is its own `ListView`. Each page therefore
  owns a private scroll position that ends at that sub-topic's last block. That is the bug.
- **The project already solved this exact problem once, in the book reader.** `lib/screens/reader_screen.dart`
  renders a whole chapter as ONE `CustomScrollView` driven by an `AutoScrollController` (the
  `scroll_to_index: ^3.0.1` package, already a direct dependency in `pubspec.yaml`), and:
  - `_navigateToSection` (reader_screen.dart:215) scrolls to a section — `Scrollable.ensureVisible`
    on a `GlobalKey` when the target is already built, falling back to
    `_scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.begin)`.
  - `_updateActiveSection` (reader_screen.dart:131) IS a scrollspy: it walks
    `_scrollController.tagMap`, finds the tag straddling an activation line (or the nearest one
    below it), and maps that tag index back to the enclosing section. Copy this algorithm; see the
    activation-line caveat below.
- **`ReaderContent` already exposes everything needed.** With `asSliver: true` plus an
  `autoScrollController`, `BlockRenderer` emits a lazy `SliverList` whose every child is wrapped in
  an `AutoScrollTag` indexed `0..n-1` (block_renderer.dart:263-278), and `onItemIndexesReady` hands
  back a `Map<String,int>` of section id AND subsection id to that same flat index
  (block_renderer.dart:90-110). `onKeysReady` hands back `sectionKeys` / `subsectionKeys`
  `GlobalKey` maps. Laziness is preserved — `scrollToIndex` is built for unbuilt targets.
- **Do NOT render the per-tab slices back to back.** `BlockRenderer` emits a `_SectionHeader` for
  every section of whatever chapter it is given (block_renderer.dart:213). Every slice produced by
  `subtopicTabsFor` carries a copy of the source section, so concatenating Abdominal Examination's
  33 slices into one scroll view would repeat the same section header 33 times. The content-backed
  path must render the ORIGINAL, unsliced chapter exactly once and use the slices only to derive
  tab labels and scroll anchors.
- **`subtopicTabsFor` must not change.** `test/widgets/subtopic_tabs_test.dart` has 8 pure unit
  tests pinning its output (titles, slice identity via `same(...)`, id preservation, blank-title
  guarding), and `test/utils/osce_subtopics_test.dart` pins its heading-grouping branch against the
  real shipped `abdominal_examination.json`. All of those must still pass untouched. The slices it
  builds stay built even though the content-backed render path no longer draws them — do not
  "optimize" that construction away.
- **Activation-line caveat.** reader_screen's `_updateActiveSection` hard-codes a screen-relative
  `dy` of `100`. That works there because the reader content starts near the top of the screen. It
  is WRONG here: `ResourceTopicDetailScreen` stacks a 16:9 hero `Image.asset`, a category label and
  the tab strip above the scroll view, so a fixed `100` sits well above the viewport and would
  always resolve to the wrong sub-topic. Derive the line from the scroll view's own `RenderBox`
  global top instead.
- **`onItemIndexesReady` / `onKeysReady` fire during a descendant's `initState`/`didUpdateWidget`.**
  reader_screen assigns into plain fields with no `setState` (reader_screen.dart:174-176). Calling
  `setState` from those callbacks throws. Assign, then resolve anchors lazily at tap/scroll time.
- **`TabBar.controller!.index` is readable in tests here** because this widget owns an explicit
  `TabController` and passes it to `TabBar` (the null-controller trap in `260918-dr5`'s notes
  applies only to an ancestor `DefaultTabController`, which this widget does not use). Existing
  tests already assert this way; keep that style.
- **Two existing tests drag a `TabBarView` and will not survive** — `test/widgets/subtopic_tabs_test.dart`
  ("...swipeable by drag", ~line 154) and `test/screens/osce_screen_test.dart` ("dragging the content
  area sideways advances the tab controller by one...", ~line 117). They encode sibling `260918-dr2`'s
  swipe requirement, which this plan keeps as a real behaviour; re-point them at the new gesture
  rather than deleting them.
- `flutter analyze lib test` reports pre-existing findings in unrelated files
  (`exam_prep_home_screen.dart`, `login_screen.dart`, `profile_screen.dart`, `register_screen.dart`,
  `toc_drawer.dart`, `exam_prep_repository.dart`, `reader_notes_test.dart`, `reader_screen_test.dart`).
  None are in this plan's files, so the analyze gate below is scoped to this plan's files and must
  come back clean.
</context>

<tasks>

<task type="tracer" tdd="true">
  <name>Task 1: One continuous scroll view with a scrollspy tab strip, proven end-to-end on a content-backed topic</name>
  <files>enchiridion/lib/widgets/common/subtopic_tabs.dart, enchiridion/test/widgets/subtopic_tabs_test.dart</files>
  <reversibility rating="reversible">Swapping the pager for one scroll view is contained in a single widget whose public constructor signature is unchanged, so both call sites are untouched and a revert is a one-file revert.</reversibility>
  <behavior>
    Write these as failing widget tests first, in the existing `test/widgets/subtopic_tabs_test.dart`,
    alongside (not replacing) the 8 pure `subtopicTabsFor` unit tests, which must stay green untouched.
    Build the fixture chapter with one section holding four subsections, each carrying enough
    paragraph blocks that the assembled document is several times taller than the test viewport —
    otherwise "scrolling past a boundary" is unobservable.

    - Test 1 (no pager): rendering a content-backed topic produces exactly one `Scrollable` in the
      content area, and the per-tab paging widget is absent from the tree entirely.
    - Test 2 (continuity, the bug itself): without ever tapping a tab, repeatedly scrolling the
      content view downwards eventually brings the FOURTH sub-topic's heading text into view. This
      is the regression that fails on today's code, where scrolling stops inside sub-topic one.
    - Test 3 (chapter rendered once): the source section's title appears exactly once in the
      rendered tree — proof the original chapter is drawn once rather than one slice per tab.
    - Test 4 (scrollspy): after scrolling far enough that the third sub-topic's heading is at the
      top of the content area, the `TabBar`'s controller index is 2, with no tab ever tapped.
    - Test 5 (tab tap scrolls): tapping the fourth tab settles with that sub-topic's heading visible
      and the controller index at 3, and the first sub-topic's opening text is no longer on screen.
    - Test 6 (async chapter arrival): rebuilding the widget with the chapter changing from null to
      non-null swaps a one-tab outline view for the four-tab content view without a controller
      length assertion failure, and the scrollspy then works on the new content.
  </behavior>
  <action>
    Rewrite `_SubtopicTabsViewState` so the content area is a single `CustomScrollView` owned by one
    `AutoScrollController` (`package:scroll_to_index/scroll_to_index.dart`, already a direct
    dependency), with the tab strip above it in the existing `Column`. Keep the widget's constructor
    signature exactly as it is — `topic`, `chapter`, `initialIndex`, `isSectionHeading` — so neither
    `resource_topic_detail_screen.dart` nor `osce_screen.dart` needs editing.

    Leave `subtopicTabsFor` and `SubtopicTab` alone except for ONE additive member: a getter that
    resolves a tab's scroll anchor id from the slice it already carries — the first subsection id of
    the slice's single section, falling back to that section's id, and null when the tab has no
    content. That getter covers all three content branches (multi-section, one-section-many-subsections,
    whole-chapter) with no new fields and no change to the derivation, so the 8 existing unit tests
    and `test/utils/osce_subtopics_test.dart` stay valid.

    For the content-backed path, the scroll view's slivers are: the topic blurb once at the top when
    `topic.description` is non-null (it used to be pinned to the first tab), then
    `ReaderContent(chapter: <the original unsliced chapter>, bookId: '', asSliver: true,
    autoScrollController: <the controller>, onItemIndexesReady: ..., onKeysReady: ...)`, then a
    bottom `SliverPadding` carrying `bottomViewportInset(context)` once for the whole view rather
    than once per body. Pass the ORIGINAL chapter, never a slice — the section-header duplication
    reason is in the context block, and it belongs in a dartdoc line here too.

    Store the `onItemIndexesReady` map and the `onKeysReady` maps into plain fields with no
    `setState` (those callbacks fire during a descendant's init, mirroring reader_screen.dart:174).
    Resolve each tab's anchor index lazily, at tap or scroll time, by looking its anchor id up in
    that map; treat a miss as "not resolvable yet" and no-op rather than throwing.

    Tab taps: give `TabBar` an `onTap` that scrolls the single view to that tab's anchor — prefer
    `Scrollable.ensureVisible` on the subsection `GlobalKey` when it is currently built, and fall
    back to `scrollToIndex(anchorIndex, preferPosition: AutoScrollPosition.begin)` when it is not.
    That is the same two-step `_navigateToSection` uses at reader_screen.dart:215.

    Scrollspy: add a listener to the controller that walks `tagMap`, picks the tag whose render box
    straddles the activation line or else the nearest one below it, then selects the last tab whose
    resolved anchor index is at or before that tag index, defaulting to the first tab. Drive the
    strip with `TabController.animateTo`; because the strip is scrollable it reveals the selected
    tab on its own. Derive the activation line from the scroll view's own `RenderBox` global top
    plus a small inset — read the caveat in the context block and record the reason in a comment,
    because copying reader_screen's fixed screen-relative number silently misbehaves behind the
    instrumentation hero image.

    Guard the feedback loop: a tab tap must not have its own programmatic scroll re-enter the
    listener and fight the selection. Hold a flag for the duration of the tap-initiated scroll
    future plus one post-frame settle, and have the listener return early while it is held.

    Convert `_SubtopicBody` and `_ComingSoonSubtopicBody` from `ListView`s to non-scrolling column
    content — they are now items inside one outer scroll view, and a nested scrollable would
    reintroduce a boundary. Drop their per-body `PageStorageKey`s and per-body bottom insets.

    Keep the existing "one sub-topic means no tab strip" early return; it should now render that
    single body inside the same one scroll view.

    Do not leave the removed pager widget's identifier in any comment in this file — describe it as
    the former per-tab pager instead. Task 3 greps non-comment lines for it, and a stale mention
    would make that gate ambiguous.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/widgets/subtopic_tabs_test.dart test/utils/osce_subtopics_test.dart</automated>
  </verify>
  <done>A content-backed topic renders one scroll view whose content runs from the first sub-topic to
  the last without interruption; the tab strip's selection follows the scroll; tapping a tab scrolls
  to that sub-topic; the source section header is rendered once; and every pre-existing
  `subtopicTabsFor` unit test still passes unmodified.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Continuous outline-only topics, and the sideways fling re-pointed at the new scroll</name>
  <files>enchiridion/lib/widgets/common/subtopic_tabs.dart, enchiridion/test/widgets/subtopic_tabs_test.dart, enchiridion/test/screens/osce_screen_test.dart</files>
  <behavior>
    - Test 1 (outline continuity): a topic with no chapter and a four-entry outline renders one
      scroll view; scrolling down without tapping any tab brings the fourth entry's coming-soon body
      into view.
    - Test 2 (outline scrollspy): scrolling until the third entry's body is at the top of the content
      area moves the `TabBar` controller index to 2 with no tab tapped.
    - Test 3 (fling forward): flinging the content area leftwards advances the controller index by
      one AND settles with the next sub-topic's heading in view — the index moving alone is not
      enough, since the point of this item is that the content follows.
    - Test 4 (fling back): flinging rightwards returns to the previous sub-topic, index and content
      together.
    - Test 5 (vertical scrolling survives the gesture): a vertical drag still scrolls the content and
      leaves the fling handler inert — the horizontal recognizer must not swallow vertical drags.
    - Test 6 (`test/screens/osce_screen_test.dart`, real screen): opening the content-less
      Cardiovascular station still shows its outline as tabs, and scrolling the station's content
      reaches the last outline entry without a tab tap. The station-list case, the coming-soon badge
      case, and the Abdominal Examination heading-grouping case in that file must keep passing
      unchanged.
  </behavior>
  <action>
    Extend the same `_SubtopicTabsViewState` to the no-content path. When `subtopicTabsFor` returns
    tabs with null content, build the one `CustomScrollView` from a lazy `SliverList` of one
    coming-soon body per tab, each wrapped in an `AutoScrollTag` on the same controller with index
    `i` and a distinct key. That makes the anchor index for tab `i` simply `i`, so the tap-to-scroll
    and scrollspy code written in Task 1 serves both paths with no branching beyond how the anchor
    index is resolved. Do not add your own tags on the content-backed path — `BlockRenderer` already
    owns indices `0..n-1` on that controller there, and a second tagger would collide.

    Restore sibling `260918-dr2`'s sideways swipe on top of the new scroll: wrap the content area in
    a `GestureDetector` handling `onHorizontalDragEnd`, and on a fling past a sensible velocity
    threshold move one sub-topic forward or back through the exact same scroll path a tab tap uses,
    clamped at both ends. A horizontal recognizer does not contend with a vertical scrollable's drag
    arena, so vertical reading is unaffected — Test 5 pins that. The old warning comment against
    wrapping the content in a gesture detector was written about the former per-tab pager, whose own
    recognizer was horizontal; that hazard left with it. Replace that comment rather than leaving it
    contradicting the code.

    Then update the two drag-based tests named in the context block. Both encode dr2's swipe as a
    real requirement, so re-point them at the fling behaviour on the scroll view instead of deleting
    them, and assert content position as well as controller index.

    Handle the async chapter swap: when `didUpdateWidget` sees a new chapter, clear the stored item
    index and key maps along with rebuilding the tab controller, so a stale index from the previous
    chapter can never be used as an anchor.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter test test/widgets/subtopic_tabs_test.dart test/screens/osce_screen_test.dart</automated>
  </verify>
  <done>Outline-only topics scroll continuously through every entry with the tab strip tracking
  along; a sideways fling moves one sub-topic and takes the content with it; vertical scrolling is
  unaffected; and the OSCE screen's station-list, badge and heading-grouping cases still pass.</done>
</task>

<task type="auto">
  <name>Task 3: Regression sweep across all three affected surfaces</name>
  <files>enchiridion/lib/widgets/common/subtopic_tabs.dart, enchiridion/test/widgets/subtopic_tabs_test.dart, enchiridion/test/screens/osce_screen_test.dart</files>
  <action>
    Run the scoped analyzer over this plan's three files and then the full suite. The suite includes
    `test/utils/osce_subtopics_test.dart` (the real-asset Abdominal grouping, owned by `260918-dr5`),
    `test/guards/available_before_coming_soon_guard_test.dart` and the resource-topic list screen
    tests — none of which this plan's widget change should disturb, since no list screen, model or
    content JSON was touched.

    Confirm the shared widget is the only mechanism and that it now drives one scroll view: check
    that it references `AutoScrollController`, and that the removed per-tab pager no longer appears
    as a constructor call on any non-comment line.

    Then confirm the fix actually reaches all three surfaces named in the report by checking that
    `lib/screens/resource_topic_detail_screen.dart` (Surgical and Medical Instrumentation) and
    `lib/screens/osce_screen.dart` (OSCE) both still build `SubtopicTabsView` and that neither
    acquired a tab strip of its own.

    Fix only what this plan's own changes broke. The pre-existing analyzer findings listed in the
    context block belong to other files and stay out of scope; if the full suite surfaces a failure
    in a file this plan never touched, record it in the summary rather than fixing it.
  </action>
  <verify>
    <automated>cd enchiridion &amp;&amp; flutter analyze lib/widgets/common/subtopic_tabs.dart test/widgets/subtopic_tabs_test.dart test/screens/osce_screen_test.dart &amp;&amp; flutter test &amp;&amp; grep -q 'AutoScrollController' lib/widgets/common/subtopic_tabs.dart &amp;&amp; grep -q 'SubtopicTabsView' lib/screens/resource_topic_detail_screen.dart &amp;&amp; grep -q 'SubtopicTabsView' lib/screens/osce_screen.dart &amp;&amp; ! grep -v '^[[:space:]]*//' lib/widgets/common/subtopic_tabs.dart | grep -q 'TabBarView('</automated>
  </verify>
  <done>The scoped analyze is clean, the full suite passes including the sibling-owned Abdominal
  grouping and ordering guards, the shared widget provably drives a single auto-scroll-controlled
  view with no per-tab pager left in it, and all three reported surfaces still route through that
  one widget.</done>
</task>

</tasks>

<verification>
- `cd enchiridion && flutter test` passes in full, including `test/utils/osce_subtopics_test.dart`
  and `test/guards/available_before_coming_soon_guard_test.dart`, neither of which this plan touches.
- `cd enchiridion && flutter analyze lib/widgets/common/subtopic_tabs.dart test/widgets/subtopic_tabs_test.dart test/screens/osce_screen_test.dart` reports no issues.
- The reported halt is gone on both content shapes: a content-backed topic (Abdominal Examination,
  Sutures, IV Cannula) and an outline-only topic each scroll from their first sub-topic to their last
  without a single tab tap.
- `subtopicTabsFor`'s derivation output is unchanged — the 8 pure unit tests pinning it pass
  unmodified, so sibling `260918-dr5`'s heading grouping is preserved exactly.
- No model, list screen or content JSON is touched, so siblings `260919-kix`, `260919-kiy` and
  `260919-kiz` merge without a conflict from this item.
</verification>

<success_criteria>
Module content in Surgical Instrumentation, Medical Instrumentation and OSCE scrolls continuously
across every sub-topic, the tab strip auto-advances to name whichever sub-topic is currently in
view, tapping a tab scrolls the reader there instead of swapping pages, the sideways-fling
affordance still jumps one sub-topic, and the tabs themselves remain as in-page navigation.
</success_criteria>

<output>
Create `.planning/quick/260919-kiw-surgical-and-medical-instrumentation-and-osce-make-module-co/260919-kiw-SUMMARY.md` when done.
</output>