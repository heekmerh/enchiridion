import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
import 'pinned_notes_screen.dart';
import '../widgets/common/subtopic_tabs.dart';

class ResourceTopicDetailScreen extends StatefulWidget {
  final ResourceTopic topic;

  const ResourceTopicDetailScreen({
    super.key,
    required this.topic,
  });

  @override
  State<ResourceTopicDetailScreen> createState() =>
      _ResourceTopicDetailScreenState();
}

class _ResourceTopicDetailScreenState extends State<ResourceTopicDetailScreen> {
  bool _loading = true;
  Object? _error;
  Chapter? _chapter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final assetPath = widget.topic.dataAssetPath;
    if (assetPath == null) {
      setState(() {
        _error = StateError('${widget.topic.title} has no content yet.');
        _loading = false;
      });
      return;
    }
    try {
      final chapter = await ResourceTopicService.loadChapter(assetPath);
      if (!mounted) return;
      setState(() {
        _chapter = chapter;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            tooltip: 'Notes for ${widget.topic.title}',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PinnedNotesScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load this topic.\n\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SubtopicTabsView(
                  topic: widget.topic,
                  chapter: _chapter,
                  // The hero banner and category label scroll away with the
                  // content; the tab strip stays pinned above the scroll
                  // view so sub-topic navigation never leaves the screen.
                  headerSlivers: [
                    SliverToBoxAdapter(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          widget.topic.heroAssetPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.topic.categoryTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
