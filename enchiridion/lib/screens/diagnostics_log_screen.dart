import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/diagnostics_log.dart';

/// Shows the on-device Study Buddy diagnostic log (see
/// `lib/services/diagnostics_log.dart`) so a freeze can be diagnosed from the
/// device itself — no adb required, though `adb exec-out run-as
/// <applicationId> cat files/study_buddy_diagnostics.log` also works since
/// the file lives in ordinary app-private storage.
class DiagnosticsLogScreen extends StatefulWidget {
  const DiagnosticsLogScreen({super.key});

  @override
  State<DiagnosticsLogScreen> createState() => _DiagnosticsLogScreenState();
}

class _DiagnosticsLogScreenState extends State<DiagnosticsLogScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final content = await DiagnosticsLog.readAll();
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics log copied to clipboard.')),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear diagnostics log?'),
        content: const Text(
            'This deletes the log on this device. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DiagnosticsLog.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics log'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _content.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No diagnostics recorded yet. Tap a Study Buddy '
                        'notification or wait for the next ambient prompt, '
                        'then check back here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Newest entries are at the bottom. Copy this '
                                'before it happens again.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            _content,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading || _content.isEmpty ? null : _clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading || _content.isEmpty ? null : _copy,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
