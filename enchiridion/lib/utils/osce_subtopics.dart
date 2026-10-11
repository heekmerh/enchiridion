/// OSCE-specific sub-topic heading detection, used by `osce_screen.dart` via
/// `subtopicTabsFor`'s `isSectionHeading` parameter. Abdominal Examination's
/// source content is 69 flat subsections whose titles alternate between
/// ALL-CAPS headings (`A. INSPECTION`) and sentence-case continuations
/// (`Light palpation`); [isOsceSubtopicHeading] recovers the real sub-topic
/// boundaries from that alternation instead of surfacing one tab per raw
/// subsection. Kept free of Flutter imports so it is testable as pure string
/// logic.
library;

final RegExp _leadingEnumerator = RegExp(r'^[A-Za-z]\.\s*');
final RegExp _nonLetter = RegExp(r'[^A-Za-z]');

/// Whether [title] should open a new sub-topic group rather than continue
/// the group above it: strips a leading enumerator ("A. ") and all non-letter
/// characters, then checks the survivors are all uppercase (true vacuously
/// when nothing survives, so a purely symbolic title starts its own group).
/// `A. INSPECTION`/`FBC`/`U&E` are headings; `Light palpation` is not.
bool isOsceSubtopicHeading(String title) {
  final withoutEnumerator = title.replaceFirst(_leadingEnumerator, '');
  final letters = withoutEnumerator.replaceAll(_nonLetter, '');
  return letters.isEmpty || letters == letters.toUpperCase();
}
