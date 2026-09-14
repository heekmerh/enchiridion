import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Platform-specific device fingerprinting for the one-account-per-device
/// gate (see `AuthProvider.deviceGateStatus`).
///
/// Per the locked design (D-01, `.planning/phases/01-email-device-binding/`):
/// - Android: the platform's device id (via `device_info_plus`, which reads
///   `Settings.Secure.ANDROID_ID` under the hood).
/// - iOS: a UUID generated on first launch and persisted in secure storage —
///   deliberately not `identifierForVendor`, which is not stable across an
///   uninstall/reinstall and would silently "forget" the binding.
/// - Fallback (anything else, or if a platform API throws): a random UUID,
///   also persisted, so it's still stable across calls.
///
/// This always succeeds and never blocks the user — a failure anywhere in
/// this chain falls through to the next option down to the fallback UUID.
class DeviceService {
  static const String _iosUuidKey = 'device_ios_uuid';
  static const String _fallbackUuidKey = 'device_fallback_uuid';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceFingerprint() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidId();
      } else if (Platform.isIOS) {
        return await _getOrCreatePersistentUuid(_iosUuidKey);
      } else {
        return await _getOrCreatePersistentUuid(_fallbackUuidKey);
      }
    } catch (_) {
      return await _getOrCreatePersistentUuid(_fallbackUuidKey);
    }
  }

  static Future<String> _getAndroidId() async {
    try {
      final info = await _deviceInfo.androidInfo;
      if (info.id.isNotEmpty) return info.id;
    } catch (_) {
      // Falls through to the fallback UUID below.
    }
    return _getOrCreatePersistentUuid(_fallbackUuidKey);
  }

  static Future<String> _getOrCreatePersistentUuid(String key) async {
    try {
      final stored = await _secureStorage.read(key: key);
      if (stored != null && stored.isNotEmpty) return stored;

      final generated = const Uuid().v4();
      await _secureStorage.write(key: key, value: generated);
      return generated;
    } catch (_) {
      // Secure storage itself is unavailable — return an unpersisted UUID
      // rather than block. Rare, and means this call may return a different
      // id next time, which is an acceptable degradation (see class doc).
      return const Uuid().v4();
    }
  }
}
