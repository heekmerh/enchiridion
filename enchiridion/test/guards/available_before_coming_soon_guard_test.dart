// Repo-wide guard: fails if any display-order catalog regresses to
// interleaved order — a placeholder entry ranking ahead of one with real
// content. Asserts the last entry that has content sits at or before the
// first that doesn't (trivially true for an all-available or all-placeholder
// catalog). Checks the actual runtime `List`, not source text. Add a future
// catalog to `_catalogs` below as a one-line addition.

import 'package:enchiridion/models/book_catalog.dart';
import 'package:enchiridion/models/calculator_definition.dart';
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

List<_Catalog> _calculatorCategoryCatalogs() {
  return groupedCalculatorsInDisplayOrder()
      .entries
      .map((entry) => _Catalog(
            'groupedCalculatorsInDisplayOrder()["${entry.key}"]',
            entry.value,
            (e) => (e as CalculatorDefinition).hasContent,
          ))
      .toList();
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
    // Registers the real shipped list — the one the Library call site
    // actually reads — not an ad-hoc recomputation. This catalog is
    // group-ordered (see 260918-dr4): if a second category ever gains
    // written content, the correct response is to move this entry to the
    // group-aware assertions in
    // test/models/medical_instrumentation_display_order_test.dart, not to
    // weaken this guard's flat-list invariant for everyone else.
    _Catalog(
      'kMedicalInstrumentationTopicsInDisplayOrder',
      kMedicalInstrumentationTopicsInDisplayOrder,
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
    // Registered per-category, not as a flattened calculator list —
    // flattening would interleave categories and violate this guard's
    // flat-list invariant by design.
    ..._calculatorCategoryCatalogs(),
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
