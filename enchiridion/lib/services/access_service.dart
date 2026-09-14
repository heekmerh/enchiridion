import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resource_topic.dart';
import '../services/auth_service.dart';

class AccessService {
  static AccessService? _instance;
  static AccessService get instance => _instance ??= AccessService._();
  AccessService._();

  /// Testing-only override. Set to `true`/`false` in tests to short-circuit
  /// the Supabase call. Reset to `null` in tearDown to avoid state leakage.
  @visibleForTesting
  static bool? testAccessOverride;

  // Cache: bookId -> has access. '*' = full subscription.
  final Map<String, bool> _cache = {};
  bool _loaded = false;
  String? _loadedForUserId;

  /// Call once after login to populate the cache.
  Future<void> loadAccess() async {
    final user = AuthService.currentUser;
    if (user == null) {
      clearCache();
      return;
    }

    final userId = user.id;
    _cache.clear();
    _loaded = false;
    _loadedForUserId = userId;

    try {
      final rows = await Supabase.instance.client
          .from('user_book_access')
          .select('book_id')
          .eq('user_id', userId);

      // Auth can change while the request is in flight. Discard stale rows
      // rather than granting one user's entitlements to another user.
      if (AuthService.currentUser?.id != userId) {
        clearCache();
        return;
      }

      for (final row in rows as List) {
        _cache[row['book_id'] as String] = true;
      }
    } catch (_) {
      // Supabase not configured or offline: default to the free tier. The
      // cache was already cleared, so old entitlements cannot leak through.
    }

    _loaded = true;
  }

  void clearCache() {
    _cache.clear();
    _loaded = false;
    _loadedForUserId = null;
  }

  Future<bool> hasBookAccess(String bookId) async {
    if (testAccessOverride != null) return testAccessOverride!;
    final user = AuthService.currentUser;
    if (user == null) return false;
    if (!_loaded || _loadedForUserId != user.id) await loadAccess();
    return _cache.containsKey('*') || (_cache[bookId] ?? false);
  }

  Future<bool> hasFullAccess() async {
    if (testAccessOverride != null) return testAccessOverride!;
    final user = AuthService.currentUser;
    if (user == null) return false;
    if (!_loaded || _loadedForUserId != user.id) await loadAccess();
    return _cache.containsKey('*');
  }

  Future<bool> hasExamPrepAccess() async {
    if (testAccessOverride != null) return testAccessOverride!;
    final user = AuthService.currentUser;
    if (user == null) return false;
    if (!_loaded || _loadedForUserId != user.id) await loadAccess();
    return _cache.containsKey('*') ||
        (_cache[kStandaloneExamPrepScope] ?? false);
  }

  /// Grant access manually (for testing / admin use).
  Future<void> grantBookAccess(String bookId) async {
    final user = AuthService.currentUser;
    if (user == null) return;
    await Supabase.instance.client.from('user_book_access').upsert({
      'user_id': user.id,
      'book_id': bookId,
      'access_type': bookId == '*' ? 'subscription' : 'book',
    });
    _loadedForUserId = user.id;
    _loaded = true;
    _cache[bookId] = true;
  }
}
