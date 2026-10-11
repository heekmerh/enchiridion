/// App-wide content-availability ordering rule: content a user can actually
/// open ranks above content that is still a placeholder. This file is the
/// single source for that rule — every mixed list in the app (OSCE stations,
/// Surgical/Medical Instrumentation topics, the Library book shelf, and any
/// future catalog) should call [availableFirst] instead of re-implementing
/// its own sort.
library;

/// Stably partitions [items] into those where [isAvailable] is true followed
/// by those where it's false, preserving each group's relative order. Use
/// this rather than `List.sort` — Dart's sort isn't guaranteed stable and
/// would scramble authored curation order inside each group.
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

/// Group-aware sibling of [availableFirst]: buckets [items] by [groupOf]
/// (first-appearance order), orders the openable members ahead of the
/// pending ones within each bucket via [availableFirst], then orders the
/// buckets themselves the same way (a bucket with any available item leads)
/// and flattens — so group membership always stays contiguous even though a
/// pending item in an earlier group can precede an available item in a
/// later one. An input with a single group key (including [groupOf]
/// returning null for everything) degenerates to plain [availableFirst].
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
