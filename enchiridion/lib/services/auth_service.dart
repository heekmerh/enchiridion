import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

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
