import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bookmark.dart';
import '../models/clip_note.dart';
import '../models/pinned_note.dart';
import '../models/question.dart';
import 'auth_service.dart';
import 'storage_service.dart';

/// Progress reports from [UserDataSyncService.pushAll]/[pullAndMergeAll]:
/// a human-readable stage label plus completed/total stage counts.
typedef SyncProgressCallback = void Function(
    String stageLabel, int completed, int total);

/// Best-effort cross-device sync for user-authored data (notes, bookmarks,
/// clips, answers, settings, book history). Local `SharedPreferences` (via
/// [StorageService]) stays authoritative; every method swallows
/// network/Supabase failures so the app keeps working offline. Conflicts
/// resolve last-write-wins per row; deletions propagate as tombstones
/// (`synced_deletions`, purged after 90 days). `main()` binds
/// [StorageService.onUserDataChanged] to [pushEntity]; [AuthProvider] calls
/// [pullAndMergeAll] after sign-in.
class UserDataSyncService {
  static const _logName = 'UserDataSyncService';

  final StorageService _storage;

  const UserDataSyncService(this._storage);

  /// Uploads one domain after a local mutation. Fire-and-forget safe.
  Future<void> pushEntity(UserDataEntity entity) {
    switch (entity) {
      case UserDataEntity.pinnedNotes:
        return _pushPinnedNotes();
      case UserDataEntity.noteCollections:
        return _pushNoteCollections();
      case UserDataEntity.bookmarks:
        return _pushBookmarks();
      case UserDataEntity.readingNotes:
        return _pushReadingNotes();
      case UserDataEntity.clips:
        return _pushClips();
      case UserDataEntity.answers:
        return _pushAnswers();
      case UserDataEntity.settings:
        return _pushSettings();
      case UserDataEntity.bookHistory:
        return _pushBookHistory();
    }
  }

  /// Uploads every domain. Used after sign-in to reconcile a device whose
  /// local state is newer than the server's (push first), before pulling.
  /// Reports per-domain progress through [onProgress] when given.
  Future<void> pushAll({SyncProgressCallback? onProgress}) async {
    const labels = [
      'pinned notes',
      'collections',
      'bookmarks',
      'reading notes',
      'clips',
      'answers',
      'settings',
      'reading history',
    ];
    const entities = UserDataEntity.values;
    for (var i = 0; i < entities.length; i++) {
      await pushEntity(entities[i]);
      onProgress?.call(labels[i], i + 1, entities.length);
    }
  }

  /// Pulls every domain and merges into local storage (last-write-wins),
  /// then applies remote tombstones and refreshes cached providers.
  /// Intended for one call right after sign-in so a new device recovers
  /// everything before the user starts studying. Reports per-domain
  /// progress through [onProgress] when given.
  Future<void> pullAndMergeAll({SyncProgressCallback? onProgress}) async {
    const totalStages = 9;
    var done = 0;
    void report(String label) {
      done += 1;
      onProgress?.call(label, done, totalStages);
    }

    try {
      if (AuthService.currentUser == null) return;
      await _pullPinnedNotes();
      report('pinned notes');
      await _pullNoteCollections();
      report('collections');
      await _pullBookmarks();
      report('bookmarks');
      await _pullReadingNotes();
      report('reading notes');
      await _pullClips();
      report('clips');
      await _pullAnswers();
      report('answers');
      await _pullSettings();
      report('settings');
      await _pullBookHistory();
      report('reading history');
      await _pullDeletions();
      await _storage.purgeOldDeletions();
      report('tidying up');
      try {
        _storage.onUserDataMerged?.call();
      } catch (_) {}
    } catch (e) {
      developer.log('Could not pull user data: $e', name: _logName);
    }
  }

  // ── Push ───────────────────────────────────────────────────────────────────

