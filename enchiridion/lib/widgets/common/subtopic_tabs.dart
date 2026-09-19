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
///   tab per subsection, labelled with the subsection title. Each slice is
///   the original [Chapter] copied, carrying one [ChapterSection] that
///   reuses the original section's id/title/order/color and holds only that
///   single, unmodified [ChapterSubsection]. This is the branch
///   `abdominal_examination.json` (69 subsections), `sutures.json` (36) and
///   `iv_cannula.json` (28) take.
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
List<SubtopicTab> subtopicTabsFor({
  required ResourceTopic topic,
  Chapter? chapter,
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

  const SubtopicTabsView({
    super.key,
    required this.topic,
    this.chapter,
    this.initialIndex = 0,
  });

  @override
  State<SubtopicTabsView> createState() => _SubtopicTabsViewState();
}

class _SubtopicTabsViewState extends State<SubtopicTabsView>
    with SingleTickerProviderStateMixin {
  late List<SubtopicTab> _tabs;
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _tabs = subtopicTabsFor(topic: widget.topic, chapter: widget.chapter);
    _controller = TabController(
      length: _tabs.length,
      initialIndex: widget.initialIndex.clamp(0, _tabs.length - 1),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant SubtopicTabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.topic, widget.topic) &&
        identical(oldWidget.chapter, widget.chapter)) {
      return;
    }
    final newTabs = subtopicTabsFor(topic: widget.topic, chapter: widget.chapter);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.length <= 1) {
      return _SubtopicBody(topic: widget.topic, tab: _tabs.first, isFirst: true);
    }
    return Column(
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabs: [for (final tab in _tabs) Tab(text: tab.title)],
        ),
        Expanded(
          // Physics intentionally left unset: the default drag behaviour is
          // the sideways swipe between sub-topics this widget exists to
          // provide. Do not wrap this in a gesture detector that would win
          // the horizontal drag arena instead.
          child: TabBarView(
            controller: _controller,
            children: [
              for (var i = 0; i < _tabs.length; i++)
                _SubtopicBody(topic: widget.topic, tab: _tabs[i], isFirst: i == 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtopicBody extends StatelessWidget {
  final ResourceTopic topic;
  final SubtopicTab tab;
  final bool isFirst;

  const _SubtopicBody({
    required this.topic,
    required this.tab,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final content = tab.content;
    if (content == null) {
      return _ComingSoonSubtopicBody(topic: topic, label: tab.title);
    }
    return ListView(
      key: PageStorageKey<String>(tab.title),
      padding: EdgeInsets.only(bottom: 24 + bottomViewportInset(context)),
      children: [
        // The topic blurb is preserved exactly once — on the first tab
        // only — rather than repeated on every sub-topic.
        if (isFirst && topic.description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              topic.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ReaderContent(chapter: content, bookId: ''),
      ],
    );
  }
}

/// Placeholder body for a sub-topic that has no written content yet. Renders
/// through the shared coming-soon treatment (`coming_soon.dart`) rather than
/// restyling locally.
class _ComingSoonSubtopicBody extends StatelessWidget {
  final ResourceTopic topic;
  final String label;

  const _ComingSoonSubtopicBody({required this.topic, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      key: PageStorageKey<String>(label),
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        24 + bottomViewportInset(context),
      ),
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
    );
  }
}
