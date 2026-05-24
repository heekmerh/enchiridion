import 'package:flutter/foundation.dart';
import '../models/bookmark.dart';
import '../services/storage_service.dart';

class BookmarkProvider with ChangeNotifier {
  final StorageService _storageService;
  List<Bookmark> _bookmarks = [];

  List<Bookmark> get bookmarks => _bookmarks;

  BookmarkProvider(this._storageService) {
    _loadBookmarks();
  }

  void _loadBookmarks() {
    _bookmarks = _storageService.getBookmarks();
    notifyListeners();
  }

  bool isBookmarked(String chapterId) {
    return _bookmarks.any((b) => b.chapterId == chapterId);
  }

  Future<void> toggleBookmark(String chapterId, String chapterTitle) async {
    if (isBookmarked(chapterId)) {
      final bookmark = _bookmarks.firstWhere((b) => b.chapterId == chapterId);
      await _removeBookmark(bookmark.id);
    } else {
      await _addBookmark(chapterId, chapterTitle);
    }
  }

  Future<void> _addBookmark(String chapterId, String chapterTitle) async {
    final bookmark = Bookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chapterId: chapterId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      name: chapterTitle,
      scrollProgress: 0.0,
    );
    
    // Optimistic update
    _bookmarks.insert(0, bookmark);
    notifyListeners();

    await _storageService.saveBookmark(bookmark);
  }

  Future<void> _removeBookmark(String id) async {
    // Optimistic update
    _bookmarks.removeWhere((b) => b.id == id);
    notifyListeners();

    await _storageService.removeBookmark(id);
  }
}
