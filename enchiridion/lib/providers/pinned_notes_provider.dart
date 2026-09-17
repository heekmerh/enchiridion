import 'package:flutter/foundation.dart';
import '../models/pinned_note.dart';
import '../services/storage_service.dart';

class PinnedNotesProvider with ChangeNotifier {
  final StorageService _storageService;
  List<PinnedNote> _notes;
  List<NoteCollection> _collections;

  PinnedNotesProvider(this._storageService)
      : _notes = _storageService.getPinnedNotes(),
        _collections = _storageService.getNoteCollections();

  /// Newest first, across every book/chapter.
  List<PinnedNote> get all => _notes;
  List<NoteCollection> get collections => _collections;

  List<PinnedNote> forCollection(String? collectionId) =>
      _notes.where((note) => note.collectionId == collectionId).toList();

  List<PinnedNote> forChapter(String bookId, String chapterId) => _notes
      .where((n) => n.bookId == bookId && n.chapterId == chapterId)
      .toList();

  List<PinnedNote> forAnchor(
          String bookId, String chapterId, String anchorId) =>
      _notes
          .where((n) =>
              n.bookId == bookId &&
              n.chapterId == chapterId &&
              n.anchorId == anchorId)
          .toList();

  Future<PinnedNote> add({
    required String bookId,
    required String chapterId,
    required String anchorId,
    required NoteSide side,
    required String content,
  }) async {
    final note = await _storageService.addPinnedNote(
      bookId: bookId,
      chapterId: chapterId,
      anchorId: anchorId,
      side: side,
      content: content,
    );
    _reload();
    return note;
  }

  Future<void> update(String id, String content) async {
    await _storageService.updatePinnedNote(id, content);
    _reload();
  }

  Future<void> delete(String id) async {
    await _storageService.deletePinnedNote(id);
    _reload();
  }

  Future<NoteCollection> createCollection(String name) async {
    final collection = await _storageService.createNoteCollection(name);
    _reload();
    return collection;
  }

  Future<void> renameCollection(String id, String name) async {
    await _storageService.renameNoteCollection(id, name);
    _reload();
  }

  Future<void> deleteCollection(String id) async {
    await _storageService.deleteNoteCollection(id);
    _reload();
  }

  Future<void> assignToCollection(String noteId, String? collectionId) async {
    await _storageService.assignPinnedNoteToCollection(noteId, collectionId);
    _reload();
  }

  void _reload() {
    _notes = _storageService.getPinnedNotes();
    _collections = _storageService.getNoteCollections();
    notifyListeners();
  }
}
