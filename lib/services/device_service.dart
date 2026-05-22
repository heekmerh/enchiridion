import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// DeviceService handles platform-specific device fingerprinting.
///
/// Per decision D-01:
/// - Android: Retrieves ANDROID_ID via platform channel
/// - iOS: Generates UUID on first launch, stores in secure storage
/// - Fallback: Generates random UUID if platform APIs fail
class DeviceService {
  static const String _androidIdKey = 'device_android_id';
  static const String _iosUuidKey = 'device_ios_uuid';
  static const String _fallbackUuidKey = 'device_fallback_uuid';
  static const platform = MethodChannel('com.example.enchiridion/device');

  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  /// Retrieves the device fingerprint.
  /// Returns platform-specific ID (ANDROID_ID on Android, UUID on iOS),
  /// or a fallback UUID if platform APIs are unavailable.
  ///
  /// Per D-01, this method always succeeds and returns a device ID
  /// without blocking the user.
  static Future<String> getDeviceFingerprint() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidId();
      } else if (Platform.isIOS) {
        return await _getOrCreateIosUuid();
      } else {
        // Fallback for other platforms (web, Windows, etc.)
        return await _getOrCreateFallbackUuid();
      }
    } catch (e) {
      // If platform detection or retrieval fails, use fallback UUID
      return await _getOrCreateFallbackUuid();
    }
  }

  /// Retrieves Android ANDROID_ID via platform channel.
  /// Falls back to UUID if platform channel fails.
  static Future<String> _getAndroidId() async {
    try {
      final String result =
          await platform.invokeMethod<String>('getAndroidId') ?? '';
      if (result.isNotEmpty) {
        return result;
      }
    } catch (e) {
      // Platform channel call failed or returned empty
    }
    // Fallback to UUID if ANDROID_ID unavailable
    return await _getOrCreateFallbackUuid();
  }

  /// Retrieves or creates iOS UUID.
  /// On first launch, generates UUID and stores in secure storage.
  /// On subsequent launches, retrieves the stored UUID.
  /// Per D-01, this provides consistent device identification across app sessions.
  static Future<String> _getOrCreateIosUuid() async {
    try {
      final stored = await _secureStorage.read(key: _iosUuidKey);
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }

      // Generate new UUID
      final uuid = const Uuid().v4();
      await _secureStorage.write(key: _iosUuidKey, value: uuid);
      return uuid;
    } catch (e) {
      // Secure storage failed, use fallback
      return await _getOrCreateFallbackUuid();
    }
  }

  /// Retrieves or creates a fallback UUID.
  /// Used when platform APIs fail or on unsupported platforms.
  /// Per D-01, this ensures the app remains functional even if
  /// platform-specific device IDs are unavailable.
  static Future<String> _getOrCreateFallbackUuid() async {
    try {
      final stored = await _secureStorage.read(key: _fallbackUuidKey);
      if (stored != null && stored.isNotEmpty) {
        return stored;
      }

      // Generate new UUID
      final uuid = const Uuid().v4();
      await _secureStorage.write(key: _fallbackUuidKey, value: uuid);
      return uuid;
    } catch (e) {
      // As a last resort, generate a UUID without persisting
      // (this is a rare edge case)
      return const Uuid().v4();
    }
  }

  /// Stores a device ID to secure storage (mainly for testing/manual management).
  /// In normal flow, device IDs are stored automatically by DeviceService.
  static Future<void> storeDeviceId(String id) async {
    try {
      if (Platform.isAndroid) {
        await _secureStorage.write(key: _androidIdKey, value: id);
      } else if (Platform.isIOS) {
        await _secureStorage.write(key: _iosUuidKey, value: id);
      } else {
        await _secureStorage.write(key: _fallbackUuidKey, value: id);
      }
    } catch (_) {
      // Silently fail if storage is unavailable
    }
  }

  /// Retrieves a previously stored device ID from secure storage.
  /// Returns null if no device ID is stored.
  static Future<String?> getStoredDeviceId() async {
    try {
      if (Platform.isAndroid) {
        return await _secureStorage.read(key: _androidIdKey);
      } else if (Platform.isIOS) {
        return await _secureStorage.read(key: _iosUuidKey);
      } else {
        return await _secureStorage.read(key: _fallbackUuidKey);
      }
    } catch (_) {
      return null;
    }
  }

  /// Clears all stored device IDs from secure storage.
  /// Useful for testing or factory reset scenarios.
  static Future<void> clearStoredDeviceId() async {
    try {
      await _secureStorage.delete(key: _androidIdKey);
      await _secureStorage.delete(key: _iosUuidKey);
      await _secureStorage.delete(key: _fallbackUuidKey);
    } catch (_) {
      // Silently fail if storage is unavailable
    }
  }
}
