import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AccessService {
  static AccessService? _instance;
  static AccessService get instance => _instance ??= AccessService._();
  AccessService._();

  /// Testing-only override. Set to `true`/`false` in tests to short-circuit
  /// the Supabase call. Reset to `null` in tearDown to avoid state leakage.
  @visibleForTesting
  static bool? testAccessOverride;

  // Cache: bookId → has access. '*' = full subscription.
  final Map<String, bool> _cache = {};
  bool _loaded = false;

  /// Call once after login to populate the cache.
  Future<void> loadAccess() async {
    final user = AuthService.currentUser;
    if (user == null) {
      _cache.clear();
      _loaded = false;
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('user_book_access')
          .select('book_id')
          .eq('user_id', user.id);

      _cache.clear();
      for (final row in rows as List) {
        _cache[row['book_id'] as String] = true;
      }
    } catch (_) {
      // Supabase not configured or offline — default to free tier.
    }
    _loaded = true;
  }

  void clearCache() {
    _cache.clear();
    _loaded = false;
  }

  Future<bool> hasBookAccess(String bookId) async {
    if (testAccessOverride != null) return testAccessOverride!;
    if (!_loaded) await loadAccess();
    return _cache.containsKey('*') || (_cache[bookId] ?? false);
  }

  Future<bool> hasFullAccess() async {
    if (!_loaded) await loadAccess();
    return _cache.containsKey('*');
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
    _cache[bookId] = true;
  }
}
