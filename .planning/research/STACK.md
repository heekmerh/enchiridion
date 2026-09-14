# Technology Stack

**Project:** Enchiridion — Flutter Medical Reference App
**Researched:** 2026-04-11
**Confidence:** MEDIUM (no live web search available; based on codebase analysis + knowledge through August 2025)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flutter | 3.22+ (stable) | Cross-platform mobile framework | Already chosen; 3.22 is the stable LTS-equivalent as of mid-2025 |
| Dart | 3.4+ | Language | Ships with Flutter; null-safety is mature |
| Flutter SDK constraint | `>=3.4.0 <4.0.0` | Narrower than current `>=3.0.0` | 3.0 allows regressions from before Dart 3 sealed classes; tighten to get modern Dart features |

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Provider** | ^6.1.2 | Global state (settings, auth, IAP entitlements, bookmarks) | Already in use, team knows it, sufficient for this app's complexity. Riverpod is better for large teams but Provider is simpler for a solo/small-team project with well-defined domain boundaries. **Keep it.** |
| `ValueNotifier` / `setState` | SDK built-in | Local widget state (form inputs, calculator state) | Use for ephemeral state; don't push everything into Provider |

**Decision rationale:** Riverpod 2.x is more powerful and better for testability, but the existing Provider setup is correct and functional. Migrating adds risk with no clear benefit for this app's scope. The auth and IAP providers that need to be added fit cleanly into the existing MultiProvider pattern.

### Authentication

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **firebase_auth** | ^4.19.0 | Email/password authentication | Firebase Auth is the standard for Flutter mobile apps in 2025. Free tier covers this project's scale entirely. Email/password is the only required auth method (per PROJECT.md). Supabase is a credible alternative but adds infra management overhead with no advantage for email-only auth. |
| **firebase_core** | ^2.31.0 | Firebase SDK initialisation | Required peer dependency |
| **cloud_firestore** | ^4.17.0 | User profile, notes/annotations, entitlements | Stores per-user data that must sync across device reinstalls: unlocked books, personal notes. SQLite (sqflite) is right for pure offline content; Firestore is right for user-owned data that must survive app deletion. |

**Firebase vs Supabase decision:**
- Firebase Auth + Firestore: turnkey SDK, battle-tested Flutter plugin, zero backend to manage, handles token refresh/persistence automatically, generous free tier (Spark plan). **Confidence: HIGH**
- Supabase: Better SQL story, open source, but Flutter SDK is less mature than Firebase's official SDK, adds complexity for email-only auth, requires managing Postgres instance. **Verdict: not worth switching for this scope.**

### In-App Purchases / Freemium Gating

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **purchases_flutter** (RevenueCat) | ^6.x | Cross-platform IAP management | This is the correct choice over native `in_app_purchase`. RevenueCat handles: receipt validation server-side (required to prevent spoofing), cross-platform entitlement logic (iOS + Android in one SDK), subscription state synced to user ID, entitlement restoration on reinstall, webhook support for Firestore entitlement updates. The native `in_app_purchase` plugin requires you to build all of this yourself. For a freemium medical app targeting app stores, RevenueCat is industry standard. **Confidence: HIGH** |
| `in_app_purchase` | — | Native IAP | Do NOT use as primary IAP layer. Acceptable only as RevenueCat's underlying transport, which it already uses internally. Building entitlement logic on raw StoreKit/Google Play Billing APIs is 3–4x the implementation cost. |

**RevenueCat integration notes:**
- Create a free RevenueCat account; configure products in App Store Connect and Google Play Console
- Products to create: `enchiridion_book_[slug]_unlock` (one per book) OR `enchiridion_all_access` (single unlock for all 7 books). All-access is simpler and likely better conversion.
- Link RevenueCat user ID to Firebase Auth UID on login: `await Purchases.logIn(firebaseUser.uid)`
- Entitlement check: `CustomerInfo.entitlements.active.containsKey('all_access')` — wrap in an `EntitlementProvider`

### Offline Content Storage

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Flutter asset bundling** (existing) | SDK built-in | Embed JSON book content | All 7 book JSON files are bundled in `assets/data/`. This is correct for static content that ships with the app. No network required, no CDN needed, works offline day 1. Keep this pattern. |
| **sqflite** | ^2.3.3 | User notes/annotations local cache | For personal notes that the user adds to topics: write to Firestore (source of truth) + cache locally in SQLite for instant load. SharedPreferences is for simple key-value (settings, last-read); SQLite is right for structured note data with queries (notes per book, per chapter). |
| **shared_preferences** | ^2.2.3 | Settings, last-read, visited chapters | Already in use and correct. Keep for lightweight key-value persistence. |
| **path_provider** | ^2.1.3 | File system paths for SQLite | Required by sqflite |

