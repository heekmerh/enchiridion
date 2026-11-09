# Domain Pitfalls

**Domain:** Flutter mobile medical reference and education app (freemium, offline-first, African market)
**Project:** Enchiridion
**Researched:** 2026-04-11
**Confidence:** MEDIUM-HIGH (App Store guidelines verified from official sources; Flutter performance from official docs; RevenueCat from training data + partial verification)

---

## Critical Pitfalls

Mistakes that cause rewrites, app store rejection, or legal exposure.

---

### Pitfall 1: Drug Dosage Calculator Rejected Under App Store Guideline 1.4.2

**What goes wrong:**
Apple's Guideline 1.4.2 explicitly restricts drug dosage calculators to apps submitted by drug manufacturers, hospitals, universities, health insurance companies, pharmacies, or FDA-approved entities. An indie developer or small team submitting a drug dosage calculator app — even with disclaimers — will be rejected. The guideline states Apple needs assurance the app "will be supported and updated over the long term" due to potential patient harm.

Enchiridion plans weight-based dosing (mg/kg), Cockcroft-Gault creatinine clearance, IV infusion rate, and pediatric fluid calculators. These are explicitly in-scope for this guideline.

**Why it happens:**
Developers assume disclaimers ("for educational use only") are sufficient. They are not. Apple evaluates the function of the feature, not the label on it. A calculator that outputs "give 240mg" is a dosage calculator regardless of what the disclaimer says.

**Consequences:**
- App rejected before launch
- Requires removal of all dosage calculators to ship
- Re-submission delay of weeks
- Potential account flag if the submission appears to deliberately circumvent the rule

**Prevention:**
- Frame calculators as "clinical learning tools" and "estimation aids" rather than prescribing tools
- Avoid output language like "give X mg" — use "calculated estimate: X mg" with a required clinical verification step in the UI
- Add a mandatory disclaimer interaction on first calculator use (user must tap "I understand this is for learning, not clinical prescribing")
- Register as a university-affiliated project if possible — the author's medical school affiliation may qualify
- Consult Apple's App Review before submission (use the feedback form in App Store Connect)
- On Google Play: the equivalent policy is less strict but requires the "Health & Fitness" or "Medical" category and accurate content rating

**Detection (warning signs):**
- Any calculator output that looks like a dosing instruction rather than an educational estimate
- UI language that implies the app is making a clinical decision
- Missing mandatory disclaimer on per-calculator basis

**Phase mapping:** Phase addressing calculators must address this before any calculator UI is built. The content model (how results are worded) must be locked before implementation.

---

### Pitfall 2: 5.5 MB JSON Loaded Synchronously on Main Thread — Startup Jank

**What goes wrong:**
`book.json` is currently 5.54 MB. The current `BookService.loadBook()` calls `rootBundle.loadString()` and `json.decode()` synchronously on the main UI thread. This blocks the UI during parse. On a mid-range Android device (common in the Nigerian/African student market) this will cause 200–800ms of total freeze at startup — a blank white screen after the splash disappears.

As chapters grow (the plan includes 8+ specialty books), this will worsen. The current app has one book; the roadmap adds Paediatrics, Surgery, Obs & Gynae, Psychiatry, Radiology, Orthopedics, Dermatology, Internal Medicine — each likely 3-6 MB.

**Why it happens:**
Flutter's `rootBundle.loadString()` is async but `json.decode()` is synchronous CPU work. Developers assume `await` makes it non-blocking — it does not for CPU-intensive operations. The work still runs on the Dart main isolate.

**Consequences:**
- Visible freeze at startup on low-end Android (Tecno, Itel, Infinix — common in target market)
- ANR (Application Not Responding) risk on Android if parse exceeds 5 seconds
- Poor first impression; users who experience freeze once do not return

**Prevention:**
- Move JSON parsing to a background isolate using Flutter's `compute()` function:
  ```dart
  final book = await compute(Book.fromJson, jsonDecode(jsonString));
  ```
- Consider splitting the monolithic `book.json` into per-chapter files loaded lazily on chapter navigation
- Implement a loading state that renders something (skeleton UI or chapter list stub) while the full book parses
- For multiple books: never load more than the active book into memory; use lazy loading per book tap

