---
phase: 01-email-device-binding
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/services/device_service.dart
  - lib/services/auth_service.dart
  - lib/providers/auth_provider.dart
  - lib/screens/verification_code_screen.dart
  - lib/screens/device_auth_dialog.dart
  - lib/screens/device_authorization_dialog.dart
  - lib/main.dart
autonomous: true
requirements: [AUTH-01, AUTH-02, AUTH-03]
user_setup: []
must_haves:
  truths:
    - "User cannot access app without confirming email"
    - "Device fingerprint is correctly identified on first login"
    - "Device binding prevents unauthorized cross-device access"
    - "Monthly rolling window allows one device switch per 30 days"
    - "Factory reset is treated as a new device"
  artifacts:
    - path: "lib/services/device_service.dart"
      provides: "Platform-specific device fingerprinting (Android ANDROID_ID, iOS UUID)"
      exports: ["getDeviceFingerprint()", "storeDeviceId(String)", "getStoredDeviceId()"]
    - path: "lib/screens/verification_code_screen.dart"
      provides: "Email verification with 6-digit code entry + resend + countdown"
      min_lines: 80
    - path: "lib/screens/device_auth_dialog.dart"
      provides: "First-device binding confirmation dialog"
      min_lines: 40
    - path: "lib/screens/device_authorization_dialog.dart"
      provides: "Second device authorization prompt with quota display"
      min_lines: 60
    - path: "lib/services/auth_service.dart"
      provides: "Updated signUp + signIn to handle device binding + email verification"
      modified_methods: ["signUp()", "signIn()", "ensureProfile()"]
    - path: "lib/providers/auth_provider.dart"
      provides: "Auth state management with device binding workflow"
      modified_methods: ["_init()", "signIn()", "signUp()"]
  key_links:
    - from: "AuthProvider.signUp()"
      to: "VerificationCodeScreen"
      via: "Navigation after signup returns 'confirm_email'"
      pattern: "if.*confirm_email.*navigate"
    - from: "AuthProvider.signIn()"
      to: "DeviceAuthDialog/DeviceAuthorizationDialog"
      via: "Check device fingerprint match → show appropriate dialog"
      pattern: "if.*device.*mismatch.*show.*dialog"
    - from: "DeviceService.getDeviceFingerprint()"
      to: "Supabase profiles table"
      via: "Store device_id, authorized_devices, last_device_switch after binding"
      pattern: "profiles\\.upsert.*device"
    - from: "VerificationCodeScreen"
      to: "DeviceAuthDialog"
      via: "Email verified → trigger device binding on first auth"
      pattern: "on.*verify.*success.*show.*dialog"

---

<objective>
Implement email confirmation + device binding to secure app access. Users must confirm their email before entering the app and are tied to their signing device. They can authorize one additional device per 30-day rolling period. Factory resets are treated as new devices.

Purpose: Reduce unauthorized app sharing while maintaining user-friendly verification flow. Email confirmation gates app access entirely; device binding enforces device-specific licensing.

Output: Fully working email verification, device fingerprinting, and device authorization flow integrated into existing auth service and screens. All routing enforces email confirmation + device binding checks.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/01-email-device-binding/01-CONTEXT.md
@.planning/REQUIREMENTS.md

## Existing Codebase Context

From lib/services/auth_service.dart:
```dart
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;
  static User? get currentUser => _client.auth.currentUser;
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  static Future<AuthResponse> signUp({...}) // returns response with null session if email confirmation required
  static Future<AuthResponse> signIn({...})
  static Future<void> ensureProfile(User user) // creates profile after email confirmation
  static Future<Map<String, dynamic>?> getProfile()
}
```

From lib/providers/auth_provider.dart:
```dart
enum AuthStatus { loading, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  Future<String?> signUp({...}) // returns 'confirm_email' if confirmation required
  Future<String?> signIn(String email, String password)
  AuthStatus get status // determines navigation flow
  User? get user
}
```

Current navigation flow:
- Unauthenticated → LoginScreen
- After successful auth → AuthProvider.status == authenticated → LibraryScreen
- After signup requiring confirmation → AuthProvider returns 'confirm_email' → ConfirmEmailScreen (to be created)

## Database Schema Requirements

Supabase `profiles` table must have (per 01-CONTEXT.md):
```
device_id: TEXT (platform-specific identifier)
email_confirmed: BOOLEAN (email verification status)
authorized_devices: JSONB (array of {device_id, authorized_at})
last_device_switch: TIMESTAMP (rolling 30-day window)
bound_at: TIMESTAMP (when first device was bound)
```

This must be added via Supabase migration BEFORE phase execution.

## Key Decision References

Per 01-CONTEXT.md locked decisions:

**Device Fingerprint (D-01):**
- Android: ANDROID_ID via platform channel
- iOS: Generate + store UUID in flutter_secure_storage
- Fallback: Generate random UUID if APIs fail, allow user to proceed
- Factory reset: Treat as new device, show authorization prompt

