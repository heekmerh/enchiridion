import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/announcement.dart';
import '../../providers/announcement_provider.dart';

class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    context.read<AnnouncementProvider>().refresh();
  }

  Future<void> _showFullMessage(Announcement announcement) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(announcement.title),
        content: SingleChildScrollView(child: Text(announcement.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcement = context.watch<AnnouncementProvider>().current;
    if (announcement == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final background = announcement.isImportant
        ? colors.errorContainer
        : colors.primaryContainer;
    final foreground = announcement.isImportant
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFullMessage(announcement),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  announcement.isImportant
                      ? Icons.priority_high_rounded
                      : Icons.campaign_outlined,
                  color: foreground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        announcement.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: foreground),
                  tooltip: 'Dismiss',
                  onPressed: () => context
                      .read<AnnouncementProvider>()
                      .dismiss(announcement),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