**What NOT to add:**
- Hive / Isar: Valid alternatives to sqflite but adds a build step and non-SQL query syntax. sqflite is simpler for notes which are simple structured records. Notes don't need the ORM-style querying Isar provides.
- Drift (formerly Moor): Type-safe SQL layer on sqflite. Good for complex schemas; overkill for notes.

### JSON Content Rendering

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **Custom block renderer** (existing) | — | Render typed ContentBlock widgets | The existing `block_renderer.dart` pattern is correct and already supports 9 block types (mnemonic, table, checklist, clinical_pearls, red_flags, age_reference, algorithm, key_value, paragraph). **Keep this architecture.** |
| NO flutter_html | — | — | The existing codebase uses native Flutter widgets per block type, not HTML. This is better: richer styling control, no HTML parsing overhead, no webview. flutter_html was listed in the migration guide but was correctly not added to pubspec.yaml — do not add it. |

### Navigation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **go_router** | ^13.0.0 | Declarative routing | The app needs named routes for: `/`, `/login`, `/register`, `/books`, `/book/:id`, `/book/:id/chapter/:chapterId`, `/calculators`, `/quiz/:bookId`. go_router handles deep links, route guards (auth gate), and nested navigation. The current app uses MaterialApp `home:` with no named routing — this must be added before the app has multiple screens. **Confidence: HIGH** |

**Navigator 2.0 (go_router) vs Navigator 1.0 (push/pop):**
Navigator 1.0 is simpler to start but becomes painful with auth guards and deep linking. go_router adds minimal boilerplate and is the Flutter team's recommended routing library.

### Calculator Feature

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **math_expressions** | ^2.4.0 | Formula evaluation for calculators | Clinical calculators need formula evaluation (BMI, GCS, qSOFA, etc.). math_expressions handles variable substitution in formula strings, avoiding hardcoded `if/switch` per calculator. This allows adding new calculators via JSON config without Dart code changes. |
| **flutter_form_builder** | ^9.3.0 | Calculator input forms | Calculators have validated numeric/enum inputs. flutter_form_builder eliminates boilerplate for field validation, focus management, and form state. Worth the dependency for a feature with 10+ calculators. |
| **form_builder_validators** | ^10.0.0 | Input validation for calculators | Peer library to flutter_form_builder for validation rules |

### UI & Polish

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **flutter_screenutil** | ^5.9.3 | Responsive sizing | Already in use; correct for consistent sizing across phone screen sizes. |
| **flutter_platform_widgets** | ^6.0.2 | Platform-adaptive widgets | Already in use; allows Cupertino/Material switching. |
| **cached_network_image** | ^3.3.1 | Book cover thumbnail loading | The 7 book covers displayed on the home screen come from `coverUrl` in book JSON. If these remain local assets, this is not needed; if thumbnails are served remotely, use this package. Conditional: add when cover images are confirmed remote. |
| **shimmer** | ^3.0.0 | Loading skeleton screens | Better UX than spinners during auth/IAP state loading. Lightweight. |
| **flutter_svg** | ^2.0.10 | SVG icon rendering | If any book covers or UI icons are SVGs. Low risk to add early. |

### Notifications (defer to v2)

Do not add push notifications for v1. Per PROJECT.md, push notifications are explicitly out of scope.

### Analytics (optional v1)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **firebase_analytics** | ^10.10.0 | Usage analytics | Understand which books/calculators are used, conversion funnel from free to paid. Low-effort add alongside Firebase setup. Optional but valuable for a freemium product. |
| **firebase_crashlytics** | ^3.5.0 | Crash reporting | Required for a medical app going to app stores. Catches silent crashes in production. |

---

## Full pubspec.yaml

