import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Checks display-name availability via the `is_display_name_available`
  /// RPC (see scripts/sql/002_unique_display_name.sql) — a plain `select`
  /// against `profiles` can't do this client-side, since its RLS policy only
  /// lets a user read their own row.
  ///
  /// Fails open (returns true) on any error — e.g. the migration hasn't been
  /// run yet, or the network is down — so a broken check never blocks
  /// sign-up outright; the DB's unique index is still the real guard against
  /// a genuine collision, this is just the friendlier up-front UX.
  static Future<bool> isDisplayNameAvailable(String displayName) async {
    try {
      final result = await _client.rpc(
        'is_display_name_available',
        params: {'name': displayName},
      );
      return result as bool;
    } catch (_) {
      return true;
    }
  }

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
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Completes registration with the 6-digit code emailed on sign-up.
  ///
  /// Requires the "Confirm signup" email template to render `{{ .Token }}`.
  /// On success a session is created, so the auth state listener picks it up
  /// exactly as it would after a normal sign-in.
  static Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
  }

  /// Sends a fresh sign-up code. Supabase rate-limits this server-side, so the
  /// caller should also throttle to avoid burning the quota on double-taps.
  static Future<void> resendEmailOtp(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  static Future<void> ensureProfile(User user) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        final meta = user.userMetadata ?? {};
        await _client.from('profiles').upsert({
          'id': user.id,
          'display_name': meta['display_name'] as String? ?? '',
          'role': meta['role'] as String? ?? 'student',
        });
      }
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();

    return response;
  }

  // ── Device binding (one account, one primary device + occasional new
  // device — see AuthProvider.deviceGateStatus and
  // .planning/phases/01-email-device-binding/ for the locked design) ──────

  /// Rolling window for authorizing a second device, per decision D-03 —
  /// deliberately rolling from [getProfile]'s `last_device_switch`, not a
  /// calendar month.
  static const Duration deviceSwitchCooldown = Duration(days: 30);

  /// True if this account is exempt from the one-account-per-device gate
  /// entirely (the `device_binding_exempt` column — set by hand in SQL for
  /// shared QA/test accounts, never through app UI). Checked before anything
  /// else in `AuthProvider._checkDeviceGate`.
  static bool isDeviceBindingExempt(Map<String, dynamic> profile) {
    return profile['device_binding_exempt'] == true;
  }

  /// True if [fingerprint] is the account's bound device or was previously
  /// authorized as an additional device.
  static bool matchesAuthorizedDevice(
    Map<String, dynamic> profile,
    String fingerprint,
  ) {
    if (profile['device_id'] == fingerprint) return true;
    final authorized = profile['authorized_devices'] as List<dynamic>? ?? [];
    return authorized.any(
      (entry) => (entry as Map<String, dynamic>)['device_id'] == fingerprint,
    );
  }

  static bool canAuthorizeNewDevice(Map<String, dynamic> profile) {
    final last = _parseLastSwitch(profile);
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last) >= deviceSwitchCooldown;
  }

  /// Null when a new device could be authorized right now.
  static DateTime? getNextDeviceSwitchDate(Map<String, dynamic> profile) {
    final last = _parseLastSwitch(profile);
    if (last == null) return null;
    final next = last.add(deviceSwitchCooldown);
    return next.isAfter(DateTime.now().toUtc()) ? next : null;
  }

  static DateTime? _parseLastSwitch(Map<String, dynamic> profile) {
    final raw = profile['last_device_switch'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// First-ever binding for this account: sets `device_id` + `bound_at`.
  /// Only ever called once per account, when `getProfile()['device_id']` is
  /// still null (see `DeviceAuthDialog`).
  static Future<void> bindDevice(String fingerprint) async {
    final user = currentUser;
    if (user == null) throw StateError('Not authenticated');
    await _client.from('profiles').upsert({
      'id': user.id,
      'device_id': fingerprint,
      'bound_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Adds [fingerprint] to `authorized_devices` (an accumulating list — this
  /// never replaces the primary `device_id`) and resets the 30-day cooldown.
  /// Caller must have already confirmed [canAuthorizeNewDevice].
  static Future<void> authorizeNewDevice(
    Map<String, dynamic> profile,
    String fingerprint,
  ) async {
    final user = currentUser;
    if (user == null) throw StateError('Not authenticated');
    final now = DateTime.now().toUtc().toIso8601String();
    final authorized =
        List<dynamic>.from(profile['authorized_devices'] as List<dynamic>? ?? [])
          ..add({'device_id': fingerprint, 'authorized_at': now});
    await _client.from('profiles').upsert({
      'id': user.id,
      'authorized_devices': authorized,
      'last_device_switch': now,
    });
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
