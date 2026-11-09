// Repo-wide guard: fails if the Surgical Instrumentation catalog ever
// silently drops an instrument the source markdown lists, or carries an id
// it doesn't. Reads `../scripts/content/surgical instrumentation.md`,
// parses/dedupes/slugifies its bullets the same way the catalog was
// authored, then asserts set equality both ways (with one alias: `Suture
// material` maps to the pre-existing `sutures` id). Skips with a clear
// reason, rather than failing, if the source file is absent.

import 'dart:io';

import 'package:enchiridion/models/resource_topic.dart';
import 'package:flutter_test/flutter_test.dart';

/// Independently derived from the same rule used to author
/// `kSurgicalInstrumentationTopics` in `lib/models/resource_topic.dart`:
/// lowercase, strip straight and typographic apostrophes, collapse each run
/// of non-alphanumeric characters to a single hyphen, trim leading/trailing
/// hyphens. Implemented locally rather than imported so this guard proves
/// the invariant rather than assuming the production code got it right.
String _slugify(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll("'", '').replaceAll('’', '');
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s;
}

/// The one documented alias between the source markdown and the catalog:
/// `Suture material` maps to the pre-existing topic id `sutures`, which was
/// authored before this catalog was expanded to cover every instrument.
const Map<String, String> _aliasSlugToId = {
  'suture-material': 'sutures',
};

List<String> _parseBullets(String contents) {
  final bullets = <String>[];
  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('* ')) continue;
    final text = line.substring(2).trim();
    if (text.isEmpty) continue;
    bullets.add(text);
  }
  return bullets;
}

List<String> _dedupeCaseInsensitive(List<String> items) {
  final seen = <String>{};
  final result = <String>[];
  for (final item in items) {
    final key = item.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    result.add(item);
  }
  return result;
}

void main() {
  test(
      'every instrument in scripts/content/surgical instrumentation.md has a matching catalog row, and vice versa',
      () {
    const sourcePath = '../scripts/content/surgical instrumentation.md';
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      markTestSkipped(
        'Source file not found at $sourcePath relative to the Flutter '
        'package root — skipping in this sparse checkout.',
      );
      return;
    }

    final bullets = _dedupeCaseInsensitive(_parseBullets(
      sourceFile.readAsStringSync(),
    ));

    final expectedIds = bullets
        .map((bullet) {
          final slug = _slugify(bullet);
          return _aliasSlugToId[slug] ?? slug;
        })
        .toSet();

    final actualIds =
        kSurgicalInstrumentationTopics.map((t) => t.id).toSet();

    final missingFromCatalog = expectedIds.difference(actualIds);
    final extraInCatalog = actualIds.difference(expectedIds);

    expect(
      missingFromCatalog,
      isEmpty,
      reason: missingFromCatalog.isEmpty
          ? null
          : 'Source bullet(s) with no matching catalog row (by id): '
              '${missingFromCatalog.join(', ')}',
    );
    expect(
      extraInCatalog,
      isEmpty,
      reason: extraInCatalog.isEmpty
          ? null
          : 'Catalog id(s) with no matching source bullet: '
              '${extraInCatalog.join(', ')}',
    );
  });
}
