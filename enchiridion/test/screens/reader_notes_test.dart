import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/book.dart';
import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/providers/book_provider.dart';
import 'package:enchiridion/providers/bookmark_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/screens/reader_screen.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';

Book _makeBook() => Book(
      id: 'book-1',
      title: 'Test Book',
      author: 'Tester',
      coverUrl: '',
      chapters: const [
        Chapter(
          id: 'chapter-1',
          title: 'Editable Chapter',
          order: 1,
          sections: [],
        ),
      ],
    );

Widget _buildSubject(StorageService storage, BookProvider provider) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
      ChangeNotifierProvider(create: (_) => BookmarkProvider(storage)),
    ],
    child: MaterialApp(
      home: ReaderScreen(
        bookId: 'book-1',
        testBookProvider: provider,
      ),
    ),
  );
}

void main() {
  late StorageService storageService;
  late BookProvider bookProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
    bookProvider = BookProvider.withBook(storageService, _makeBook());
    AccessService.testAccessOverride = true;
  });

  tearDown(() {
    AccessService.testAccessOverride = null;
  });

  testWidgets('chapter notes reopen with edited content', (tester) async {
    await tester.pumpWidget(_buildSubject(storageService, bookProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chapter notes'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Editable note');
    await tester.tap(find.text('Save Note'));
    await tester.pumpAndSettle();

    expect(storageService.getNote('book-1', 'chapter-1'), 'Editable note');

    await tester.tap(find.byTooltip('Chapter notes'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).last);
    expect(textField.controller?.text, 'Editable note');
  });
}
