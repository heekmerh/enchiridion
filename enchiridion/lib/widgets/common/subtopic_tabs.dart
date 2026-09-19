/// The single place the app decides what a topic's SUB-TOPICS are.
///
/// Opening a topic (an OSCE station, a Surgical/Medical Instrumentation
/// entry, or any future topic-shaped screen) should show tabs for that
/// topic's own sub-topics — never a tab strip of unrelated sibling topics —
/// and the content area should swipe sideways between them. New topic
/// surfaces should consume [SubtopicTabsView] / [subtopicTabsFor] rather
/// than inventing their own tab strip.
library;

import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../models/chapter.dart';
import '../../models/resource_topic.dart';
import '../../utils/bottom_inset.dart';
import '../reader/reader_content.dart';
import 'coming_soon.dart';

/// One tab in a [SubtopicTabsView]: a label and the content slice it
/// renders.
class SubtopicTab {
  /// The tab label. Already guarded against being blank — see
  /// [subtopicTabsFor].
  final String title;

  /// The content slice this tab renders, or null when this sub-topic has
  /// no written content yet (the tab then renders the shared coming-soon
  /// placeholder instead).
  final Chapter? content;

  const SubtopicTab({required this.title, this.content});

  /// The id this tab scrolls to in the one shared content scroll view — a
  /// key into `BlockRenderer`'s `onItemIndexesReady` map (see
  /// `block_renderer.dart`'s `_buildKeys`), which indexes every section and
  /// subsection id of the ORIGINAL, unsliced chapter that the content-backed
  /// path renders.
  ///
  /// Resolved as the first subsection id of this tab's slice's single
  /// section, falling back to that section's id when the section has no
  /// subsections, and null when this tab has no content at all. Covers all
  /// three content branches of [subtopicTabsFor] (multi-section,
  /// one-section-many-subsections, whole-chapter) with no new fields and no
  /// change to that derivation.
  String? get anchorId {
    final sections = content?.sections;
    if (sections == null || sections.isEmpty) return null;
    final section = sections.single;
    if (section.subsections.isNotEmpty) {
      return section.subsections.first.id;
    }
    return section.id;
  }
}

