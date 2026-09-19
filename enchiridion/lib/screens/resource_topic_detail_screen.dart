import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
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
              : Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(
                        widget.topic.heroAssetPath,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
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
                    Expanded(
                      child: SubtopicTabsView(
                        topic: widget.topic,
                        chapter: _chapter,
                      ),
                    ),
                  ],
                ),
    );
  }
}
