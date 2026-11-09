import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/resource_topic.dart';
import '../services/resource_topic_service.dart';
import '../utils/bottom_inset.dart';
import '../utils/osce_subtopics.dart';
import '../widgets/common/coming_soon.dart';
import '../widgets/common/subtopic_tabs.dart';
import 'pinned_notes_screen.dart';

/// Browse stations first; opening a station shows tabs for that station's
/// own sub-topics (see `subtopic_tabs.dart`) — never a strip of other
/// stations.
class OsceScreen extends StatelessWidget {
  /// Test-only chapter loader override, forwarded to [_OsceDetailScreen].
  /// Defaults to [ResourceTopicService.loadChapter] (real `rootBundle`
  /// asset loading) when omitted. Real asset loading hangs indefinitely in
  /// this project's widget-test environment — mirrors
  /// `ExamPrepHomeScreen.testQuestions` / `ReaderScreen.testBookProvider`.
  final Future<Chapter> Function(String assetPath)? testChapterLoader;

  const OsceScreen({super.key, this.testChapterLoader});

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
          final comingSoon = topic.isComingSoon;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: comingSoon
                  ? ComingSoonStyle.container(cs)
                  : cs.primaryContainer,
              child: Icon(
                Icons.medical_services_outlined,
                size: 20,
                color: comingSoon
                    ? ComingSoonStyle.icon(cs)
                    : cs.onPrimaryContainer,
              ),
            ),
            title: Text(
              topic.title,
              style: comingSoon
                  ? TextStyle(color: ComingSoonStyle.title(cs))
                  : null,
            ),
            subtitle: Text(
              topic.description ?? (topic.outline?.join(' • ') ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: comingSoon
                  ? TextStyle(color: ComingSoonStyle.body(cs))
                  : null,
            ),
            // A content-less station still shows a genuinely useful outline
            // as its sub-topic tabs (SubtopicTabsView), so the row stays
            // tappable while grayed — only the trailing affordance changes.
            trailing: comingSoon
                ? const ComingSoonBadge(compact: true)
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _OsceDetailScreen(
                topic: topic,
                chapterLoader: testChapterLoader ?? ResourceTopicService.loadChapter,
              ),
            )),
          );
        },
      ),
    );
  }
}

class _OsceDetailScreen extends StatefulWidget {
  final ResourceTopic topic;
  final Future<Chapter> Function(String assetPath) chapterLoader;
  const _OsceDetailScreen({required this.topic, required this.chapterLoader});

  @override
  State<_OsceDetailScreen> createState() => _OsceDetailScreenState();
}

class _OsceDetailScreenState extends State<_OsceDetailScreen> {
  Chapter? _chapter;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final path = widget.topic.dataAssetPath;
    // Stations with no content JSON simply never resolve `_chapter`; their
    // outline is real structure and `SubtopicTabsView` turns it into one
    // tab per outline entry with the shared coming-soon placeholder.
    if (path == null) return;
    widget.chapterLoader(path).then((chapter) {
      if (!mounted) return;
      setState(() => _chapter = chapter);
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _error = error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.topic.dataAssetPath != null &&
        _error == null &&
        _chapter == null;

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
      body: isLoading          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load this section.\n\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SubtopicTabsView(
                  topic: widget.topic,
                  chapter: _chapter,
                  // Abdominal Examination's 69 subsections alternate
                  // between ALL-CAPS headings and sentence-case
                  // continuations; group by that signal instead of
                  // surfacing one tab per raw subsection. See
                  // `lib/utils/osce_subtopics.dart`.
                  isSectionHeading: isOsceSubtopicHeading,
                ),
    );
  }
}