**Detection (warning signs):**
- Startup time >300ms on a mid-range Android device in profile mode
- Flutter DevTools shows a single long frame on app launch
- `Timeline` trace shows `json.decode` in the UI thread

**Phase mapping:** Address in the book loading architecture phase (before adding more books). The current single-book app is borderline tolerable; the multi-book library will break without this fix.

---

### Pitfall 3: Freemium Gate Bypassable Because Access Is Checked Client-Side Only

**What goes wrong:**
The planned freemium model gates book content after chapter 1, question banks after question 10, and some calculators. If the gate is implemented as a conditional check in Flutter (`if (isPremium) showContent()`), the gate can be bypassed by any user with a rooted device, an APK reverse-engineer, or by modifying SharedPreferences values directly.

Medical students — the target audience — are technically capable and motivated to bypass paywalls.

**Why it happens:**
Client-side gating is the first instinct. It feels sufficient because most users won't bypass it. But the app ships with all content in the bundle, making extraction trivial.

**Consequences:**
- Revenue loss from determined bypass users
- Full book content is accessible without payment
- If content is bundled in APK assets, it can be extracted without even running the app

**Prevention:**
- Gate premium content server-side: store full content on a backend, serve only free content in the initial bundle
- Or: encrypt the premium content bundle and deliver the decryption key only after verified purchase through RevenueCat's webhook
- RevenueCat server-to-server webhooks must validate purchases — do not rely on `Purchases.getCustomerInfo()` alone on the client
- The current `assets/data/book.json` approach is fundamentally incompatible with strong content gating — this is an architectural decision that must be made before building the freemium system
- Minimum viable protection: at launch, ship only free chapter content in assets; premium content fetched from server after auth + purchase verification

**Detection (warning signs):**
- All book content present in the installed APK
- Access checks implemented only in Widget `build()` or Provider getters
- No server-side entitlement verification

**Phase mapping:** Must be resolved before implementing freemium (auth + IAP phase). Architectural decision: bundled vs. server-delivered premium content.

---

### Pitfall 4: RevenueCat Purchase Flow Leaves Users in "Pending" State After Payment

**What goes wrong:**
RevenueCat (purchases_flutter) has a known pattern: a user completes a payment on Google Play or App Store, but the entitlement is not yet active when the purchase callback fires. This happens with:
- Google Play's pending purchases (common in markets with carrier billing, which is prevalent in Africa)
- App Store StoreKit 2 async confirmation flows
- Network interruptions during purchase completion

If the app immediately navigates to premium content after `purchasePackage()` completes, users who paid but have a pending state will see a "still locked" screen. They paid; they see no content. This triggers refund requests, 1-star reviews, and support burden.

**Why it happens:**
Developers treat the `PurchasesErrorCode.purchaseCancelledError` path and assume all non-error completions are immediate grants. Pending purchases are a third state that is easy to miss.

**Consequences:**
- Users who paid cannot access what they paid for
- Support burden disproportionate to user base
- Google Play carrier billing is common in Nigeria, Ghana, Kenya — it has high pending purchase rates

**Prevention:**
- Always check `CustomerInfo.entitlements.active` after purchase, not just purchase success callback
- Implement `Purchases.addCustomerInfoUpdateListener()` to listen for entitlement activation asynchronously
- Show a "Purchase processing — content will unlock shortly" state rather than navigating immediately
- Test specifically with Google Play's pending purchase test methodology (use `google.play.billingclient.api.BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED`)
- Do not disable the purchase button after a pending state — users should be able to retry

**Detection (warning signs):**
- Purchase flow navigates directly to premium content without re-checking `CustomerInfo`
- No listener registered for async entitlement updates
- No "pending purchase" UI state in the app

**Phase mapping:** Must be addressed during IAP implementation phase, specifically in the purchase completion flow design.

---

### Pitfall 5: Floating-Point Errors Silently Produce Wrong Clinical Values

**What goes wrong:**
Dart uses 64-bit IEEE 754 floating point. Clinical calculator formulas involving division chains, unit conversions, or multiple multiplications accumulate floating-point errors. For example:

- Cockcroft-Gault: `((140 - age) * weight_kg) / (72 * Scr_mg_dL)` — if `Scr_umol_L` is converted to `mg_dL` first, rounding at each step can produce a result that differs from the "true" answer by 0.5–2 mL/min. In a patient near a kidney function threshold band, this changes the interpretation.
- Unit conversion from lb to kg: `weight_lb / 2.20462` — the displayed value rounds but the stored value retains floating point representation, and downstream calculations use the unrounded value.
- The Holliday-Segar formula uses step-wise addition; each step should be calculated with integer arithmetic where possible to avoid drift.

**Why it happens:**
Developers write formulas as single expressions matching the textbook formula, without considering intermediate rounding or the display-vs-stored-value gap.

**Consequences:**
- Results that appear correct to 1 decimal place but have wrong interpretation band classification
- Inconsistent results when the same inputs are entered twice (display rounding vs. calculation precision)
- Credibility damage if a medical educator or clinician notices a discrepancy

**Prevention:**
- Define a `round(double value, int decimals)` utility and apply it at every output display, not at intermediate calculation steps
- Write unit tests for every calculator against reference values from the clinical literature or online calculators (e.g., MDCalc)
- For unit conversions: convert once at input, store in canonical unit (always kg, always mg/dL), never convert in the formula body
- For formulas with categorical outputs (e.g., GFR band): use `>=` comparisons against defined thresholds, and test boundary values explicitly (e.g., input that should produce exactly 60.0 mL/min)
- Document the reference formula source and version for each calculator

**Detection (warning signs):**
- No unit tests for calculators
- Formula implementation written inline without intermediate variable names
- No reference values to validate against

**Phase mapping:** Before any calculator ships, a test suite of reference values must exist. This is a prerequisite, not an afterthought.

---

## Moderate Pitfalls

---

### Pitfall 6: Provider State Management Causes Unnecessary Full-Book Rebuilds

**What goes wrong:**
The current `BookProvider` holds the entire parsed `Book` object and calls `notifyListeners()` on every chapter navigation. Any widget that calls `context.watch<BookProvider>()` (or `Consumer<BookProvider>`) will rebuild completely, even widgets that only care about whether the user is on chapter 3 or chapter 4. As content grows (8 books, calculators, question bank, notes), a single navigation action will trigger rebuilds across the entire widget tree.

**Why it happens:**
Provider is simple to start with but requires discipline to scope. The `ChangeNotifier` pattern is coarse-grained by default.

**Prevention:**
- Use `context.select()` to subscribe only to the specific slice of state a widget needs:
  ```dart
  final chapterId = context.select((BookProvider p) => p.currentChapterId);
  ```
- Split `BookProvider` into separate concerns: `NavigationProvider` (current chapter, position) vs. `BookContentProvider` (the parsed book data, which almost never changes)
- Never put the full `Book` object in a provider that also triggers navigation state changes

**Detection (warning signs):**
- Widgets using `Consumer<BookProvider>` that only care about one property
- DevTools showing full widget tree rebuilds on chapter swipe

**Phase mapping:** Refactor before adding the multi-book library screen and calculator state.

---

### Pitfall 7: Named Routes / Navigator 1.0 Cannot Support Deep Linking or Auth Guards

**What goes wrong:**
The current app uses implicit navigation. Once auth, a library screen, chapter deep links, and calculator tabs are added, navigation grows complex. Flutter's `Navigator.pushNamed()` with named routes cannot handle:
- Deep link `enchiridion://book/paediatrics/chapter/fluid-management`
- Auth guards that redirect unauthenticated users to login
- Returning to the correct screen after login

Flutter's official documentation explicitly states: "We don't recommend using named routes for most applications. Use go_router instead."

**Prevention:**
- Adopt `go_router` before implementing auth or the library screen
- Define all routes declaratively with path parameters
- Use `go_router`'s `redirect` callback for auth guards
- Set this up before building any screen that requires navigation beyond the current reader

**Detection (warning signs):**
- Any use of `Navigator.pushNamed()` in new screens
- Auth check implemented inside screen `initState()` rather than in a route guard
- No deep link configuration in `AndroidManifest.xml` or `Info.plist`

**Phase mapping:** Resolve in the auth phase (before the library landing page is built).

---

### Pitfall 8: Session State Lost on App Restart Because Firebase Auth Stream Is Not Persisted Correctly