String _guardLabel(String? raw, String fallback) {
  final trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

/// Derives the sub-topic tabs for [topic], given its loaded [chapter] (null
/// while content hasn't loaded yet, or when the topic has no content JSON
/// at all).
///
/// Precedence, most-structured content first. The measured shapes below are
/// from the three bundled topic JSONs (see PLAN context): a chapter with one
/// section holding many subsections is the common case today, but nothing
/// enforces that shape, so a multi-section chapter is handled too.
///
/// - [chapter] non-null with 2+ sections: one tab per section, labelled with
///   the section title. Each slice is the original [Chapter] copied
///   (id/title/icon/description/order/tags/chapterColor unchanged) but
///   carrying only that one, unmodified [ChapterSection].
/// - [chapter] non-null with exactly 1 section holding 2+ subsections: one
///   tab per subsection, labelled with the subsection title, UNLESS
///   [isSectionHeading] is supplied — see below. Each slice is the original
///   [Chapter] copied, carrying one [ChapterSection] that reuses the
///   original section's id/title/order/color and holds only that single,
///   unmodified [ChapterSubsection]. This is the branch `sutures.json` (36
///   subsections) and `iv_cannula.json` (28) take.
/// - [chapter] non-null otherwise (no sections, or one section with 0 or 1
///   subsections): exactly one tab carrying the chapter unchanged, labelled
///   with the chapter title when non-blank, the topic title otherwise.
/// - [chapter] null with a non-empty `topic.outline`: one tab per outline
///   entry, labelled with the entry text, with no content slice.
/// - [chapter] null with no usable outline: exactly one tab labelled with
///   the topic title, with no content slice.
///
/// Every slice preserves the original section/subsection ids verbatim.
/// `blockAnchorId` (`lib/widgets/blocks/block_renderer.dart`) keys
/// pinned/margin notes off those ids, so inventing new ones on split would
/// orphan existing note anchors.
///
/// [isSectionHeading] is an optional, additive override for the "1 section,
/// 2+ subsections" branch only. When supplied, that branch walks the
/// section's subsections in authored order and opens a new group whenever
/// [isSectionHeading] returns true for a subsection's title (and for the
/// very first subsection regardless), appending to the currently open group
/// otherwise; it then emits one tab per group, titled by the group's
/// opening subsection, with a slice carrying every subsection in that
/// group (each original [ChapterSubsection] reused verbatim, so anchors
/// stay stable — see above). When omitted (every caller except the OSCE
/// detail screen), this branch's original one-tab-per-subsection behaviour
/// is unchanged. This exists because a single-section chapter whose
/// subsections alternate between ALL-CAPS headings and sentence-case
/// continuations (`abdominal_examination.json`'s 69 subsections) should
/// surface sub-topics inferred from that structure, not one tab per raw
/// subsection; see `lib/utils/osce_subtopics.dart`.
List<SubtopicTab> subtopicTabsFor({
  required ResourceTopic topic,
  Chapter? chapter,
  bool Function(String title)? isSectionHeading,
}) {
  if (chapter != null) {
    final sections = chapter.sections;

    if (sections.length >= 2) {
      return [
        for (var i = 0; i < sections.length; i++)
          SubtopicTab(
            title: _guardLabel(sections[i].title, 'Part ${i + 1}'),
            content: Chapter(
              id: chapter.id,
              title: chapter.title,
              icon: chapter.icon,
              description: chapter.description,
              order: chapter.order,
              tags: chapter.tags,
              chapterColor: chapter.chapterColor,
              sections: [sections[i]],
            ),
          ),
      ];
    }

    if (sections.length == 1 && sections.first.subsections.length >= 2) {
      final section = sections.first;
      final subsections = section.subsections;

      if (isSectionHeading != null) {
        final groups = <List<ChapterSubsection>>[];
        for (final subsection in subsections) {
          if (groups.isEmpty || isSectionHeading(subsection.title)) {
            groups.add([subsection]);
          } else {
            groups.last.add(subsection);
          }
        }
        return [
          for (var i = 0; i < groups.length; i++)
            SubtopicTab(
              title: _guardLabel(groups[i].first.title, 'Part ${i + 1}'),
              content: Chapter(
                id: chapter.id,
                title: chapter.title,
                icon: chapter.icon,
                description: chapter.description,
                order: chapter.order,
                tags: chapter.tags,
                chapterColor: chapter.chapterColor,
                sections: [
                  ChapterSection(
                    id: section.id,
                    title: section.title,
                    order: section.order,
                    sectionColor: section.sectionColor,
                    subsections: groups[i],
                  ),
                ],
              ),
            ),
        ];
      }

      return [
        for (var i = 0; i < subsections.length; i++)
          SubtopicTab(
            title: _guardLabel(subsections[i].title, 'Part ${i + 1}'),
            content: Chapter(
              id: chapter.id,
              title: chapter.title,
              icon: chapter.icon,
              description: chapter.description,
              order: chapter.order,
              tags: chapter.tags,
              chapterColor: chapter.chapterColor,
              sections: [
                ChapterSection(
                  id: section.id,
                  title: section.title,
                  order: section.order,
                  sectionColor: section.sectionColor,
                  subsections: [subsections[i]],
                ),
              ],
            ),
          ),
      ];
    }

    return [
      SubtopicTab(
        title: _guardLabel(chapter.title, topic.title),
        content: chapter,
      ),
    ];
  }

  final outline = topic.outline;
  if (outline != null && outline.isNotEmpty) {
    return [
      for (var i = 0; i < outline.length; i++)
        SubtopicTab(title: _guardLabel(outline[i], 'Part ${i + 1}')),
    ];
  }

  return [SubtopicTab(title: _guardLabel(topic.title, 'Overview'))];
}

/// Renders [topic]'s sub-topics (per [subtopicTabsFor]) as a swipeable,
/// scrollable tab strip above the matching content — or, when there is only
/// one sub-topic, that single body alone with no tab strip.
///
/// [chapter] arrives asynchronously in every caller today (it is loaded from
/// an asset), so the tab count can change from 1 to N mid-life; this widget
/// recomputes its tabs and rebuilds its [TabController] whenever that
/// happens, always keeping the controller's length in sync with the tab
/// count.
class SubtopicTabsView extends StatefulWidget {
  final ResourceTopic topic;
  final Chapter? chapter;
  final int initialIndex;

  /// Forwarded verbatim to [subtopicTabsFor]'s `isSectionHeading` — see that
  /// parameter's dartdoc. Only the OSCE detail screen supplies this today;
  /// every other caller omits it and keeps the default one-tab-per-raw-
  /// subsection behaviour.
  final bool Function(String title)? isSectionHeading;

  const SubtopicTabsView({
    super.key,
    required this.topic,
    this.chapter,
    this.initialIndex = 0,
    this.isSectionHeading,
  });

  @override
  State<SubtopicTabsView> createState() => _SubtopicTabsViewState();
}

class _SubtopicTabsViewState extends State<SubtopicTabsView>
    with TickerProviderStateMixin {
  /// Distance below the content scroll view's own top edge used as the
  /// scrollspy activation line. Derived from the scroll view's own
  /// [RenderBox] rather than a fixed screen-relative offset (compare
  /// `reader_screen.dart`'s `_updateActiveSection`, which hard-codes a
  /// screen-relative `dy` of 100): `ResourceTopicDetailScreen` stacks a
  /// 16:9 hero image, a category label and this tab strip above the scroll
  /// view, so a fixed screen-relative number would sit above the viewport
  /// and always resolve to the wrong sub-topic.
  static const double _activationLineInset = 16;

  late List<SubtopicTab> _tabs;
  late TabController _controller;
  late AutoScrollController _autoScrollController;
  final GlobalKey _scrollViewKey = GlobalKey();

  // Populated by BlockRenderer's onItemIndexesReady/onKeysReady callbacks,
  // which fire during a descendant's initState/didUpdateWidget — assigned
  // directly with no setState (mirrors reader_screen.dart:174-176; calling
  // setState from those callbacks throws). Anchors are resolved lazily, at
  // tap or scroll time, by looking the tab's anchor id up in these maps.
  Map<String, int> _itemIndexes = {};
  Map<String, GlobalKey> _sectionKeys = {};
  Map<String, GlobalKey> _subsectionKeys = {};

  // Guards the scrollspy listener against fighting a tap-initiated scroll:
  // held for the duration of that scroll's future plus one post-frame
  // settle, during which the listener returns early.
  bool _suppressScrollSpy = false;

  @override
  void initState() {
    super.initState();
    _tabs = subtopicTabsFor(
      topic: widget.topic,
      chapter: widget.chapter,
      isSectionHeading: widget.isSectionHeading,
    );
    _controller = TabController(
      length: _tabs.length,
      initialIndex: widget.initialIndex.clamp(0, _tabs.length - 1),
      vsync: this,
    );
    _autoScrollController = AutoScrollController();
    _autoScrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant SubtopicTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.topic, widget.topic) &&
        identical(oldWidget.chapter, widget.chapter)) {
      return;
    }
    // A stale index/key from the previous chapter must never be used as a
    // scroll anchor for the new one — BlockRenderer calls
    // onItemIndexesReady/onKeysReady again once the new chapter lays out.
    _itemIndexes = {};
    _sectionKeys = {};
    _subsectionKeys = {};
    final newTabs = subtopicTabsFor(
      topic: widget.topic,
      chapter: widget.chapter,
      isSectionHeading: widget.isSectionHeading,
    );
    if (newTabs.length != _tabs.length) {
      final retainedIndex = _controller.index.clamp(0, newTabs.length - 1);
      _controller.dispose();
      _controller = TabController(
        length: newTabs.length,
        initialIndex: retainedIndex,
        vsync: this,
      );
    }
    setState(() => _tabs = newTabs);
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoScrollController.removeListener(_onScroll);
    _autoScrollController.dispose();
    super.dispose();
  }

  void _onItemIndexesReady(Map<String, int> indexes) {
    _itemIndexes = indexes;
  }

  void _onKeysReady(
    Map<String, GlobalKey> sectionKeys,
    Map<String, GlobalKey> subsectionKeys,
  ) {
    _sectionKeys = sectionKeys;
    _subsectionKeys = subsectionKeys;
  }

  double? _viewportTop() {
    final renderObject = _scrollViewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero).dy;
  }

  /// The scroll index tab [tabIndex] scrolls to. For the outline-only path
  /// (no content JSON yet), each tab IS its own `AutoScrollTag` with index
  /// equal to the tab's own position — see the no-content branch of
  /// [_buildContentSlivers]. For the content-backed path, the index comes
  /// from `BlockRenderer`'s `onItemIndexesReady` map, keyed by the tab's
  /// [SubtopicTab.anchorId].
  int? _anchorIndexFor(int tabIndex) {
    final tab = _tabs[tabIndex];
    if (tab.content == null) return tabIndex;
    final anchorId = tab.anchorId;
    if (anchorId == null) return null;
    return _itemIndexes[anchorId];
  }

  // Scrollspy: mirrors reader_screen.dart's `_updateActiveSection` — lazy
  // children have no stable offsets until built, so this walks the visible
  // AutoScrollTag nearest the activation line, then maps that tag index
  // back to the tab whose anchor is at or before it.
  void _onScroll() {
    if (_suppressScrollSpy || _tabs.length <= 1) return;
    if (!_autoScrollController.hasClients ||
        _autoScrollController.tagMap.isEmpty) {
      return;
    }
    final viewportTop = _viewportTop();
    if (viewportTop == null) return;
    final activationLine = viewportTop + _activationLineInset;

    int? activeTagIndex;
    var nearestBelowTop = double.infinity;
    for (final entry in _autoScrollController.tagMap.entries) {
      final renderObject = entry.value.context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      if (top <= activationLine && bottom > activationLine) {
        activeTagIndex = entry.key;
        break;
      }
      if (top > activationLine && top < nearestBelowTop) {
        nearestBelowTop = top;
        activeTagIndex = entry.key;
      }
    }
    if (activeTagIndex == null) return;

    var bestTab = 0;
    var bestAnchor = -1;
    for (var i = 0; i < _tabs.length; i++) {
      final anchorIndex = _anchorIndexFor(i);
      if (anchorIndex != null &&
          anchorIndex <= activeTagIndex &&
          anchorIndex > bestAnchor) {
        bestAnchor = anchorIndex;
        bestTab = i;
      }
    }
    if (bestTab != _controller.index) {
      _controller.animateTo(bestTab);
    }
  }

  // Scrolls the one content view to tab [tabIndex]'s anchor — preferring
  // `Scrollable.ensureVisible` on the subsection/section GlobalKey when
  // already built, falling back to `scrollToIndex` when it is not. Mirrors
  // the two-step `_navigateToSection` in reader_screen.dart.
  Future<void> _scrollToTab(int tabIndex) async {
    _suppressScrollSpy = true;
    try {
      final tab = _tabs[tabIndex];
      final anchorId = tab.anchorId;
      final key = anchorId == null
          ? null
          : (_subsectionKeys[anchorId] ?? _sectionKeys[anchorId]);
      final ctx = key?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.0,
        );
      } else {
        final anchorIndex = _anchorIndexFor(tabIndex);
        if (anchorIndex != null && _autoScrollController.hasClients) {
          await _autoScrollController.scrollToIndex(
            anchorIndex,
            preferPosition: AutoScrollPosition.begin,
          );
        }
      }
    } finally {
      if (mounted) {
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted) {
        _suppressScrollSpy = false;
      }
    }
  }

  /// The one content scroll view's slivers.
  ///
  /// Content-backed: the topic blurb once (it used to be pinned to the
  /// first tab), then the ORIGINAL, unsliced chapter exactly once — NEVER
  /// one slice per tab, which would repeat the source section header once
  /// per sub-topic (`BlockRenderer` emits a section header for every
  /// section of whatever chapter it is given). The slices `subtopicTabsFor`
  /// builds are used only to derive tab labels and scroll anchors.
  ///
  /// No content JSON at all: one coming-soon body per tab, each its own
  /// `AutoScrollTag` on this same controller with index equal to the tab's
  /// own position — see [_anchorIndexFor].
  List<Widget> _buildContentSlivers(BuildContext context) {
    final chapter = widget.chapter;
    if (chapter != null) {
      return [
        if (widget.topic.description != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                widget.topic.description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ReaderContent(
          chapter: chapter,
          bookId: '',
          asSliver: true,
          autoScrollController: _autoScrollController,
          onItemIndexesReady: _onItemIndexesReady,
          onKeysReady: _onKeysReady,
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: 24 + bottomViewportInset(context)),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => AutoScrollTag(
            key: ValueKey('subtopic-outline-$index'),
            controller: _autoScrollController,
            index: index,
            child: _ComingSoonSubtopicBody(
              topic: widget.topic,
              label: _tabs[index].title,
            ),
          ),
          childCount: _tabs.length,
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.only(bottom: 24 + bottomViewportInset(context)),
      ),
    ];
  }

  // Restores sibling 260918-dr2's sideways swipe on top of the one scroll
  // view: a fling past this velocity threshold moves one sub-topic forward
  // or back through the exact same scroll path a tab tap uses (clamped at
  // both ends), rather than paging a separate widget. A horizontal
  // GestureDetector recognizer does not contend with the vertical
  // scrollable's own drag arena, so ordinary vertical reading is
  // unaffected — the old warning against wrapping this content in a
  // gesture detector was about the former per-tab pager, whose own
  // recognizer was horizontal; that hazard left with it.
  static const double _flingVelocityThreshold = 300;

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _flingVelocityThreshold) return;
    // A leftward fling (negative velocity) reveals sub-topics further
    // along, i.e. moves forward; a rightward fling moves back.
    final direction = velocity < 0 ? 1 : -1;
    final target = (_controller.index + direction).clamp(0, _tabs.length - 1);
    if (target == _controller.index) return;
    _controller.animateTo(target);
    _scrollToTab(target);
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.length <= 1) {
      return CustomScrollView(
        key: _scrollViewKey,
        controller: _autoScrollController,
        slivers: _buildContentSlivers(context),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          onTap: _scrollToTab,
          tabs: [for (final tab in _tabs) Tab(text: tab.title)],
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            child: CustomScrollView(
              key: _scrollViewKey,
              controller: _autoScrollController,
              slivers: _buildContentSlivers(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Placeholder body for a sub-topic that has no written content yet. Renders
/// through the shared coming-soon treatment (`coming_soon.dart`) rather than
/// restyling locally. A plain (non-scrolling) column — it is placed as an
/// item inside the shared outer scroll view, so a nested scrollable here
/// would reintroduce the very boundary this widget exists to remove.
class _ComingSoonSubtopicBody extends StatelessWidget {
  final ResourceTopic topic;
  final String label;

  const _ComingSoonSubtopicBody({required this.topic, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ComingSoonBadge(),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$kComingSoonLabel — this part of ${topic.title} has not been '
            'written yet. The rest of this topic is still browsable.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ComingSoonStyle.body(cs),
            ),
          ),
        ],
      ),
    );
  }
}
