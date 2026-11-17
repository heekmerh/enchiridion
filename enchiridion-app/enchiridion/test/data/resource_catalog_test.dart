import 'dart:convert';
import 'dart:io';

import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:flutter_test/flutter_test.dart';

final Map<String, dynamic> _manifest =
    jsonDecode(File('../scripts/osce_manifest.json').readAsStringSync())
        as Map<String, dynamic>;

const Map<String, List<ResourceTopic>> _catalogsByDartName = {
  'kOsceTopics': kOsceTopics,
  'kObstetricsOsceTopics': kObstetricsOsceTopics,
  'kPediatricsOsceTopics': kPediatricsOsceTopics,
  'kMedicalInstrumentationTopics': kMedicalInstrumentationTopics,
  'kSurgicalInstrumentationTopics': kSurgicalInstrumentationTopics,
  'kQuickRevisionTopics': kQuickRevisionTopics,
};

List<ResourceTopic> get _allTopics =>
    [for (final catalog in _catalogsByDartName.values) ...catalog];

Iterable<Map<String, dynamic>> _blocks(Object? node) sync* {
  if (node is Map<String, dynamic>) {
    if (node['type'] is String) yield node;
    for (final value in node.values) {
      yield* _blocks(value);
    }
  } else if (node is List) {
    for (final value in node) {
      yield* _blocks(value);
    }
  }
}

void main() {
  test('every manifest card generates a catalog with the same topics in order',
      () {
    for (final card in (_manifest['cards'] as List).cast<Map>()) {
      final catalog = _catalogsByDartName[card['dart_name']]!;
      expect(
        catalog.map((t) => t.id).toList(),
        [for (final topic in card['topics'] as List) topic['id']],
        reason: '${card['dart_name']} drifted from the manifest',
      );
      for (final topic in catalog) {
        expect(topic.categoryTitle, card['category_title']);
        expect(topic.heroAssetPath, card['hero_asset']);
      }
    }
  });

  test('topic ids are unique across every resource catalog', () {
    final ids = _allTopics.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('quick revision has one topic per part, all with content', () {
    expect(kQuickRevisionTopics, isNotEmpty);
    expect(kQuickRevisionTopics.every((t) => t.hasContent), isTrue);
  });

  test(
      'every content file parses, and every image and sound it references '
      'ships under a declared asset folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final missing = <String>[];
    final undeclared = <String>{};
    for (final topic in _allTopics.where((t) => t.hasContent)) {
      final file = File(topic.dataAssetPath!);
      expect(file.existsSync(), isTrue, reason: topic.dataAssetPath);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      Chapter.fromJson(json);
      for (final block in _blocks(json)) {
        final paths = <String>[
          if (block['type'] == 'image') block['assetPath']?.toString() ?? '',
          if (block['type'] == 'audio')
            ...(block['tracks'] as List).map((t) => t.toString()),
        ];
        for (final path in paths.where((p) => p.isNotEmpty)) {
          if (!File(path).existsSync()) missing.add('${topic.id}: $path');
          final folder = path.substring(0, path.lastIndexOf('/') + 1);
          if (!pubspec.contains('- $folder\n')) undeclared.add(folder);
        }
      }
    }
    expect(missing, isEmpty);
    expect(undeclared, isEmpty);
  });

  test('topicTitleForNotesScope resolves topics from every new catalog', () {
    for (final topic in [
      kObstetricsOsceTopics.first,
      kPediatricsOsceTopics.first,
      kQuickRevisionTopics.first,
    ]) {
      expect(topicTitleForNotesScope(topic.notesScope), topic.title);
    }
  });
}