**What goes wrong:**
Firebase Auth Flutter SDK persists auth tokens to disk by default, but the auth state stream (`FirebaseAuth.instance.authStateChanges()`) fires asynchronously at startup. If the app's root widget renders before the auth stream emits, it will briefly show the login screen to an already-authenticated user (a "flash of unauthenticated state"). Worse: if the app initializes its providers before `FirebaseAuth.instance.app` is ready, the initial token check returns null and the user is treated as logged out.

**Prevention:**
- Use `FirebaseAuth.instance.authStateChanges()` as the single source of truth for auth state
- Wrap the app in a `StreamBuilder` that shows a neutral loading screen until the first auth state emission
- Call `Firebase.initializeApp()` before `runApp()` and `await` it — do not use `unawaited()`
- Test the specific scenario: kill and restart the app while logged in, verify no flash of login screen

**Detection (warning signs):**
- Login screen briefly visible on startup for logged-in users
- `FirebaseAuth.currentUser` checked synchronously in `main()` before `initializeApp` completes
- No loading state between app start and auth state resolution

**Phase mapping:** Auth phase. The pattern must be established before the library screen is built.

---

### Pitfall 9: Search Across 5.5 MB JSON on the Main Thread Freezes Scroll

**What goes wrong:**
The planned search functionality must search across chapters, sections, subsections, and content blocks — a deeply nested tree. Doing this synchronously on every keystroke (or even on a debounced timer) while the full book object is in memory will cause visible UI freeze on low-end Android. The current book structure has 5+ levels of nesting; a linear scan across all text content is O(N) where N is every string in the entire book.

**Prevention:**
- Build a flat search index at parse time: extract all searchable strings once, with their location metadata (chapter ID, section ID, anchor), into a `List<SearchEntry>`
- Run the index build in an isolate immediately after book parse completes
- Debounce search input (minimum 300ms) before querying the index
- Limit results to the first 20 matches; do not scan the full index on every keystroke
- Store the index in a `SearchService` separate from `BookProvider` so it is not rebuilt on navigation changes

**Detection (warning signs):**
- Search implemented as `book.chapters.where((c) => c.text.contains(query))`
- No debounce on the search TextField
- Search runs synchronously in the build method

**Phase mapping:** Build the search index architecture when implementing the TOC/search widget, before the multi-book library makes the problem significantly worse.

---

### Pitfall 10: App Store Rejection for Missing "Medical Content" Disclaimer at Launch

**What goes wrong:**
Apple's App Store Review Guideline 1.4.1 requires medical apps to "remind users to see a doctor" before making medical decisions. Apps that launch directly into content without an upfront disclaimer or that bury the disclaimer in settings are more likely to trigger scrutiny. The guideline also requires that apps claiming accuracy disclose the "data and methodology" supporting their claims.

Google Play requires medical apps to be categorized accurately and have appropriate content ratings. Mis-categorizing a medical reference tool as "Education" to avoid health-content scrutiny can lead to rejection or post-publication removal.

**Prevention:**
- Show a one-time disclaimer on first app launch (persist to SharedPreferences once accepted): "Enchiridion is a clinical learning resource. Content does not replace professional judgment, institutional guidelines, or senior review."
- Require explicit user acceptance (tap "I understand") — not just a dismissable toast
- Category on App Store: "Medical" — do not try to file as "Education" to avoid scrutiny
- In the calculator safety framework (already designed correctly in the Ideas docs), every calculator shows its disclaimer — keep this non-bypassable
- Do not claim the app provides "accurate" clinical data without specifying what the accuracy claim is based on

**Detection (warning signs):**
- No first-launch disclaimer screen
- Calculator disclaimers are dismissable without acknowledgment
- App filed under "Education" category in App Store Connect

**Phase mapping:** Implement the disclaimer screen during the auth/onboarding phase so it appears before the user reaches any content.

---

### Pitfall 11: Low-End Android Performance Degraded by Heavy Widget Trees in Content Renderer

**What goes wrong:**
Medical content blocks include tables, checklists, expandable sections, nested bullets, code-style formatted text, and rich typography. Rendering a chapter that has 30+ content blocks — each a multi-widget tree — in a `ListView` without virtualization causes frame drops. Shader compilation jank on first render of new widget types (e.g., the first `Table` widget on a device that has never seen one) adds 100–300ms of jank on low-end devices.

