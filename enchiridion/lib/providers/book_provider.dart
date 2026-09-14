import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/book_service.dart';
import '../services/storage_service.dart';

enum BookStatus { loading, loaded, error }

class BookProvider with ChangeNotifier {
  final StorageService _storageService;

  BookStatus _status = BookStatus.loading;
  Book? _book;
  String? _error;
  String? _currentChapterId;
  Set<String> _visitedChapterIds = {};

  Set<String> get visitedChapterIds => _visitedChapterIds;

  BookStatus get status => _status;
  Book? get book => _book;
  String? get error => _error;

  List<Chapter> get chapters => _book?.chapters ?? [];

  String? get currentChapterId => _currentChapterId;

  Chapter? get currentChapter {
    if (_book == null || _currentChapterId == null) return null;
    return _book!.chapters.firstWhere(
      (c) => c.id == _currentChapterId,
      orElse: () => _book!.chapters.first,
    );
  }

  int get currentIndex {
    if (_book == null || _currentChapterId == null) return 0;
    return _book!.chapters.indexWhere((c) => c.id == _currentChapterId);
  }

  bool get hasPrevious => currentIndex > 0;
  bool get hasNext =>
      _book != null && currentIndex < _book!.chapters.length - 1;
  double get progress =>
      _book == null ? 0.0 : (currentIndex + 1) / _book!.chapters.length;

  final String _dataFile;

  BookProvider(this._storageService,
      [this._dataFile = 'assets/data/paediatrics.json']) {
    _loadBook();
  }

  /// Testing-only constructor. Bypasses rootBundle and initialises the provider
  /// with [book] already loaded so tests do not need a running platform channel.
  @visibleForTesting
  BookProvider.withBook(this._storageService, Book book) : _dataFile = '' {
    _book = book;
    _currentChapterId =
        book.chapters.isNotEmpty ? book.chapters.first.id : null;
    _status = BookStatus.loaded;
  }

  Future<void> _loadBook() async {
    try {
      final book = await BookService.loadBook(_dataFile);
      final lastChapterId = _storageService.getLastReadChapter();
      _book = book;
      _currentChapterId = lastChapterId ?? book.chapters.first.id;
      _visitedChapterIds = _storageService.getVisitedChapters();
      if (_currentChapterId != null) {
        _visitedChapterIds.add(_currentChapterId!);
      }
      _status = BookStatus.loaded;
    } catch (e) {
      _error = e.toString();
      _status = BookStatus.error;
    }
    notifyListeners();
  }

  Future<void> retry() async {
    _status = BookStatus.loading;
    _error = null;
    notifyListeners();
    await _loadBook();
  }

  void navigateToChapter(String chapterId) {
    _currentChapterId = chapterId;
    _visitedChapterIds.add(chapterId);
    _storageService.setLastReadChapter(chapterId);
    _storageService.markChapterVisited(chapterId);
    notifyListeners();
  }

  void goToPrevious() {
    if (!hasPrevious) return;
    navigateToChapter(_book!.chapters[currentIndex - 1].id);
  }

  void goToNext() {
    if (!hasNext) return;
    navigateToChapter(_book!.chapters[currentIndex + 1].id);
  }
}
