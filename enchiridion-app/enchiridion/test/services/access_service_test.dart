import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:enchiridion/config/pricing_config.dart';
import 'package:enchiridion/services/access_service.dart';
import 'package:enchiridion/services/storage_service.dart';

/// How often the app asks Supabase for a user's subscription, and what it
/// does when Supabase can't be reached. Sized for 20,000 users: launch,
/// resume and token refreshes cost at most one call a day per user.
void main() {
  final access = AccessService.instance;
  late DateTime now;
  late bool online;
  late List<Map<String, dynamic>> rows;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    access.bindStorage(StorageService(await SharedPreferences.getInstance()));
    access.clearCache();
    access.fetchCount = 0;
    now = DateTime.utc(2026, 11, 24, 8);
    online = true;
    rows = [
      {'feature': kPremiumFeature, 'expires_at': null, 'source': 'play'},
    ];
    AccessService.userIdOverride = () => 'user-1';
    AccessService.clockOverride = () => now;
    AccessService.fetchOverride = () async {
      if (!online) throw Exception('offline');
      return rows;
    };
  });

  tearDown(() {
    AccessService.userIdOverride = null;
    AccessService.clockOverride = null;
    AccessService.fetchOverride = null;
    access.clearCache();
  });

  test('a day of launches, resumes and token refreshes costs one call',
      () async {
    await access.refreshIfDue(); // launch
    for (var hour = 1; hour < 23; hour++) {
      now = now.add(const Duration(hours: 1));
      await access.refreshIfDue(); // resume or hourly token refresh
      expect(await access.hasFullAccess(), isTrue);
    }

    expect(access.fetchCount, 1);
  });

  test('after 24 hours the next launch or resume checks again', () async {
    await access.refreshIfDue();
    now = now.add(const Duration(hours: 24));
    await access.refreshIfDue();
    await access.refreshIfDue();

    expect(access.fetchCount, 2);
  });

  test('a cold start within the day reuses the stored grants', () async {
    await access.refreshIfDue();
    access.clearCache(); // the app was closed
    now = now.add(const Duration(hours: 5));

    await access.refreshIfDue();

    expect(await access.hasFullAccess(), isTrue);
    expect(access.fetchCount, 1);
  });

  test('calls made while a check is running share one request', () async {
    await Future.wait([
      access.loadAccess(),
      access.loadAccess(),
      access.loadAccess(),
    ]);

    expect(access.fetchCount, 1);
  });

  test('offline for up to 7 days keeps paid access', () async {
    await access.loadAccess();
    online = false;

    now = now.add(const Duration(days: 6, hours: 23));
    access.clearCache(); // cold start with no connection
    await access.refreshIfDue();
    expect(await access.hasFullAccess(), isTrue);

    // A forced check that fails, such as opening the paywall offline, also
    // keeps access instead of dropping to the free tier.
    await access.loadAccess();
    expect(await access.hasFullAccess(), isTrue);
  });

  test('offline for more than 7 days falls back to the free tier', () async {
    await access.loadAccess();
    online = false;

    now = now.add(const Duration(days: 7, minutes: 1));
    access.clearCache();
    await access.refreshIfDue();

    expect(await access.hasFullAccess(), isFalse);
  });

  test('coming back online after the 7 days restores access', () async {
    await access.loadAccess();
    online = false;
    now = now.add(const Duration(days: 8));
    expect(await access.hasFullAccess(), isFalse);

    online = true;
    await access.refreshIfDue();

    expect(await access.hasFullAccess(), isTrue);
  });

  test('a grant past its own expiry is rechecked before the day is up',
      () async {
    rows = [
      {
        'feature': kPremiumFeature,
        'expires_at': now.add(const Duration(hours: 2)).toIso8601String(),
        'source': 'play',
      },
    ];
    await access.refreshIfDue();
    now = now.add(const Duration(hours: 1));
    await access.refreshIfDue();
    expect(access.fetchCount, 1);

    rows = []; // the subscription ended and was not renewed
    now = now.add(const Duration(hours: 2));
    await access.refreshIfDue();

    expect(access.fetchCount, 2);
    expect(await access.hasFullAccess(), isFalse);
  });

  test('a different account on the same device is checked straight away',
      () async {
    await access.refreshIfDue();
    AccessService.userIdOverride = () => 'user-2';
    rows = [];

    await access.refreshIfDue();

    expect(access.fetchCount, 2);
    expect(await access.hasFullAccess(), isFalse);
  });
}
