// Repo-wide guard: fails the suite by name if the Surgical Instrumentation
// catalog ever silently drops an instrument that the source markdown lists,
// or carries an id the source markdown does not.
//
// This gate reads `../scripts/content/surgical instrumentation.md` relative
// to the Flutter package root (the working directory `flutter test` runs
// with), parses every `* ` bullet, dedupes case-insensitively preserving
// first-seen order, and slugifies each bullet with the exact rule
// `kSurgicalInstrumentationTopics` was authored with. It then asserts set
// equality — in both directions — against the catalog's ids, applying one
// documented alias: the `Suture material` bullet maps to the pre-existing
// id `sutures` (that entry predates the catalog expansion and its title is
// owned by sibling 260918-dr1).
//
// If the source file is absent from the checkout, the test skips with a
// clear reason instead of failing, so the suite stays green in a sparse
// worktree.

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
