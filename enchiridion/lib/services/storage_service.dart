import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clip_note.dart';
import '../models/pinned_note.dart';
import '../models/user_settings.dart';
import '../models/bookmark.dart';
import '../models/question.dart';
import '../models/question_review.dart';
import '../models/serve_log.dart';
import '../models/study_day_stats.dart';

class StorageService {
  static const _settingsKey = 'enchiridion_settings';
  static const _bookmarksKey = 'enchiridion_bookmarks';
  static const _lastReadKey = 'enchiridion_last_read_chapter';
  static const _visitedKey = 'enchiridion_visited_chapters';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Refreshes values written by the headless bubble worker in
  /// `bubble_alarm_callback.dart`. It runs in another isolate with its own
  /// preferences instance, so this instance's cache otherwise misses serves.
  Future<void> refreshFromDisk() => _prefs.reload();

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
  static const _studyStatsPrefix = 'study_stats_';

  String _clipKey(String bookId, String chapterId, String sectionId) =>
      '$_clipsPrefix${bookId}_${chapterId}_$sectionId';

  List<ClipNote> getClips(String bookId, String chapterId, String sectionId) {
    try {
      final raw = _prefs.getString(_clipKey(bookId, chapterId, sectionId));
      if (raw == null) return [];
      final jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((item) => ClipNote.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveClips(
    String bookId,
    String chapterId,
    String sectionId,
    List<ClipNote> clips,
  ) async {
    await _prefs.setString(
      _clipKey(bookId, chapterId, sectionId),
      jsonEncode(clips.map((clip) => clip.toJson()).toList()),
    );
  }

  Future<ClipNote> addClip(
    String bookId,
    String chapterId,
    String sectionId,
    String text,
  ) async {
    final clips = getClips(bookId, chapterId, sectionId);
    final clip = ClipNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      createdAt: DateTime.now(),
    );
    clips.add(clip);
    await _saveClips(bookId, chapterId, sectionId, clips);
    return clip;
  }

  Future<void> updateClip(
    String bookId,
    String chapterId,
    String sectionId,
    String clipId,
    String text,
  ) async {
    final clips = getClips(bookId, chapterId, sectionId)
        .map((clip) => clip.id == clipId ? clip.copyWith(content: text) : clip)
        .toList();
    await _saveClips(bookId, chapterId, sectionId, clips);
  }

  Future<void> deleteClip(
      String bookId, String chapterId, String sectionId, String clipId) async {
    final clips = getClips(bookId, chapterId, sectionId);
    clips.removeWhere((c) => c.id == clipId);
    await _saveClips(bookId, chapterId, sectionId, clips);
  }

  // ── Pinned Notes (margin notes anchored to a specific content block,
  // placed via long-press while reading; reachable for browsing from the
  // Library screen too) ──────────────────────────────────────────────────

  static const _pinnedNotesKey = 'pinned_notes';
  static const _noteCollectionsKey = 'note_collections';

  List<NoteCollection> getNoteCollections() {
    try {
      final raw = _prefs.getString(_noteCollectionsKey);
      if (raw == null) return [];
      final items = jsonDecode(raw) as List<dynamic>;
      return items
          .map((item) => NoteCollection.fromJson(item as Map<String, dynamic>))
          .where((collection) => collection.id.isNotEmpty && collection.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveNoteCollections(List<NoteCollection> collections) async {
    await _prefs.setString(
      _noteCollectionsKey,
      jsonEncode(collections.map((collection) => collection.toJson()).toList()),
    );
  }

  Future<NoteCollection> createNoteCollection(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
    final collections = getNoteCollections();
    for (final existing in collections) {
      if (existing.name.toLowerCase() == trimmed.toLowerCase()) return existing;
    }
    final collection = NoteCollection(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    collections.add(collection);
    await _saveNoteCollections(collections);
    return collection;
  }

  Future<void> renameNoteCollection(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name');
    final collections = getNoteCollections();
    if (collections.any((c) =>
        c.id != id && c.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError.value(name, 'name', 'Collection already exists');
    }
    await _saveNoteCollections(
      collections.map((c) => c.id == id ? c.copyWith(name: trimmed) : c).toList(),
    );
  }

  Future<void> deleteNoteCollection(String id) async {
    final notes = getPinnedNotes()
        .map((note) => note.collectionId == id
            ? note.copyWith(clearCollection: true)
            : note)
        .toList();
    await _savePinnedNotes(notes);
    await _saveNoteCollections(
      getNoteCollections().where((collection) => collection.id != id).toList(),
    );
  }

  Future<void> assignPinnedNoteToCollection(String noteId, String? collectionId) async {
    if (collectionId != null &&
        !getNoteCollections().any((collection) => collection.id == collectionId)) {
      throw ArgumentError.value(collectionId, 'collectionId');
    }
    final notes = getPinnedNotes()
        .map((note) => note.id == noteId
            ? note.copyWith(
                collectionId: collectionId,
                clearCollection: collectionId == null,
              )
            : note)
        .toList();
    await _savePinnedNotes(notes);
  }

  /// Newest first.
  List<PinnedNote> getPinnedNotes() {
    try {
      final raw = _prefs.getString(_pinnedNotesKey);
      if (raw == null) return [];
      final jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((item) => PinnedNote.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePinnedNotes(List<PinnedNote> notes) async {
    await _prefs.setString(
      _pinnedNotesKey,
      jsonEncode(notes.map((n) => n.toJson()).toList()),
    );
  }

  Future<PinnedNote> addPinnedNote({
    required String bookId,
    required String chapterId,
    required String anchorId,
    required NoteSide side,
    required String content,
  }) async {
    final notes = getPinnedNotes();
    final note = PinnedNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: bookId,
      chapterId: chapterId,
      anchorId: anchorId,
      side: side,
      content: content,
      createdAt: DateTime.now(),
    );
    notes.add(note);
    await _savePinnedNotes(notes);
    return note;
  }

  Future<void> updatePinnedNote(String id, String content) async {
    final notes = getPinnedNotes()
        .map((n) => n.id == id ? n.copyWith(content: content) : n)
        .toList();
    await _savePinnedNotes(notes);
  }

  Future<void> deletePinnedNote(String id) async {
    final notes = getPinnedNotes();
    notes.removeWhere((n) => n.id == id);
    await _savePinnedNotes(notes);
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
      return map.map((k, v) =>
          MapEntry(k, UserAnswer.fromJson(v as Map<String, dynamic>)));
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

  /// Records an answered question in both the legacy per-question map (used
  /// for the tick marks in question lists) and the spaced-repetition ladder.
  ///
  /// This must record the review *before* touching the legacy map: on a
  /// scope's very first answer, [recordQuestionReview] derives its starting
  /// state from that same legacy map when no review has been written yet
  /// (see [getQuestionReviews]). Calling [saveAnswer] first would let that
  /// derivation pick up the answer being recorded right now, then
  /// [recordQuestionReview] would fold the same answer in a second time —
  /// silently double-advancing (or double-lapsing) the ladder. Prefer this
  /// method over calling the two separately.
  Future<QuestionReview> recordAnswer(
    String scope,
    UserAnswer answer, {
    bool confident = true,
  }) async {
    final review =
        await recordQuestionReview(scope, answer, confident: confident);
    await saveAnswer(scope, answer);
    return review;
  }

  // ── Question Reviews (spaced repetition) ──────────────────────

  static const _reviewsPrefix = 'reviews_';
  static const _serveLogPrefix = 'serve_log_';

  /// Ladder state for every question the user has touched in [scope].
  ///
  /// Falls back to deriving state from the legacy `answers_` map when no
  /// review record has been written yet, so an existing install keeps its
  /// history instead of restarting from zero. Call
  /// [ensureQuestionReviewsMigrated] to make that derivation permanent.
  Map<String, QuestionReview> getQuestionReviews(String scope) {
    try {
      final raw = _prefs.getString('$_reviewsPrefix$scope');
      if (raw == null) return _reviewsFromLegacyAnswers(scope);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(
          key,
          QuestionReview.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      developer.log('Error loading reviews: $e', name: 'StorageService');
      return {};
    }
  }

  Map<String, QuestionReview> _reviewsFromLegacyAnswers(String scope) {
    return {
      for (final entry in getAnswers(scope).entries)
        entry.key: QuestionReview.fromLegacyAnswer(entry.value),
    };
  }

  /// One-shot persistence of the legacy-answer derivation. Safe to call on
  /// every load: it writes only when the review key is genuinely absent.
  Future<void> ensureQuestionReviewsMigrated(String scope) async {
    if (_prefs.getString('$_reviewsPrefix$scope') != null) return;
    await _writeQuestionReviews(scope, _reviewsFromLegacyAnswers(scope));
  }

  Future<void> _writeQuestionReviews(
    String scope,
    Map<String, QuestionReview> reviews,
  ) async {
    await _prefs.setString(
      '$_reviewsPrefix$scope',
      jsonEncode(reviews.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  /// Folds one answer into the ladder and persists the result.
  ///
  /// [confident] is the user's self-report that they knew the answer rather
  /// than guessed; a guessed-correct answer does not graduate the question.
  Future<QuestionReview> recordQuestionReview(
    String scope,
    UserAnswer answer, {
    bool confident = true,
  }) async {
    await ensureQuestionReviewsMigrated(scope);
    final reviews = getQuestionReviews(scope);
    final current = reviews[answer.questionId] ??
        QuestionReview.initial(answer.questionId);
    final updated = current.applyAnswer(
      isCorrect: answer.isCorrect,
      selectedOption: answer.selectedOption,
      confident: confident,
      at: answer.answeredAt,
    );
    reviews[answer.questionId] = updated;
    await _writeQuestionReviews(scope, reviews);
    return updated;
  }

  /// Folds remote review rows into local storage, last-write-wins on
  /// [QuestionReview.lastSeenAt].
  ///
  /// Used by `QuestionReviewSyncService` after sign-in so progress made on
  /// another device is reflected here. Never favors a remote row over a
  /// strictly newer local one — this device's own in-flight answers, still
  /// mid-upload or made offline, must not be clobbered by a stale pull.
  Future<void> mergeQuestionReviews(
    String scope,
    Iterable<QuestionReview> remoteReviews,
  ) async {
    await ensureQuestionReviewsMigrated(scope);
    final local = getQuestionReviews(scope);
    var changed = false;
    for (final remote in remoteReviews) {
      final existing = local[remote.questionId];
      if (existing == null || remote.lastSeenAt.isAfter(existing.lastSeenAt)) {
        local[remote.questionId] = remote;
        changed = true;
      }
    }
    if (changed) await _writeQuestionReviews(scope, local);
  }

  ServeLog getServeLog(String scope) {
    try {
      final raw = _prefs.getString('$_serveLogPrefix$scope');
      if (raw == null) return ServeLog.empty;
      return ServeLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ServeLog.empty;
    }
  }

  Future<void> saveServeLog(String scope, ServeLog log) async {
    await _prefs.setString(
      '$_serveLogPrefix$scope',
      jsonEncode(log.toJson()),
    );
  }

  StudyDayStats getDailyStudyStats(String scope, String dateKey) {
    try {
      final raw = _prefs.getString('$_studyStatsPrefix$scope');
      if (raw == null) {
        return StudyDayStats.empty(scope: scope, dateKey: dateKey);
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final json = map[dateKey];
      if (json is Map<String, dynamic>) {
        return StudyDayStats.fromJson(json);
      }
      return StudyDayStats.empty(scope: scope, dateKey: dateKey);
    } catch (_) {
      return StudyDayStats.empty(scope: scope, dateKey: dateKey);
    }
  }

  Future<void> saveDailyStudyStats(StudyDayStats stats) async {
    final key = '$_studyStatsPrefix${stats.scope}';
    final raw = _prefs.getString(key);
    final map = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    map[stats.dateKey] = stats.toJson();
    await _prefs.setString(key, jsonEncode(map));
  }
}
