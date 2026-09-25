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

/// User-data domains mirrored to Supabase for cross-device continuity (see
/// `UserDataSyncService`). Serve logs and last-read chapter are
/// intentionally absent: rotation state and reading position rebuild
/// naturally and are not worth syncing.
enum UserDataEntity {
  pinnedNotes,
  noteCollections,
  bookmarks,
  readingNotes,
  clips,
  answers,
  settings,
  bookHistory,
}

/// One free-text reading note with its location, for sync upload/merge.
class ReadingNoteRecord {
  final String bookId;
  final String chapterId;
  final String content;
  final DateTime? updatedAt;

  const ReadingNoteRecord({
    required this.bookId,
    required this.chapterId,
    required this.content,
    this.updatedAt,
  });
}

/// One text clip with its location, for sync upload/merge.
class ClipRecord {
  final String bookId;
  final String chapterId;
  final String sectionId;
  final ClipNote clip;

  const ClipRecord({
    required this.bookId,
    required this.chapterId,
    required this.sectionId,
    required this.clip,
  });
}

/// A record that a synced entity was deleted locally, so the deletion can
/// be propagated to Supabase and to the user's other devices.
class SyncDeletion {
  final UserDataEntity entity;
  final String id;
  final DateTime deletedAt;

  const SyncDeletion({
    required this.entity,
    required this.id,
    required this.deletedAt,
  });

  Map<String, String> toJson() => {
        'entity': entity.name,
        'id': id,
        'at': deletedAt.toIso8601String(),
      };

  static SyncDeletion? fromJson(Map<String, dynamic> json) {
    final name = json['entity']?.toString();
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (name == null || at == null) return null;
    try {
      final entity = UserDataEntity.values.byName(name);
      return SyncDeletion(
        entity: entity,
        id: json['id']?.toString() ?? '',
        deletedAt: at,
      );
    } catch (_) {
      return null;
    }
  }
}

