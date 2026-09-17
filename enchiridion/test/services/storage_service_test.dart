import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/question.dart';
import 'package:enchiridion/models/question_review.dart';
import 'package:enchiridion/models/study_day_stats.dart';
import 'package:enchiridion/models/pinned_note.dart';
import 'package:enchiridion/services/storage_service.dart';

void main() {
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  group('StorageService', () {
    test('pinned notes retain book anchors across a cross-book collection',
        () async {
      final paediatric = await storageService.addPinnedNote(
        bookId: 'paediatrics',
        chapterId: 'overview',
        anchorId: 'section/subsection/group/1',
        side: NoteSide.left,
        content: 'Fever approach',
      );
      final surgery = await storageService.addPinnedNote(
        bookId: 'surgery',
        chapterId: 'wounds',
        anchorId: 'wounds/assessment/group/2',
        side: NoteSide.right,
        content: 'Wound assessment',
      );
      final collection =
          await storageService.createNoteCollection('Final exam');
      await storageService.assignPinnedNoteToCollection(
          paediatric.id, collection.id);
      await storageService.assignPinnedNoteToCollection(
          surgery.id, collection.id);

      final notes = storageService.getPinnedNotes();
      expect(notes.where((note) => note.collectionId == collection.id),
          hasLength(2));
      expect(notes.firstWhere((note) => note.id == surgery.id).bookId,
          'surgery');
      expect(notes.firstWhere((note) => note.id == paediatric.id).anchorId,
          'section/subsection/group/1');

      await storageService.renameNoteCollection(collection.id, 'Clinical exam');
      expect(storageService.getNoteCollections().single.name, 'Clinical exam');
      await storageService.deleteNoteCollection(collection.id);
      expect(storageService.getNoteCollections(), isEmpty);
      expect(storageService.getPinnedNotes(), hasLength(2));
      expect(storageService.getPinnedNotes().every((n) => n.collectionId == null),
          isTrue);
    });

    test('chapter notes save, reopen, edit, and clear', () async {
      expect(storageService.getNote('book', 'chapter-1'), isNull);

      await storageService.saveNote('book', 'chapter-1', 'First note');
      expect(storageService.getNote('book', 'chapter-1'), 'First note');

      await storageService.saveNote('book', 'chapter-1', 'Edited note');
      expect(storageService.getNote('book', 'chapter-1'), 'Edited note');

      await storageService.deleteNote('book', 'chapter-1');
      expect(storageService.getNote('book', 'chapter-1'), isNull);
    });

    test('clip notes add, edit, delete, and persist', () async {
      final clip = await storageService.addClip(
        'book',
        'chapter-1',
        'section-a',
        'Original clip',
      );

      final savedClips =
          storageService.getClips('book', 'chapter-1', 'section-a');
      expect(savedClips, hasLength(1));
      expect(savedClips.first.content, 'Original clip');

      await storageService.updateClip(
        'book',
        'chapter-1',
        'section-a',
        clip.id,
        'Updated clip',
      );

      final editedClips =
          storageService.getClips('book', 'chapter-1', 'section-a');
      expect(editedClips.first.content, 'Updated clip');

      await storageService.deleteClip(
        'book',
        'chapter-1',
        'section-a',
        clip.id,
      );
      expect(
          storageService.getClips('book', 'chapter-1', 'section-a'), isEmpty);
    });

    test('answers overwrite on save for retakes', () async {
      final first = UserAnswer(
        questionId: 'q-1',
        selectedOption: 'a',
        isCorrect: false,
        answeredAt: DateTime(2026, 6, 10, 9),
      );
      final second = UserAnswer(
        questionId: 'q-1',
        selectedOption: 'c',
        isCorrect: true,
        answeredAt: DateTime(2026, 6, 10, 10),
      );

      await storageService.saveAnswer('exam', first);
      await storageService.saveAnswer('exam', second);

      final answers = storageService.getAnswers('exam');
      expect(answers, hasLength(1));
      expect(answers['q-1']?.selectedOption, 'c');
      expect(answers['q-1']?.isCorrect, isTrue);
    });

    test('daily study stats persist by scope and day', () async {
      final stats = StudyDayStats(
        scope: 'exam_prep',
        dateKey: '2026-06-10',
        questionsAnswered: 8,
        correctAnswers: 6,
        performancePoints: 60,
        updatedAt: DateTime(2026, 6, 10, 18),
      );

      await storageService.saveDailyStudyStats(stats);

      final loaded =
          storageService.getDailyStudyStats('exam_prep', '2026-06-10');
      expect(loaded.questionsAnswered, 8);
      expect(loaded.correctAnswers, 6);
      expect(loaded.performancePoints, 60);
    });

    test('recordQuestionReview persists ladder state across reads', () async {
      final wrong = UserAnswer(
        questionId: 'q-1',
        selectedOption: 'c',
        isCorrect: false,
        answeredAt: DateTime(2026, 1, 1, 9),
      );

      final review =
          await storageService.recordQuestionReview('exam_prep', wrong);
      expect(review.lapses, 1);
      expect(review.stage, 0);

      final reloaded = storageService.getQuestionReviews('exam_prep');
      expect(reloaded['q-1']?.lapses, 1);
      expect(reloaded['q-1']?.attempts, 1);
    });

    test(
        'getQuestionReviews derives state from legacy answers when no review '
        'has been written yet', () async {
      await storageService.saveAnswer(
        'exam_prep',
        UserAnswer(
          questionId: 'q-legacy',
          selectedOption: 'a',
          isCorrect: true,
          answeredAt: DateTime(2026, 1, 1),
        ),
      );

      // No recordQuestionReview call yet — this install only has the old
      // answers_ map, as if it upgraded from a version before reviews
      // existed.
      final derived = storageService.getQuestionReviews('exam_prep');
      expect(derived['q-legacy']?.attempts, 1);
      expect(derived['q-legacy']?.lastCorrect, isTrue);
    });

    test('ensureQuestionReviewsMigrated writes the derived state once',
        () async {
      await storageService.saveAnswer(
        'exam_prep',
        UserAnswer(
          questionId: 'q-legacy',
          selectedOption: 'a',
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 1),
        ),
      );

      await storageService.ensureQuestionReviewsMigrated('exam_prep');
      final firstMigration = storageService.getQuestionReviews('exam_prep');

      // A later wrong answer recorded directly should not be clobbered by a
      // second migration pass reading the (unrelated) legacy answers map.
      await storageService.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q-legacy',
          selectedOption: 'b',
          isCorrect: false,
          answeredAt: DateTime(2026, 1, 2),
        ),
      );
      await storageService.ensureQuestionReviewsMigrated('exam_prep');
      final afterSecondCall = storageService.getQuestionReviews('exam_prep');

      expect(firstMigration['q-legacy']?.attempts, 1);
      expect(afterSecondCall['q-legacy']?.attempts, 2);
    });

    test('serve log records and caps recently served question ids',
        () async {
      expect(storageService.getServeLog('exam_prep').recent, isEmpty);

      var log = storageService.getServeLog('exam_prep');
      for (var i = 0; i < 15; i++) {
        log = log.record('q-$i');
      }
      await storageService.saveServeLog('exam_prep', log);

      final reloaded = storageService.getServeLog('exam_prep');
      expect(reloaded.recent, hasLength(12));
      expect(reloaded.recent.first, 'q-14');
      expect(reloaded.counter, 15);
    });

    test('mergeQuestionReviews takes the newer row per question', () async {
      final answeredAt = DateTime(2026, 1, 1, 9);
      await storageService.recordQuestionReview(
        'exam_prep',
        UserAnswer(
          questionId: 'q-1',
          selectedOption: 'a',
          isCorrect: true,
          answeredAt: answeredAt,
        ),
      );
      final localBefore = storageService.getQuestionReviews('exam_prep');
      expect(localBefore['q-1']?.stage, 1);

      // A remote row seen an hour *earlier* than the local one must not
      // overwrite it — this device's own answer is the newer truth.
      final staleRemote = QuestionReview.initial('q-1').copyWith(
        stage: 0,
        lastSeenAt: answeredAt.subtract(const Duration(hours: 1)),
      );
      await storageService.mergeQuestionReviews('exam_prep', [staleRemote]);
      expect(storageService.getQuestionReviews('exam_prep')['q-1']?.stage, 1);

      // A remote row seen an hour *later* — e.g. the same question answered
      // again on a second device — must win.
      final newerRemote = QuestionReview.initial('q-1').copyWith(
        stage: 3,
        lastSeenAt: answeredAt.add(const Duration(hours: 1)),
      );
      await storageService.mergeQuestionReviews('exam_prep', [newerRemote]);
      expect(storageService.getQuestionReviews('exam_prep')['q-1']?.stage, 3);
    });

    test('mergeQuestionReviews adds a question with no local record',
        () async {
      final remote = QuestionReview.initial('q-new').copyWith(
        stage: 2,
        lastSeenAt: DateTime(2026, 1, 1),
      );
      await storageService.mergeQuestionReviews('exam_prep', [remote]);

      final reviews = storageService.getQuestionReviews('exam_prep');
      expect(reviews['q-new']?.stage, 2);
    });
  });
}
