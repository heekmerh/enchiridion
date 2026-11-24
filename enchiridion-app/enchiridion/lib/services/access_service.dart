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
  /// discarded and the user reverts to freemium, so access can't be kept
  /// alive indefinitely by cutting the app off from the internet. Until then
  /// a device that can't reach Supabase keeps the last confirmed grants.
  static const maxValidationAge = Duration(days: 7);

  /// How long a successful check is trusted before launch, resume or a
  /// token refresh asks Supabase again. Keeps a busy user to about one
  /// entitlement call a day instead of one per app switch. A purchase, a
  /// sign-in and the paywall screen still check straight away, and a grant
  /// whose own expiry has passed is rechecked early.
  static const revalidateAfter = Duration(hours: 24);

  /// Testing seams: the entitlement rows Supabase would return, the signed-in
  /// user id, and the clock. Reset to null in tearDown.
  @visibleForTesting
  static Future<List<dynamic>> Function()? fetchOverride;
  @visibleForTesting
  static String? Function()? userIdOverride;
  @visibleForTesting
  static DateTime Function()? clockOverride;

  StorageService? _storage;

  /// Wires the persistent validation-timestamp store. Called once at startup
  /// (see `main()`); without it the in-memory cache still works, but the
  /// 7-day offline window cannot tell how stale a cached grant is across
  /// restarts.
  void bindStorage(StorageService storage) {
    _storage = storage;
  }

  // Cache: bookId -> has access. '*' = full subscription.
  final Map<String, bool> _cache = {};
  bool _loaded = false;
  String? _loadedForUserId;
  Future<void>? _inflight;

  /// Number of entitlement requests sent to Supabase, for tests.
  @visibleForTesting
  int fetchCount = 0;

  DateTime _now() => (clockOverride?.call() ?? DateTime.now()).toUtc();

  String? _currentUserId() {
    final override = userIdOverride;
    if (override != null) return override();
    return AuthService.currentUser?.id;
  }

  Future<List<dynamic>> _fetchEntitlements() async {
    fetchCount++;
    final override = fetchOverride;
    if (override != null) return override();
    return await Supabase.instance.client.rpc('get_my_entitlements') as List;
  }

  /// For launch, resume and token refreshes: asks Supabase only when the
  /// last successful check is older than [revalidateAfter], or a cached
  /// grant has passed its own expiry. Otherwise it reuses the stored grants.
  Future<void> refreshIfDue() async {
    final userId = _currentUserId();
    if (userId == null) {
      clearCache();
      return;
    }
    if (!_isDue(userId)) {
      if (!(_loaded && _loadedForUserId == userId)) {
        _hydrateFromStorage(userId);
      }
      return;
    }
    await loadAccess();
  }

  bool _isDue(String userId) {
    final storage = _storage;
    if (storage == null) return true;
    final last = storage.getLastAccessValidation(userId);
    if (last == null || storage.getCachedAccessScopes(userId) == null) {
      return true;
    }
    final now = _now();
    if (now.difference(last) >= revalidateAfter) return true;
    final expiry = storage.getAccessExpiry(userId);
    return expiry != null && !now.isBefore(expiry);
  }

  /// Checks entitlements with Supabase now. Used after sign-in, a purchase
  /// and on the paywall screen. Calls made while one is already running
  /// share it rather than sending a second request.
  Future<void> loadAccess() {
    final running = _inflight;
    if (running != null) return running;
    final future = _load();
    _inflight = future;
    return future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
  }

  Future<void> _load() async {
    final userId = _currentUserId();
    if (userId == null) {
      clearCache();
      return;
    }

    try {
      final rows = await _fetchEntitlements();

      // Auth can change while the request is in flight. Discard stale rows
      // rather than granting one user's entitlements to another user.
      if (_currentUserId() != userId) {
        clearCache();
        return;
      }

      final scopes = <String>{};
      DateTime? earliestExpiry;
      for (final row in rows) {
        final map = row as Map;
        scopes.add(scopeForFeature(map['feature'] as String));
        final raw = map['expires_at'];
        final expiry = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
        if (expiry != null &&
            (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
          earliestExpiry = expiry;
        }
      }
      _cache
        ..clear()
        ..addEntries(scopes.map((scope) => MapEntry(scope, true)));
      _loaded = true;
      _loadedForUserId = userId;

      // Records this successful validation for `_isDue` and
      // `_enforceValidationFreshness`, and persists the granted scopes so
      // `_hydrateFromStorage` lets a cold start or an offline device reuse
      // them instead of repeating this round trip.
      await _storage?.setLastAccessValidation(userId, _now());
      await _storage?.setCachedAccessScopes(userId, scopes.toList());
      await _storage?.setAccessExpiry(userId, earliestExpiry);
    } catch (_) {
      // Offline or Supabase unreachable. Keep the last confirmed grants while
      // they are within [maxValidationAge]; past that, or with nothing
      // stored, fall back to the free tier.
      if (_currentUserId() != userId) {
        clearCache();
        return;
      }
      if (!_hydrateFromStorage(userId)) {
        _cache.clear();
        _loaded = true;
        _loadedForUserId = userId;
      }
    }
  }

  void clearCache() {
    _cache.clear();
    _loaded = false;
    _loadedForUserId = null;
  }

  Future<bool> hasBookAccess(String bookId) async {
    if (testAccessOverride != null) return testAccessOverride!;
    final userId = _currentUserId();
    if (userId == null) return false;
    await _ensureAccessLoaded(userId);
    return _cache.containsKey('*') || (_cache[bookId] ?? false);
  }

  Future<bool> hasFullAccess() async {
    if (testAccessOverride != null) return testAccessOverride!;
    final userId = _currentUserId();
    if (userId == null) return false;
    await _ensureAccessLoaded(userId);
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
    final userId = _currentUserId();
    if (userId == null) return false;
    await _ensureAccessLoaded(userId);
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
    if (last == null || _now().difference(last) > maxValidationAge) {
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
    if (last != null && _now().difference(last) <= maxValidationAge) {
      return;
    }
    // Never validated, or validated too long ago (including pre-upgrade
    // installs with a warm cache but no timestamp): revalidate now.
    await loadAccess();
  }
}
