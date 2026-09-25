// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, User;
import 'package:enchiridion/providers/auth_provider.dart';
import 'package:enchiridion/providers/settings_provider.dart';
import 'package:enchiridion/screens/library_screen.dart';
import 'package:enchiridion/screens/calculator_list_screen.dart';
import 'package:enchiridion/screens/resource_topic_list_screen.dart';
import 'package:enchiridion/services/storage_service.dart';
import 'package:enchiridion/widgets/common/coming_soon.dart';

@GenerateNiceMocks([MockSpec<SharedPreferences>()])
import 'library_screen_test.mocks.dart';

// ---------------------------------------------------------------------------
// Fake AuthProvider — bypasses Supabase constructor initialisation.
// LibraryScreen only reads AuthProvider inside _showSettings(); it is never
// read during the initial build, so a minimal stub is sufficient.
// ---------------------------------------------------------------------------

class _FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus get status => AuthStatus.unauthenticated;

  @override
  bool get isAuthenticated => false;

  @override
  String? get error => null;

  @override
  User? get user => null;

  @override
  Future<String?> signIn(String email, String password) async => null;

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String termsVersion,
  }) async =>
      null;

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> resetPassword(String email) async => null;

  @override
  Future<String?> verifyEmailOtp({
    required String email,
    required String token,
  }) async =>
      null;

  @override
  Future<String?> resendEmailOtp(String email) async => null;

  @override
  DeviceGateStatus get deviceGateStatus => DeviceGateStatus.boundToThisDevice;

  @override
  bool get canAuthorizeNewDevice => true;

  @override
  DateTime? get nextDeviceSwitchDate => null;

  @override
  Future<void> completeDeviceBinding() async {}

  @override
  Future<void> authorizeThisDevice() async {}

  @override
  bool get initialSyncRunning => false;

  @override
  String get syncStageLabel => '';

  @override
  double get syncProgress => 0;

  @override
  void skipInitialSync() {}
}

// ---------------------------------------------------------------------------
// Test helper — builds a minimal widget tree that LibraryScreen requires.
// ---------------------------------------------------------------------------

Widget _buildSubject(StorageService storage) {
  return MultiProvider(
    providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FakeAuthProvider(),
      ),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(storage),
      ),
    ],
    child: const MaterialApp(
      home: LibraryScreen(),
    ),
  );
}

StorageService _makeStorage() {
  final prefs = MockSharedPreferences();
  // Default stubs so StorageService loads without error.
  when(prefs.getString(any)).thenReturn(null);
  when(prefs.getStringList(any)).thenReturn(null);
  when(prefs.setString(any, any)).thenAnswer((_) async => true);
  return StorageService(prefs);
}

