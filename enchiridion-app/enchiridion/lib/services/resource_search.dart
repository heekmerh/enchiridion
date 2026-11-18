import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/resource_topic.dart';

/// One place a search matched: a topic's title, or one subsection of its
/// content.
class ResourceSearchHit {
  final ResourceTopic topic;

  /// Null for a match on the topic's own title.
  final String? subsectionId;
  final String? subsectionTitle;
  final String snippet;

  const ResourceSearchHit({
    required this.topic,
    required this.snippet,
    this.subsectionId,
    this.subsectionTitle,
  });
}

class _IndexedSubsection {
  final String id;
  final String title;

  /// The body, for snippets. Matching also covers the title.
  final String text;
  final String lower;

  _IndexedSubsection(this.id, this.title, this.text)
      : lower = '$title $text'.toLowerCase();
}

/// Searches the content of a fixed list of resource topics, so each section
/// of the app searches only its own topics. Topic JSON is read from the
/// asset bundle the first time it is searched and kept for the session.
class ResourceSearch {
  ResourceSearch._();

  static const int maxHits = 200;
  static const int _snippetRadius = 60;

  /// Asset loader, swappable in tests.
  static Future<String> Function(String path) loadAsset = rootBundle.loadString;

  static final Map<String, List<_IndexedSubsection>> _cache = {};

  static void clearCache() => _cache.clear();

  static List<String> _terms(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static Future<List<ResourceSearchHit>> search(
    List<ResourceTopic> topics,
    String query,
  ) async {
    final terms = _terms(query);
    if (terms.isEmpty) return const [];
    final hits = <ResourceSearchHit>[];
    for (final topic in topics) {
      final title = topic.title.toLowerCase();
      if (terms.every(title.contains)) {
        hits.add(ResourceSearchHit(
          topic: topic,
          snippet: topic.group ?? topic.categoryTitle,
        ));
      }
      final path = topic.dataAssetPath;
      if (path == null) continue;
      final subsections = await _index(path);
      for (final sub in subsections) {
        if (!terms.every(sub.lower.contains)) continue;
        hits.add(ResourceSearchHit(
          topic: topic,
          subsectionId: sub.id,
          subsectionTitle: sub.title,
          snippet: _snippet(sub, terms.first),
        ));
        if (hits.length >= maxHits) return hits;
      }
      if (hits.length >= maxHits) return hits;
    }
    return hits;
  }

  static String _snippet(_IndexedSubsection sub, String term) {
    final at = sub.text.toLowerCase().indexOf(term);
    if (at < 0) {
      return sub.text.length <= 2 * _snippetRadius
          ? sub.text
          : '${sub.text.substring(0, 2 * _snippetRadius)}…';
    }
    final start = (at - _snippetRadius).clamp(0, sub.text.length);
    final end = (at + term.length + _snippetRadius).clamp(0, sub.text.length);
    return '${start > 0 ? '…' : ''}'
        '${sub.text.substring(start, end).trim()}'
        '${end < sub.text.length ? '…' : ''}';
  }

  static Future<List<_IndexedSubsection>> _index(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    final data = json.decode(await loadAsset(path)) as Map<String, dynamic>;
    final result = <_IndexedSubsection>[];
    for (final section in (data['sections'] as List? ?? const [])) {
      for (final sub in ((section as Map)['subsections'] as List? ?? const [])) {
        final map = sub as Map;
        final parts = <String>[];
        _collect(map['content_groups'], parts);
        final title = (map['subsection_title'] as String?) ?? '';
        result.add(_IndexedSubsection(
          map['subsection_id'] as String? ?? '',
          _plain(title),
          _plain(parts.join(' ')),
        ));
      }
    }
    _cache[path] = result;
    return result;
  }

  static const _skipKeys = {'type', 'style', 'assetPath', 'tracks', 'level'};

  static void _collect(Object? node, List<String> out) {
    if (node is String) {
      if (node.trim().isNotEmpty) out.add(node);
    } else if (node is List) {
      for (final item in node) {
        _collect(item, out);
      }
    } else if (node is Map) {
      node.forEach((key, value) {
        final k = key.toString();
        if (_skipKeys.contains(k) || k.endsWith('_id') || k.endsWith('_icon')) {
          return;
        }
        _collect(value, out);
      });
    }
  }

  static String _plain(String text) => text
      .replaceAll('**', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
