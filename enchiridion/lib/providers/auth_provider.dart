import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _init();
  }

  void _init() {
    final session = AuthService.currentSession;
    if (session != null) {
      _user = session.user;
      _status = AuthStatus.authenticated;
      AccessService.instance.loadAccess();
    } else {
      _status = AuthStatus.unauthenticated;
    }

    AuthService.authStateChanges.listen((event) {
      _user = event.session?.user;
      if (event.session != null) {
        _status = AuthStatus.authenticated;
        AccessService.instance.loadAccess();
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
      // Email confirmation required — session is null until user confirms
      if (response.session == null && response.user != null) {
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
    } catch (e) {
      notifyListeners();
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
