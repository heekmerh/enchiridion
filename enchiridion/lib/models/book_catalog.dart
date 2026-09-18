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

/// Returns [kBooks] ordered for display: most-recently-opened first among
/// books that share read [history], then all remaining books in their
/// authored order — with readable books (see [CatalogBook.hasContent])
/// always ranked ahead of placeholder books. Availability is the OUTER key;
/// recency only orders within a group, so a placeholder book can never
/// outrank a readable one no matter how recently it was "opened".
///
/// Pure (no Flutter, no provider) so it can be unit-tested and reused
/// directly by a guard test.
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
