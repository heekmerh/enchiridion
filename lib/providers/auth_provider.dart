import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/access_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _error;

  // Per D-01, D-03: tracks if user needs device binding after email verification
  bool _requiresDeviceBinding = false;
  String? _deviceAuthorizationState; // 'pending' or null

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Per D-01, D-03: expose for routing to show device binding dialogs
  bool get requiresDeviceBinding => _requiresDeviceBinding;
  String? get deviceAuthorizationState => _deviceAuthorizationState;

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

    // Per D-01, D-03: listen to auth state changes to detect email confirmation
    AuthService.authStateChanges.listen((event) {
      _user = event.session?.user;
      if (event.session != null) {
        _status = AuthStatus.authenticated;
        AccessService.instance.loadAccess();

        // Create profile from metadata if this is the first sign-in after
        // email confirmation (profile may not exist yet)
        AuthService.ensureProfile(event.session!.user);

        // Per D-01, D-03: Check if device binding is needed on first login
        // This happens after email confirmation when user has no device_id yet
        _checkDeviceBindingRequired(event.session!.user);
      } else {
        _status = AuthStatus.unauthenticated;
        AccessService.instance.clearCache();
        _requiresDeviceBinding = false;
        _deviceAuthorizationState = null;
      }
      _error = null;
      notifyListeners();
    });
  }

  /// Per D-01, D-03: Check if current user needs device binding.
  /// Shows DeviceAuthDialog if user just confirmed email and has no device_id.
  Future<void> _checkDeviceBindingRequired(User user) async {
    try {
      final profile = await AuthService.getProfile();
      if (profile == null) return;

      // If device_id is null, user needs to bind a device
      if (profile['device_id'] == null) {
        _requiresDeviceBinding = true;
        notifyListeners();
      }
    } catch (_) {
      // Silently fail; device binding check is optional
    }
  }

  /// Called after user successfully binds their first device via DeviceAuthDialog.
  /// Clears the device binding requirement flag.
  void deviceBindingComplete() {
    _requiresDeviceBinding = false;
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    _error = null;
    _deviceAuthorizationState = null;

    try {
      await AuthService.signIn(email: email, password: password);

      // Per D-01, D-03: After successful signin, check device matching
      final user = AuthService.currentUser;
      if (user != null) {
        await _handleDeviceMatching(user);
      }

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

  /// Per D-01, D-03: Handles device matching logic after signin.
  /// If device matches primary device or authorized devices, allows login.
  /// If device doesn't match and quota available, triggers authorization dialog.
  /// If device doesn't match and quota exhausted, shows error and returns to login.
  Future<void> _handleDeviceMatching(User user) async {
    try {
      final currentFingerprint =
          await DeviceService.getDeviceFingerprint();

      // Check if device matches (per D-01)
      final matches =
          await AuthService.matchesAuthorizedDevice(user, currentFingerprint);
      if (matches) {
        // Device is authorized, login proceeds normally
        return;
      }

      // Device doesn't match - check quota (per D-03)
      final canAuthorize = await AuthService.canAuthorizeNewDevice(user);

      if (canAuthorize) {
        // User can authorize this device
        _deviceAuthorizationState = 'pending_authorization';
        notifyListeners();
      } else {
        // Quota exhausted
        final nextDate = await AuthService.getNextDeviceSwitchDate(user);
        _error = nextDate != null
            ? 'Device not authorized. Next available: ${nextDate.month}/${nextDate.day}/${nextDate.year}'
            : 'Device not authorized.';
        _deviceAuthorizationState = 'quota_exhausted';
        notifyListeners();
      }
    } catch (_) {
      // If device check fails, allow login to proceed
      // (service layer doesn't block on device errors)
    }
  }

  /// Called when user authorizes a new device.
  /// Persists the device to authorized_devices and updates quota.
  Future<void> deviceAuthorizationComplete() async {
    _deviceAuthorizationState = null;
    notifyListeners();
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
        // Per D-02: User must verify email before device binding
        _requiresDeviceBinding = false;
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
    _requiresDeviceBinding = false;
    _deviceAuthorizationState = null;
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
