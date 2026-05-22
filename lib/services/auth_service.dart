import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName, 'role': role},
    );

    // Only insert profile if we have a live session (email confirmation off).
    // When confirmation is required, the session is null here — the profile
    // will be created on first sign-in after the user confirms their email.
    // Device binding happens on first login after email verification (per D-01).
    if (response.session != null && response.user != null) {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'display_name': displayName,
        'role': role,
      });
    }

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response =
        await _client.auth.signInWithPassword(email: email, password: password);

    // Note: Device matching logic is handled in AuthProvider after signIn succeeds.
    // This service layer does not block login on device mismatch (separation of concerns).
    // Per D-01, device authorization prompts are shown by UI/Provider layer.

    return response;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Creates or updates user profile after email confirmation.
  /// Per D-01, stores device_id and bound_at on first login.
  static Future<void> ensureProfile(User user) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id, device_id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // First profile creation — happens after email confirmation
        final meta = user.userMetadata ?? {};
        final now = DateTime.now().toUtc().toIso8601String();

        // Retrieve device fingerprint and bind first device (per D-01)
        final deviceId = await DeviceService.getDeviceFingerprint();

        await _client.from('profiles').upsert({
          'id': user.id,
          'display_name': meta['display_name'] as String? ?? '',
          'role': meta['role'] as String? ?? 'student',
          'device_id': deviceId, // First device binding (per D-01)
          'bound_at': now, // Record binding timestamp
          'email_confirmed': true, // Mark email as confirmed
          'authorized_devices': [], // Initialize empty authorized devices list
        });
      } else if (existing['device_id'] == null) {
        // Profile exists but device not yet bound (edge case)
        final now = DateTime.now().toUtc().toIso8601String();
        final deviceId = await DeviceService.getDeviceFingerprint();

        await _client.from('profiles').upsert({
          'id': user.id,
          'device_id': deviceId,
          'bound_at': now,
          'email_confirmed': true,
        });
      }
    } catch (_) {
      // Silently fail if profile creation fails; user can retry
    }
  }

  /// Checks if current device fingerprint matches authorized devices.
  /// Per D-01, returns true if device matches primary device_id or is in authorized_devices.
  /// Returns false if device doesn't match (UI will show authorization prompt).
  static Future<bool> matchesAuthorizedDevice(
      User user, String currentFingerprint) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('device_id, authorized_devices')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return false;
      }

      // Check if matches primary device
      if (profile['device_id'] == currentFingerprint) {
        return true;
      }

      // Check if in authorized devices list
      final authorizedDevices = profile['authorized_devices'] as List?;
      if (authorizedDevices != null) {
        for (final device in authorizedDevices) {
          if (device is Map && device['device_id'] == currentFingerprint) {
            return true;
          }
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if user can authorize a new device.
  /// Per D-01, uses rolling 30-day window from last_device_switch.
  /// Returns true if user hasn't switched yet or 30+ days have passed.
  static Future<bool> canAuthorizeNewDevice(User user) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('last_device_switch')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        return true; // First device, can authorize
      }

      final lastSwitch = profile['last_device_switch'];
      if (lastSwitch == null) {
        return true; // Never switched, can authorize new device
      }

      // Parse timestamp and check if 30 days have elapsed
      final lastSwitchTime = DateTime.parse(lastSwitch as String);
      final now = DateTime.now().toUtc();
      final daysSinceSwitch = now.difference(lastSwitchTime).inDays;

      return daysSinceSwitch >= 30; // Per D-01, rolling 30-day window
    } catch (_) {
      return false; // Err on side of caution if query fails
    }
  }

  /// Returns next available device switch date if user has exhausted quota.
  /// Per D-01, calculates 30 days from last_device_switch.
  /// Returns null if user can authorize now.
  static Future<DateTime?> getNextDeviceSwitchDate(User user) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('last_device_switch')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['last_device_switch'] == null) {
        return null; // Can switch now
      }

      final lastSwitch = DateTime.parse(profile['last_device_switch'] as String);
      final nextSwitch = lastSwitch.add(const Duration(days: 30));

      return nextSwitch;
    } catch (_) {
      return null;
    }
  }

  /// Authorizes a new device by adding it to authorized_devices list.
  /// Per D-01, updates last_device_switch timestamp.
  static Future<void> authorizeNewDevice(User user, String deviceId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('authorized_devices')
          .eq('id', user.id)
          .maybeSingle();

      final authorizedDevices = profile?['authorized_devices'] as List? ?? [];
      final now = DateTime.now().toUtc().toIso8601String();

      // Append new device to authorized_devices
      authorizedDevices.add({
        'device_id': deviceId,
        'authorized_at': now,
      });

      // Update profile with new device and reset switch quota
      await _client.from('profiles').upsert({
        'id': user.id,
        'authorized_devices': authorizedDevices,
        'last_device_switch': now, // Reset quota clock
      });
    } catch (_) {
      // Silently fail if authorization fails
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  static Future<void> updateDisplayName(String displayName) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
    });
  }

  /// Uploads [file] to the `avatars` storage bucket and saves the public URL
  /// in the user's profile row. Returns the public URL.
  static Future<String> uploadAvatar(File file) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user.id}/avatar.$ext';

    await _client.storage.from('avatars').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('avatars').getPublicUrl(path);

    await _client.from('profiles').upsert({
      'id': user.id,
      'avatar_url': url,
    });

    return url;
  }
}
