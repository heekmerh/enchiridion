import 'package:flutter/foundation.dart';

import '../models/announcement.dart';
import '../services/announcement_service.dart';
import '../services/diagnostics_log.dart';

class AnnouncementProvider with ChangeNotifier {
  final AnnouncementService _service;
  List<Announcement> _unread = const [];
  Set<String> _dismissedIds = {};
  bool _dismissedIdsLoaded = false;

  AnnouncementProvider([AnnouncementService? service])
      : _service = service ?? AnnouncementService();

  Announcement? get current => _unread.isEmpty ? null : _unread.first;

  Future<void> refresh() async {
    try {
      if (!_dismissedIdsLoaded) {
        _dismissedIds = await _service.dismissedIds();
        _dismissedIdsLoaded = true;
      }
      final live = await _service.fetchLive();
      _unread = live.where((a) => !_dismissedIds.contains(a.id)).toList();
      notifyListeners();
    } catch (error, stack) {
      DiagnosticsLog.error('announcements_refresh', error, stack);
    }
  }

  Future<void> dismiss(Announcement announcement) async {
    _dismissedIds.add(announcement.id);
    _unread = _unread.where((a) => a.id != announcement.id).toList();
    notifyListeners();
    await _service.saveDismissedIds(_dismissedIds);
  }
}
