import 'package:flutter/material.dart';

import '../../services/biometric_sign_in_service.dart';

class BiometricSignInSetting extends StatefulWidget {
  const BiometricSignInSetting({super.key});

  @override
  State<BiometricSignInSetting> createState() => _BiometricSignInSettingState();
}

class _BiometricSignInSettingState extends State<BiometricSignInSetting> {
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await BiometricSignInService.instance.isEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {}
  }

  Future<void> _forget() async {
    setState(() => _busy = true);
    try {
      await BiometricSignInService.instance.disable();
      if (mounted) setState(() => _enabled = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not remove fingerprint sign-in. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.fingerprint),
      title: const Text('Fingerprint sign-in enabled'),
      subtitle: const Text('Saved on this device, including after logout.'),
      trailing: TextButton(
        onPressed: _busy ? null : _forget,
        child: Text(_busy ? 'Removing…' : 'Forget'),
      ),
    );
  }
}
