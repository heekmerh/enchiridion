/// App-wide content-availability ordering rule: content a user can actually
/// open ranks above content that is still a placeholder. This file is the
/// single source for that rule — every mixed list in the app (OSCE stations,
/// Surgical/Medical Instrumentation topics, the Library book shelf, and any
/// future catalog) should call [availableFirst] instead of re-implementing
/// its own sort.
library;

/// Partitions [items] into two groups — those for which [isAvailable]
/// returns true, and those for which it returns false — and returns the
/// available group followed by the pending group.
///
/// This is a STABLE partition (not a comparator sort): each group preserves
/// the relative order the items already had in [items]. Use this, not
/// `List.sort`, because Dart's sort is not guaranteed stable and would
/// scramble authored curation order inside each group.
List<T> availableFirst<T>(Iterable<T> items, bool Function(T) isAvailable) {
  final available = <T>[];
  final pending = <T>[];
  for (final item in items) {
    if (isAvailable(item)) {
      available.add(item);
    } else {
      pending.add(item);
    }
  }
  return [...available, ...pending];
}

/// Shared status label for content that has not been written yet. Siblings
/// reuse this single spelling rather than each declaring their own copy.
const String kComingSoonLabel = 'Coming Soon';

/// Group-aware sibling of [availableFirst]: orders [items] so that the group
/// (as keyed by [groupOf]) holding openable content leads, and within every
/// group the openable members lead their pending members — but group
/// membership always stays contiguous. Members of a group are never
/// interleaved with another group's members, even when both groups hold a
/// mix of available and pending content.
///
/// Every step below delegates to [availableFirst], so its stability
/// guarantee — original relative order preserved inside each partition — is
/// inherited rather than re-derived:
///
/// 1. Items are bucketed into blocks keyed by [groupOf], using
///    `putIfAbsent` so block order starts as first-appearance order in
///    [items] (the same idiom `groupByCategory` uses in
///    `calculator_definition.dart`).
/// 2. Each block is passed through [availableFirst] so an openable item
///    leads its own block.
/// 3. The blocks themselves are ordered by [availableFirst] over the block
///    list, keyed on "this block contains at least one available item",
///    then flattened back into a single list.
///
/// An input where every item's group key is identical — including the case
/// where [groupOf] returns null for every item — degenerates to a single
/// block, so the result is identical to calling `availableFirst(items,
/// isAvailable)` directly.
///
/// This creates one tension with the flat [availableFirst] rule: once two
/// different groups each hold partial content, group contiguity means some
/// pending item necessarily precedes an available item from a later group.
/// Group structure wins for a grouped catalog — a pending item stays with
/// its own section rather than jumping ahead of its heading.
List<T> availableFirstByGroup<T>(
  Iterable<T> items, {
  required Object? Function(T) groupOf,
  required bool Function(T) isAvailable,
}) {
  final blocks = <Object?, List<T>>{};
  for (final item in items) {
    blocks.putIfAbsent(groupOf(item), () => []).add(item);
  }
  final orderedBlockEntries = availableFirst<MapEntry<Object?, List<T>>>(
    blocks.entries,
    (entry) => entry.value.any(isAvailable),
  );
  return [
    for (final entry in orderedBlockEntries)
      ...availableFirst(entry.value, isAvailable),
  ];
}
