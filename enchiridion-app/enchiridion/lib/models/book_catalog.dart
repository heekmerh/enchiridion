import '../utils/content_availability.dart';

class CatalogBook {
  final String id;
  final String title;
  final String assetPath;
  final String dataFile; // JSON asset path; empty = content coming soon
  final String specialty;

  const CatalogBook({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.dataFile,
    required this.specialty,
  });

  bool get hasContent => dataFile.isNotEmpty;

  /// Whether this book should render with the shared coming-soon
  /// treatment — see `ComingSoonStyle` in `widgets/common/coming_soon.dart`.
  bool get isComingSoon => !hasContent;
}

const List<CatalogBook> kBooks = [
  CatalogBook(
    id: 'paediatrics',
    title: 'Paediatrics',
    assetPath: 'assets/books/Paediatrics.png',
    dataFile: 'assets/data/paediatrics.json',
    specialty: 'Paediatrics',
  ),
  CatalogBook(
    id: 'internal-medicine',
    title: 'Internal Medicine',
    assetPath: 'assets/books/Internal Medicine.jpeg',
    dataFile: '',
    specialty: 'Internal Medicine',
  ),
  CatalogBook(
    id: 'surgery',
    title: 'Surgery',
    assetPath: 'assets/books/Surgery.jpeg',
    dataFile: '',
    specialty: 'Surgery',
  ),
  CatalogBook(
    id: 'obs-gynae',
    title: 'Obstetrics & Gynaecology',
    assetPath: 'assets/books/Obstetrics & Gynaecology.jpeg',
    dataFile: '',
    specialty: 'Obs & Gynae',
  ),
  CatalogBook(
    id: 'psychiatry',
    title: 'Psychiatry',
    assetPath: 'assets/books/Psychiatry.jpeg',
    dataFile: '',
    specialty: 'Psychiatry',
  ),
  CatalogBook(
    id: 'radiology',
    title: 'Radiology',
    assetPath: 'assets/books/Radiology.jpeg',
    dataFile: '',
    specialty: 'Radiology',
  ),
  CatalogBook(
    id: 'orthopedics',
    title: 'Orthopedics',
    assetPath: 'assets/books/Orthopedics.jpeg',
    dataFile: '',
    specialty: 'Orthopedics',
  ),
  CatalogBook(
    id: 'dermatology',
    title: 'Dermatology',
    assetPath: 'assets/books/Dermatology.jpeg',
    dataFile: '',
    specialty: 'Dermatology',
  ),
];

/// Returns [kBooks] most-recently-opened first among books sharing [history],
/// then the rest in authored order, with readable books (see
/// [CatalogBook.hasContent]) always ranked ahead of placeholders regardless
/// of recency. Pure (no Flutter, no provider) so it is unit-testable.
List<CatalogBook> booksInDisplayOrder(Map<String, DateTime> history) {
  final sorted = List<CatalogBook>.from(kBooks);
  sorted.sort((a, b) {
    final aTime = history[a.id];
    final bTime = history[b.id];
    if (aTime != null && bTime != null) return bTime.compareTo(aTime);
    if (aTime != null) return -1;
    if (bTime != null) return 1;
    return 0;
  });
  return availableFirst(sorted, (b) => b.hasContent);
}
