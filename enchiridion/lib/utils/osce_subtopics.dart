/// OSCE-specific sub-topic heading detection.
///
/// `lib/widgets/common/subtopic_tabs.dart` (built by sibling `260918-dr2`)
/// already owns the single, shared "what are this topic's sub-topics"
/// derivation (`subtopicTabsFor`) that every topic-shaped screen in this app
/// renders through. For a content-backed chapter with exactly one section
/// holding two or more subsections, that shared derivation's default
/// behaviour is one tab per raw subsection.
///
/// Abdominal Examination's source content
/// (`assets/data/resources/abdominal_examination.json`) is authored as 69
/// flat subsections whose titles alternate between ALL-CAPS headings
/// (`A. INSPECTION`, `SPECIAL TESTS (HIGH-YIELD)`, ...) and sentence-case
/// continuations that belong under the heading above them (`Light
/// palpation`, `What is guarding?`, ...). One-tab-per-raw-subsection would
/// surface every continuation as its own tab, which is not "sub-topics
/// inferred from written content" — it is just the unfiltered outline.
///
/// [isOsceSubtopicHeading] is the predicate that recovers the real
/// sub-topic boundaries from that alternation. `osce_screen.dart` passes it
/// into `subtopicTabsFor`'s optional `isSectionHeading` parameter (an
/// additive, backward-compatible extension of the shared derivation — every
/// other caller, including the Sutures / IV Cannula detail screen, omits it
/// and keeps the original one-tab-per-subsection behaviour untouched).
///
/// Kept free of any Flutter import so it is testable as pure string logic.
library;

final RegExp _leadingEnumerator = RegExp(r'^[A-Za-z]\.\s*');
final RegExp _nonLetter = RegExp(r'[^A-Za-z]');

/// Returns true when [title] should open a new sub-topic group rather than
/// continue the group opened by the subsection above it.
///
/// Strips a leading single-letter enumerator ("A. ", "B. ", ...), then
/// discards every remaining non-letter character (digits, punctuation,
/// symbols, emoji, whitespace). Returns true when the surviving letters are
/// all uppercase — including when no letters survive at all, so a purely
/// symbolic title (e.g. an emoji-prefixed label) starts its own group
/// rather than silently folding into whatever came before it.
///
/// `A. INSPECTION`, `SPECIAL TESTS (HIGH-YIELD)`, `FBC` and `U&E` are
/// headings; `Light palpation` and `What is guarding?` are not.
bool isOsceSubtopicHeading(String title) {
  final withoutEnumerator = title.replaceFirst(_leadingEnumerator, '');
  final letters = withoutEnumerator.replaceAll(_nonLetter, '');
  return letters.isEmpty || letters == letters.toUpperCase();
}
