import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:enchiridion/services/biometric_sign_in_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool available;
  late bool enabled;
  String? secret;
  late int reads;
  late int logins;
  late List<bool> preferenceWrites;
  Future<String?> Function()? readOverride;
  Future<void> Function(String, String)? loginOverride;
  Future<void> Function(String)? writeOverride;
  late BiometricSignInService service;

  setUp(() {
    available = true;
    enabled = false;
    secret = null;
    reads = 0;
    logins = 0;
    preferenceWrites = [];
    readOverride = null;
    loginOverride = null;
    writeOverride = null;
    service = BiometricSignInService(
      available: () async => available,
      enabled: () async => enabled,
      setEnabled: (value) async {
        enabled = value;
        preferenceWrites.add(value);
      },
      read: () async {
        reads++;
        return readOverride != null ? await readOverride!() : secret;
      },
      write: (value) async {
        if (writeOverride != null) await writeOverride!(value);
        secret = value;
      },
      delete: () async => secret = null,
      signIn: (email, password) async {
        logins++;
        expect(email, 'reader@example.com');
        expect(password, 'test-password');
        await loginOverride?.call(email, password);
      },
    );
  });

  Future<void> enroll() =>
      service.enable('reader@example.com', 'test-password');

  test('native storage requires strong biometric authentication on every read',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'read'
          ? jsonEncode(
              {'email': 'reader@example.com', 'password': 'test-password'})
          : null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final nativeService = BiometricSignInService(
      available: () async => true,
      enabled: () async => true,
      signIn: (_, __) async {},
    );
    expect(await nativeService.signIn(), BiometricSignInResult.signedIn);
    expect(await nativeService.signIn(), BiometricSignInResult.signedIn);
    expect(calls.where((call) => call.method == 'read'), hasLength(2));
    for (final call in calls) {
      final options = (call.arguments as Map)['options'] as Map;
      expect(options['enforceBiometrics'], 'true');
      expect(options['requireBiometricsPerOperation'], 'true');
      expect(options['biometricType'], 'strongBiometricOnly');
      expect(options['storageNamespace'], 'enchiridion_biometric_login');
    }
  });

  test('without consent, never accesses credentials or signs in', () async {
    expect(await service.signIn(), BiometricSignInResult.unavailable);
    expect(reads, 0);
    expect(logins, 0);
  });

  test('unsupported device cannot save credentials', () async {
    available = false;
    await expectLater(enroll(), throwsStateError);
    expect(secret, isNull);
    expect(enabled, isFalse);
  });

  test('enrollment is enabled only after protected storage succeeds', () async {
    writeOverride = (_) async => throw PlatformException(code: 'canceled');
    await expectLater(enroll(), throwsA(isA<PlatformException>()));
    expect(enabled, isFalse);
    expect(secret, isNull);
  });

  test('protected credentials are passed to normal backend authentication',
      () async {
    await enroll();
    expect(preferenceWrites, [false, true]);
    expect(jsonDecode(secret!)['email'], 'reader@example.com');
    expect(await service.signIn(), BiometricSignInResult.signedIn);
    expect(reads, 1);
    expect(logins, 1);
  });

  test('canceling biometric read never invokes backend sign-in', () async {
    await enroll();
    readOverride = () async => throw PlatformException(code: 'auth_canceled');
    expect(await service.signIn(), BiometricSignInResult.canceled);
    expect(logins, 0);
    expect(enabled, isTrue);
  });

  test('unavailable biometrics do not read protected credentials', () async {
    await enroll();
    available = false;
    expect(await service.signIn(), BiometricSignInResult.unavailable);
    expect(reads, 0);
    expect(logins, 0);
  });

  test('invalid backend credentials remove saved login', () async {
    await enroll();
    loginOverride = (_, __) async => throw const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        );
    expect(await service.signIn(), BiometricSignInResult.expired);
    expect(enabled, isFalse);
    expect(secret, isNull);
  });

  test('network failures retain enrollment for retry', () async {
    await enroll();
    loginOverride = (_, __) async => throw Exception('offline');
    expect(await service.signIn(), BiometricSignInResult.failed);
    expect(enabled, isTrue);
    expect(secret, isNotNull);
  });

  test('missing protected data requires password login again', () async {
    await enroll();
    secret = null;
    expect(await service.signIn(), BiometricSignInResult.expired);
    expect(enabled, isFalse);
    expect(logins, 0);
  });

  test('malformed credentials are cleared without backend login', () async {
    await enroll();
    secret = '{"email": 1}';
    expect(await service.signIn(), BiometricSignInResult.expired);
    expect(enabled, isFalse);
    expect(logins, 0);
  });

  test('forget removes protected credentials and prevents further login',
      () async {
    await enroll();
    await service.disable();
    expect(secret, isNull);
    expect(await service.signIn(), BiometricSignInResult.unavailable);
    expect(reads, 0);
  });

  test('concurrent taps only invoke one biometric read and login', () async {
    await enroll();
    final prompt = Completer<String?>();
    readOverride = () => prompt.future;
    final first = service.signIn();
    await Future<void>.delayed(Duration.zero);
    expect(await service.signIn(), BiometricSignInResult.canceled);
    prompt.complete(secret);
    expect(await first, BiometricSignInResult.signedIn);
    expect(reads, 1);
    expect(logins, 1);
  });
}