Low-end Android (Tecno Spark, Itel, Infinix Hot — prevalent in the Nigerian student market) typically has 2GB RAM and a PowerVR or Mali-400 GPU. These are the worst-case scenario for Flutter rendering.

**Prevention:**
- Use `ListView.builder` — never `ListView` with a `children` list for content rendering
- Use `const` constructors everywhere a content block widget does not depend on runtime data
- Pre-compile shaders using Flutter's `--bundle-sksl-path` flag with a captured `--cache-sksl` trace from a real device
- Limit the complexity of a single content block widget: tables should not be `DataTable` (heavy) — use a custom grid renderer
- Test on a physical low-end Android device before every content rendering change, not only on an emulator or flagship device

**Detection (warning signs):**
- Content blocks rendered with `Column(children: blocks.map(...).toList())`
- No `const` keywords on static content widgets
- Testing only performed on an emulator or high-end device

**Phase mapping:** Establish rendering patterns in the content widget phase. Retrofitting virtualization is painful.

---

### Pitfall 12: Offline-First Auth State Not Handled — App Locks Out Users With No Connection

**What goes wrong:**
The planned auth gates all content. Firebase Auth token expiry is typically 1 hour (ID token) with refresh via a 30-day refresh token. If a user opens the app offline and their ID token has expired, `FirebaseAuth.currentUser` will return a user object but calls to verify against Firestore/RTDB will fail with a network error. If the app treats a network-dependent auth check failure as "logged out," the user loses access to content they have offline — a critical failure for an offline-first app.

**Prevention:**
- Treat `FirebaseAuth.currentUser != null` as sufficient to show cached/offline content, regardless of network state
- Never block content access behind a network-dependent auth call for users who are already authenticated
- Separate "auth verification for purchase actions" (requires network) from "access to already-downloaded content" (does not require network)
- Use Firebase Auth's built-in offline persistence — it handles token refresh automatically when the network returns

**Detection (warning signs):**
- `Firestore.instance.collection('users').doc(uid).get()` called on app startup before showing any content
- Content gated behind a real-time Firestore read rather than local auth state
- No graceful offline state: app shows error instead of cached content

**Phase mapping:** Auth phase. Define the offline/online content access policy before wiring auth to content.

---

## Minor Pitfalls

---

### Pitfall 13: Keystore File Committed to Git — Cannot Publish Updates to Play Store

**What goes wrong:**
The release signing keystore (`upload-keystore.jks`) and `key.properties` contain the signing credentials required to publish updates to Google Play. If committed to git (even accidentally, even once), these must be treated as compromised. If the file is later deleted from git history without rotating the keystore, an attacker with a copy of the repo history can impersonate the app.

More commonly: developers lose the keystore file when switching machines, which permanently prevents them from updating the Play Store listing (Google will reject updates signed with a different key).

**Prevention:**
- Add `key.properties` and `*.jks` to `.gitignore` before the first commit
- Store the keystore in a password manager or encrypted cloud backup
- Use Google Play App Signing (recommended): upload a AAB, Google manages the signing key, and you only keep the "upload key" — Google holds the "app signing key"

**Detection (warning signs):**
- `key.properties` present in `git status` as a tracked file
- No backup of the keystore file outside the development machine

**Phase mapping:** First Android release build setup.

---

### Pitfall 14: SharedPreferences Used for Sensitive Auth Tokens

**What goes wrong:**
`SharedPreferences` stores data in plaintext on Android (`/data/data/com.package.name/shared_prefs/`). On rooted devices, any app can read this data. Storing Firebase auth tokens, user IDs tied to purchase state, or any PII in SharedPreferences is a security vulnerability.

**Prevention:**
- Use `flutter_secure_storage` for anything security-sensitive: tokens, user identifiers, purchase entitlement cache
- `SharedPreferences` is appropriate for: last-read chapter, display settings, theme preference, calculator unit preferences
- Never store a RevenueCat `appUserId` or entitlement state in SharedPreferences as the sole source of truth

**Detection (warning signs):**
- `SharedPreferences.setString('user_token', token)` anywhere in the codebase
- No `flutter_secure_storage` dependency in `pubspec.yaml`

