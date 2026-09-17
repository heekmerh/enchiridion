import 'package:enchiridion/models/pinned_note.dart';
import 'package:enchiridion/providers/bookmark_provider.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/screens/pinned_notes_screen.dart';
import 'package:enchiridion/screens/reader_screen.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('note list groups books and opens the matching book anchor',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    AccessService.testAccessOverride = true;
    addTearDown(() => AccessService.testAccessOverride = null);
    await storage.addPinnedNote(
      bookId: 'paediatrics',
      chapterId: 'overview',
      anchorId: 'overview_s2/subsection/group/0',
      side: NoteSide.left,
      content: 'Fever note',
    );
    await storage.addPinnedNote(
      bookId: 'surgery',
      chapterId: 'wounds',
      anchorId: 'wounds/assessment/group/0',
      side: NoteSide.right,
      content: 'Wound note',
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => BookmarkProvider(storage)),
      ],
      child: const MaterialApp(home: PinnedNotesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Paediatrics'), findsOneWidget);
    expect(find.text('Surgery'), findsOneWidget);
    await tester.tap(find.text('Fever note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
    expect(reader.bookId, 'paediatrics');
    expect(reader.dataFile, 'assets/data/paediatrics.json');
    expect(reader.initialChapterId, 'overview');
    expect(reader.initialAnchorId, 'overview_s2/subsection/group/0');
  });

  testWidgets('users can create a named collection from the notes screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    await storage.addPinnedNote(
      bookId: 'paediatrics',
      chapterId: 'overview',
      anchorId: 'section/subsection/group/0',
      side: NoteSide.left,
      content: 'Study this section',
    );
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => PinnedNotesProvider(storage),
      child: const MaterialApp(home: PinnedNotesScreen()),
    ));

    await tester.tap(find.byTooltip('New collection'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Final exam');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Note actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study collection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Final exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();

    expect(find.text('Final exam'), findsOneWidget);
    expect(storage.getNoteCollections().single.name, 'Final exam');
    expect(storage.getPinnedNotes().single.collectionId,
        storage.getNoteCollections().single.id);
  });
}