  Future<void> _pushPinnedNotes() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final notes = _storage.getPinnedNotes();
      if (notes.isNotEmpty) {
        await Supabase.instance.client.from('pinned_notes').upsert([
          for (final note in notes)
            {
              'user_id': user.id,
              'id': note.id,
              'book_id': note.bookId,
              'chapter_id': note.chapterId,
              'anchor_id': note.anchorId,
              'side': note.side == NoteSide.right ? 'right' : 'left',
              'content': note.content,
              'collection_id': note.collectionId,
              'created_at': note.createdAt.toIso8601String(),
              'updated_at': note.updatedAt.toIso8601String(),
            },
        ]);
      }
      await _pushDeletions(UserDataEntity.pinnedNotes, (deletion) async {
        await Supabase.instance.client
            .from('pinned_notes')
            .delete()
            .eq('user_id', user.id)
            .eq('id', deletion.id);
      });
    } catch (e) {
      developer.log('Could not push pinned notes: $e', name: _logName);
    }
  }

  Future<void> _pushNoteCollections() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final collections = _storage.getNoteCollections();
      if (collections.isNotEmpty) {
        await Supabase.instance.client.from('note_collections').upsert([
          for (final collection in collections)
            {
              'user_id': user.id,
              'id': collection.id,
              'name': collection.name,
              'created_at': collection.createdAt.toIso8601String(),
              'updated_at': collection.updatedAt.toIso8601String(),
            },
        ]);
      }
      await _pushDeletions(UserDataEntity.noteCollections, (deletion) async {
        await Supabase.instance.client
            .from('note_collections')
            .delete()
            .eq('user_id', user.id)
            .eq('id', deletion.id);
      });
    } catch (e) {
      developer.log('Could not push note collections: $e', name: _logName);
    }
  }

  Future<void> _pushBookmarks() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final bookmarks = _storage.getBookmarks();
      if (bookmarks.isNotEmpty) {
        await Supabase.instance.client.from('bookmarks').upsert([
          for (final bookmark in bookmarks)
            {
              'user_id': user.id,
              'id': bookmark.id,
              'chapter_id': bookmark.chapterId,
              'name': bookmark.name,
              'scroll_progress': bookmark.scrollProgress,
              'created_at': DateTime.fromMillisecondsSinceEpoch(
                      bookmark.createdAt)
                  .toIso8601String(),
            },
        ]);
      }
      await _pushDeletions(UserDataEntity.bookmarks, (deletion) async {
        await Supabase.instance.client
            .from('bookmarks')
            .delete()
            .eq('user_id', user.id)
            .eq('id', deletion.id);
      });
    } catch (e) {
      developer.log('Could not push bookmarks: $e', name: _logName);
    }
  }

  Future<void> _pushReadingNotes() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final notes = _storage.getAllReadingNotes();
      if (notes.isNotEmpty) {
        await Supabase.instance.client.from('reading_notes').upsert(
          [
            for (final note in notes)
              {
                'user_id': user.id,
                'book_id': note.bookId,
                'chapter_id': note.chapterId,
                'content': note.content,
                'updated_at': (note.updatedAt ?? DateTime.now().toUtc())
                    .toIso8601String(),
              },
          ],
          onConflict: 'user_id,book_id,chapter_id',
        );
      }
      await _pushDeletions(UserDataEntity.readingNotes, (deletion) async {
        final parts = deletion.id.split('|');
        if (parts.length != 2) return;
        await Supabase.instance.client
            .from('reading_notes')
            .delete()
            .eq('user_id', user.id)
            .eq('book_id', parts[0])
            .eq('chapter_id', parts[1]);
      });
    } catch (e) {
      developer.log('Could not push reading notes: $e', name: _logName);
    }
  }

  Future<void> _pushClips() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final clips = _storage.getAllClips();
      if (clips.isNotEmpty) {
        await Supabase.instance.client.from('clips').upsert([
          for (final record in clips)
            {
              'user_id': user.id,
              'id': record.clip.id,
              'book_id': record.bookId,
              'chapter_id': record.chapterId,
              'section_id': record.sectionId,
              'content': record.clip.content,
              'created_at': record.clip.createdAt.toIso8601String(),
              'updated_at': record.clip.updatedAt.toIso8601String(),
            },
        ]);
      }
      await _pushDeletions(UserDataEntity.clips, (deletion) async {
        final parts = deletion.id.split('|');
        if (parts.length != 4) return;
        await Supabase.instance.client
            .from('clips')
            .delete()
            .eq('user_id', user.id)
            .eq('id', parts[3]);
      });
    } catch (e) {
      developer.log('Could not push clips: $e', name: _logName);
    }
  }

  Future<void> _pushAnswers() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final rows = <Map<String, dynamic>>[];
      for (final scope in _storage.getAnswerScopes()) {
        for (final answer in _storage.getAnswers(scope).values) {
          rows.add({
            'user_id': user.id,
            'scope': scope,
            'question_id': answer.questionId,
            'selected_option': answer.selectedOption,
            'is_correct': answer.isCorrect,
            'answered_at': answer.answeredAt.toIso8601String(),
          });
        }
      }
      if (rows.isEmpty) return;
      await Supabase.instance.client.from('user_answers').upsert(
            rows,
            onConflict: 'user_id,scope,question_id',
          );
    } catch (e) {
      developer.log('Could not push answers: $e', name: _logName);
    }
  }

  Future<void> _pushSettings() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': user.id,
        'settings': _storage.getSettings().toJson(),
        'updated_at': (_storage.getSettingsUpdatedAt() ?? DateTime.now().toUtc())
            .toIso8601String(),
      });
    } catch (e) {
      developer.log('Could not push settings: $e', name: _logName);
    }
  }

  Future<void> _pushBookHistory() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;
      final history = _storage.getBookHistory();
      if (history.isEmpty) return;
      await Supabase.instance.client.from('user_book_history').upsert(
        [
          for (final entry in history.entries)
            {
              'user_id': user.id,
              'book_id': entry.key,
              'opened_at': entry.value.toIso8601String(),
            },
        ],
        onConflict: 'user_id,book_id',
      );
    } catch (e) {
      developer.log('Could not push book history: $e', name: _logName);
    }
  }

  /// Uploads pending tombstones for [entity], deletes the matching remote
  /// rows, and clears the pushed tombstones locally.
  Future<void> _pushDeletions(
    UserDataEntity entity,
    Future<void> Function(SyncDeletion deletion) deleteRemote,
  ) async {
    final pending = _storage
        .getDeletions()
        .where((d) => d.entity == entity)
        .toList();
    if (pending.isEmpty) return;
    final user = AuthService.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('synced_deletions').upsert([
      for (final deletion in pending)
        {
          'user_id': user.id,
          'entity': deletion.entity.name,
          'entity_id': deletion.id,
          'deleted_at': deletion.deletedAt.toIso8601String(),
        },
    ]);
    for (final deletion in pending) {
      try {
        await deleteRemote(deletion);
      } catch (e) {
        developer.log('Could not delete remote row: $e', name: _logName);
      }
    }
    await _storage.clearDeletions(pending);
  }

  // ── Pull & merge ───────────────────────────────────────────────────────────

  Future<void> _pullPinnedNotes() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('pinned_notes')
          .select()
          .eq('user_id', user.id);
      final remote = <PinnedNote>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        remote.add(PinnedNote(
          id: map['id']?.toString() ?? '',
          bookId: map['book_id']?.toString() ?? '',
          chapterId: map['chapter_id']?.toString() ?? '',
          anchorId: map['anchor_id']?.toString() ?? '',
          side: map['side'] == 'right' ? NoteSide.right : NoteSide.left,
          content: map['content']?.toString() ?? '',
          collectionId: map['collection_id']?.toString(),
          createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ));
      }
      await _storage.mergePinnedNotes(remote);
    } catch (e) {
      developer.log('Could not pull pinned notes: $e', name: _logName);
    }
  }

  Future<void> _pullNoteCollections() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('note_collections')
          .select()
          .eq('user_id', user.id);
      final remote = <NoteCollection>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final createdAt =
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        remote.add(NoteCollection(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          createdAt: createdAt,
          updatedAt:
              DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
                  createdAt,
        ));
      }
      await _storage.mergeNoteCollections(remote);
    } catch (e) {
      developer.log('Could not pull note collections: $e', name: _logName);
    }
  }

  Future<void> _pullBookmarks() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('bookmarks')
          .select()
          .eq('user_id', user.id);
      final remote = <Bookmark>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        remote.add(Bookmark(
          id: map['id']?.toString() ?? '',
          chapterId: map['chapter_id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          scrollProgress:
              (map['scroll_progress'] as num?)?.toDouble() ?? 0.0,
          createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
        ));
      }
      await _storage.mergeBookmarks(remote);
    } catch (e) {
      developer.log('Could not pull bookmarks: $e', name: _logName);
    }
  }

  Future<void> _pullReadingNotes() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('reading_notes')
          .select()
          .eq('user_id', user.id);
      final remote = <ReadingNoteRecord>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        remote.add(ReadingNoteRecord(
          bookId: map['book_id']?.toString() ?? '',
          chapterId: map['chapter_id']?.toString() ?? '',
          content: map['content']?.toString() ?? '',
          updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
        ));
      }
      await _storage.mergeReadingNotes(remote);
    } catch (e) {
      developer.log('Could not pull reading notes: $e', name: _logName);
    }
  }

  Future<void> _pullClips() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('clips')
          .select()
          .eq('user_id', user.id);
      final remote = <ClipRecord>[];
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final createdAt =
            DateTime.tryParse(map['created_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        remote.add(ClipRecord(
          bookId: map['book_id']?.toString() ?? '',
          chapterId: map['chapter_id']?.toString() ?? '',
          sectionId: map['section_id']?.toString() ?? '',
          clip: ClipNote(
            id: map['id']?.toString() ?? '',
            content: map['content']?.toString() ?? '',
            createdAt: createdAt,
            updatedAt:
                DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
                    createdAt,
          ),
        ));
      }
      await _storage.mergeClips(remote);
    } catch (e) {
      developer.log('Could not pull clips: $e', name: _logName);
    }
  }

  Future<void> _pullAnswers() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('user_answers')
          .select()
          .eq('user_id', user.id);
      final byScope = <String, Map<String, UserAnswer>>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final scope = map['scope']?.toString() ?? '';
        final answer = UserAnswer(
          questionId: map['question_id']?.toString() ?? '',
          selectedOption: map['selected_option']?.toString() ?? '',
          isCorrect: map['is_correct'] as bool? ?? false,
          answeredAt: DateTime.tryParse(
                  map['answered_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        );
        (byScope[scope] ??= {})[answer.questionId] = answer;
      }
      for (final entry in byScope.entries) {
        await _storage.mergeAnswers(entry.key, entry.value);
      }
    } catch (e) {
      developer.log('Could not pull answers: $e', name: _logName);
    }
  }

  Future<void> _pullSettings() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final row = await Supabase.instance.client
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (row == null) return;
      final map = row;
      final settings = map['settings'];
      final updatedAt =
          DateTime.tryParse(map['updated_at']?.toString() ?? '');
      if (settings is Map<String, dynamic> && updatedAt != null) {
        await _storage.mergeSettings(settings, updatedAt);
      }
    } catch (e) {
      developer.log('Could not pull settings: $e', name: _logName);
    }
  }

  Future<void> _pullBookHistory() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('user_book_history')
          .select()
          .eq('user_id', user.id);
      final remote = <String, DateTime>{};
      for (final row in rows as List) {
        final map = row as Map<String, dynamic>;
        final openedAt =
            DateTime.tryParse(map['opened_at']?.toString() ?? '');
        if (openedAt != null) {
          remote[map['book_id']?.toString() ?? ''] = openedAt;
        }
      }
      remote.remove('');
      await _storage.mergeBookHistory(remote);
    } catch (e) {
      developer.log('Could not pull book history: $e', name: _logName);
    }
  }

  Future<void> _pullDeletions() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('synced_deletions')
          .select()
          .eq('user_id', user.id);
      final remote = <SyncDeletion>[];
      for (final row in rows as List) {
        final deletion =
            SyncDeletion.fromJson(row as Map<String, dynamic>);
        if (deletion != null) remote.add(deletion);
      }
      await _storage.applyDeletions(remote);
    } catch (e) {
      developer.log('Could not pull deletions: $e', name: _logName);
    }
  }
}
