import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/content_block.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/reader/reader_content.dart';

Chapter _chapterWithClipsAndImage() => Chapter(
      id: 'chapter-1',
      title: 'Chapter',
      order: 1,
      sections: [
        ChapterSection(
          id: 'section-1',
          title: 'Section One',
          order: 1,
          subsections: [
            ChapterSubsection(
              id: 'subsection-1',
              title: 'Subsection',
              contentGroups: [
                ContentGroup(
                  id: 'group-1',
                  title: 'Visuals',
                  blocks: [
                    ImageBlock(assetPath: 'assets/resources/exam_prep.jpeg'),
                    ParagraphBlock(text: 'Body copy'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );

Widget _buildSubject(StorageService storage) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
      ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ReaderContent(
              chapter: _chapterWithClipsAndImage(),
              bookId: 'book-1',
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  late StorageService storageService;

  setUp(() async {
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      FlutterError.presentError(details);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
  });

  testWidgets('clip notes can be added and edited from the section sheet',
      (tester) async {
    await tester.pumpWidget(_buildSubject(storageService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'First clip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      storageService.getClips('book-1', 'chapter-1', 'section-1').first.content,
      'First clip',
    );

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated clip');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(
      storageService.getClips('book-1', 'chapter-1', 'section-1').first.content,
      'Updated clip',
    );
  });

  testWidgets('image blocks open the full-screen viewer on tap',
      (tester) async {
    await tester.pumpWidget(_buildSubject(storageService));
    await tester.pumpAndSettle();

    // Two ancestor GestureDetectors now wrap the image: the block's own
    // tap-to-zoom (nearest) and _NotableBlock's long-press-to-pin (outer) —
    // take the nearest one, which is the tap-to-zoom target.
    final imageGesture = find
        .ancestor(
          of: find.byType(Image).first,
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.ensureVisible(imageGesture);
    await tester.pumpAndSettle();
    await tester.tap(imageGesture, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsWidgets);
  });
}
