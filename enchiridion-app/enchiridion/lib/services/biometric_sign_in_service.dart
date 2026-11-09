import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum BiometricSignInResult { signedIn, unavailable, canceled, expired, failed }

class BiometricSignInService {
  BiometricSignInService({
    Future<bool> Function()? available,
    Future<bool> Function()? enabled,
    Future<void> Function(bool)? setEnabled,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    Future<void> Function()? delete,
    Future<void> Function(String, String)? signIn,
  })  : _available = available ?? _deviceAvailable,
        _enabled = enabled ?? _readEnabled,
        _setEnabled = setEnabled ?? _writeEnabled,
        _read = read ?? (() => _storage.read(key: _key)),
        _write = write ?? ((value) => _storage.write(key: _key, value: value)),
        _delete = delete ?? (() => _storage.deleteAll()),
        _signIn = signIn ?? _passwordSignIn;

  static final instance = BiometricSignInService();
  static const _key = 'credentials';
  static const _preference = 'biometric_sign_in_enabled';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'enchiridion_biometric_login',
      enforceBiometrics: true,
      requireBiometricsPerOperation: true,
      resetOnError: false,
      biometricType: AndroidBiometricType.strongBiometricOnly,
      biometricPromptTitle: 'Sign in to Enchiridion',
      biometricPromptSubtitle:
          'Use your fingerprint or supported face recognition',
      biometricPromptNegativeButton: 'Use password',
    ),
  );

  final Future<bool> Function() _available;
  final Future<bool> Function() _enabled;
  final Future<void> Function(bool) _setEnabled;
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Future<void> Function() _delete;
  final Future<void> Function(String, String) _signIn;
  bool _busy = false;

  static Future<bool> _deviceAvailable() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final android = await DeviceInfoPlugin().androidInfo;
    if (android.version.sdkInt < 28) return false;
    final enrolled = await LocalAuthentication().getAvailableBiometrics();
    return enrolled.contains(BiometricType.strong) ||
        enrolled.contains(BiometricType.fingerprint);
  }

  static Future<bool> _readEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_preference) ?? false;

  static Future<void> _writeEnabled(bool value) async {
    final saved = await (await SharedPreferences.getInstance())
        .setBool(_preference, value);
    if (!saved) throw StateError('Could not save biometric preference');
  }

  static Future<void> _passwordSignIn(String email, String password) async {
    await AuthService.signIn(email: email, password: password);
  }

  Future<bool> isAvailable() async {
    try {
      return await _available();
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() => _enabled();

  Future<void> enable(String email, String password) async {
    if (!await isAvailable()) throw StateError('Biometrics unavailable');
    await _setEnabled(false);
    await _write(jsonEncode({'email': email, 'password': password}));
    await _setEnabled(true);
  }

  Future<void> disable() async {
    await _setEnabled(false);
    await _delete();
  }

  Future<void> _invalidate() async {
    await _setEnabled(false);
    try {
      await _delete();
    } catch (_) {}
  }

  Future<BiometricSignInResult> signIn() async {
    if (_busy) return BiometricSignInResult.canceled;
    _busy = true;
    try {
      if (!await isAvailable() || !await isEnabled()) {
        return BiometricSignInResult.unavailable;
      }
      final secret = await _read();
      if (secret == null) {
        await _invalidate();
        return BiometricSignInResult.expired;
      }
      final credentials = jsonDecode(secret);
      if (credentials is! Map<String, dynamic> ||
          credentials['email'] is! String ||
          credentials['password'] is! String) {
        throw const FormatException();
      }
      final email = credentials['email'] as String;
      final password = credentials['password'] as String;
      if (email.isEmpty || password.isEmpty) throw const FormatException();
      await _signIn(email, password);
      return BiometricSignInResult.signedIn;
    } on AuthException catch (error) {
      if (error.code == 'invalid_credentials') {
        await _invalidate();
        return BiometricSignInResult.expired;
      }
      return BiometricSignInResult.failed;
    } on PlatformException catch (error) {
      final details = '${error.code} ${error.message}'.toLowerCase();
      if (details.contains('cancel') || details.contains('negative button')) {
        return BiometricSignInResult.canceled;
      }
      return BiometricSignInResult.failed;
    } on FormatException {
      await _invalidate();
      return BiometricSignInResult.expired;
    } catch (_) {
      return BiometricSignInResult.failed;
    } finally {
      _busy = false;
    }
  }
}
