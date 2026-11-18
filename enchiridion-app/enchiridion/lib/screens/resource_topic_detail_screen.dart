import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
import '../services/sound_player.dart';
import 'pinned_notes_screen.dart';
import '../widgets/notes/chapter_notes_sheet.dart';
import '../widgets/common/subtopic_tabs.dart';

class ResourceTopicDetailScreen extends StatefulWidget {
  final ResourceTopic topic;

  /// Opens the topic at the tab holding this subsection, for search results.
  final String? initialSubsectionId;

  const ResourceTopicDetailScreen({
    super.key,
    required this.topic,
    this.initialSubsectionId,
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

  @override
  void dispose() {
    SoundPlayer.instance.stop();
    super.dispose();
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
            icon: const Icon(Icons.edit_note_outlined),
            tooltip: 'Topic notes',
            onPressed: () => showChapterNotesSheet(
              context,
              bookId: widget.topic.notesScope,
              chapterId: widget.topic.id,
              noun: 'topic',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            tooltip: 'Pinned notes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PinnedNotesScreen()),
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
                  initialIndex: initialTabFor(
                    topic: widget.topic,
                    chapter: _chapter,
                    subsectionId: widget.initialSubsectionId,
                  ),
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

/// The tab of [subtopicTabsFor] whose content holds [subsectionId], or 0.
int initialTabFor({
  required ResourceTopic topic,
  required Chapter? chapter,
  required String? subsectionId,
}) {
  if (subsectionId == null || chapter == null) return 0;
  final tabs = subtopicTabsFor(topic: topic, chapter: chapter);
  for (var i = 0; i < tabs.length; i++) {
    final content = tabs[i].content;
    if (content == null) continue;
    for (final section in content.sections) {
      if (section.subsections.any((s) => s.id == subsectionId)) return i;
    }
  }
  return 0;
}