**Email Confirmation (D-02):**
- In-app 6-digit OTP (not email link)
- Code expires 10 min, resend 1/min rate-limited
- Complete lockout until verified
- Show email + countdown on verification screen

**Device Authorization (D-03):**
- Dialog on first login after email verification
- Minimal message: "This device is now tied to your account"
- 2nd device: "Authorize? (1 per month)"
- Rolling 30-day quota (not calendar month)

</context>

<tasks>

<task type="auto">
  <name>Task 1: Create DeviceService with platform-specific fingerprinting</name>
  <files>lib/services/device_service.dart</files>
  <action>
Create a new service that retrieves the platform-specific device fingerprint. Per D-01:

- Android: Use platform channel to call `Settings.Secure.ANDROID_ID` (native Android API)
- iOS: Generate a UUID on first launch, store in `flutter_secure_storage`, retrieve on subsequent calls
- Fallback: If platform APIs fail or permissions denied, generate random UUID, store in secure storage, allow user to proceed without blocking

Implement methods:
1. `getDeviceFingerprint()` → Future<String> — returns device ID (platform-specific or fallback UUID)
2. `storeDeviceId(String id)` → Future<void> — save device ID to secure storage (iOS only; Android uses system API)
3. `getStoredDeviceId()` → Future<String?> — retrieve stored UUID from secure storage
4. `clearStoredDeviceId()` → Future<void> — used for testing/reset

The service must handle all platform-specific logic and fallback transparently. Do NOT require user action to generate UUID unless APIs fail.

Reference existing access_service.dart pattern for singleton pattern if needed. Use `flutter_secure_storage` (likely already in pubspec) for iOS UUID persistence.

Verify: Method signatures exist, Android platform channel declared, iOS secure storage integration in place. Do NOT run on device yet (that comes in verification task).
  </action>
  <verify>
    <automated>grep -n "getDeviceFingerprint" lib/services/device_service.dart | grep -c "Future<String>"</automated>
  </verify>
  <done>
DeviceService created with:
- getDeviceFingerprint() returning platform-specific ID or fallback UUID
- Android platform channel method signature declared
- iOS secure storage integration for UUID persistence
- Fallback UUID generation if platform APIs unavailable
- All methods return Future<String> (sync retrieval not allowed)
  </done>
</task>

<task type="auto">
  <name>Task 2: Update AuthService to integrate device binding in signUp and signIn</name>
  <files>lib/services/auth_service.dart</files>
  <action>
Update the existing AuthService to handle device binding workflow. Do NOT modify the signUp/signIn method signatures — add helper methods and internal logic.

Internal changes (do not expose new public methods):

1. **signUp() — add internal device binding:**
   - After user confirms email (during `ensureProfile` call), retrieve device fingerprint via `DeviceService.getDeviceFingerprint()`
   - Store in profiles table: `device_id`, `bound_at` (now), `email_confirmed: true`
   - Skip device binding at signup time; binding happens on first login after email confirmation

2. **signIn() — add device matching logic (internal):**
   - Retrieve current user's device_id, authorized_devices, last_device_switch from profiles
   - Get current device fingerprint via `DeviceService.getDeviceFingerprint()`
   - Compare: if fingerprint matches device_id OR is in authorized_devices → login succeeds
   - If mismatch: do NOT block here; return success; let AuthProvider/UI handle device auth dialog
   - Rationale: separation of concerns — service handles data, provider/UI handles UX

3. **ensureProfile() — update to support device binding:**
   - Already creates profile if missing; now also set `email_confirmed: true` if user just confirmed email
   - Retrieve device fingerprint and store as device_id + bound_at timestamp

4. **New internal method: `_matchesAuthorizedDevice(User user, String currentFingerprint) → Future<bool>`:**
   - Check if currentFingerprint matches device_id or any in authorized_devices array
   - Return true if match, false if mismatch (includes case where no devices are bound yet)

5. **New internal method: `_canAuthorizeNewDevice(User user) → Future<bool>`:**
   - Check `last_device_switch` timestamp
   - If null (no previous switch) → return true
   - If `now() - last_device_switch >= 30 days` → return true
   - Else → return false

Do NOT change method signatures of signUp, signIn, or signOut. Do NOT return device status to caller — return will be handled by AuthProvider.

Add comments referencing decision D-01, D-02, D-03 at key points.
  </action>
  <verify>
    <automated>grep -n "DeviceService\|device_id\|authorized_devices\|last_device_switch" lib/services/auth_service.dart | wc -l</automated>
  </verify>
  <done>
AuthService updated with:
- device matching logic in signIn (internal, non-blocking)
- device_id + bound_at stored in ensureProfile
- _matchesAuthorizedDevice() helper checking device against profile
- _canAuthorizeNewDevice() helper for monthly quota check
- All new logic commented with decision references (D-01, D-03)
- Public method signatures unchanged
  </done>
</task>

<task type="auto">
  <name>Task 3: Create VerificationCodeScreen for email confirmation</name>
  <files>lib/screens/verification_code_screen.dart</files>
  <action>
