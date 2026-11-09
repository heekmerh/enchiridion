import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/services/storage_service.dart';

/// Contract behind `AccessService._hydrateFromStorage`, which lets a cold
/// isolate (the headless Study Buddy alarm makes a new one every run) trust a
/// recent validation instead of paying a Supabase round trip before every
/// ambient prompt.
void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService(await SharedPreferences.getInstance());
  });

  test('granted scopes survive a round trip', () async {
    await storage.setCachedAccessScopes('user-1', ['exam_prep_plab', 'surgery']);

    expect(storage.getCachedAccessScopes('user-1'),
        ['exam_prep_plab', 'surgery']);
  });

  test('an install that never recorded scopes reads as null, not as empty',
      () async {
    // The distinction is load-bearing: null must send AccessService to the
    // network, because treating it as "holds nothing" would strip a paying
    // user's access on upgrade until their validation timestamp aged out.
    expect(storage.getCachedAccessScopes('user-1'), isNull);

    await storage.setLastAccessValidation('user-1', DateTime.now().toUtc());

    // A timestamp alone is exactly the pre-upgrade state, and still must not
    // be mistaken for a validated empty grant set.
    expect(storage.getCachedAccessScopes('user-1'), isNull);
  });

  test('a validated free-tier user records an empty grant set', () async {
    await storage.setCachedAccessScopes('user-1', const []);

    // Empty, not null: hydration can trust this and stay offline.
    expect(storage.getCachedAccessScopes('user-1'), isEmpty);
    expect(storage.getCachedAccessScopes('user-1'), isNotNull);
  });

  test('grants are keyed per user and never read across accounts', () async {
    await storage.setCachedAccessScopes('user-1', ['*']);

    expect(storage.getCachedAccessScopes('user-2'), isNull);
    expect(storage.getCachedAccessScopes('user-1'), ['*']);
  });

  test('a full subscription and its validation timestamp persist together',
      () async {
    final validatedAt = DateTime.utc(2026, 9, 25, 12);
    await storage.setLastAccessValidation('user-1', validatedAt);
    await storage.setCachedAccessScopes('user-1', ['*']);

    expect(storage.getLastAccessValidation('user-1'), validatedAt);
    expect(storage.getCachedAccessScopes('user-1'), contains('*'));
  });
}
