import 'dart:async';

import 'package:flutter/material.dart';

import '../models/resource_topic.dart';
import '../services/access_service.dart';
import '../services/resource_search.dart';
import '../utils/bottom_inset.dart';
import '../widgets/common/coming_soon.dart';
import 'resource_topic_detail_screen.dart';
import 'resource_topic_list_screen.dart';
import 'unlock_screen.dart';

/// The search icon for a section's app bar. It opens [ResourceSearchScreen]
/// over [catalogs], so a section searches only its own topics.
class ResourceSearchButton extends StatelessWidget {
  final String sectionTitle;
  final List<List<ResourceTopic>> catalogs;

  const ResourceSearchButton({
    super.key,
    required this.sectionTitle,
    required this.catalogs,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      tooltip: 'Search $sectionTitle',
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResourceSearchScreen(
          sectionTitle: sectionTitle,
          catalogs: catalogs,
        ),
      )),
    );
  }
}

/// Searches the topics of one section. Each entry of [catalogs] is one topic
/// list as its own screen shows it, so the free topic of each list stays
/// open to a free account, exactly as on that list.
class ResourceSearchScreen extends StatefulWidget {
  final String sectionTitle;
  final List<List<ResourceTopic>> catalogs;

  const ResourceSearchScreen({
    super.key,
    required this.sectionTitle,
    required this.catalogs,
  });

  @override
  State<ResourceSearchScreen> createState() => _ResourceSearchScreenState();
}

class _ResourceSearchScreenState extends State<ResourceSearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  bool _hasAccess = false;
  bool _searching = false;
  List<ResourceSearchHit> _hits = const [];
  String _lastQuery = '';
  late final List<ResourceTopic> _topics;
  late final Set<String> _freeIds;

  @override
  void initState() {
    super.initState();
    _topics = [];
    final free = <String>{};
    for (final catalog in widget.catalogs) {
      final ordered = [
        for (final group in groupTopicsForDisplay(catalog).values) ...group,
      ];
      _topics.addAll(ordered);
      free.addAll(freeTopicIds(ordered));
    }
    _freeIds = free;
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final access = await AccessService.instance.hasFullAccess();
    if (!mounted) return;
    setState(() => _hasAccess = access);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _lastQuery = query;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await ResourceSearch.search(_topics, query);
    if (!mounted || _query.text.trim() != query) return;
    setState(() {
      _hits = hits;
      _lastQuery = query;
      _searching = false;
    });
  }

  bool _isLocked(ResourceTopic topic) =>
      !topic.isComingSoon && !_hasAccess && !_freeIds.contains(topic.id);

  Future<void> _open(ResourceSearchHit hit) async {
    final topic = hit.topic;
    if (topic.isComingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${topic.title} — $kComingSoonLabel'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_isLocked(topic)) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UnlockScreen()),
      );
      if (mounted) await _loadAccess();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResourceTopicDetailScreen(
        topic: topic,
        initialSubsectionId: hit.subsectionId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _run,
          decoration: InputDecoration(
            hintText: 'Search ${widget.sectionTitle}',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () {
                _query.clear();
                _run('');
              },
            ),
        ],
      ),
      body: _searching && _hits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _lastQuery.length < 2
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Search ${widget.sectionTitle} by topic or any word in it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              : _hits.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No results for "$_lastQuery" in ${widget.sectionTitle}.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(
                        top: 8,
                        bottom: 8 + bottomViewportInset(context),
                      ),
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final hit = _hits[index];
                        final locked = _isLocked(hit.topic);
                        final heading = hit.subsectionTitle == null ||
                                hit.subsectionTitle!.isEmpty
                            ? hit.topic.title
                            : '${hit.topic.title} · ${hit.subsectionTitle}';
                        return ListTile(
                          title: Text(
                            heading,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            hit.snippet,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: hit.topic.isComingSoon
                              ? const ComingSoonBadge(compact: true)
                              : locked
                                  ? Icon(Icons.lock_outline,
                                      size: 16, color: cs.onSurfaceVariant)
                                  : null,
                          onTap: () => _open(hit),
                        );
                      },
                    ),
    );
  }
}