Create a new screen that displays after signup when email confirmation is required. Per D-02:

UI Layout:
1. Title: "Confirm Your Email"
2. Subtitle: "A 6-digit code has been sent to [user.email]"
3. Countdown timer: "Code expires in X:XX"
4. 6 input fields (single digit each, auto-focus next field on digit entry)
5. Resend button: "Didn't get the code? Resend in [X]s" (grayed out during cooldown, 1-minute limit)
6. Submit button: "Verify Code" (disabled until all 6 digits entered)
7. Error message display (if verification fails)

Behavior:
- Fetch user email from AuthService.currentUser.email (captured at signup)
- On digit entry: combine 6 digits into code string
- "Verify Code" calls: await Supabase.instance.client.auth.verifyOTP(email: email, type: 'email', token: code)
- If successful: notify caller (via callback or Provider update), navigate to next screen (device auth)
- If failed (invalid code): show error "Incorrect code. Try again." and clear fields
- If failed (expired): show error "Code expired. Tap 'Resend' to get a new code."
- Resend button: rate-limited to 1 request per 60 seconds (store last_resend timestamp locally)
- Resend action: call Supabase to resend OTP (same method Supabase uses for signup flow)
- Countdown: update every second, show "mm:ss" format, expire at 10:00 → auto-trigger resend option

Do NOT navigate after verify — instead, set a Provider flag or emit event that AuthProvider listens to. AuthProvider will handle navigation to device binding.

Reference existing PatternScreen or LoginScreen for styling/theming patterns.

Test surfaces:
- 6 input fields populate correctly
- Auto-focus works between fields
- Resend button rate-limit enforced
- Error messages display on invalid/expired codes
- Countdown timer runs correctly
- Submit button disabled until all 6 digits entered
  </action>
  <verify>
    <automated>grep -n "TextField\|verifyOTP\|resend\|countdown\|expires" lib/screens/verification_code_screen.dart | wc -l</automated>
  </verify>
  <done>
VerificationCodeScreen created with:
- 6 single-digit input fields with auto-focus
- Countdown timer (10 minutes)
- Resend button with 1-minute rate-limit
- Error messaging for invalid/expired codes
- Verify Code button calls Supabase auth.verifyOTP()
- User email displayed on screen
- Integration hook for AuthProvider (callback or stream listen)
  </done>
</task>

<task type="auto">
  <name>Task 4: Create DeviceAuthDialog for first-device binding</name>
  <files>lib/screens/device_auth_dialog.dart</files>
  <action>
Create a dialog shown immediately after email verification on first login. Per D-03:

Dialog content:
- Title: "Device Authorization"
- Message: "This device is now tied to your account. You can authorize one new device every 30 days."
- Icon: Simple device/phone icon (use Icons.smartphone or similar)
- Button: "Got it" (or "Continue")

Behavior:
- Non-dismissible (user must tap "Got it" to proceed)
- Called after VerificationCodeScreen verification succeeds AND no device_id exists yet in profiles
- On "Got it": call DeviceService.getDeviceFingerprint() → store device_id + bound_at in profiles via AuthService
- After storage succeeds, navigate to LibraryScreen or emit event for AuthProvider to navigate

Implementation notes:
- Use `showDialog` with `barrierDismissible: false`
- Keep message minimal (per D-03 "Minimal message")
- Do NOT show device name, model, or quota details here
- Styling: match existing dialog patterns in the app (check UnlockScreen or similar for reference)

Test surfaces:
- Dialog displays with correct message
- Not dismissible via back or outside tap
- "Got it" button calls device binding logic
- Device stored correctly in profiles
  </action>
  <verify>
    <automated>grep -n "non-dismissible\|barrierDismissible.*false\|This device is now tied\|device_id" lib/screens/device_auth_dialog.dart | wc -l</automated>
  </verify>
  <done>
DeviceAuthDialog created with:
- Non-dismissible dialog (barrierDismissible: false)
- Minimal message about device binding
- "Got it" button that triggers device fingerprint retrieval + storage
- Integration with AuthService to persist device_id + bound_at
  </done>
</task>

<task type="auto">
  <name>Task 5: Create DeviceAuthorizationDialog for second-device authorization</name>
  <files>lib/screens/device_authorization_dialog.dart</files>
  <action>
Create a dialog shown when user logs in from an unauthorized device (Device B while Device A is bound). Per D-03:

Dialog content:
- Title: "Authorize New Device"
- Message: "This device is not authorized. Authorize it? (1 new device per 30 days)"
- Buttons: "Authorize" | "Cancel"

Behavior:
- Called from AuthProvider.signIn() when device fingerprint doesn't match device_id and no remaining quota
- Dismissible (user can tap "Cancel" to reject)
- On "Cancel": navigate back to LoginScreen (do not proceed with login)
- On "Authorize": 
  1. Call DeviceService.getDeviceFingerprint()
  2. Store new device in profiles.authorized_devices array (append {device_id, authorized_at: now})
  3. Update profiles.last_device_switch = now
  4. Consume 1 monthly switch quota
  5. Complete login, navigate to LibraryScreen

