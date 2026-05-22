import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../models/bookmark.dart';
import '../models/question.dart';

class StorageService {
  static const _settingsKey = 'enchiridion_settings';
  static const _bookmarksKey = 'enchiridion_bookmarks';
  static const _lastReadKey = 'enchiridion_last_read_chapter';
  static const _visitedKey = 'enchiridion_visited_chapters';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Settings
  UserSettings getSettings() {
    try {
      final jsonString = _prefs.getString(_settingsKey);
      if (jsonString == null) return UserSettings.defaultSettings;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserSettings.fromJson(json);
    } catch (e) {
      developer.log('Error loading settings: $e', name: 'StorageService');
      return UserSettings.defaultSettings;
    }
  }

  Future<void> saveSettings(UserSettings settings) async {
    try {
      final jsonString = jsonEncode(settings.toJson());
      await _prefs.setString(_settingsKey, jsonString);
    } catch (e) {
      developer.log('Error saving settings: $e', name: 'StorageService');
    }
  }

  // Bookmarks
  List<Bookmark> getBookmarks() {
    try {
      final jsonString = _prefs.getString(_bookmarksKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Error loading bookmarks: $e', name: 'StorageService');
      return [];
    }
  }

  Future<void> saveBookmark(Bookmark bookmark) async {
    try {
      final bookmarks = getBookmarks();
      bookmarks.insert(0, bookmark);
      await _saveAllBookmarks(bookmarks);
    } catch (e) {
      developer.log('Error saving bookmark: $e', name: 'StorageService');
    }
  }

  Future<void> removeBookmark(String id) async {
    try {
      final bookmarks = getBookmarks();
      bookmarks.removeWhere((b) => b.id == id);
      await _saveAllBookmarks(bookmarks);
    } catch (e) {
      developer.log('Error removing bookmark: $e', name: 'StorageService');
    }
  }

  Future<void> _saveAllBookmarks(List<Bookmark> bookmarks) async {
    final jsonList = bookmarks.map((b) => b.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_bookmarksKey, jsonString);
  }

  // Last Read Chapter
  String? getLastReadChapter() {
    return _prefs.getString(_lastReadKey);
  }

  Future<void> setLastReadChapter(String chapterId) async {
    await _prefs.setString(_lastReadKey, chapterId);
  }

  // Visited Chapters
  Set<String> getVisitedChapters() {
    final list = _prefs.getStringList(_visitedKey) ?? [];
    return list.toSet();
  }

  Future<void> markChapterVisited(String chapterId) async {
    final visited = getVisitedChapters();
    if (visited.add(chapterId)) {
      await _prefs.setStringList(_visitedKey, visited.toList());
    }
  }

  // ── Notes ────────────────────────────────────────────────────────────────────

  static const _notesPrefix = 'note_';

  String? getNote(String bookId, String chapterId) =>
      _prefs.getString('$_notesPrefix${bookId}_$chapterId');

  Future<void> saveNote(String bookId, String chapterId, String text) async {
    if (text.isEmpty) {
      await _prefs.remove('$_notesPrefix${bookId}_$chapterId');
    } else {
      await _prefs.setString('$_notesPrefix${bookId}_$chapterId', text);
    }
  }

  Future<void> deleteNote(String bookId, String chapterId) async =>
      _prefs.remove('$_notesPrefix${bookId}_$chapterId');

  // ── Clips ─────────────────────────────────────────────────────────────────────

  static const _clipsPrefix = 'clips_';

  String _clipKey(String bookId, String chapterId, String sectionId) =>
      '$_clipsPrefix${bookId}_${chapterId}_$sectionId';

  List<Map<String, dynamic>> getClips(
      String bookId, String chapterId, String sectionId) {
    try {
      final raw = _prefs.getString(_clipKey(bookId, chapterId, sectionId));
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> addClip(
      String bookId, String chapterId, String sectionId, String text) async {
    final clips = getClips(bookId, chapterId, sectionId);
    clips.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'content': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(
        _clipKey(bookId, chapterId, sectionId), jsonEncode(clips));
  }

  Future<void> deleteClip(
      String bookId, String chapterId, String sectionId, String clipId) async {
    final clips = getClips(bookId, chapterId, sectionId);
    clips.removeWhere((c) => c['id'] == clipId);
    await _prefs.setString(
        _clipKey(bookId, chapterId, sectionId), jsonEncode(clips));
  }

  // ── Calculator Favourites ────────────────────────────────────────────────────

  static const _favoritesKey = 'calc_favorites';

  Set<String> getFavorites() =>
      (_prefs.getStringList(_favoritesKey) ?? []).toSet();

  Future<void> addFavorite(String calculatorId) async {
    final favs = getFavorites()..add(calculatorId);
    await _prefs.setStringList(_favoritesKey, favs.toList());
  }

  Future<void> removeFavorite(String calculatorId) async {
    final favs = getFavorites()..remove(calculatorId);
    await _prefs.setStringList(_favoritesKey, favs.toList());
  }

  // ── Book History ─────────────────────────────────────────────────────────────

  static const _bookHistoryKey = 'book_history';

  Map<String, DateTime> getBookHistory() {
    try {
      final raw = _prefs.getString(_bookHistoryKey);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
    } catch (_) {
      return {};
    }
  }

  Future<void> recordBookOpen(String bookId) async {
    final history = getBookHistory();
    history[bookId] = DateTime.now();
    await _prefs.setString(
      _bookHistoryKey,
      jsonEncode(history.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
  }

  // ── Question Answers ─────────────────────────────────────────────────────────

  static const _answersPrefix = 'answers_';

  Map<String, UserAnswer> getAnswers(String bookId) {
    try {
      final raw = _prefs.getString('$_answersPrefix$bookId');
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
          (k, v) => MapEntry(k, UserAnswer.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAnswer(String bookId, UserAnswer answer) async {
    final answers = getAnswers(bookId);
    answers[answer.questionId] = answer;
    await _prefs.setString(
      '$_answersPrefix$bookId',
      jsonEncode(answers.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
