import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/access_service.dart';
import '../services/device_service.dart';
import '../services/play_billing_service.dart';
import '../services/question_review_sync_service.dart';
import '../services/storage_service.dart';
import '../services/user_data_sync_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

/// Where a signed-in user stands on the one-account-per-device gate. See
/// `.planning/phases/01-email-device-binding/` for the locked design (D-03)
/// and `AuthGate`, the widget that renders each of these.
enum DeviceGateStatus {
  /// Fetching the profile / computing the device fingerprint.
  checking,

  /// This device is the account's bound device, or a previously authorized
  /// one — the normal, every-day state.
  boundToThisDevice,

  /// The account has never bound a device yet (`device_id` is null).
  needsFirstBind,

  /// This device doesn't match the bound device or any authorized one.
  /// [AuthProvider.canAuthorizeNewDevice] says whether the 30-day cooldown
  /// allows adding it right now.
  needsAuthorization,
}

class AuthProvider with ChangeNotifier {
  final StorageService _storage;

  AuthStatus _status = AuthStatus.loading;
  User? _user;
  String? _error;

  DeviceGateStatus _deviceGateStatus = DeviceGateStatus.checking;
  bool _canAuthorizeNewDevice = true;
  DateTime? _nextDeviceSwitchDate;
  String? _deviceFingerprint;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  DeviceGateStatus get deviceGateStatus => _deviceGateStatus;
  bool get canAuthorizeNewDevice => _canAuthorizeNewDevice;
  DateTime? get nextDeviceSwitchDate => _nextDeviceSwitchDate;

  /// True while the first cross-device sync is running with visible
  /// progress (new device that never synced). `AuthGate` shows the sync
  /// splash instead of the library until this clears.
  bool get initialSyncRunning => _initialSyncRunning;
  bool _initialSyncRunning = false;

  /// Human-readable stage of the running initial sync (`SyncSplashScreen`).
  String get syncStageLabel => _syncStageLabel;
  String _syncStageLabel = '';

  /// 0..1 progress across push (8 stages) + pull (9 stages) = 17 ticks.
  double get syncProgress => _syncProgress;
  double _syncProgress = 0;
  static const int syncTotalStages = 17;

  bool _skipSyncRequested = false;

  /// Lets the user proceed offline without waiting for the initial sync.
  /// The sync futures keep running detached; their results still merge when
  /// they land, and the splash returns next launch until one completes.
  void skipInitialSync() {
    _skipSyncRequested = true;
    _initialSyncRunning = false;
    notifyListeners();
  }

  AppLifecycleListener? _lifecycle;

  AuthProvider(this._storage) {
    _init();
    _lifecycle = AppLifecycleListener(onResume: _refreshEntitlements);
  }