Quota display (if user has already switched once in rolling window):
- Modify message to: "This device is not authorized. Authorize it? Next available: [date in 30 days]"
- Show "Authorize" button disabled if quota exhausted (show as grayed out)
- Show error message: "You can authorize one new device per 30 days. Next available: [date]."
- Button: Only "Cancel" available

Implementation notes:
- Per D-03, quota is rolling 30 days, not calendar month
- Calculate eligibility: `if (last_device_switch == null) → eligible; else if (now() - last_device_switch >= 30 days) → eligible; else not eligible`
- Use `authorized_devices` array in profiles (JSONB); append with Firebase-style write (Supabase allows raw JSONB updates)
- Styling: match LoginScreen or existing dialogs

Test surfaces:
- Dialog shows for Device B when Device A is bound
- "Authorize" button stores new device + updates last_device_switch
- "Cancel" button returns to LoginScreen without storing device
- Quota exhaustion shows disabled "Authorize" button with date
- Monthly rolling window calculation correct (not calendar month)
  </action>
  <verify>
    <automated>grep -n "Authorize.*Device\|authorized_devices\|last_device_switch\|30 days\|rolling" lib/screens/device_authorization_dialog.dart | wc -l</automated>
  </verify>
  <done>
DeviceAuthorizationDialog created with:
- Dialog shows when device not authorized
- "Authorize" button stores device + updates last_device_switch
- "Cancel" button returns to LoginScreen
- Quota check prevents authorization if 30-day window not elapsed
- Message displays next available date if quota exhausted
- Disabled "Authorize" button when quota exhausted
  </done>
</task>

<task type="auto">
  <name>Task 6: Update AuthProvider to orchestrate email verification + device binding workflow</name>
  <files>lib/providers/auth_provider.dart</files>
  <action>
Update AuthProvider to manage the email confirmation and device binding flows. Do NOT change public method signatures for signIn/signUp.

Add new internal state and methods:

1. **New enum or state field:**
   - Add `_requiresDeviceBinding` flag (bool, tracks if user just verified email and needs device binding)
   - This is separate from AuthStatus; used for UI routing

2. **signUp() — no changes to signature, but add internal logic:**
   - Already returns 'confirm_email' on email confirmation required
   - Now set internal flag: `_requiresDeviceBinding = false` (device binding happens after email verification, not signup)
   - Keep existing behavior

3. **Listen to auth state changes — add device binding trigger:**
   - In authStateChanges listener, check if user just confirmed email and no device_id exists yet
   - If true: set `_requiresDeviceBinding = true`, emit notification for UI to show DeviceAuthDialog
   - After DeviceAuthDialog completes (user taps "Got it"), set `_requiresDeviceBinding = false`

4. **signIn() — add device matching check:**
   - Call new helper method: `bool _matchesAuthorizedDevice(User user, currentFingerprint)` from AuthService
   - If device matches: proceed normally (login succeeds, navigate to LibraryScreen)
   - If device doesn't match AND user can authorize new device (rolling 30 days): show DeviceAuthorizationDialog
   - If device doesn't match AND user cannot authorize (quota exhausted): show error dialog with date + return to LoginScreen

5. **New getter: `bool requiresDeviceBinding`** — expose for routing

Implementation notes:
- Keep all async operations properly awaited
- Use ChangeNotifier pattern consistently
- Store timestamps locally or fetch from Supabase profiles
- Do NOT modify signUp/signIn signatures
- Device fingerprint retrieval must happen in AuthService, not AuthProvider (clean separation)

Test surfaces:
- signUp returns 'confirm_email' on email required (unchanged)
- After email verification, requiresDeviceBinding = true triggers UI routing
- signIn shows device dialogs only if needed
- Quota logic enforced correctly
  </action>
  <verify>
    <automated>grep -n "requiresDeviceBinding\|_matchesAuthorizedDevice\|authStateChanges\|notifyListeners" lib/providers/auth_provider.dart | wc -l</automated>
  </verify>
  <done>
AuthProvider updated with:
- requiresDeviceBinding getter for routing
- Device matching check in signIn flow
- Device authorization dialog trigger on quota available
- authStateChanges listener updated for email verification trigger
- All async operations properly awaited
- Public method signatures unchanged
  </done>
</task>

<task type="auto">
  <name>Task 7: Update main.dart routing to enforce email verification + device binding gates</name>
  <files>lib/main.dart</files>
  <action>
Update the app's main routing logic to enforce the email verification and device binding gates. Per requirements, users locked out entirely until both complete.

Routing logic (updated in main.dart or app-level router):

Current flow (assumed):
```
AuthStatus.loading → SplashScreen
AuthStatus.unauthenticated → LoginScreen
AuthStatus.authenticated → LibraryScreen
```

