// Repo-wide guard: fails the suite if any display-order catalog regresses
// to interleaved order — i.e. a placeholder entry (no real content) ranks
// ahead of an entry with real content.
//
// This gate asserts one invariant only: within an ordered catalog, the last
// entry that HAS content must sit at or before the first entry that does
// NOT have content. A catalog that is entirely available or entirely
// placeholder passes trivially (there is no "first entry without content"
// or no "last entry with content" to compare against).
//
// The guard checks RUNTIME order — the actual `List` each catalog produces
// today — not source text. Add a future catalog to `_catalogs` below as a
// one-line addition; there is nothing else to wire up.

import 'package:enchiridion/models/book_catalog.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/utils/content_availability.dart';
import 'package:flutter_test/flutter_test.dart';

class _Catalog {
  final String name;
  final List<dynamic> orderedEntries;
  final bool Function(dynamic) hasContent;

  const _Catalog(this.name, this.orderedEntries, this.hasContent);
}

class _Violation {
  final String catalogName;
  final int lastWithContentIndex;
  final int firstWithoutContentIndex;

  _Violation(
      this.catalogName, this.lastWithContentIndex, this.firstWithoutContentIndex);

  @override
  String toString() =>
      '$catalogName: entry without content at index $firstWithoutContentIndex '
      'appears before entry with content at index $lastWithContentIndex';
}

List<_Catalog> _catalogs() {
  return [
    _Catalog(
      'kOsceTopicsInDisplayOrder',
      kOsceTopicsInDisplayOrder,
      (e) => (e as ResourceTopic).hasContent,
    ),
    _Catalog(
      'availableFirst(kSurgicalInstrumentationTopics)',
      availableFirst(kSurgicalInstrumentationTopics, (t) => t.hasContent),
      (e) => (e as ResourceTopic).hasContent,
    ),
    _Catalog(
      'availableFirst(kMedicalInstrumentationTopics)',
      availableFirst(kMedicalInstrumentationTopics, (t) => t.hasContent),
      (e) => (e as ResourceTopic).hasContent,
    ),
    _Catalog(
      'booksInDisplayOrder(no history)',
      booksInDisplayOrder(const {}),
      (e) => (e as CatalogBook).hasContent,
    ),
    _Catalog(
      'booksInDisplayOrder(history on a readable book)',
      booksInDisplayOrder(
        {kBooks.firstWhere((b) => b.hasContent).id: DateTime.now()},
      ),
      (e) => (e as CatalogBook).hasContent,
    ),
  ];
}

List<_Violation> _checkCatalogs(List<_Catalog> catalogs) {
  final violations = <_Violation>[];
  for (final catalog in catalogs) {
    final lastWithContent =
        catalog.orderedEntries.lastIndexWhere(catalog.hasContent);
    final firstWithoutContent = catalog.orderedEntries
        .indexWhere((e) => !catalog.hasContent(e));

    // Vacuously true when the catalog is entirely available (no entry
    // without content) or entirely placeholder (no entry with content).
    if (lastWithContent == -1 || firstWithoutContent == -1) continue;

    if (lastWithContent > firstWithoutContent) {
      violations.add(
          _Violation(catalog.name, lastWithContent, firstWithoutContent));
    }
  }
  return violations;
}

void main() {
  test('every display-order catalog ranks content ahead of placeholders', () {
    final violations = _checkCatalogs(_catalogs());

    expect(
      violations,
      isEmpty,
      reason: violations.isEmpty
          ? null
          : 'Available-before-coming-soon ordering violated:\n'
              '${violations.map((v) => v.toString()).join('\n')}',
    );
  });
}
