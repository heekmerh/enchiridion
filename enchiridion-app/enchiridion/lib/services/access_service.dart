import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/pricing_config.dart';
import '../models/exam_module.dart';
import '../services/auth_service.dart';
import 'storage_service.dart';

String scopeForFeature(String feature) =>
    feature == kPremiumFeature ? kFullAccessScope : feature;

const String kFullAccessScope = '*';

class AccessService {
  static AccessService? _instance;
  static AccessService get instance => _instance ??= AccessService._();
  AccessService._();

  /// Testing-only override. Set to `true`/`false` in tests to short-circuit
  /// the Supabase call. Reset to `null` in tearDown to avoid state leakage.
  @visibleForTesting
  static bool? testAccessOverride;

  /// Past this age without a successful revalidation, cached grants are
  /// discarded and the user reverts to freemium — so access can't be kept
  /// alive indefinitely by cutting the app off from the internet.
  static const maxValidationAge = Duration(days: 7);

  StorageService? _storage;

  /// Wires the persistent validation-timestamp store. Called once at startup
  /// (see `main()`); without it the in-memory cache still works, but the
  /// 7-day offline revert cannot tell how stale a cached grant is across
  /// restarts.
  void bindStorage(StorageService storage) {
    _storage = storage;
  }

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
      final rows = await Supabase.instance.client.rpc('get_my_entitlements');

      // Auth can change while the request is in flight. Discard stale rows
      // rather than granting one user's entitlements to another user.
      if (AuthService.currentUser?.id != userId) {
        clearCache();
        return;
      }

      for (final row in rows as List) {
        _cache[scopeForFeature(row['feature'] as String)] = true;
      }

      // Records this successful validation for `_enforceValidationFreshness`,
      // and persists the granted scopes so `_hydrateFromStorage` lets a cold
      // isolate reuse them instead of repeating this round trip.
      if (AuthService.currentUser?.id == userId) {
        await _storage?.setLastAccessValidation(userId, DateTime.now().toUtc());
        await _storage?.setCachedAccessScopes(userId, _cache.keys.toList());
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
    await _ensureAccessLoaded(user.id);
    return _cache.containsKey('*') || (_cache[bookId] ?? false);
  }

  Future<bool> hasFullAccess() async {
    if (testAccessOverride != null) return testAccessOverride!;
    final user = AuthService.currentUser;
    if (user == null) return false;
    await _ensureAccessLoaded(user.id);
    return _cache.containsKey('*');
  }

  Future<bool> hasExamPrepAccess() async {
    return hasModuleAccess(kPlabModuleId);
  }

  /// Whether the user can access [moduleId]'s exam prep. PLAB resolves to
  /// the legacy `exam_prep` scope; future modules resolve to their own
  /// `exam_prep_<id>` scope. A full (`*`) subscription unlocks every module.
  Future<bool> hasModuleAccess(String moduleId) async {
    if (testAccessOverride != null) return testAccessOverride!;
    final user = AuthService.currentUser;
    if (user == null) return false;
    await _ensureAccessLoaded(user.id);
    return _cache.containsKey('*') ||
        (_cache[examScopeForModule(moduleId)] ?? false);
  }

  /// Scope-based access check for paywall callers that only hold a scope
  /// string (book id, exam module scope, or `*` for full access).
  Future<bool> hasScopeAccess(String scope) async {
    if (scope == '*') return hasFullAccess();
    for (final module in kExamModules) {
      if (examScopeForModule(module.id) == scope) {
        return hasModuleAccess(module.id);
      }
    }
    return hasBookAccess(scope);
  }

  /// Makes [_cache] usable for [userId], preferring the cheapest source that
  /// is still within [maxValidationAge]: the warm in-memory cache, then the
  /// grants persisted by the last successful validation, and only then a
  /// Supabase round trip.
  Future<void> _ensureAccessLoaded(String userId) async {
    if (_loaded && _loadedForUserId == userId) {
      await _enforceValidationFreshness(userId);
      return;
    }
    if (_hydrateFromStorage(userId)) return;
    await loadAccess();
  }

  /// Rebuilds [_cache] from the last successful validation's persisted
  /// scopes, if still fresh, returning whether the cache is now usable. Keeps
  /// the headless Study Buddy alarm — a brand-new, always-cold isolate — off
  /// the network for every ambient prompt. A stale/missing timestamp still
  /// falls through to [loadAccess], so a server-revoked grant is honoured at
  /// the next revalidation, same as a warm in-app cache.
  bool _hydrateFromStorage(String userId) {
    final storage = _storage;
    if (storage == null) return false;
    final last = storage.getLastAccessValidation(userId);
    if (last == null ||
        DateTime.now().toUtc().difference(last) > maxValidationAge) {
      return false;
    }
    // null, not empty: an empty list is a validated free-tier user (hydrate,
    // stay offline), while null means this install has never recorded scopes
    // and must revalidate — otherwise an upgrade would silently strip a paid
    // user's access until their timestamp aged out.
    final scopes = storage.getCachedAccessScopes(userId);
    if (scopes == null) return false;
    _cache
      ..clear()
      ..addEntries(scopes.map((scope) => MapEntry(scope, true)));
    _loaded = true;
    _loadedForUserId = userId;
    return true;
  }

  /// Discards cached grants not revalidated within [maxValidationAge].
  /// Called on every access check that would otherwise trust a warm cache,
  /// so a device kept offline past the grace window reverts to freemium even
  /// without a process restart; `loadAccess` does the actual reverting when
  /// offline, or just refreshes the cache when still online.
  Future<void> _enforceValidationFreshness(String userId) async {
    final storage = _storage;
    if (storage == null) return;
    final last = storage.getLastAccessValidation(userId);
    if (last != null &&
        DateTime.now().toUtc().difference(last) <= maxValidationAge) {
      return;
    }
    // Never validated, or validated too long ago (including pre-upgrade
    // installs with a warm cache but no timestamp): revalidate now.
    await loadAccess();
  }
}
