import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import '../utils/bottom_inset.dart';
import '../utils/content_availability.dart';
import '../widgets/common/coming_soon.dart';
import 'resource_topic_detail_screen.dart';

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
    // Ordering happens here, inside the shared list screen, not at each call
    // site — so any topics list handed to this screen inherits the
    // available-first rule for free.
    final orderedTopics = availableFirst(topics, (t) => t.hasContent);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: dense
          ? _buildDenseList(context, orderedTopics)
          : _buildCardList(context, orderedTopics),
    );
  }

  Widget _buildDenseList(
    BuildContext context,
    List<ResourceTopic> orderedTopics,
  ) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + bottomViewportInset(context),
      ),
      itemCount: orderedTopics.length,
      itemBuilder: (context, index) {
        final topic = orderedTopics[index];
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
    List<ResourceTopic> orderedTopics,
  ) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        24 + bottomViewportInset(context),
      ),
      itemCount: orderedTopics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final topic = orderedTopics[index];
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: comingSoon
                                      ? ComingSoonStyle.title(cs)
                                      : null,
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
      },
    );
  }
}
