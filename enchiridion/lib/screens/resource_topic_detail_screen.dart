import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
import '../utils/bottom_inset.dart';
import '../widgets/reader/reader_content.dart';

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
  dynamic _chapter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final chapter =
          await ResourceTopicService.loadChapter(widget.topic.dataAssetPath);
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
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: 24 + bottomViewportInset(context),
                  ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.topic.categoryTitle,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.topic.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.topic.description != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              widget.topic.description!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    ReaderContent(
                      chapter: _chapter,
                      bookId: '',
                    ),
                  ],
                ),
    );
  }
}
