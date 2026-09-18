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
import 'package:enchiridion/services/storage_service.dart';

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