  void _refreshEntitlements() {
    if (_status != AuthStatus.authenticated) return;
    unawaited(AccessService.instance.loadAccess());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _init() {
    final session = AuthService.currentSession;
    if (session != null) {
      _user = session.user;
      _status = AuthStatus.authenticated;
      AccessService.instance.loadAccess();
      QuestionReviewSyncService(_storage).pullAndMergeAll();
      unawaited(_runUserDataSync());
      _checkDeviceGate();
    } else {
      _status = AuthStatus.unauthenticated;
    }

    AuthService.authStateChanges.listen((event) async {
      _user = event.session?.user;
      if (event.session != null) {
        _status = AuthStatus.authenticated;
        AccessService.instance.loadAccess();
        if (event.event == AuthChangeEvent.signedIn) {
          unawaited(PlayBillingService.instance.restore(reportOutcome: false));
        }
        // Catches up on progress made on another device — or made on this
        // one while offline and only now reaching Supabase — before the
        // user starts studying this session.
        QuestionReviewSyncService(_storage).pullAndMergeAll();
        unawaited(_runUserDataSync());
        // Awaited: the device gate check right after needs the profile row
        // to exist, or it reads a false "needsFirstBind" from an empty one.
        await AuthService.ensureProfile(event.session!.user);
        await _checkDeviceGate();
      } else {
        _status = AuthStatus.unauthenticated;
        _deviceGateStatus = DeviceGateStatus.checking;
        AccessService.instance.clearCache();
      }
      _error = null;
      notifyListeners();
    });
  }

  /// Pushes this device's offline user-data changes, then pulls everything.
  /// First sync runs visibly: [initialSyncRunning] stays true with per-stage
  /// progress so `AuthGate` can show the sync splash; later syncs refresh
  /// silently.
  Future<void> _runUserDataSync() async {
    final sync = UserDataSyncService(_storage);
    if (_storage.hasCompletedInitialSync()) {
      unawaited(sync.pushAll());
      unawaited(sync.pullAndMergeAll());
      return;
    }
    _skipSyncRequested = false;
    _initialSyncRunning = true;
    _syncStageLabel = 'Preparing…';
    _syncProgress = 0;
    notifyListeners();
    try {
      await sync.pushAll(onProgress: (label, done, total) {
        if (_skipSyncRequested) return;
        _syncStageLabel = 'Backing up $label…';
        _syncProgress = done / syncTotalStages;
        notifyListeners();
      });
      if (_skipSyncRequested || AuthService.currentUser == null) return;
      await sync.pullAndMergeAll(onProgress: (label, done, total) {
        if (_skipSyncRequested) return;
        _syncStageLabel = 'Restoring $label…';
        _syncProgress = (8 + done) / syncTotalStages;
        notifyListeners();
      });
      if (_skipSyncRequested) return;
      await _storage.setInitialSyncComplete();
    } finally {
      _initialSyncRunning = false;
      notifyListeners();
    }
  }

  /// Compares this device's fingerprint against the account's bound/
  /// authorized devices and sets [deviceGateStatus] accordingly. Fails open
  /// on any error, matching this app's fail-open pattern elsewhere — a
  /// network blip must not lock a legitimate user out of a clinical
  /// reference app.
  Future<void> _checkDeviceGate() async {
    _deviceGateStatus = DeviceGateStatus.checking;
    notifyListeners();
    try {
      final fingerprint = await DeviceService.getDeviceFingerprint();
      _deviceFingerprint = fingerprint;
      final profile = await AuthService.getProfile();

      if (profile != null && AuthService.isDeviceBindingExempt(profile)) {
        _deviceGateStatus = DeviceGateStatus.boundToThisDevice;
      } else if (profile == null || profile['device_id'] == null) {
        _deviceGateStatus = DeviceGateStatus.needsFirstBind;
      } else if (AuthService.matchesAuthorizedDevice(profile, fingerprint)) {
        _deviceGateStatus = DeviceGateStatus.boundToThisDevice;
      } else {
        _canAuthorizeNewDevice = AuthService.canAuthorizeNewDevice(profile);
        _nextDeviceSwitchDate = AuthService.getNextDeviceSwitchDate(profile);
        _deviceGateStatus = DeviceGateStatus.needsAuthorization;
      }
    } catch (_) {
      _deviceGateStatus = DeviceGateStatus.boundToThisDevice;
    }
    notifyListeners();
  }

  /// Called by `DeviceAuthDialog` once the user taps "Got it".
  Future<void> completeDeviceBinding() async {
    final fingerprint =
        _deviceFingerprint ?? await DeviceService.getDeviceFingerprint();
    try {
      await AuthService.bindDevice(fingerprint);
    } catch (_) {
      // Best-effort: if this write fails the user is simply asked to bind
      // again next launch rather than stranded on the dialog now.
    }
    _deviceGateStatus = DeviceGateStatus.boundToThisDevice;
    notifyListeners();
  }

  /// Called by `DeviceAuthorizationDialog` once the user taps "Authorize".
  /// Caller must have already confirmed [canAuthorizeNewDevice].
  Future<void> authorizeThisDevice() async {
    final fingerprint =
        _deviceFingerprint ?? await DeviceService.getDeviceFingerprint();
    try {
      final profile = await AuthService.getProfile();
      if (profile != null) {
        await AuthService.authorizeNewDevice(profile, fingerprint);
      }
    } catch (_) {
      // Best-effort, same reasoning as completeDeviceBinding.
    }
    _deviceGateStatus = DeviceGateStatus.boundToThisDevice;
    notifyListeners();
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
    required String termsVersion,
    String? referredBy,
  }) async {
    _error = null;
    try {
      final response = await AuthService.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        termsVersion: termsVersion,
        referredBy: referredBy,
      );
      // No session covers both "confirmation required" and GoTrue's
      // obfuscated already-registered reply (neither session nor user, to
      // avoid confirming the address exists). Do NOT test `user != null`
      // instead — AuthResponse derives it from the session, so the
      // obfuscated reply would misread as a successful sign-up.
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
      // 23505 = unique_violation: rare given RegisterScreen's pre-submit
      // check, but the DB's unique index is the real guard against a race.
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
      // Supabase returns one combined "Token has expired or is invalid" for
      // both cases — do not branch on 'expired' vs 'invalid', it would
      // misreport a simply wrong code as expired.
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

  Future<({bool signedIn, String? error})> signInWithGoogle({
    required String termsVersion,
  }) async {
    _error = null;
    try {
      final response = await AuthService.signInWithGoogle();
      if (response?.session == null) return (signedIn: false, error: null);
      await AuthService.recordTermsAcceptance(termsVersion);
      return (signedIn: true, error: null);
    } on AuthException catch (e) {
      _error = e.message;
      notifyListeners();
      return (signedIn: false, error: 'Google sign-in failed: ${e.message}');
    } catch (_) {
      notifyListeners();
      return (
        signedIn: false,
        error: 'Google sign-in failed. Please try again.',
      );
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
