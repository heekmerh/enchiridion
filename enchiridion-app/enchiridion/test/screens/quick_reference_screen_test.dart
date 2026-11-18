import 'package:enchiridion/screens/notebook_screen.dart';
import 'package:enchiridion/screens/quick_reference_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/services/notebook_image_store.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enchiridion/services/access_service.dart';

void main() {
  // These tests cover a premium account; the free-tier paywall has its own
  // tests in resource_topic_paywall_test.dart.
  setUp(() => AccessService.testAccessOverride = true);
  tearDown(() => AccessService.testAccessOverride = null);
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance(),
        notebookImages: MemoryNotebookImageStore());
  });

  Widget host() => Provider<StorageService>.value(
        value: storage,
        child: const MaterialApp(
          localizationsDelegates: [FlutterQuillLocalizations.delegate],
          home: QuickReferenceScreen(),
        ),
      );

  testWidgets('shows quick revision, mnemonics and the notebook',
      (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Quick revision'), findsOneWidget);
    expect(find.text('Mnemonics'), findsOneWidget);
    expect(find.text('Add your notes'), findsOneWidget);
  });

  testWidgets('quick revision opens its topic list', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Quick revision'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceTopicListScreen), findsOneWidget);
  });

  testWidgets('mnemonics opens its chapter list', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Mnemonics'));
    await tester.pumpAndSettle();

    expect(find.byType(ResourceTopicListScreen), findsOneWidget);
    expect(find.text('Cardiovascular medicine'), findsOneWidget);
  });

  testWidgets('add your notes opens an empty notebook', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Add your notes'));
    await tester.pumpAndSettle();

    expect(find.byType(NotebookScreen), findsOneWidget);
    expect(find.text('Your notebook is empty'), findsOneWidget);
  });

  testWidgets('the notebook lists saved notes and can move and delete them',
      (tester) async {
    await storage.addNotebookText('first');
    await storage.addNotebookText('second');
    await tester.pumpWidget(Provider<StorageService>.value(
      value: storage,
      child: const MaterialApp(
        localizationsDelegates: [FlutterQuillLocalizations.delegate],
        home: NotebookScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('first', findRichText: true), findsOneWidget);
    expect(find.text('second', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Note options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move up'));
    await tester.pumpAndSettle();
    expect(storage.getNotebookEntries().map((e) => e.content).toList(),
        ['second', 'first']);

    await tester.tap(find.byTooltip('Note options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
        storage.getNotebookEntries().map((e) => e.content).toList(), ['first']);
  });
}