class StorageService {
  static const _settingsKey = 'enchiridion_settings';
  static const _bookmarksKey = 'enchiridion_bookmarks';
  static const _lastReadKey = 'enchiridion_last_read_chapter';
  static const _visitedKey = 'enchiridion_visited_chapters';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Fired at the end of every user-data mutation (notes, clips, bookmarks,
  /// answers, settings, history) so cross-device sync can push the change.
  /// Wired once in `main()`; null in tests and unwired contexts, where
  /// mutations stay local-only. Callers never await it. Merge methods below
  /// run quietly (see [runQuietly]) so applying remote state never
  /// re-triggers a push.
  void Function(UserDataEntity)? onUserDataChanged;

  /// Fired after a pull merges remote state into storage, so providers with
  /// cached copies (notes, bookmarks, settings, stats) can refresh. Wired
  /// once in `main()`.
  void Function()? onUserDataMerged;

  bool _quiet = false;

  /// Runs [fn] without firing [onUserDataChanged] — used when applying
  /// remote state pulled from Supabase.
  Future<T> runQuietly<T>(Future<T> Function() fn) async {
    _quiet = true;
    try {
      return await fn();
    } finally {
      _quiet = false;
    }
  }

  void _notify(UserDataEntity entity) {
    if (_quiet) return;
    try {
      onUserDataChanged?.call(entity);
    } catch (_) {
      // A sync-hook failure must never break the local write that
      // just succeeded.
    }
  }

  // ── Sync indexes & deletion tombstones ─────────────────────────────────────
  //
  // Reading notes and clips live under composite keys that cannot be
  // enumerated unambiguously, so each maintains a `|`-joined location index.
  // Deletions are recorded as tombstones (entity + id + time) so they
  // propagate to Supabase and other devices instead of being resurrected by
  // the next pull. Tombstones older than 90 days are purged on pull — a
  // device offline longer than that re-receives already-deleted rows only
  // in the pathological case, and they vanish on the next push.

  Set<String> _getIndex(String key) =>
      (_prefs.getStringList(key) ?? []).toSet();

  Future<void> _addToIndex(String key, String entry) async {
    final index = _getIndex(key);
    if (index.add(entry)) {
      await _prefs.setStringList(key, index.toList());
    }
  }

  Future<void> _removeFromIndex(String key, String entry) async {
    final index = _getIndex(key);
    if (index.remove(entry)) {
      await _prefs.setStringList(key, index.toList());
    }
  }

  static const _deletionsKey = 'synced_deletions';

  List<SyncDeletion> getDeletions() {
    try {
      final raw = _prefs.getString(_deletionsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(SyncDeletion.fromJson)
          .whereType<SyncDeletion>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDeletions(List<SyncDeletion> deletions) async {
    await _prefs.setString(
      _deletionsKey,
      jsonEncode(deletions.map((d) => d.toJson()).toList()),
    );
  }

  /// Records that a synced entity was deleted locally. Replaces any older
  /// tombstone for the same entity+id.
  Future<void> recordDeletion(UserDataEntity entity, String id) async {
    final deletions = getDeletions()
        .where((d) => !(d.entity == entity && d.id == id))
        .toList();
    deletions.add(SyncDeletion(
      entity: entity,
      id: id,
      deletedAt: DateTime.now().toUtc(),
    ));
    await _saveDeletions(deletions);
  }

  /// Drops tombstones already pushed to Supabase.
  Future<void> clearDeletions(List<SyncDeletion> pushed) async {
    if (pushed.isEmpty) return;
    final keys = pushed.map((d) => '${d.entity.name}|${d.id}').toSet();
    await _saveDeletions(getDeletions()
        .where((d) => !keys.contains('${d.entity.name}|${d.id}'))
        .toList());
  }

  /// Purges tombstones older than [maxAge] (default 90 days).
  Future<void> purgeOldDeletions(
      [Duration maxAge = const Duration(days: 90)]) async {
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    await _saveDeletions(getDeletions()
        .where((d) => d.deletedAt.isAfter(cutoff))
        .toList());
  }

  /// Removes local rows matching remotely-pulled tombstones. Returns true
  /// when anything was removed.
  Future<bool> applyDeletions(List<SyncDeletion> remote) async {
    if (remote.isEmpty) return false;
    var changed = false;
    await runQuietly(() async {
      for (final deletion in remote) {
        changed = await _applyDeletion(deletion) || changed;
      }
    });
    return changed;
  }

  /// Deletes one local row for [deletion]. Returns true when a row existed.
  Future<bool> _applyDeletion(SyncDeletion deletion) async {
    switch (deletion.entity) {
      case UserDataEntity.pinnedNotes:
        final notes = getPinnedNotes();
        final before = notes.length;
        notes.removeWhere((n) => n.id == deletion.id);
        if (notes.length == before) return false;
        await _savePinnedNotes(notes);
        return true;
      case UserDataEntity.noteCollections:
        final collections = getNoteCollections();
        final before = collections.length;
        collections.removeWhere((c) => c.id == deletion.id);
        if (collections.length == before) return false;
        await _saveNoteCollections(collections);
        final notes = getPinnedNotes()
            .map((n) => n.collectionId == deletion.id
                ? n.copyWith(
                    clearCollection: true, updatedAt: deletion.deletedAt)
                : n)
            .toList();
        await _savePinnedNotes(notes);
        return true;
      case UserDataEntity.bookmarks:
        final bookmarks = getBookmarks();
        final before = bookmarks.length;
        bookmarks.removeWhere((b) => b.id == deletion.id);
        if (bookmarks.length == before) return false;
        await _saveAllBookmarks(bookmarks);
        return true;
      case UserDataEntity.readingNotes:
        final parts = deletion.id.split('|');
        if (parts.length != 2) return false;
        if (_prefs.getString(_noteKey(parts[0], parts[1])) == null) {
          return false;
        }
        await _prefs.remove(_noteKey(parts[0], parts[1]));
        await _prefs.remove('$_noteMetaPrefix${parts[0]}_${parts[1]}');
        await _removeFromIndex(_notesIndexKey, deletion.id);
        return true;
      case UserDataEntity.clips:
        final parts = deletion.id.split('|');
        if (parts.length != 4) return false;
        final clips =
            getClips(parts[0], parts[1], parts[2]);
        final before = clips.length;
        clips.removeWhere((c) => c.id == parts[3]);
        if (clips.length == before) return false;
        await _saveClips(parts[0], parts[1], parts[2], clips);
        return true;
      case UserDataEntity.answers:
      case UserDataEntity.settings:
      case UserDataEntity.bookHistory:
        // Answers are never deleted, settings are a single row, and history
        // is append-only — nothing to apply.
        return false;
    }
  }

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
      await _prefs.setString(
          _settingsUpdatedAtKey, DateTime.now().toUtc().toIso8601String());
    } catch (e) {
      developer.log('Error saving settings: $e', name: 'StorageService');
    }
    _notify(UserDataEntity.settings);
  }

  static const _settingsUpdatedAtKey = 'enchiridion_settings_updated_at';

  /// Last local settings write, for last-write-wins cross-device merge.
  DateTime? getSettingsUpdatedAt() {
    final raw = _prefs.getString(_settingsUpdatedAtKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Applies remotely-synced settings when they are newer than the local
  /// copy. Runs quietly (no re-push).
  Future<bool> mergeSettings(
      Map<String, dynamic> json, DateTime remoteUpdatedAt) async {
    final local = getSettingsUpdatedAt();
    if (local != null && !remoteUpdatedAt.isAfter(local)) return false;
    return runQuietly(() async {
      await _prefs.setString(_settingsKey, jsonEncode(json));
      await _prefs.setString(
          _settingsUpdatedAtKey, remoteUpdatedAt.toIso8601String());
      return true;
    });
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
    _notify(UserDataEntity.bookmarks);
  }

  Future<void> removeBookmark(String id) async {
    try {
      final bookmarks = getBookmarks();
      bookmarks.removeWhere((b) => b.id == id);
      await _saveAllBookmarks(bookmarks);
      await recordDeletion(UserDataEntity.bookmarks, id);
    } catch (e) {
      developer.log('Error removing bookmark: $e', name: 'StorageService');
    }
    _notify(UserDataEntity.bookmarks);
  }

  Future<void> _saveAllBookmarks(List<Bookmark> bookmarks) async {
    final jsonList = bookmarks.map((b) => b.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_bookmarksKey, jsonString);
  }

  /// Applies remotely-synced bookmarks: union by id (bookmarks are
  /// immutable once written; removals arrive as tombstones). Runs quietly.
  /// Returns true when anything changed.
  Future<bool> mergeBookmarks(List<Bookmark> remote) async {
    final local = {for (final b in getBookmarks()) b.id: b};
    var changed = false;
    for (final bookmark in remote) {
      if (!local.containsKey(bookmark.id)) {
        local[bookmark.id] = bookmark;
        changed = true;
      }
    }
    if (!changed) return false;
    await runQuietly(() async {
      final merged = local.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveAllBookmarks(merged);
    });
    return true;
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

  // ── Reading notes ────────────────────────────────────────────────────────────
  //
  // Free-text notes keyed by book+chapter. An index + per-note updated-at
  // metadata power enumeration and last-write-wins sync; the content keys
  // themselves are unchanged.

  static const _notesPrefix = 'note_';
  static const _notesIndexKey = 'note_index';
  static const _noteMetaPrefix = 'note_meta_';

  String _noteKey(String bookId, String chapterId) =>
      '$_notesPrefix${bookId}_$chapterId';

  String? getNote(String bookId, String chapterId) =>
      _prefs.getString(_noteKey(bookId, chapterId));

  DateTime? getNoteUpdatedAt(String bookId, String chapterId) {
    final raw = _prefs.getString('$_noteMetaPrefix${bookId}_$chapterId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> saveNote(String bookId, String chapterId, String text) async {
    if (text.isEmpty) {
      await _prefs.remove(_noteKey(bookId, chapterId));
      await _prefs.remove('$_noteMetaPrefix${bookId}_$chapterId');
      await _removeFromIndex(_notesIndexKey, '$bookId|$chapterId');
      await recordDeletion(
          UserDataEntity.readingNotes, '$bookId|$chapterId');
    } else {
      await _prefs.setString(_noteKey(bookId, chapterId), text);
      await _prefs.setString('$_noteMetaPrefix${bookId}_$chapterId',
          DateTime.now().toUtc().toIso8601String());
      await _addToIndex(_notesIndexKey, '$bookId|$chapterId');
    }
    _notify(UserDataEntity.readingNotes);
  }

  Future<void> deleteNote(String bookId, String chapterId) async {
    await _prefs.remove(_noteKey(bookId, chapterId));
    await _prefs.remove('$_noteMetaPrefix${bookId}_$chapterId');
    await _removeFromIndex(_notesIndexKey, '$bookId|$chapterId');
    await recordDeletion(UserDataEntity.readingNotes, '$bookId|$chapterId');
    _notify(UserDataEntity.readingNotes);
  }

  /// Every stored reading note with its location, for sync upload.
  List<ReadingNoteRecord> getAllReadingNotes() {
    final records = <ReadingNoteRecord>[];
    for (final entry in _getIndex(_notesIndexKey)) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      final content = _prefs.getString(_noteKey(parts[0], parts[1]));
      if (content == null || content.isEmpty) continue;
      records.add(ReadingNoteRecord(
        bookId: parts[0],
        chapterId: parts[1],
        content: content,
        updatedAt: getNoteUpdatedAt(parts[0], parts[1]),
      ));
    }
    return records;
  }

  /// Applies remotely-synced reading notes, last-write-wins per note.
  /// Returns true when anything changed.
  Future<bool> mergeReadingNotes(List<ReadingNoteRecord> remote) async {
    var changed = false;
    await runQuietly(() async {
      for (final record in remote) {
        final localAt = getNoteUpdatedAt(record.bookId, record.chapterId);
        final remoteAt = record.updatedAt;
        if (localAt != null &&
            remoteAt != null &&
            !remoteAt.isAfter(localAt)) {
          continue;
        }
        await _prefs.setString(
            _noteKey(record.bookId, record.chapterId), record.content);
        await _prefs.setString(
            '$_noteMetaPrefix${record.bookId}_${record.chapterId}',
            (remoteAt ?? DateTime.now().toUtc()).toIso8601String());
        await _addToIndex(
            _notesIndexKey, '${record.bookId}|${record.chapterId}');
        changed = true;
      }
    });
    return changed;
  }

  // ── Clips ─────────────────────────────────────────────────────────────────────

  static const _clipsPrefix = 'clips_';
  static const _clipsIndexKey = 'clips_index';
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
    final now = DateTime.now();
    final clip = ClipNote(
      id: now.millisecondsSinceEpoch.toString(),
      content: text,
      createdAt: now,
      updatedAt: now,
    );
    clips.add(clip);
    await _saveClips(bookId, chapterId, sectionId, clips);
    await _addToIndex(
        _clipsIndexKey, '$bookId|$chapterId|$sectionId');
    _notify(UserDataEntity.clips);
    return clip;
  }

  Future<void> updateClip(
    String bookId,
    String chapterId,
    String sectionId,
    String clipId,
    String text,
  ) async {
    final now = DateTime.now().toUtc();
    final clips = getClips(bookId, chapterId, sectionId)
        .map((clip) => clip.id == clipId
            ? clip.copyWith(content: text, updatedAt: now)
            : clip)
        .toList();
    await _saveClips(bookId, chapterId, sectionId, clips);
    _notify(UserDataEntity.clips);
  }

  Future<void> deleteClip(
      String bookId, String chapterId, String sectionId, String clipId) async {
    final clips = getClips(bookId, chapterId, sectionId);
    clips.removeWhere((c) => c.id == clipId);
    await _saveClips(bookId, chapterId, sectionId, clips);
    if (getClips(bookId, chapterId, sectionId).isEmpty) {
      await _removeFromIndex(
          _clipsIndexKey, '$bookId|$chapterId|$sectionId');
    }
    await recordDeletion(
        UserDataEntity.clips, '$bookId|$chapterId|$sectionId|$clipId');
    _notify(UserDataEntity.clips);
  }

  /// Every stored clip with its location, for sync upload.
  List<ClipRecord> getAllClips() {
    final records = <ClipRecord>[];
    for (final entry in _getIndex(_clipsIndexKey)) {
      final parts = entry.split('|');
      if (parts.length != 3) continue;
      for (final clip in getClips(parts[0], parts[1], parts[2])) {
        records.add(ClipRecord(
          bookId: parts[0],
          chapterId: parts[1],
          sectionId: parts[2],
          clip: clip,
        ));
      }
    }
    return records;
  }

  /// Applies remotely-synced clips, last-write-wins per clip id within its
  /// location. Returns true when anything changed.
  Future<bool> mergeClips(List<ClipRecord> remote) async {
    var changed = false;
    await runQuietly(() async {
      final byLocation = <String, List<ClipNote>>{};
      for (final record in remote) {
        final key = '${record.bookId}|${record.chapterId}|${record.sectionId}';
        final local = {
          for (final c in getClips(
                  record.bookId, record.chapterId, record.sectionId))
            c.id: c
        };
        final incoming = record.clip;
        final existing = local[incoming.id];
        if (existing != null &&
            !incoming.updatedAt.isAfter(existing.updatedAt)) {
          continue;
        }
        local[incoming.id] = incoming;
        (byLocation[key] ??= []).addAll(local.values);
        await _addToIndex(_clipsIndexKey, key);
        changed = true;
      }
      for (final entry in byLocation.entries) {
        final parts = entry.key.split('|');
        final deduped = <String, ClipNote>{};
        for (final clip in entry.value) {
          final prev = deduped[clip.id];
          if (prev == null || clip.updatedAt.isAfter(prev.updatedAt)) {
            deduped[clip.id] = clip;
          }
        }
        await _saveClips(
            parts[0], parts[1], parts[2], deduped.values.toList());
      }
    });
    return changed;
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
    final now = DateTime.now();
    final collection = NoteCollection(
      id: now.microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    collections.add(collection);
    await _saveNoteCollections(collections);
    _notify(UserDataEntity.noteCollections);
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
    final now = DateTime.now().toUtc();
    await _saveNoteCollections(
      collections
          .map((c) => c.id == id
              ? c.copyWith(name: trimmed, updatedAt: now)
              : c)
          .toList(),
    );
    _notify(UserDataEntity.noteCollections);
  }

  Future<void> deleteNoteCollection(String id) async {
    final now = DateTime.now().toUtc();
    final notes = getPinnedNotes()
        .map((note) => note.collectionId == id
            ? note.copyWith(clearCollection: true, updatedAt: now)
            : note)
        .toList();
    await _savePinnedNotes(notes);
    await _saveNoteCollections(
      getNoteCollections().where((collection) => collection.id != id).toList(),
    );
    await recordDeletion(UserDataEntity.noteCollections, id);
    _notify(UserDataEntity.noteCollections);
    _notify(UserDataEntity.pinnedNotes);
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
                updatedAt: DateTime.now().toUtc(),
              )
            : note)
        .toList();
    await _savePinnedNotes(notes);
    _notify(UserDataEntity.pinnedNotes);
  }

  /// Applies remotely-synced collections, last-write-wins per id. Runs
  /// quietly. Returns true when anything changed.
  Future<bool> mergeNoteCollections(List<NoteCollection> remote) async {
    final local = {for (final c in getNoteCollections()) c.id: c};
    var changed = false;
    for (final collection in remote) {
      final existing = local[collection.id];
      if (existing == null ||
          collection.updatedAt.isAfter(existing.updatedAt)) {
        local[collection.id] = collection;
        changed = true;
      }
    }
    if (!changed) return false;
    await runQuietly(
        () => _saveNoteCollections(local.values.toList()));
    return true;
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
    final now = DateTime.now();
    final note = PinnedNote(
      id: now.millisecondsSinceEpoch.toString(),
      bookId: bookId,
      chapterId: chapterId,
      anchorId: anchorId,
      side: side,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    notes.add(note);
    await _savePinnedNotes(notes);
    _notify(UserDataEntity.pinnedNotes);
    return note;
  }

  Future<void> updatePinnedNote(String id, String content) async {
    final notes = getPinnedNotes()
        .map((n) => n.id == id
            ? n.copyWith(content: content, updatedAt: DateTime.now().toUtc())
            : n)
        .toList();
    await _savePinnedNotes(notes);
    _notify(UserDataEntity.pinnedNotes);
  }

  Future<void> deletePinnedNote(String id) async {
    final notes = getPinnedNotes();
    notes.removeWhere((n) => n.id == id);
    await _savePinnedNotes(notes);
    await recordDeletion(UserDataEntity.pinnedNotes, id);
    _notify(UserDataEntity.pinnedNotes);
  }

  /// Applies remotely-synced pinned notes, last-write-wins per id. Runs
  /// quietly. Returns true when anything changed.
  Future<bool> mergePinnedNotes(List<PinnedNote> remote) async {
    final local = {for (final n in getPinnedNotes()) n.id: n};
    var changed = false;
    for (final note in remote) {
      final existing = local[note.id];
      if (existing == null || note.updatedAt.isAfter(existing.updatedAt)) {
        local[note.id] = note;
        changed = true;
      }
    }
    if (!changed) return false;
    await runQuietly(() => _savePinnedNotes(local.values.toList()));
    return true;
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
    _notify(UserDataEntity.bookHistory);
  }

  /// Applies remotely-synced book history, keeping the latest open per book.
  /// Runs quietly. Returns true when anything changed.
  Future<bool> mergeBookHistory(Map<String, DateTime> remote) async {
    final local = getBookHistory();
    var changed = false;
    for (final entry in remote.entries) {
      final existing = local[entry.key];
      if (existing == null || entry.value.isAfter(existing)) {
        local[entry.key] = entry.value;
        changed = true;
      }
    }
    if (!changed) return false;
    await runQuietly(() => _prefs.setString(
          _bookHistoryKey,
          jsonEncode(local.map((k, v) => MapEntry(k, v.toIso8601String()))),
        ));
    return true;
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
    _notify(UserDataEntity.answers);
  }

  /// Every scope with a locally stored answer map (book ids and exam module
  /// scopes), for sync upload.
  List<String> getAnswerScopes() {
    const prefix = _answersPrefix;
    return _prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toList();
  }

  /// Applies remotely-synced answers for [scope], last-write-wins per
  /// question on `answeredAt`. Runs quietly. Returns true on change.
  Future<bool> mergeAnswers(
      String scope, Map<String, UserAnswer> remote) async {
    final local = getAnswers(scope);
    var changed = false;
    for (final entry in remote.entries) {
      final existing = local[entry.key];
      if (existing == null ||
          entry.value.answeredAt.isAfter(existing.answeredAt)) {
        local[entry.key] = entry.value;
        changed = true;
      }
    }
    if (!changed) return false;
    await runQuietly(() => _prefs.setString(
          '$_answersPrefix$scope',
          jsonEncode(local.map((k, v) => MapEntry(k, v.toJson()))),
        ));
    return true;
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

  // ── Subscription validation ──────────────────────────────────────────────────  //
  // Timestamp of the last time the subscription cache was successfully
  // revalidated against Supabase (see `AccessService`). If the device goes
  // longer than `AccessService.maxValidationAge` without a successful
  // validation (e.g. the user cuts internet to keep access indefinitely),
  // access automatically reverts to freemium until the next successful check.

  static const _accessValidationPrefix = 'access_validated_at_';
  DateTime? getLastAccessValidation(String userId) {
    final raw = _prefs.getString('$_accessValidationPrefix$userId');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastAccessValidation(String userId, DateTime when) async {
    await _prefs.setString(
        '$_accessValidationPrefix$userId', when.toIso8601String());
  }

  static const _accessScopesPrefix = 'access_scopes_';

  /// The scopes ([`*`] for a full subscription, otherwise book ids / exam
  /// module scopes) granted at the last successful validation for [userId].
  ///
  /// Persisted alongside [getLastAccessValidation] so a cold isolate — the
  /// headless Study Buddy alarm creates a fresh one on every run — can trust
  /// a recent validation instead of paying a Supabase round trip each time.
  /// Keyed by user id, so one account's grants can never be read for another.
  ///
  /// Returns null when no validation has ever been recorded on this install,
  /// which is distinct from an empty list: a validated free-tier user legibly
  /// holds no scopes, whereas null means "nothing known, ask the server". An
  /// install that predates this key has a timestamp but no scopes, and must
  /// revalidate rather than be treated as holding nothing.
  List<String>? getCachedAccessScopes(String userId) {
    try {
      return _prefs.getStringList('$_accessScopesPrefix$userId');
    } catch (_) {
      return null;
    }
  }

  Future<void> setCachedAccessScopes(String userId, List<String> scopes) async {
    await _prefs.setStringList('$_accessScopesPrefix$userId', scopes);
  }

  static const _initialSyncKey = 'initial_sync_complete';

  /// Whether this device has ever completed a full cross-device sync.
  /// Guards the new-device sync splash: first sync is shown with progress,
  /// later ones refresh silently in the background.
  bool hasCompletedInitialSync() =>
      _prefs.getBool(_initialSyncKey) ?? false;

  Future<void> setInitialSyncComplete() async {
    await _prefs.setBool(_initialSyncKey, true);
  }

  // ── Pre-launch scope migration ─────────────────────────────────────────────
  //
  // PLAB's storage scope was renamed from the bare `exam_prep` to
  // `exam_prep_plab` before launch (uniform `exam_prep_<module>` scheme).
  // This one-time copy carries any answers, reviews, serve log, and study
  // stats recorded under the old scope on a development device over to the
  // new one. It only copies when the destination is absent, never overwrites,
  // and is a no-op for fresh installs.

  static const _legacyExamPrepScope = 'exam_prep';
  static const _currentExamPrepScope = 'exam_prep_plab';

  Future<void> migrateLegacyExamPrepScope() async {
    const prefixes = [_answersPrefix, _reviewsPrefix, _serveLogPrefix];
    for (final prefix in prefixes) {
      final from = '$prefix$_legacyExamPrepScope';
      final to = '$prefix$_currentExamPrepScope';
      if (_prefs.getString(to) != null) continue;
      final raw = _prefs.getString(from);
      if (raw != null) await _prefs.setString(to, raw);
    }
    const fromStats = '$_studyStatsPrefix$_legacyExamPrepScope';
    const toStats = '$_studyStatsPrefix$_currentExamPrepScope';
    if (_prefs.getString(toStats) == null) {
      final raw = _prefs.getString(fromStats);
      if (raw != null) await _prefs.setString(toStats, raw);
    }
  }

  // ── Daily study stats ──────────────────────────────────────────────────────

  StudyDayStats getDailyStudyStats(String scope, String dateKey) {    try {
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

  /// Every stored [StudyDayStats] day for [scope], decoded from the whole
  /// per-day map at once. Used to fold lifetime totals — unlike
  /// [getDailyStudyStats], this is not scoped to a single date key.
  ///
  /// Tolerates malformed or absent entries the same way [getDailyStudyStats]
  /// does: an individually unparsable day is skipped rather than aborting
  /// the whole read, and a missing/corrupt top-level map returns empty
  /// rather than throwing.
  List<StudyDayStats> getAllDailyStudyStats(String scope) {
    try {
      final raw = _prefs.getString('$_studyStatsPrefix$scope');
      if (raw == null) return [];
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final days = <StudyDayStats>[];
      for (final value in map.values) {
        if (value is! Map<String, dynamic>) continue;
        try {
          days.add(StudyDayStats.fromJson(value));
        } catch (_) {
          // Skip this one malformed day; the rest of the map is still good.
        }
      }
      return days;
    } catch (_) {
      return [];
    }
  }
}
