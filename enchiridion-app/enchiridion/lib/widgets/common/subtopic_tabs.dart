/// The single place the app decides what a topic's sub-topics are. New
/// topic-shaped screens should consume [SubtopicTabsView] / [subtopicTabsFor]
/// rather than inventing their own tab strip.
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
  /// Already guarded against being blank — see [subtopicTabsFor].
  final String title;

  /// Null when this sub-topic has no written content yet (the tab then
  /// renders the shared coming-soon placeholder instead).
  final Chapter? content;

  const SubtopicTab({required this.title, this.content});

  /// Key into `BlockRenderer`'s `onItemIndexesReady` map: the first
  /// subsection id of this tab's slice, falling back to the section id, or
  /// null when this tab has no content at all.
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

/// Derives the sub-topic tabs for [topic] given its loaded [chapter] (null
/// before content loads, or when there is no content JSON). Every slice
/// preserves the original section/subsection ids verbatim, since
/// `blockAnchorId` (`lib/widgets/blocks/block_renderer.dart`) keys
/// pinned/margin notes off those ids and inventing new ones would orphan
/// existing anchors. [isSectionHeading] (OSCE detail screen only) overrides
/// the "1 section, 2+ subsections" case to group consecutive subsections by
/// predicate instead of one tab per subsection; see `osce_subtopics.dart`.
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
/// one sub-topic, that single body alone with no tab strip. [chapter]
/// arrives asynchronously (loaded from an asset), so the tab count can
/// change from 1 to N mid-life; this widget recomputes its tabs and rebuilds
/// its [TabController] whenever that happens.
class SubtopicTabsView extends StatefulWidget {
  final ResourceTopic topic;
  final Chapter? chapter;
  final int initialIndex;

  /// Forwarded verbatim to [subtopicTabsFor]'s `isSectionHeading`. Only the
  /// OSCE detail screen supplies this today.
  final bool Function(String title)? isSectionHeading;

  /// Slivers rendered at the top of the one content scroll view, above the
  /// topic body — e.g. a hero banner a detail screen wants to scroll away
  /// while the tab strip (outside the scroll view) stays pinned.
  final List<Widget> headerSlivers;

  const SubtopicTabsView({
    super.key,
    required this.topic,
    this.chapter,
    this.initialIndex = 0,
    this.isSectionHeading,
    this.headerSlivers = const [],
  });

  @override
  State<SubtopicTabsView> createState() => _SubtopicTabsViewState();
}

class _SubtopicTabsViewState extends State<SubtopicTabsView>
    with TickerProviderStateMixin {
  /// Scrollspy activation line, relative to the scroll view's own
  /// [RenderBox] rather than the screen — a caller-stacked tab strip would
  /// throw off a screen-relative number.
  static const double _activationLineInset = 16;

  late List<SubtopicTab> _tabs;
  late TabController _controller;
  late AutoScrollController _autoScrollController;
  final GlobalKey _scrollViewKey = GlobalKey();

  // Assigned directly with no setState: these fire during a descendant's
  // initState/didUpdateWidget, and calling setState there throws.
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
    // A stale index/key from the previous chapter must never be reused as a
    // scroll anchor for the new one.
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

  /// The scroll index tab [tabIndex] scrolls to: the tab's own position for
  /// the outline-only path (see the no-content branch of
  /// [_buildContentSlivers]), or `BlockRenderer`'s `onItemIndexesReady` map
  /// keyed by [SubtopicTab.anchorId] for the content-backed path.
  int? _anchorIndexFor(int tabIndex) {
    final tab = _tabs[tabIndex];
    if (tab.content == null) return tabIndex;
    final anchorId = tab.anchorId;
    if (anchorId == null) return null;
    return _itemIndexes[anchorId];
  }

  // Lazy children have no stable offsets until built, so this walks the
  // visible AutoScrollTag nearest the activation line, then maps that tag
  // index back to the tab whose anchor is at or before it.
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

  // Prefers `Scrollable.ensureVisible` on the subsection/section GlobalKey
  // when already built, falling back to `scrollToIndex` when it is not.
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

  /// The one content scroll view's slivers. Renders the original, unsliced
  /// chapter exactly once — never one slice per tab, which would repeat the
  /// source section header per sub-topic — using `subtopicTabsFor`'s slices
  /// only to derive tab labels and scroll anchors. With no content JSON,
  /// renders one coming-soon body per tab instead; see [_anchorIndexFor].
  List<Widget> _buildContentSlivers(BuildContext context) {
    final chapter = widget.chapter;
    if (chapter != null) {
      return [
        ...widget.headerSlivers,
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
          // Anchors notes under the topic's own scope so the pin controls
          // render (BlockRenderer gates them on `bookId.isNotEmpty`).
          bookId: widget.topic.notesScope,
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
      ...widget.headerSlivers,
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

  // A fling past this velocity moves one sub-topic via the same scroll path
  // a tab tap uses; the horizontal recognizer doesn't contend with vertical
  // scrolling's own drag arena.
  static const double _flingVelocityThreshold = 300;

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _flingVelocityThreshold) return;
    // A leftward (negative) fling moves forward; a rightward fling moves back.
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

/// Placeholder body for a sub-topic with no written content yet, via the
/// shared coming-soon treatment. Non-scrolling: it sits inside the shared
/// outer scroll view, so nesting a scrollable here would reintroduce the
/// boundary this widget exists to remove.
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
