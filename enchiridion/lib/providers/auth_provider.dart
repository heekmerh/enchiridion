import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';
import '../services/question_review_sync_service.dart';
import '../services/storage_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  final StorageService _storage;

  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider(this._storage) {
    _init();
  }

  void _init() {
    final session = AuthService.currentSession;
    if (session != null) {
      _user = session.user;
      _status = AuthStatus.authenticated;
      AccessService.instance.loadAccess();
      QuestionReviewSyncService(_storage).pullAndMergeAll();
    } else {
      _status = AuthStatus.unauthenticated;
    }

    AuthService.authStateChanges.listen((event) {
      _user = event.session?.user;
      if (event.session != null) {
        _status = AuthStatus.authenticated;
        AccessService.instance.loadAccess();
        // Catches up on progress made on another device — or made on this
        // one while offline and only now reaching Supabase — before the
        // user starts studying this session.
        QuestionReviewSyncService(_storage).pullAndMergeAll();
        // Create profile from metadata if this is the first sign-in after
        // email confirmation (profile may not exist yet)
        AuthService.ensureProfile(event.session!.user);
      } else {
        _status = AuthStatus.unauthenticated;
        AccessService.instance.clearCache();
      }
      _error = null;
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) async {
    _error = null;
    try {
      await AuthService.signIn(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return 'Incorrect email or password';
    } catch (_) {
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
  }) async {
    _error = null;
    try {
      final response = await AuthService.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      // No session means the account is not usable yet. That covers both
      // "confirmation required" and GoTrue's obfuscated reply for an email
      // that is already registered — which carries neither a session nor a
      // user, to avoid confirming the address exists.
      //
      // Do NOT test `user != null` here: AuthResponse sets user from the
      // session when the payload has no user id, so the obfuscated reply
      // leaves both null and would otherwise read as a successful sign-up
      // and drop the caller into the app with no session.
      if (response.session == null) {
        return 'confirm_email';
      }
      return null;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      if (e.message.toLowerCase().contains('already registered')) {
        return 'An account with this email already exists.';
      }
      return e.message;
    } on PostgrestException catch (e) {
      notifyListeners();
      // 23505 = unique_violation. The pre-submit availability check in
      // RegisterScreen makes this rare — only a genuine race with another
      // sign-up choosing the identical name in the same instant — but the
      // unique index (scripts/sql/002_unique_display_name.sql) is the real
      // guard, so it must still be handled here.
      if (e.code == '23505') {
        return 'That display name is already taken — please choose another.';
      }
      return 'Something went wrong. Please try again.';
    } catch (e) {
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  /// Verifies the 6-digit sign-up code. Returns null on success, or a
  /// user-facing message. A successful call creates a session, which the
  /// authStateChanges listener above turns into AuthStatus.authenticated.
  Future<String?> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    _error = null;
    try {
      final response =
          await AuthService.verifyEmailOtp(email: email, token: token);
      if (response.session == null) {
        return 'That code could not be verified. Please try again.';
      }
      return null;
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      // Supabase deliberately returns ONE message for both cases — "Token has
      // expired or is invalid" — so the two cannot be told apart here. Do not
      // branch on 'expired' vs 'invalid': the combined string matches
      // 'expired' first and would report a simply wrong code as expired.
      //
      // A code is most often rejected because it is stale, not old: only the
      // code from the newest email is valid, so any earlier one fails.
      final message = e.message.toLowerCase();
      if (message.contains('expired') || message.contains('invalid')) {
        return 'That code did not work. Codes expire after 1 hour, and only '
            'the code from the most recent email is valid — check the latest '
            'email, or tap "Resend code".';
      }
      return e.message;
    } catch (_) {
      notifyListeners();
      return 'Something went wrong. Please try again.';
    }
  }

  /// Requests a new sign-up code. Returns null on success, or a message.
  Future<String?> resendEmailOtp(String email) async {
    try {
      await AuthService.resendEmailOtp(email);
      return null;
    } on AuthException catch (e) {
      // Supabase rate-limits resends; surface that rather than a generic error
      // so the user knows to wait instead of retrying immediately.
      if (e.message.toLowerCase().contains('security purposes') ||
          e.message.toLowerCase().contains('rate limit')) {
        return 'Please wait a moment before requesting another code.';
      }
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await AuthService.resetPassword(email);
      return null;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }
}
