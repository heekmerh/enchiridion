// Widget tests for the freemium gate in ReaderScreen.
//
// Uses ReaderScreen.testBookProvider to inject a pre-built BookProvider so
// tests never touch rootBundle / platform channels. This avoids the
// ui.ImmutableBuffer.fromAsset path that bypasses binary-messenger mocks in
// Flutter 3.19+.
//
// Free vs paid access is driven via AccessService.testAccessOverride so that
// no Supabase connection is required.
//
// _LockedChapterOverlay is private; its presence is detected by its exclusive
// public markers: Icon(Icons.lock_outline) + Text('Unlock').

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/screens/reader_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/providers/bookmark_provider.dart';
import 'package:enchiridion/providers/book_provider.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/models/book.dart';
import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/widgets/reader/reader_content.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Book _makeFakeBook() => Book(
      id: 'test-book',
      title: 'Test Book',
      author: 'Test',
      coverUrl: '',
      chapters: [
        const Chapter(id: 'ch1', title: 'Chapter One', order: 1, sections: []),
        const Chapter(id: 'ch2', title: 'Chapter Two', order: 2, sections: []),
      ],
    );

Widget _buildTestApp({
  required StorageService storage,
  required String bookId,
  required BookProvider bookProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
      ChangeNotifierProvider(create: (_) => BookmarkProvider(storage)),
      ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
    ],
    child: MaterialApp(
      home: ReaderScreen(
        bookId: bookId,
        testBookProvider: bookProvider,
      ),
    ),
  );
}

// Pumps two frames: one to process initState (starts _checkAccess), one more
// to let the async _checkAccess microtask complete and setState fire.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  const kBookId = 'test-book';
  late StorageService storageService;

  setUp(() async {
    // Suppress missing-asset Flutter errors so logo.png absence doesn't fail tests.
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.library == 'image resource service') return;
      FlutterError.presentError(details);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    AccessService.testAccessOverride = null;
  });

  group('ReaderScreen — freemium gating', () {
    testWidgets(
        '(a) free user at chapter index 0 → sees content, no lock overlay',
        (tester) async {
      // Arrange: no paid access, chapter 0 (within free tier).
      AccessService.testAccessOverride = false;
      final bookProvider =
          BookProvider.withBook(storageService, _makeFakeBook());

      await tester.pumpWidget(
        _buildTestApp(
            storage: storageService,
            bookId: kBookId,
            bookProvider: bookProvider),
      );
      await _settle(tester);

      // Gate: _hasAccess(false) || currentIndex(0) < kFreeChapterCount(1) → true
      expect(find.byType(ReaderContent), findsOneWidget,
          reason: 'Chapter index 0 is free; content should be visible');
      expect(find.byIcon(Icons.lock_outline), findsNothing,
          reason: 'No lock overlay expected at index 0');
      expect(find.text('Unlock'), findsNothing,
          reason: 'Unlock button belongs to overlay; should not appear');
    });

    testWidgets(
        '(b) free user at chapter index 1 → sees locked overlay, no content',
        (tester) async {
      // Arrange: no paid access, navigate to Chapter 2 (index 1).
      AccessService.testAccessOverride = false;
      final book = _makeFakeBook();
      final bookProvider = BookProvider.withBook(storageService, book);

      await tester.pumpWidget(
        _buildTestApp(
            storage: storageService,
            bookId: kBookId,
            bookProvider: bookProvider),
      );
      await _settle(tester);

      // Navigate to chapter index 1 by calling the provider directly.
      bookProvider.navigateToChapter(book.chapters[1].id);
      // notifyListeners → Consumer rebuilds; _hasAccess unchanged (false).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Gate: _hasAccess(false) || currentIndex(1) < kFreeChapterCount(1) → false
      expect(find.byIcon(Icons.lock_outline), findsOneWidget,
          reason: 'Lock overlay expected at index 1 for free user');
      expect(find.text('Unlock'), findsOneWidget,
          reason: 'Unlock button rendered inside _LockedChapterOverlay');
      expect(find.byType(ReaderContent), findsNothing,
          reason: 'Content should be hidden behind the overlay');
    });

    testWidgets(
        '(c) paid user at chapter index 1 → sees content, no lock overlay',
        (tester) async {
      // Arrange: paid access — testAccessOverride=true → _hasAccess=true.
      AccessService.testAccessOverride = true;
      final book = _makeFakeBook();
      final bookProvider = BookProvider.withBook(storageService, book);

      await tester.pumpWidget(
        _buildTestApp(
            storage: storageService,
            bookId: kBookId,
            bookProvider: bookProvider),
      );
      await _settle(tester);

      // Navigate to index 1.
      bookProvider.navigateToChapter(book.chapters[1].id);
      await tester.pump();

      // Gate: _hasAccess(true) → true regardless of index.
      expect(find.byType(ReaderContent), findsOneWidget,
          reason: 'Paid user should see content at any chapter index');
      expect(find.byIcon(Icons.lock_outline), findsNothing,
          reason: 'No lock overlay for paid users');
      expect(find.text('Unlock'), findsNothing,
          reason: 'Unlock button should not appear for paid users');
    });
  });
}
