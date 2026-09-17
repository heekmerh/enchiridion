import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/content_block.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/reader/reader_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reader lays out nearby blocks and can jump to a distant block',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final controller = AutoScrollController();
    final chapter = Chapter(
      id: 'chapter',
      title: 'Chapter',
      order: 0,
      sections: [
        ChapterSection(
          id: 'section',
          title: 'Section',
          order: 0,
          subsections: [
            ChapterSubsection(
              id: 'subsection',
              title: 'Subsection',
              contentGroups: [
                ContentGroup(
                  id: 'group',
                  title: '',
                  blocks: List.generate(
                    100,
                    (i) => ParagraphBlock(text: 'Distinct paragraph $i'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    Map<String, int> indexes = {};

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: controller,
            slivers: [
              ReaderContent(
                chapter: chapter,
                asSliver: true,
                autoScrollController: controller,
                onItemIndexesReady: (value) => indexes = value,
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Distinct paragraph 0'), findsOneWidget);
    expect(find.text('Distinct paragraph 99'), findsNothing);

    final jump = controller.scrollToIndex(
      indexes['section/subsection/group/99']!,
      preferPosition: AutoScrollPosition.begin,
    );
    await tester.pumpAndSettle();
    await jump;

    expect(find.text('Distinct paragraph 99'), findsOneWidget);
  });
}
