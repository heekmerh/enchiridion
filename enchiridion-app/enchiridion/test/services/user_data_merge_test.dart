import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/pinned_note.dart';
import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/services/storage_service.dart';

PinnedNote _note(String id, String content, DateTime at) => PinnedNote(
      id: id,
      bookId: 'paediatrics',
      chapterId: 'ch1',
      anchorId: 'a',
      side: NoteSide.left,
      content: content,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  group('cross-device merge', () {
    test('pinned notes merge last-write-wins per id', () async {
      final old = DateTime.utc(2026, 1, 1);
      final middle = DateTime.utc(2026, 1, 2);
      final recent = DateTime.utc(2026, 1, 3);
      await storage.runQuietly(() async {
        await storage.mergePinnedNotes([_note('n1', 'local', middle)]);
      });

      // Older remote copy loses.
      expect(
        await storage.mergePinnedNotes([_note('n1', 'stale', old)]),
        isFalse,
      );
      expect(storage.getPinnedNotes().single.content, 'local');

      // Newer remote copy wins, new remote rows join.
      expect(
        await storage.mergePinnedNotes(
            [_note('n1', 'remote', recent), _note('n2', 'new', recent)]),
        isTrue,
      );
      final notes = {
        for (final n in storage.getPinnedNotes()) n.id: n.content
      };
      expect(notes, {'n1': 'remote', 'n2': 'new'});
    });

    test('deleted pinned notes stay deleted via tombstones', () async {
      final at = DateTime.utc(2026, 1, 1);
      await storage.addPinnedNote(
        bookId: 'paediatrics',
        chapterId: 'ch1',
        anchorId: 'a',
        side: NoteSide.left,
        content: 'temp',
      );
      final id = storage.getPinnedNotes().single.id;
      await storage.deletePinnedNote(id);
      expect(storage.getPinnedNotes(), isEmpty);
      expect(storage.getDeletions(), hasLength(1));

      // A stale remote copy of the deleted note is dropped by the tombstone.
      await storage.applyDeletions(storage.getDeletions());
      expect(
        await storage.mergePinnedNotes([_note(id, 'resurrected', at)]),
        isTrue,
      );
      await storage.applyDeletions(storage.getDeletions());
      expect(storage.getPinnedNotes(), isEmpty);
    });

    test('answers merge keeps the latest attempt per question', () async {
      UserAnswer answer(String option, DateTime at) => UserAnswer(
            questionId: 'q1',
            selectedOption: option,
            isCorrect: option == 'a',
            answeredAt: at,
          );
      await storage.saveAnswer(
          'exam_prep_plab', answer('b', DateTime.utc(2026, 1, 1)));

      expect(
        await storage.mergeAnswers(
            'exam_prep_plab', {'q1': answer('b', DateTime.utc(2025, 1, 1))}),
        isFalse,
      );
      expect(
        await storage.mergeAnswers(
            'exam_prep_plab', {'q1': answer('a', DateTime.utc(2026, 6, 1))}),
        isTrue,
      );
      expect(
        storage.getAnswers('exam_prep_plab')['q1']?.selectedOption,
        'a',
      );
      expect(storage.getAnswerScopes(), contains('exam_prep_plab'));
    });

    test('reading notes enumerate with locations for upload', () async {
      await storage.saveNote('paediatrics', 'ch-1', 'hello');
      final all = storage.getAllReadingNotes();
      expect(all, hasLength(1));
      expect(all.single.bookId, 'paediatrics');
      expect(all.single.chapterId, 'ch-1');
      expect(all.single.content, 'hello');

      await storage.deleteNote('paediatrics', 'ch-1');
      expect(storage.getAllReadingNotes(), isEmpty);
    });

    test('settings merge only moves forward in time', () async {
      expect(
        await storage.mergeSettings(
            {'theme': 'dark', 'fontSize': 120, 'lineHeight': 1.6, 'fontFamily': 'sans'},
            DateTime.utc(2026, 5, 1)),
        isTrue,
      );
      expect(storage.getSettings().theme.name, 'dark');
      expect(
        await storage.mergeSettings(
            {'theme': 'light', 'fontSize': 100, 'lineHeight': 1.6, 'fontFamily': 'sans'},
            DateTime.utc(2026, 4, 1)),
        isFalse,
      );
      expect(storage.getSettings().theme.name, 'dark');
    });
  });
}