**Phase mapping:** Auth phase — establish the storage policy before implementing login.

---

### Pitfall 15: User-Written Notes Stored Without Conflict Resolution — Data Loss on Multi-Device

**What goes wrong:**
The planned notes/annotations feature allows users to add notes to topics. If notes are stored only in `SharedPreferences` or local SQLite without sync, a user who reinstalls the app or switches devices loses all notes. If sync is added later, merge conflicts arise when a note written offline conflicts with a version on the server.

**Prevention:**
- Decide the sync strategy before implementing notes: local-only (no sync, clear user expectation), or cloud-synced (Firestore with last-write-wins or merge logic)
- If Firestore: use per-note document IDs (not chapter-level arrays) to enable per-note conflict resolution
- Set user expectation clearly: "Notes are saved locally. To back up notes, [action]."

**Detection (warning signs):**
- Notes stored as a JSON blob in a single SharedPreferences key
- No plan for what happens to notes on reinstall

**Phase mapping:** Notes/annotations phase (defer until auth and content are stable).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Calculator implementation | App Store Guideline 1.4.2 rejection for drug dosage features | Frame as learning/estimation tools; mandatory disclaimers; consider university affiliation |
| Calculator implementation | Floating-point errors in clinical formula outputs | Unit test every calculator against MDCalc or published reference values before shipping |
| Book loading / content rendering | 5.5 MB JSON parse freezing UI thread on startup | Use `compute()` isolate for JSON decode; implement loading skeleton |
| Multi-book library | Loading all books into memory | Lazy-load per book; never parse a book that is not the active book |
| Freemium / IAP | Content gate bypassable client-side | Architectural decision: server-delivered premium content vs. encrypted bundle |
| Freemium / IAP | RevenueCat pending purchase state | Listen for async entitlement updates; show "processing" state |
| Auth | Flash of unauthenticated state at startup | Await Firebase.initializeApp(); use StreamBuilder with neutral loading state |
| Auth | Network-required auth check locking out offline users | Auth state from local FirebaseAuth.currentUser; never block offline content access |
| Navigation | Named routes cannot support deep links or auth guards | Adopt go_router before building the library screen |
| Content search | Synchronous full-book scan on every keystroke | Build flat search index at parse time; debounce input |
| Content rendering | Heavy widget trees causing jank on low-end Android | ListView.builder; const constructors; test on physical low-end device |
| Android release | Keystore loss preventing Play Store updates | Google Play App Signing; encrypted keystore backup |
| Storage | Sensitive tokens in SharedPreferences | Use flutter_secure_storage for tokens; SharedPreferences only for display preferences |
| Notes / annotations | Data loss on reinstall without sync plan | Define sync strategy before building notes; set user expectations |
| App Store submission | Missing first-launch medical disclaimer | One-time disclaimer with explicit acknowledgment before content access |

---

## Sources

- Apple App Store Review Guideline 1.4.2 — Drug Dosage Calculators: https://developer.apple.com/app-store/review/guidelines/ (verified 2026-04-11, HIGH confidence)
- Apple App Store Review Guideline 5.1.3 — Health and Health Research: https://developer.apple.com/app-store/review/guidelines/ (verified 2026-04-11, HIGH confidence)
- Apple App Store Review Guideline 3.1.1 — In-App Purchase requirements: https://developer.apple.com/app-store/review/guidelines/ (verified 2026-04-11, HIGH confidence)
- Flutter Performance Best Practices — official docs: https://docs.flutter.dev/perf/best-practices (verified 2026-04-11, HIGH confidence)
- Flutter Background JSON Parsing with compute() — official cookbook: https://docs.flutter.dev/cookbook/networking/background-parsing (verified 2026-04-11, HIGH confidence)
- Flutter Navigation and go_router recommendation — official docs: https://docs.flutter.dev/ui/navigation (verified 2026-04-11, HIGH confidence)
- RevenueCat pending purchases, carrier billing behavior — MEDIUM confidence (training data; RevenueCat docs partially inaccessible during research)
- Flutter shader compilation jank on Android — MEDIUM confidence (referenced in official docs; specifics from training data)
- Firebase Auth offline behavior and token expiry — MEDIUM confidence (training data, consistent with Firebase Auth documentation patterns)
