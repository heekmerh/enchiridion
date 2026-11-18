import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/screens/resource_topic_detail_screen.dart';
import 'package:enchiridion/services/storage_service.dart';

const _topic = ResourceTopic(
  id: 'test-topic',
  title: 'Test Topic',
  categoryTitle: 'Tests',
  heroAssetPath: 'assets/none.png',
);

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  testWidgets('topic notes save under the topic scope and reopen',
      (tester) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
      ],
      child: const MaterialApp(home: ResourceTopicDetailScreen(topic: _topic)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Topic notes'));
    await tester.pumpAndSettle();
    expect(find.text('Topic Notes'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'My topic note');
    await tester.tap(find.text('Save Note'));
    await tester.pumpAndSettle();

    expect(storage.getNote(_topic.notesScope, _topic.id), 'My topic note');
    expect(find.text('Topic note saved'), findsOneWidget);

    await tester.tap(find.byTooltip('Topic notes'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller?.text, 'My topic note');
  });
}
