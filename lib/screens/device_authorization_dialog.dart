import 'package:flutter/material.dart';
import '../services/device_service.dart';
import '../services/auth_service.dart';

/// DeviceAuthorizationDialog shows when user logs in from an unauthorized device.
/// Per D-03, prompts user to authorize a new device with monthly rolling quota.
class DeviceAuthorizationDialog extends StatefulWidget {
  final VoidCallback onAuthorizeSuccess;
  final VoidCallback onCancel;
  final bool canAuthorize;
  final DateTime? nextAvailableDate;

  const DeviceAuthorizationDialog({
    super.key,
    required this.onAuthorizeSuccess,
    required this.onCancel,
    required this.canAuthorize,
    this.nextAvailableDate,
  });

  @override
  State<DeviceAuthorizationDialog> createState() =>
      _DeviceAuthorizationDialogState();
}

class _DeviceAuthorizationDialogState extends State<DeviceAuthorizationDialog> {
  bool _isLoading = false;

  Future<void> _authorizeDevice() async {
    if (!widget.canAuthorize || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = AuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get current device fingerprint
      final deviceId = await DeviceService.getDeviceFingerprint();

      // Authorize new device via AuthService (per D-01, D-03)
      await AuthService.authorizeNewDevice(user, deviceId);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop(); // Close dialog
        widget.onAuthorizeSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to authorize device: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: true, // Dismissible via back button
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onCancel();
        }
      },
      child: AlertDialog(
        title: const Text('Authorize New Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message
            if (widget.canAuthorize)
              Text(
                'This device is not authorized. Authorize it? '
                '(1 new device per 30 days)',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Text(
                'This device is not authorized.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (widget.nextAvailableDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'You can authorize one new device per 30 days. '
                    'Next available: ${_formatDate(widget.nextAvailableDate!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          // Cancel button (always available)
          TextButton(
            onPressed: _isLoading ? null : () {
              Navigator.of(context).pop();
              widget.onCancel();
            },
            child: const Text('Cancel'),
          ),
          // Authorize button (only if quota available)
          if (widget.canAuthorize)
            FilledButton(
              onPressed: _isLoading ? null : _authorizeDevice,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Authorize'),
            )
          else
            FilledButton(
              onPressed: null, // Disabled when quota exhausted
              child: const Text('Authorize'),
            ),
        ],
      ),
    );
  }
}

/// Shows the DeviceAuthorizationDialog as a modal dialog.
/// Used when user logs in from an unauthorized device.
/// Per D-03, checks quota and shows appropriate message.
void showDeviceAuthorizationDialog(
  BuildContext context, {
  required VoidCallback onAuthorizeSuccess,
  required VoidCallback onCancel,
  required bool canAuthorize,
  required DateTime? nextAvailableDate,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => DeviceAuthorizationDialog(
      onAuthorizeSuccess: onAuthorizeSuccess,
      onCancel: onCancel,
      canAuthorize: canAuthorize,
      nextAvailableDate: nextAvailableDate,
    ),
  );
}
