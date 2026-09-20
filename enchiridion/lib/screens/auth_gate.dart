import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'device_auth_dialog.dart';
import 'device_authorization_dialog.dart';
import 'library_screen.dart';
import 'login_screen.dart';
import 'sync_splash_screen.dart';

/// The one place every sign-in/sign-up path (`SplashScreen`, `LoginScreen`,
/// `ConfirmEmailScreen`, `RegisterScreen`) navigates to instead of
/// `LibraryScreen` directly, so the one-account-per-device gate
/// (`AuthProvider.deviceGateStatus`) is enforced exactly once, in exactly
/// one place, regardless of how the user got here.
///
/// Renders nothing but a spinner itself — on every rebuild it reacts to the
/// current [DeviceGateStatus] by either proceeding straight to
/// [LibraryScreen] (the normal, every-day case) or showing the relevant
/// blocking dialog first.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _dialogShowing = false;
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // First sync on a new device runs visibly: show the recovery splash
    // instead of the gate spinner until it finishes or is skipped. The
    // device-gate flow below resumes afterwards.
    if (auth.initialSyncRunning) {
      return SyncSplashScreen(
        completedStages:
            (auth.syncProgress * AuthProvider.syncTotalStages).round(),
        totalStages: AuthProvider.syncTotalStages,
        stageLabel: auth.syncStageLabel,
        onSkip: () => context.read<AuthProvider>().skipInitialSync(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Future<void> _handle() async {
    if (_navigated || _dialogShowing || !mounted) return;
    final provider = context.read<AuthProvider>();
    // Sync splash owns the screen while the initial sync runs.
    if (provider.initialSyncRunning) return;
    final status = provider.deviceGateStatus;

    switch (status) {
      case DeviceGateStatus.checking:
        return;

      case DeviceGateStatus.boundToThisDevice:
        _navigated = true;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LibraryScreen()),
          (route) => false,
        );
        return;

      case DeviceGateStatus.needsFirstBind:
        _dialogShowing = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const DeviceAuthDialog(),
        );
        _dialogShowing = false;
        if (!mounted) return;
        // Re-evaluate immediately with the now-updated provider state,
        // rather than waiting for an incidental rebuild.
        await _handle();
        return;

      case DeviceGateStatus.needsAuthorization:
        _dialogShowing = true;
        final authorized = await showDialog<bool>(
          context: context,
          builder: (_) => const DeviceAuthorizationDialog(),
        );
        _dialogShowing = false;
        if (!mounted) return;

        if (authorized == true) {
          await _handle();
        } else {
          // Declined, or dismissed without authorizing: this device stays
          // signed out rather than sitting on a blank gate screen forever.
          await context.read<AuthProvider>().signOut();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return;
    }
  }
}
