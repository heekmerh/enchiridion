import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Platform-specific device fingerprinting for the one-account-per-device
/// gate (`AuthProvider.deviceGateStatus`, D-01): Android's `ANDROID_ID` via
/// `device_info_plus`; iOS a UUID persisted in secure storage (not
/// `identifierForVendor`, which resets on reinstall); anything else, or a
/// thrown platform API, falls through to a persisted random UUID. Always
/// succeeds and never blocks the user.
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
