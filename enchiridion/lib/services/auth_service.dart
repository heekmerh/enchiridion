import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';
import '../config/google_sign_in_config.dart';

class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Checks display-name availability via the `is_display_name_available`
  /// RPC, since a plain `select` against `profiles` can't do this
  /// client-side (its RLS policy only lets a user read their own row). Fails
  /// open (returns true) on any error, so a broken check never blocks
  /// sign-up — the DB's unique index is still the real guard.
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
    required String termsVersion,
  }) async {
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: '$kBackendBaseUrl/verify-email',
      data: {
        'display_name': displayName,
        'role': role,
        'terms_version': termsVersion,
        'terms_accepted_at': acceptedAt,
        'signup_source': 'android_app',
      },
    );

    // Only insert profile if we have a live session (email confirmation off).
    // When confirmation is required, the session is null here — the profile
    // will be created on first sign-in after the user confirms their email.
    if (response.session != null && response.user != null) {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'display_name': displayName,
        'role': role,
        'terms_version': termsVersion,
        'terms_accepted_at': acceptedAt,
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
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static Future<AuthResponse?> signInWithGoogle() async {
    final rawNonce = _randomNonce();
    final google = GoogleSignIn.instance;
    // Google signs the hashed nonce into the ID token and Supabase checks it against the raw one, so a captured token cannot be replayed.
    await google.initialize(
      serverClientId: kGoogleWebClientId,
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google did not return an identity token.');
    }
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  static Future<void> recordTermsAcceptance(String termsVersion) async {
    await _client.rpc('accept_terms', params: {'p_version': termsVersion});
  }

  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: '$kBackendBaseUrl/reset-password',
    );
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
          'terms_version': meta['terms_version'] as String?,
          'terms_accepted_at': meta['terms_accepted_at'] as String?,
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
    final authorized = List<dynamic>.from(
        profile['authorized_devices'] as List<dynamic>? ?? [])
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
