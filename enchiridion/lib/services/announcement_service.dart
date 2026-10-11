import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/announcement.dart';

class AnnouncementService {
  static const String _dismissedIdsKey = 'dismissed_announcement_ids';
  static const int _maxAnnouncements = 20;

  Future<List<Announcement>> fetchLive() async {
    final rows = await Supabase.instance.client
        .from('announcements')
        .select('id, title, body, is_important')
        .order('published_at', ascending: false)
        .limit(_maxAnnouncements);
    return rows.map<Announcement>(Announcement.fromJson).toList();
  }

  Future<Set<String>> dismissedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_dismissedIdsKey) ?? const []).toSet();
  }

  Future<void> saveDismissedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedIdsKey, ids.toList());
  }
}
