import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Shown when this device doesn't match the account's bound device or any
/// previously authorized one (`DeviceGateStatus.needsAuthorization`).
/// Dismissible — unlike [DeviceAuthDialog] — since declining just means
/// staying signed out on this device, not losing access to the account.
/// Pops `true` if the device was authorized, `false`/`null` otherwise; the
/// caller (`AuthGate`) decides what happens next in either case.
class DeviceAuthorizationDialog extends StatefulWidget {
  const DeviceAuthorizationDialog({super.key});

  @override
  State<DeviceAuthorizationDialog> createState() =>
      _DeviceAuthorizationDialogState();
}

class _DeviceAuthorizationDialogState
    extends State<DeviceAuthorizationDialog> {
  bool _loading = false;

  Future<void> _authorize() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().authorizeThisDevice();
    if (mounted) Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final canAuthorize = auth.canAuthorizeNewDevice;
    final nextAvailable = auth.nextDeviceSwitchDate;

    return AlertDialog(
      title: const Text('Authorize new device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This device isn't authorized on your account yet.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (canAuthorize)
            Text(
              'You can authorize one new device every 30 days. Authorize '
              'this one now?',
              style: theme.textTheme.bodyMedium,
            )
          else if (nextAvailable != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You can authorize one new device every 30 days. '
                'Next available: ${_formatDate(nextAvailable)}.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onErrorContainer),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (!canAuthorize || _loading) ? null : _authorize,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Authorize'),
        ),
      ],
    );
  }
}
