import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
import '../utils/bottom_inset.dart';
import '../widgets/reader/reader_content.dart';

/// Browse stations first; tabs appear after opening a station.
class OsceScreen extends StatelessWidget {
  const OsceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('OSCE')),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 8 + bottomViewportInset(context)),
        itemCount: kOsceTopicsInDisplayOrder.length,
        itemBuilder: (context, index) {
          final topic = kOsceTopicsInDisplayOrder[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.medical_services_outlined,
                  size: 20, color: cs.onPrimaryContainer),
            ),
            title: Text(topic.title),
            subtitle: Text(
              topic.description ?? (topic.outline?.join(' • ') ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _OsceDetailScreen(initialIndex: index),
            )),
          );
        },
      ),
    );
  }
}

class _OsceDetailScreen extends StatefulWidget {
  final int initialIndex;
  const _OsceDetailScreen({required this.initialIndex});

  @override
  State<_OsceDetailScreen> createState() => _OsceDetailScreenState();
}

class _OsceDetailScreenState extends State<_OsceDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<String, Chapter> _loadedChapters = {};
  final Map<String, Object> _loadErrors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: kOsceTopicsInDisplayOrder.length,
      initialIndex: widget.initialIndex,
      vsync: this,
    );
    for (final topic in kOsceTopicsInDisplayOrder) {
      final path = topic.dataAssetPath;
      if (path == null) continue;
      ResourceTopicService.loadChapter(path).then((chapter) {
        if (!mounted) return;
        setState(() => _loadedChapters[topic.id] = chapter);
      }).catchError((Object error) {
        if (!mounted) return;
        setState(() => _loadErrors[topic.id] = error);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSCE'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: kOsceTopicsInDisplayOrder
              .map((topic) => Tab(text: topic.title))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
            kOsceTopicsInDisplayOrder.map((topic) => _OsceTabBody(topic: topic,
                chapter: _loadedChapters[topic.id],
                error: _loadErrors[topic.id])).toList(),
      ),
    );
  }
}

class _OsceTabBody extends StatelessWidget {
  final ResourceTopic topic;
  final Chapter? chapter;
  final Object? error;

  const _OsceTabBody({required this.topic, this.chapter, this.error});

  @override
  Widget build(BuildContext context) {
    if (topic.dataAssetPath == null) {
      return _OutlinePlaceholder(topic: topic);
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load this section.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (chapter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: EdgeInsets.only(bottom: 24 + bottomViewportInset(context)),
      children: [
        if (topic.description != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              topic.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ReaderContent(chapter: chapter!, bookId: ''),
      ],
    );
  }
}

/// Shown for a station whose full content hasn't been written yet — the
/// checklist from OSCE.md stands in for it, so the structure is already
/// useful even before the prose lands.
class _OutlinePlaceholder extends StatelessWidget {
  final ResourceTopic topic;

  const _OutlinePlaceholder({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final outline = topic.outline ?? const [];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24 + bottomViewportInset(context),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.construction_outlined, size: 18, color: cs.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Full content for ${topic.title} is coming soon. Here\'s '
                  'what this station covers in the meantime.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...outline.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