void main() {
  setUpAll(() async {
    // Initialise a stub Supabase instance so that AccessService.hasFullAccess()
    // can resolve Supabase.instance without throwing. No real network connection
    // is made during tests because AccessService.loadAccess() returns early when
    // currentUser is null (unauthenticated), before any HTTP call.
    // Supabase.initialize internally uses SharedPreferences, so we must set up
    // the fake platform channel first.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('LibraryScreen — Resources tab', () {
    // -------------------------------------------------------------------
    // (a) Tab label: 'Resources' present; 'Tools' absent.
    // -------------------------------------------------------------------
    testWidgets('tab label shows Resources and not Tools', (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // The TabBar renders both tab texts in the tree.
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Tools'), findsNothing);
    });

    // -------------------------------------------------------------------
    // (b) Carousel renders: first card title 'Calculators' is visible
    //     after switching to the Resources tab.
    // -------------------------------------------------------------------
    testWidgets('Resources tab carousel shows first card title',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Switch to the Resources tab.
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      // The first card title must be visible.
      expect(find.text('Calculators'), findsOneWidget);
    });

    // -------------------------------------------------------------------
    // (c) Indicator dots present: exactly 5 AnimatedContainers render
    //     after switching to the Resources tab.
    // -------------------------------------------------------------------
    testWidgets('Resources tab renders exactly 5 indicator dots',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      // The right-side dot indicator uses one AnimatedContainer per page.
      // The Library tab also uses AnimatedContainer dots (for book pages).
      // We are now on the Resources tab, so the visible AnimatedContainers
      // belong to the Resources dot indicator.
      final animatedContainers =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(
        animatedContainers.length,
        equals(5),
        reason: 'The Resources tab right-side indicator must show 5 dots',
      );
    });

    // -------------------------------------------------------------------
    // (d) Swipe test: drag to second page — card title changes and dot
    //     count is still 4.
    // -------------------------------------------------------------------
    testWidgets('swiping carousel changes card title and preserves dot count',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      // Initial state: first card 'Calculators' visible.
      expect(find.text('Calculators'), findsOneWidget);

      // Fling upward to reveal the second vertical page.
      // Use .last because the Library tab PageView is also in the tree.
      await tester.fling(
        find.byType(PageView).last,
        const Offset(0, -400),
        800,
      );
      await tester.pumpAndSettle();

      // Second card title 'Exam Prep' should now be visible.
      expect(find.text('Exam Prep'), findsOneWidget);

      // Dot count must remain 5.
      final dotsAfterSwipe =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(dotsAfterSwipe.length, equals(5));
    });

    // -------------------------------------------------------------------
    // (e) Calculators routing: tap card → CalculatorListScreen appears.
    // -------------------------------------------------------------------
    testWidgets('tapping Calculators card navigates to CalculatorListScreen',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Switch to Resources tab.
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      // Tap the Calculators card.
      await tester.tap(find.text('Calculators'));
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorListScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------
    // (f) Medical Instrumentation routing: tap card → ResourceTopicListScreen
    //     renders the dense (ListTile) presentation, not the hero-image card
    //     presentation, with IV Cannula still leading.
    // -------------------------------------------------------------------
    testWidgets(
        'tapping Medical Instrumentation card navigates to a dense ResourceTopicListScreen',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Switch to Resources tab.
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();

      // Advance the vertical carousel to the Medical Instrumentation card.
      // Bounded loop: fail with a clear reason if the card never appears,
      // rather than a confusing tap-on-nothing error further down.
      var attempts = 0;
      while (find.text('Medical Instrumentation').evaluate().isEmpty) {
        attempts++;
        if (attempts > 6) {
          fail(
            'Medical Instrumentation card did not appear in the Resources '
            'carousel after 6 swipes — carousel order may have changed.',
          );
        }
        await tester.fling(
          find.byType(PageView).last,
          const Offset(0, -400),
          800,
        );
        await tester.pumpAndSettle();
      }

      // Tap the card.
      await tester.tap(find.text('Medical Instrumentation'));
      await tester.pumpAndSettle();

      expect(find.byType(ResourceTopicListScreen), findsOneWidget);

      final resourceTopicListScreenFinder =
          find.byType(ResourceTopicListScreen);

      // Presentation assertion 1: dense rows (ListTile) are present.
      expect(
        find.descendant(
          of: resourceTopicListScreenFinder,
          matching: find.byType(ListTile),
        ),
        findsWidgets,
      );

      // Presentation assertion 2: the card presentation (hero Image) is
      // gone. Scoped to the pushed screen's subtree so the Library tab's
      // own book-cover images underneath cannot satisfy this.
      expect(
        find.descendant(
          of: resourceTopicListScreenFinder,
          matching: find.byType(Image),
        ),
        findsNothing,
      );

      // Preserved-behavior assertion: IV Cannula still leads the list.
      expect(find.text('IV Cannula'), findsWidgets);
    });
  });

  group('LibraryScreen — Library tab coming-soon treatment', () {
    // -------------------------------------------------------------------
    // (g) At least one placeholder book page shows the shared
    //     ComingSoonBadge, and the AnimatedContainer dot count (case c/d's
    //     trap) is unaffected by the badge's presence.
    // -------------------------------------------------------------------
    testWidgets('a placeholder book page shows a ComingSoonBadge',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Stay on the Library tab (default). Only paediatrics has content;
      // swipe up to the next book page, which is a placeholder.
      await tester.fling(
        find.byType(PageView).first,
        const Offset(0, -400),
        800,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ComingSoonBadge), findsOneWidget);
    });

    testWidgets('readable book cover renders with no scrim', (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Page 0 is paediatrics, the only readable book.
      expect(find.byType(ComingSoonScrim), findsNothing);
    });

    testWidgets('placeholder cover stays full colour under a scrim',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(PageView).first,
        const Offset(0, -400),
        800,
      );
      await tester.pumpAndSettle();

      final coverFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/books/Internal Medicine.jpeg',
      );
      expect(coverFinder, findsOneWidget);
      expect(
        find.ancestor(
            of: coverFinder, matching: find.byType(ColorFiltered)),
        findsNothing,
        reason: 'Library covers must not desaturate',
      );
      expect(
        find.ancestor(
            of: coverFinder, matching: find.byType(ComingSoonDim)),
        findsNothing,
        reason: 'Library covers must not use the desaturating wrapper',
      );
      expect(find.byType(ComingSoonScrim), findsOneWidget);
      expect(find.byType(ComingSoonBadge), findsOneWidget);
    });
  });

  group('LibraryScreen — book options sheet', () {
    // -------------------------------------------------------------------
    // (f) A user with no recorded answers sees the read entry but no
    //     question-review entry when long-pressing a book card.
    // -------------------------------------------------------------------
    testWidgets(
        'long-pressing a book with no answers shows read entry and no review entry',
        (tester) async {
      await tester.pumpWidget(_buildSubject(_makeStorage()));
      await tester.pumpAndSettle();

      // Long-press the first book page on the Library tab.
      await tester.longPress(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
      expect(find.byIcon(Icons.quiz_outlined), findsNothing);
    });
  });
}