New flow:
```
AuthStatus.loading → SplashScreen
AuthStatus.unauthenticated → LoginScreen

(After signup, before email confirmed):
  → VerificationCodeScreen
  
(After email confirmed, before device bound):
  → DeviceAuthDialog (modal)
  
(After email + device confirmed):
  → LibraryScreen

(Device mismatch on login, quota available):
  → DeviceAuthorizationDialog (modal)
  → LibraryScreen (on authorize success)
  
(Device mismatch, quota exhausted):
  → Error screen or dialog
  → LoginScreen
```

Implementation:
1. Listen to `AuthProvider.status` and `AuthProvider.requiresDeviceBinding` (new getter)
2. Check `AuthProvider._error` for device quota exhaustion errors
3. Route decision tree:
   - If loading → SplashScreen
   - If unauthenticated → LoginScreen
   - If authenticated BUT requiresDeviceBinding → show DeviceAuthDialog (not full screen, overlay)
   - If authenticated → LibraryScreen

4. For device authorization dialog (on login from Device B):
   - Trigger from signIn() error or via Provider callback
   - Show DeviceAuthorizationDialog as modal
   - On success → proceed to LibraryScreen
   - On cancel → return to LoginScreen

Styling/theming: Use existing MaterialApp, theme, and navigation patterns from codebase.

Test surfaces:
- User can't skip email verification (VerificationCodeScreen mandatory)
- User can't skip device binding (DeviceAuthDialog mandatory on first login)
- Device mismatch shows authorization dialog
- All navigation flows work without errors
  </action>
  <verify>
    <automated>grep -n "VerificationCodeScreen\|DeviceAuthDialog\|DeviceAuthorizationDialog\|requiresDeviceBinding\|routing" lib/main.dart | wc -l</automated>
  </verify>
  <done>
