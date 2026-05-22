import 'package:flutter/material.dart';
import '../services/device_service.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DeviceAuthDialog shows the first-device binding confirmation dialog.
/// Per D-03, shown immediately after email verification on first login.
/// Non-dismissible (user must tap "Got it" to proceed).
class DeviceAuthDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const DeviceAuthDialog({
    super.key,
    required this.onSuccess,
  });

  @override
  State<DeviceAuthDialog> createState() => _DeviceAuthDialogState();
}

class _DeviceAuthDialogState extends State<DeviceAuthDialog> {
  bool _isLoading = false;

  Future<void> _bindDevice() async {
    setState(() => _isLoading = true);

    try {
      // Retrieve device fingerprint (per D-01)
      final deviceId = await DeviceService.getDeviceFingerprint();

      // Get current user
      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Store device_id + bound_at in profiles via AuthService
      final now = DateTime.now().toUtc().toIso8601String();
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'device_id': deviceId,
        'bound_at': now,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        // Trigger callback to proceed to LibraryScreen
        Navigator.of(context).pop(); // Close dialog
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to bind device: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false, // Prevent back button dismissal
      child: AlertDialog(
        title: const Text('Device Authorization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Center(
              child: Icon(
                Icons.smartphone,
                size: 48,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Message
            Center(
              child: Text(
                'This device is now tied to your account. '
                'You can authorize one new device every 30 days.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          // Got it button (only action, non-dismissible)
          FilledButton(
            onPressed: _isLoading ? null : _bindDevice,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Shows the DeviceAuthDialog as a modal dialog.
/// Used when user logs in for the first time and needs device binding.
void showDeviceAuthDialog(
  BuildContext context, {
  required VoidCallback onSuccess,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => DeviceAuthDialog(onSuccess: onSuccess),
  );
}
