import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// First-device binding confirmation, shown once per account on the very
/// first login (`DeviceGateStatus.needsFirstBind`). Non-dismissible — the
/// user must tap "Got it" — matching the locked D-03 design.
class DeviceAuthDialog extends StatefulWidget {
  const DeviceAuthDialog({super.key});

  @override
  State<DeviceAuthDialog> createState() => _DeviceAuthDialogState();
}

class _DeviceAuthDialogState extends State<DeviceAuthDialog> {
  bool _loading = false;

  Future<void> _bindDevice() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().completeDeviceBinding();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Device authorization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.smartphone, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'This device is now tied to your account. You can authorize '
              'one new device every 30 days.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: _loading ? null : _bindDevice,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