```yaml
name: enchiridion
description: A mobile medical reference app for medical students and junior doctors.
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  provider: ^6.1.2

  # Navigation
  go_router: ^13.0.0

  # Authentication & Backend
  firebase_core: ^2.31.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  firebase_analytics: ^10.10.0       # optional but recommended
  firebase_crashlytics: ^3.5.0       # recommended for production

  # In-App Purchases
  purchases_flutter: ^6.29.0         # RevenueCat

  # Local Storage
  shared_preferences: ^2.2.3
  sqflite: ^2.3.3
  path_provider: ^2.1.3

  # Calculator
  math_expressions: ^2.4.0
  flutter_form_builder: ^9.3.0
  form_builder_validators: ^10.0.0

  # UI
  flutter_screenutil: ^5.9.3
  flutter_platform_widgets: ^6.0.2
  flutter_svg: ^2.0.10
  shimmer: ^3.0.0
  cached_network_image: ^3.3.1       # conditional: only if covers are remote

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.9
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.3.10
```

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| State management | Provider | Riverpod 2.x | Riverpod is strictly better architecturally, but migrating the existing Provider setup adds risk/time with no functional benefit for this app's complexity. Revisit if team grows. |
| State management | Provider | BLoC/Cubit | More boilerplate, better for very complex event flows. Overkill here. |
| Auth | Firebase Auth | Supabase Auth | Supabase Flutter SDK is less mature; no advantage for email-only auth; adds managed Postgres cost |
| Auth | Firebase Auth | Custom JWT backend | Significant backend work; no reason when Firebase Auth is turnkey |
| IAP | RevenueCat | `in_app_purchase` (native) | Native requires server-side receipt validation, cross-platform entitlement logic — 3-4x build cost. RevenueCat does this out of the box. |
| IAP | RevenueCat | Adapty | RevenueCat has larger Flutter ecosystem, better documentation, more mature SDK |
| Database | Firestore | Supabase Postgres | Same Firebase Auth + Firestore pairing avoids split SDK setup; Firestore offline sync is better for mobile |
| Local storage | sqflite | Hive | Hive is faster for pure key-value but sqflite is better for structured note queries without a separate query syntax to learn |
| Local storage | sqflite | Isar | Isar is excellent but adds build steps (code gen) and a learning curve; sqflite is sufficient for notes |
| Routing | go_router | auto_route | auto_route requires code generation; go_router is official Flutter team recommendation and simpler |
| Routing | go_router | Navigator 1.0 | push/pop does not handle auth guards or deep links cleanly |

---

## Confidence Notes

| Decision | Confidence | Basis |
|----------|------------|-------|
| Keep Provider | HIGH | Codebase is already built on it; pattern is sound |
| Firebase Auth | HIGH | Standard for Flutter mobile apps; official plugin; well-documented |
| RevenueCat for IAP | HIGH | Industry standard for freemium Flutter apps; handles receipt validation that raw IAP does not |
| go_router for navigation | HIGH | Flutter team official recommendation; pub.dev package of the week |
| Keep asset-bundled JSON | HIGH | Content is static and ships with app; no network needed |
| sqflite for notes | MEDIUM | Standard choice; Isar/Drift are valid alternatives; sqflite is simplest |
| math_expressions for calculators | MEDIUM | Correct package category; version numbers reflect knowledge through Aug 2025; verify on pub.dev before implementing |
| Specific package versions | LOW | Knowledge cutoff August 2025; run `flutter pub outdated` before implementation to confirm latest compatible versions |

---

## Critical Implementation Notes

### IAP Gating Architecture

Do not gate content at the UI layer only. The entitlement check must be:
1. Stored in Firestore (server-authoritative) after RevenueCat purchase
2. Cached locally in SharedPreferences for offline reads
3. Checked in a single `EntitlementProvider` that both UI and navigation guards use
4. Never derived solely from local state that could be manipulated

### Auth Flow

Firebase Auth tokens persist across app restarts automatically. On `main.dart` startup:
- Check `FirebaseAuth.instance.currentUser` (not async, synchronous check)
- Use `authStateChanges()` stream as the source of truth for auth state
- Wrap go_router with a `redirect` guard that checks auth state before allowing access to locked content

### JSON Content at Scale

Current setup loads one `book.json` from assets. With 7 books, loading all books at startup will be slow. Strategy:
- Bundle all 7 JSON files in assets
- Load lazily: parse a book's JSON only when the user opens that book
- Cache parsed `Book` objects in `BookProvider` after first load (current pattern already does this for one book)

### Offline-First Notes

User notes are written to Firestore with offline persistence enabled (`PersistenceSettings(cacheSizeBytes: 100MB)`). Firestore SDK queues writes while offline and syncs when connectivity returns. This gives offline-first notes without building custom sync logic.

---

## Sources

- Codebase analysis: `enchiridion/pubspec.yaml`, `enchiridion/lib/main.dart`, `enchiridion/lib/services/`, `enchiridion/lib/models/`, `enchiridion/lib/providers/`
- Project spec: `.planning/PROJECT.md`
- Flutter migration guide: `FLUTTER_MIGRATION_GUIDE.md`
- RevenueCat Flutter docs: https://www.revenuecat.com/docs/getting-started/installation/flutter (MEDIUM confidence — URL correct as of Aug 2025)
- Firebase Flutter docs: https://firebase.google.com/docs/flutter/setup (HIGH confidence)
- go_router docs: https://pub.dev/packages/go_router (HIGH confidence)
- Knowledge cutoff: August 2025; verify all package versions on pub.dev before implementation
