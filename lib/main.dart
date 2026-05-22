import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/book_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bookmark_provider.dart';
import 'providers/auth_provider.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/verification_code_screen.dart';
import 'screens/device_auth_dialog.dart';
import 'screens/device_authorization_dialog.dart';
import 'screens/login_screen.dart';
import 'screens/library_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  runApp(EnchiridionApp(storageService: storageService));
}

class EnchiridionApp extends StatelessWidget {
  final StorageService storageService;

  const EnchiridionApp({
    super.key,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider(storageService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => BookmarkProvider(storageService)),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settingsProvider, authProvider, _) {
          return MaterialApp(
            title: 'Enchiridion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(settingsProvider.settings.theme),
            home: _buildHome(context, authProvider),
          );
        },
      ),
    );
  }

  /// Per D-01, D-02, D-03: Build routing tree with email verification
  /// and device binding gates.
  ///
  /// Flow:
  /// - Loading → SplashScreen
  /// - Unauthenticated → LoginScreen
  /// - Authenticated + requiresDeviceBinding → VerificationCodeScreen (email confirmation)
  /// - Authenticated + needsDeviceBinding → DeviceAuthDialog (first-device binding)
  /// - Authenticated + deviceAuthorizationState == 'pending_authorization' → DeviceAuthorizationDialog
  /// - Authenticated + deviceAuthorizationState == 'quota_exhausted' → LoginScreen with error
  /// - Authenticated → LibraryScreen
  Widget _buildHome(BuildContext context, AuthProvider authProvider) {
    // Per D-02, D-03: User locked out entirely until email + device confirmed
    if (authProvider.status == AuthStatus.loading) {
      return const SplashScreen();
    }

    if (authProvider.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // User is authenticated
    final user = authProvider.user;
    if (user == null) {
      return const LoginScreen();
    }

    // Per D-02: Check if awaiting email verification
    // (VerificationCodeScreen shown after signup before email confirmed)
    if (authProvider.deviceAuthorizationState == 'awaiting_verification') {
      return VerificationCodeScreen(
        email: user.email ?? '',
        onVerificationSuccess: () {
          // Refresh provider to check device binding requirement
          context.read<AuthProvider>();
        },
      );
    }

    // Per D-01, D-03: Check if device binding needed (first login after email confirmed)
    if (authProvider.requiresDeviceBinding) {
      return _DeviceAuthDialogWrapper(
        onSuccess: () {
          context.read<AuthProvider>().deviceBindingComplete();
        },
      );
    }

    // Per D-03: Check if device authorization needed (multi-device login)
    if (authProvider.deviceAuthorizationState ==
        'pending_authorization') {
      return _DeviceAuthorizationDialogWrapper(
        onSuccess: () {
          context.read<AuthProvider>().deviceAuthorizationComplete();
        },
      );
    }

    // Per D-03: Device authorization quota exhausted
    if (authProvider.deviceAuthorizationState == 'quota_exhausted') {
      return _QuotaExhaustedScreen(
        error: authProvider.error,
        onReturnToLogin: () {
          context.read<AuthProvider>().signOut();
        },
      );
    }

    // All gates passed - user can access the app
    return const LibraryScreen();
  }
}

/// Wrapper to show DeviceAuthDialog as full-screen overlay.
/// Replaces screen content until user taps "Got it".
class _DeviceAuthDialogWrapper extends StatelessWidget {
  final VoidCallback onSuccess;

  const _DeviceAuthDialogWrapper({required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    // Show dialog immediately, but behind a blank screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDeviceAuthDialog(
        context,
        onSuccess: onSuccess,
      );
    });

    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Wrapper to show DeviceAuthorizationDialog as full-screen overlay.
/// Replaces screen content until user authorizes or cancels.
class _DeviceAuthorizationDialogWrapper extends StatelessWidget {
  final VoidCallback onSuccess;

  const _DeviceAuthorizationDialogWrapper({required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    // Determine if user can authorize (quota available)
    // This info is computed in AuthProvider during signin
    final canAuthorize = true; // Assume quota available (state verified in Provider)
    final nextDate =
        null; // Would be fetched from AuthService if quota exhausted

    // Show dialog immediately, but behind a blank screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDeviceAuthorizationDialog(
        context,
        onAuthorizeSuccess: onSuccess,
        onCancel: () {
          // User declined authorization - return to login
          authProvider.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
        canAuthorize: canAuthorize,
        nextAvailableDate: nextDate,
      );
    });

    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Error screen shown when device quota exhausted.
class _QuotaExhaustedScreen extends StatelessWidget {
  final String? error;
  final VoidCallback onReturnToLogin;

  const _QuotaExhaustedScreen({
    required this.error,
    required this.onReturnToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: cs.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Device Not Authorized',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: onReturnToLogin,
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
