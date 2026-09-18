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
