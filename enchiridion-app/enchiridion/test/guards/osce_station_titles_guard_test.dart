// Guard: pins the OSCE station backed by `abdominal_examination.json` to
// "Abdominal Examination" everywhere user-visible, and asserts no
// `kOsceTopics` station ever regresses to its old bare organ short form.
// Selects the station by `id` and asserts on rendered text, never on list
// position or `TabBar`/`Tab` structure, so it stays green across detail-route
// layout restructures.

import 'package:enchiridion/models/chapter.dart';
import 'package:enchiridion/models/resource_topic.dart';
import 'package:enchiridion/providers/pinned_notes_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/screens/osce_screen.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _abdominalStationId = 'abdominal-examination';
const String _abdominalStationTitle = 'Abdominal Examination';
const String _abdominalStationAssetPath =
    'assets/data/resources/abdominal_examination.json';

// The bare single-word organ short form this station used to be (and its
// surrounding source comment still was, until this plan) referred to by.
// A station title must never regress to this string.
const String _bareOrganShortForm = 'Abdomen';

ResourceTopic _abdominalStation() =>
    kOsceTopics.firstWhere((t) => t.id == _abdominalStationId);

Widget _wrapWithProviders(Widget child) {
  return FutureBuilder<StorageService>(
    future: SharedPreferences.getInstance().then(StorageService.new),
    builder: (context, snapshot) {
      final storage = snapshot.data;
      if (storage == null) return const SizedBox.shrink();
      return MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
          ChangeNotifierProvider(create: (_) => PinnedNotesProvider(storage)),
        ],
        child: child,
      );
    },
  );
}

/// Minimal synthetic chapter, shaped like the real content-bearing station,
/// used purely to reach the detail route without depending on the real
/// asset load path (which hangs indefinitely in this project's widget-test
/// environment) or on any specific block content.
Chapter _syntheticAbdominalChapter() => const Chapter(
      id: 'abdominal-chapter',
      title: _abdominalStationTitle,
      order: 1,
      sections: [
        ChapterSection(
          id: 'section-1',
          title: 'Section',
          order: 1,
          subsections: [
            ChapterSubsection(
              id: 'sub-1',
              title: 'A. INTRODUCTION',
              contentGroups: [],
            ),
          ],
        ),
      ],
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'kOsceTopics entry selected by id abdominal-examination has title '
      'exactly "Abdominal Examination"', () {
    expect(_abdominalStation().title, _abdominalStationTitle);
  });

  test(
      'the abdominal-examination entry keeps its dataAssetPath unchanged — '
      'a rename must never drag the asset path along with it', () {
    expect(_abdominalStation().dataAssetPath, _abdominalStationAssetPath);
  });

  testWidgets(
      'OsceScreen renders a ListTile whose title reads exactly '
      '"Abdominal Examination", resolved by that text rather than by '
      'list position', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OsceScreen()));

    final titleFinder = find.text(_abdominalStationTitle);
    expect(titleFinder, findsOneWidget);

    final tile = tester.widget<ListTile>(
      find.ancestor(of: titleFinder, matching: find.byType(ListTile)),
    );
    expect((tile.title as Text).data, _abdominalStationTitle);
  });

  testWidgets(
      'tapping the Abdominal Examination tile pushes the detail route, '
      'which still shows "Abdominal Examination" somewhere on screen — '
      'asserted against rendered text, not against tab identity, so this '
      'passes under both the pre-dr5 and post-dr5 OSCE detail layouts',
      (tester) async {
    final chapter = _syntheticAbdominalChapter();

    await tester.pumpWidget(_wrapWithProviders(MaterialApp(
      home: OsceScreen(testChapterLoader: (_) async => chapter),
    )));
    await tester.pump();

    await tester.tap(find.text(_abdominalStationTitle));
    await tester.pumpAndSettle();

    expect(find.text(_abdominalStationTitle), findsWidgets);
  });

  test(
      'no station in kOsceTopics carries the bare single-word organ short '
      'form as its title — the short form must not creep back in on any '
      'station, including but not limited to abdominal-examination', () {
    expect(
      kOsceTopics.where((t) => t.title == _bareOrganShortForm),
      isEmpty,
      reason: 'A station title regressed to the bare short form '
          '"$_bareOrganShortForm" instead of the full display name '
          '"$_abdominalStationTitle".',
    );
  });
}
