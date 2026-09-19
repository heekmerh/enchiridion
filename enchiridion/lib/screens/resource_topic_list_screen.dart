import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import '../utils/bottom_inset.dart';
import '../widgets/common/coming_soon.dart';
import '../widgets/common/section_header.dart';
import 'resource_topic_detail_screen.dart';

/// A single row in the flattened, renderable list: either a section header
/// or a topic. Flattening headers and topics into one list lets both
/// presentations (card and dense) drive a single `ListView.builder` so a
/// large, grouped catalog builds its rows — and hero images — lazily.
sealed class _ListEntry {
  const _ListEntry();
}

class _HeaderEntry extends _ListEntry {
  final String title;
  const _HeaderEntry(this.title);
}

class _TopicEntry extends _ListEntry {
  final ResourceTopic topic;
  const _TopicEntry(this.topic);
}

class ResourceTopicListScreen extends StatelessWidget {
  final String title;
  final List<ResourceTopic> topics;

  /// When true, renders each topic as a single-line `ListTile` (the
  /// OSCE-style dense presentation) instead of the default hero-image card.
  /// Defaults to false so existing call sites (Medical Instrumentation, and
  /// any future caller that doesn't opt in) are unaffected.
  final bool dense;

  const ResourceTopicListScreen({
    super.key,
    required this.title,
    required this.topics,
    this.dense = false,
  });

  void _handleTap(
    BuildContext context,
    ResourceTopic topic,
    bool comingSoon,
  ) {
    if (comingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${topic.title} — $kComingSoonLabel'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResourceTopicDetailScreen(topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Grouping (and, inside it, the available-first ordering rule) happens
    // here, inside the shared list screen, not at each call site — so any
    // topics list handed to this screen inherits both for free. A
    // group-less list (every `ResourceTopic.group` null) collapses to one
    // bucket keyed null, which flattens below with zero header rows —
    // exactly today's rendering for Surgical Instrumentation and OSCE.
    final grouped = groupTopicsForDisplay(topics);
    final items = <_ListEntry>[
      for (final entry in grouped.entries) ...[
        if (entry.key != null) _HeaderEntry(entry.key!),
        for (final topic in entry.value) _TopicEntry(topic),
      ],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: dense
          ? _buildDenseList(context, items)
          : _buildCardList(context, items),
    );
  }

  Widget _buildDenseList(
    BuildContext context,
    List<_ListEntry> items,
  ) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + bottomViewportInset(context),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _HeaderEntry) {
          return SectionHeader(title: item.title);
        }
        final topic = (item as _TopicEntry).topic;
        final comingSoon = topic.isComingSoon;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: comingSoon
                ? ComingSoonStyle.container(cs)
                : cs.primaryContainer,
            child: Icon(
              Icons.medical_services_outlined,
              size: 20,
              color:
                  comingSoon ? ComingSoonStyle.icon(cs) : cs.onPrimaryContainer,
            ),
          ),
          title: Text(
            topic.title,
            style:
                comingSoon ? TextStyle(color: ComingSoonStyle.title(cs)) : null,
          ),
          subtitle: topic.description == null
              ? null
              : Text(
                  topic.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: comingSoon
                      ? TextStyle(color: ComingSoonStyle.body(cs))
                      : null,
                ),
          trailing: comingSoon
              ? const ComingSoonBadge(compact: true)
              : const Icon(Icons.chevron_right),
          onTap: () => _handleTap(context, topic, comingSoon),
        );
      },
    );
  }

  Widget _buildCardList(
    BuildContext context,
    List<_ListEntry> items,
  ) {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 16,
        bottom: 24 + bottomViewportInset(context),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _HeaderEntry) {
          return SectionHeader(title: item.title);
        }
        final topic = (item as _TopicEntry).topic;
        // Headers carry their own vertical padding, so a topic row only
        // needs the shared 14px gap before the *next* topic row — never
        // before a header (the header's own top padding is that gap) and
        // never after the last row (the outer ListView's bottom padding
        // already provides scroll clearance).
        final isLast = index == items.length - 1;
        final nextIsHeader = !isLast && items[index + 1] is _HeaderEntry;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            isLast || nextIsHeader ? 0 : 14,
          ),
          child: _cardTile(context, topic),
        );
      },
    );
  }

  Widget _cardTile(BuildContext context, ResourceTopic topic) {
    final comingSoon = topic.isComingSoon;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _handleTap(context, topic, comingSoon),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cs.surfaceContainerHigh,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ComingSoonDim(
                  dimmed: comingSoon,
                  child: Image.asset(
                    topic.heroAssetPath,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: comingSoon ? ComingSoonStyle.title(cs) : null,
                        ),
                  ),
                  if (topic.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      topic.description!,
                      style: comingSoon
                          ? TextStyle(color: ComingSoonStyle.body(cs))
                          : null,
                    ),
                  ],
                  if (comingSoon) ...[
                    const SizedBox(height: 8),
                    const ComingSoonBadge(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