main.dart routing updated with:
- VerificationCodeScreen shown after signup (before device binding)
- DeviceAuthDialog shown on first login after email verification
- DeviceAuthorizationDialog shown on Device B login (if quota available)
- All routing gates enforced (can't skip email or device binding)
- Error states handled (quota exhaustion returns to LoginScreen)
  </done>
</task>

<task type="auto">
  <name>Task 8: Integration test — end-to-end signup + email verification + device binding on single device</name>
  <files>integration_test/auth_e2e_test.dart</files>
  <action>
Create an end-to-end integration test that validates the complete flow on a single device. This test focuses on signup → email confirmation → device binding with no device switching.

Test scenario:
1. User signs up with email, password, display name, role
2. Signup succeeds, returns 'confirm_email' status
3. Navigate to VerificationCodeScreen
4. User sees email address and countdown timer
5. (Mock) Supabase sends 6-digit code
6. User enters code in VerificationCodeScreen
7. Code verified successfully
8. DeviceAuthDialog appears with binding message
9. User taps "Got it"
10. Device fingerprint retrieved, stored in profiles (device_id, bound_at)
11. Navigate to LibraryScreen
12. User fully authenticated

Implementation approach:
- Use `integration_test` package (standard in Flutter)
- Mock Supabase auth responses (or use Supabase test environment if available)
- Create test user with deterministic email (test_XXX@example.com)
- Verify UI elements appear/disappear at each step (VerificationCodeScreen, DeviceAuthDialog, etc.)
- Verify profiles table updated with device_id + bound_at (can query via test Supabase client)
- Verify navigation to LibraryScreen on completion

Test structure (pseudocode):
```
testWidgets('Full signup + email + device binding flow', (tester) async {
  // 1. Open app
  // 2. Tap "Sign Up"
  // 3. Fill form + submit
  // 4. Verify VerificationCodeScreen appears
  // 5. Mock code entry (6 digits)
  // 6. Verify DeviceAuthDialog
  // 7. Tap "Got it"
  // 8. Verify LibraryScreen appears
  // 9. Verify profiles table has device_id + bound_at
})
```

Do NOT test multi-device authorization in this task (that's Task 9). Focus only on single-device happy path.

Reference: Check existing test files in integration_test/ for patterns and dependencies.
  </action>
  <verify>
    <automated>grep -n "testWidgets\|signup\|email.*verification\|DeviceAuthDialog\|LibraryScreen" integration_test/auth_e2e_test.dart | wc -l</automated>
  </verify>
  <done>
Integration test created that verifies:
- Signup → VerificationCodeScreen flow
- Email verification with 6-digit code
- DeviceAuthDialog appears and device_id stored
- Navigation to LibraryScreen on completion
- Single-device happy path end-to-end
  </done>
</task>

<task type="auto">
  <name>Task 9: Integration test — multi-device authorization with quota enforcement on 2+ physical devices</name>
  <files>integration_test/device_auth_e2e_test.dart</files>
  <action>
Create an end-to-end integration test that validates device authorization flows across 2+ physical devices (or device simulators). This test validates quota enforcement, device matching, and rolling 30-day window.

Test scenario (requires 2 devices: Device A and Device B):

**Phase 1 — Device A (primary):**
1. Install app on Device A
2. Signup with email, password, display name, role
3. Verify email, bind device (same as Task 8)
4. Verify device_id stored, bound_at set, last_device_switch null
5. Logout or close app

**Phase 2 — Device B (unauthorized):**
1. Install app on Device B
2. Login with same email + password
3. DeviceAuthorizationDialog appears: "Authorize new device? (1 per month available)"
4. Tap "Authorize"
5. Device fingerprint retrieved, added to authorized_devices array
6. last_device_switch updated to now
7. Login succeeds, navigate to LibraryScreen
8. Verify profiles has Device B in authorized_devices with timestamp

**Phase 3 — Device C (quota exhausted):**
1. Install app on Device C
2. Login with same email + password
3. DeviceAuthorizationDialog appears: "Next available: [date 30 days from Device B authorization]"
4. "Authorize" button is grayed out (disabled)
5. Tap "Cancel"
6. Return to LoginScreen
7. Verify profiles unchanged (Device C not added)

**Phase 4 — Return to Device A (verify original device still works):**
1. Login on Device A
2. Verify device_id matches (no authorization needed)
3. Login succeeds, navigate to LibraryScreen

Implementation notes:
- This test is complex and requires 2–3 physical devices or emulators
- Consider using Supabase test environment with deterministic timestamps (may need to mock time)
- Alternatively, run phases sequentially with manual device setup + screenshot verification
- Verify authorized_devices array structure: `[{device_id: "xxx", authorized_at: timestamp}, ...]`
- Verify rolling window calculation: if 30 days haven't elapsed, quota check returns false

Test could be split into subtests or manual checkpoints (human verification).

Reference: Check existing multi-device test patterns (if any) in the repo for inspiration.
  </action>
  <verify>
    <automated>grep -n "DeviceAuthorizationDialog\|authorized_devices\|last_device_switch\|30 days\|quota\|disabled" integration_test/device_auth_e2e_test.dart | wc -l</automated>
  </verify>
  <done>
Integration test (or manual test plan) created that verifies:
- Device B authorization succeeds (1st switch within month)
- Device C authorization blocked (quota exhausted)
- authorized_devices array updated correctly
- last_device_switch timestamp stored
- Device A original login still works (no re-auth needed)
- Rolling 30-day window enforced (not calendar month)
- Multi-device scenario complete and testable
  </done>
</task>

<task type="auto">
  <name>Task 10: Manual testing — factory reset scenario + fallback UUID flow</name>
  <files>none (manual verification)</files>
  <action>
Perform manual tests on physical device(s) to verify edge cases not easily automated:

**Test 1: Factory Reset on Android**
1. Sign up + verify email + bind device on Device A
2. Record original device_id (via Settings → Developer → ANDROID_ID or via app logging)
3. Factory reset Device A via Settings → System → Reset options → Erase all data
4. Reinstall app
5. Login with same email + password
6. Verify DeviceAuthorizationDialog appears (treat as new device)
7. Tap "Authorize"
8. Verify login succeeds
9. Verify profiles.authorized_devices now contains new device_id (from post-reset device)
10. Verify original device_id still in profiles.device_id (bound device unchanged)

**Test 2: iOS UUID Generation + Secure Storage**
1. Sign up on iOS device
2. Verify email, bind device
3. Record app-generated UUID (from logs or test code)
4. Delete app (via Settings → iPhone Storage → [App Name] → Delete App)
5. Reinstall app
6. Login with same email + password
7. Verify app retrieves UUID from secure storage (should be same as before)
8. Verify no DeviceAuthorizationDialog (recognized as same device)
9. Login succeeds, navigate to LibraryScreen

**Test 3: Platform API Failure → Fallback UUID**
1. Simulate permission denial or platform API unavailable
2. Sign up + verify email
3. Verify fallback UUID generated (and shown in logs)
4. Tap "Got it" on device binding dialog (should allow proceed even though no system device ID available)
5. Device bound with fallback UUID
6. Login succeeds
7. Verify app uses fallback UUID on subsequent logins (consistent)

**Test 4: Email Field Display on VerificationCodeScreen**
1. Sign up with email: "test_user_123@gmail.com"
2. On VerificationCodeScreen, verify email displayed as "Code sent to test_user_123@gmail.com"
3. Verify countdown timer shows "10:00" (10 minutes)
4. Wait for timer to reach "00:00" (can be accelerated via mock)
5. Verify message changes to "Code expired. Tap 'Resend' to get a new code."

**Test 5: Resend Rate Limiting on VerificationCodeScreen**
1. On VerificationCodeScreen, tap "Resend" button
2. Verify button becomes grayed out: "Resend in 60s"
3. Countdown from 60s to 0s
4. Verify button becomes active again
5. Tap "Resend" again (should succeed)

Manual verification plan:
- Use TestFlight (iOS) or Firebase Test Lab (Android) for reproducible testing
- Take screenshots/videos for each step
- Log device_id, timestamps, and API responses for verification
- Record any errors or edge cases not handled by automated tests

Output: Test report or checklist confirming all edge cases handled.
  </action>
  <verify>
    <human-check>
Verify with user:
1. Factory reset flow tested on Android (original device_id preserved, new device added to authorized_devices)
2. iOS UUID persistence verified (UUID same after app delete + reinstall)
3. Fallback UUID generated and stored (if platform APIs unavailable)
4. VerificationCodeScreen displays email + countdown correctly
5. Resend rate limiting enforced (1 per minute)
6. All manual tests passed without errors
    </human-check>
  </verify>
  <done>
Manual testing completed with:
- Factory reset treated as new device (Device A test on Android)
- iOS UUID persisted correctly across app reinstall
- Fallback UUID generated + stored on API failure
- VerificationCodeScreen UI verified (email display, countdown, resend rate limit)
- All edge cases handled without app crashes or unexpected behavior
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description | Threat |
|----------|-------------|--------|
| User ↔ App | User enters 6-digit OTP | Brute-force guessing; interception |
| App ↔ Supabase Auth | Email confirmation, device binding | Token interception; unauthorized device binding |
| App ↔ Device APIs | Platform-specific device ID retrieval | Spoofed device ID; permission denial |
| Device A ↔ Device B | Cross-device login attempt | Unauthorized cross-device access; quota bypass |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01 | Spoofing | Device fingerprinting | Mitigate | ANDROID_ID is OS-level, tamper-resistant; iOS UUID generated locally in secure storage (no spoofing vector) |
| T-01-02 | Tampering | Device binding data (device_id, authorized_devices) | Mitigate | Stored in Supabase server-side only; client cannot directly modify. Device ID retrieved from OS APIs (not user-input). Row-level security policies enforce user-specific access. |
| T-01-03 | Repudiation | Device switch quota | Mitigate | Timestamp of last_device_switch stored server-side; rolling 30-day window calculated server-side (not client). User cannot claim "I didn't switch devices" — proof in database. |
| T-01-04 | Information Disclosure | 6-digit OTP in transit | Mitigate | Supabase Auth uses HTTPS encryption in transit. OTP sent via email (asynchronous, not directly in app). Rate-limiting (1 resend/min) + expiration (10 min) reduce brute-force window. |
| T-01-05 | Information Disclosure | Device fingerprint in logs | Mitigate | Do NOT log full ANDROID_ID or UUID to console/files. Log only hash or placeholder (e.g., "device_id: [****_XXXX]"). Device ID transmitted over HTTPS only. |
| T-01-06 | Denial of Service | Device binding quota exhaustion | Accept | User intentionally exhausted quota by switching devices. Prevents further switches for 30 days (by design). No mitigation needed; this is intended enforcement. |
| T-01-07 | Elevation of Privilege | Unauthorized device authorization | Mitigate | Dialog requires explicit user confirmation ("Authorize"). Device can only authorize if user is logged in (already authenticated). Cannot authorize new device without email + password login. |
| T-01-08 | Elevation of Privilege | Email confirmation bypass | Mitigate | Supabase Auth enforces email confirmation server-side. App-level gates enforce: user cannot access app without `session != null` AND email verified. No client-side bypass possible without Supabase keys (which are read-only). |

## Security Implementation Notes

1. **OTP Brute-Force:** Supabase Auth implements rate-limiting and expiration server-side (not client). Do NOT implement client-side brute-force detection (server is source of truth). Client enforces UI-level rate limiting (resend 1/min, expire 10 min) for UX, but server is authoritative.

2. **Device ID Spoofing:** Android's ANDROID_ID is OS-level and cannot be spoofed by apps. iOS UUID is app-generated but stored in secure storage (flutter_secure_storage uses platform keychain, which is isolated per app). Even if attacker accesses device file system, they cannot read secure storage without OS-level exploit (out of scope for app security).

3. **Device Switching:** Monthly quota enforced server-side (timestamp check on profiles.last_device_switch). Client should validate quota, but server is authoritative. No client-side quotas are enforced (server rejects invalid switches).

4. **Factory Reset:** Treated as new device (fingerprint changes after reset). User re-authenticates and can authorize the "new" device if quota available. Original device_id preserved in profiles.device_id for audit trail.

5. **Email Confirmation:** Supabase Auth's email confirmation is mandatory and cannot be bypassed. App-level gates prevent access to any screen/data until `user != null && email_verified()` (if Supabase provides verification status; if not, use `email_confirmed` column in profiles as proxy).

</threat_model>

<verification>

## Phase Completion Checks

**Email Verification:**
- [ ] VerificationCodeScreen displays user's email address
- [ ] 6-digit code entry works (auto-focus between fields)
- [ ] Countdown timer shown (10 minutes)
- [ ] Resend button rate-limited (1 per 60 seconds)
- [ ] Invalid code shows error message
- [ ] Expired code shows "Code expired" message
- [ ] Valid code triggers navigation to device binding

**Device Fingerprinting:**
- [ ] Android: ANDROID_ID retrieved via platform channel
- [ ] iOS: UUID generated on first launch, stored in secure storage
- [ ] Fallback UUID generated if platform APIs fail
- [ ] Device fingerprint retrieved consistently on all logins
- [ ] No exceptions thrown on device ID retrieval (fallback works)

**Device Binding:**
- [ ] First login after email verification: DeviceAuthDialog shown
- [ ] User taps "Got it" → device_id stored in profiles
- [ ] bound_at timestamp recorded
- [ ] email_confirmed set to true
- [ ] Subsequent logins on same device → no authorization needed

**Device Authorization (Multi-Device):**
- [ ] Second device login → DeviceAuthorizationDialog shown
- [ ] "Authorize" button stores device in authorized_devices
- [ ] last_device_switch updated to now
- [ ] Third device login (within 30 days) → "Authorize" button disabled
- [ ] Message shows "Next available: [date]"
- [ ] "Cancel" returns to LoginScreen without storing device

**Routing & Navigation:**
- [ ] Unauthenticated → LoginScreen
- [ ] After signup → VerificationCodeScreen
- [ ] After email verification → DeviceAuthDialog (first device only)
- [ ] After device binding → LibraryScreen
- [ ] Device B login → DeviceAuthorizationDialog (if quota available)
- [ ] Device C login (quota exhausted) → error dialog + LoginScreen
- [ ] All screens properly styled and themed

**Data Consistency:**
- [ ] profiles table has device_id, email_confirmed, authorized_devices, last_device_switch, bound_at
- [ ] Device IDs match platform APIs (ANDROID_ID on Android, UUID on iOS)
- [ ] authorized_devices array properly formatted: [{device_id, authorized_at}, ...]
- [ ] Rolling 30-day window calculation correct (not calendar month)
- [ ] Factory reset creates new device_id, old one not affected

**Edge Cases:**
- [ ] Platform API failure → fallback UUID generated and used
- [ ] Code expiration → resend option available
- [ ] Quota exhaustion → clear messaging + disabled button
- [ ] Factory reset → treated as new device, re-authorization needed
- [ ] Logout + login on same device → no re-authorization needed

**Code Quality:**
- [ ] No hardcoded device IDs or emails in code
- [ ] Comments reference locked decisions (D-01, D-02, D-03)
- [ ] Error messages are user-friendly
- [ ] All async operations properly awaited
- [ ] No console logs of sensitive data (device IDs, email, codes)

</verification>

<success_criteria>

Phase 1 is complete when:

1. **Email Verification Working End-to-End**
   - User receives OTP email after signup
   - User enters 6-digit code in app
   - Code verified within 10 minutes
   - User cannot access app without verified email
   - Rate-limiting enforced (1 resend per minute)

2. **Device Fingerprinting Accurate**
   - Android: ANDROID_ID retrieved correctly (matches system settings)
   - iOS: UUID generated once, persisted, consistent across launches
   - Fallback UUID generated if APIs unavailable (with user confirmation)
   - No cross-platform ID conflicts

3. **Device Binding Enforced**
   - First device bound on initial login (after email verification)
   - Same device subsequent logins do NOT require re-authorization
   - Device ID stored in profiles.device_id
   - Binding timestamp (bound_at) recorded

4. **Device Authorization Working on Multiple Devices**
   - Second device login prompts for authorization (quota available)
   - User can authorize with "Authorize" button
   - Device added to profiles.authorized_devices
   - Third device login within same 30 days shows quota exhausted
   - "Authorize" button disabled, user cannot proceed
   - Next month (30+ days later) device authorization available again

5. **Factory Reset Handled Correctly**
   - Factory reset on Android creates new device ID
   - App treats as new device, shows authorization prompt
   - Original device ID preserved in profiles.device_id
   - New device added to authorized_devices (if quota available)

6. **Routing & Navigation Complete**
   - All screens integrated into app navigation
   - No dead ends or broken navigation paths
   - User can move from signup → email verification → device binding → app
   - Error states (quota exhausted, invalid code) handled gracefully

7. **Testing Passing**
   - Single-device integration test passes (Task 8)
   - Multi-device integration test or manual test passes (Task 9)
   - Edge cases verified (Task 10)
   - No regressions in existing auth flows

8. **Security & Data Consistency**
   - No sensitive data logged to console
   - Threat model reviewed and mitigations implemented
   - Supabase row-level security enforces user-specific access
   - Device IDs from trusted OS APIs (not user-input)

**Blockers if any of above are not met:** Phase 1 is not complete. Return to executor with specific failure details.

</success_criteria>

<output>
Create `.planning/phases/01-email-device-binding/01-SUMMARY.md` when complete.

Include:
- What was built (device service, screens, provider updates, routing)
- How each locked decision (D-01, D-02, D-03) was implemented
- Test results from Tasks 8, 9, 10
- Any deviations from plan (if any)
- Known limitations or technical debt
- Next phase readiness (can Phase 2 start?)
</output>

