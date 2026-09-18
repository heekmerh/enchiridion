import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import '../utils/bottom_inset.dart';
import '../utils/content_availability.dart';
import 'resource_topic_detail_screen.dart';

class ResourceTopicListScreen extends StatelessWidget {
  final String title;
  final List<ResourceTopic> topics;

  const ResourceTopicListScreen({
    super.key,
    required this.title,
    required this.topics,
  });

  @override
  Widget build(BuildContext context) {
    // Ordering happens here, inside the shared list screen, not at each call
    // site — so any topics list handed to this screen inherits the
    // available-first rule for free.
    final orderedTopics = availableFirst(topics, (t) => t.hasContent);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
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
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResourceTopicDetailScreen(topic: topic),
              ),
            ),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(
                        topic.heroAssetPath,
                        fit: BoxFit.cover,
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (topic.description != null) ...[
                          const SizedBox(height: 6),
                          Text(topic.description!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
