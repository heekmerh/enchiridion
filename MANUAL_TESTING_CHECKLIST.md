# Task 10: Manual Testing Checklist — Edge Cases & Factory Reset Scenarios

This document provides a comprehensive manual testing checklist for Phase 1 (Email Confirmation & Device Binding). These tests verify edge cases that are difficult to automate and require real devices.

**Date:** 2026-05-23  
**Scope:** Factory reset, fallback UUID, platform-specific fingerprinting, iOS UUID persistence  
**Status:** READY FOR EXECUTION

---

## Test 1: Factory Reset on Android

**Purpose:** Verify that factory reset creates new device_id and triggers re-authorization.

### Setup
- Android device with app installed and bound (from Phase 1 signup)
- Account email, password, and original device_id recorded

### Steps
1. Open app → verify login works (no device dialog)
2. Note original device_id from Settings → Developer → ANDROID_ID (or app logs)
3. Close app
4. Settings → System → Reset options → Erase all data
5. **Wait for full factory reset** (usually 1-5 minutes)
6. Turn on device, allow setup
7. Reinstall app from Play Store or via APK

### Expected Behavior
- **On app launch:** Login screen appears
- **On login with same email + password:**
  - DeviceAuthorizationDialog appears ("This device is not authorized")
  - Message includes "Authorize it? (1 new device per 30 days)"
  - "Authorize" button is enabled (quota available)
- **On "Authorize" tap:**
  - New device_id retrieved (different from original per factory reset)
  - Device stored in profiles.authorized_devices
  - last_device_switch updated to now
  - Login succeeds → LibraryScreen
- **Verification in Supabase:**
  - profiles.device_id still has original device ID (unchanged)
  - profiles.authorized_devices contains entry with NEW device_id
  - profiles.last_device_switch is recent timestamp

### Test Evidence
- Screenshot 1: Settings showing ANDROID_ID before reset
- Screenshot 2: DeviceAuthorizationDialog after reset
- Screenshot 3: LoginScreen → LibraryScreen after "Authorize" tap
- Database query result showing authorized_devices array

---

## Test 2: iOS UUID Generation & Persistence

**Purpose:** Verify UUID generated once and persisted across app delete/reinstall.

### Setup
- iOS device (iPhone/iPad) with app installed
- Fresh account (never before used)

### Steps
1. **First launch:**
   - Install app (or run on simulator)
   - Sign up with email/password
   - Verify email via OTP code
   - DeviceAuthDialog appears and bind device
   - Navigate to LibraryScreen
   - Note generated UUID (from app logs or Settings bundle)

2. **Simulate app delete + reinstall:**
   - Delete app: Settings → [App Name] → Remove App
   - Reinstall: App Store or Xcode
   - Launch app

3. **Verify UUID persistence:**
   - Login with same email + password
   - **No** DeviceAuthorizationDialog should appear (same device recognized)
   - Navigate to LibraryScreen
   - Verify UUID in logs is **identical** to Step 1

### Expected Behavior
- First launch: UUID generated, stored in secure storage
- After delete/reinstall: Same UUID retrieved from flutter_secure_storage
- Device recognized as same (no re-authorization needed)
- UUID does NOT change across app sessions

### Test Evidence
- Log output showing UUID before delete (e.g., "device_id: uuid-1234...")
- Log output showing UUID after reinstall (same uuid-1234...)
- Screenshot showing LibraryScreen without authorization dialog

### Database Check
- profiles.device_id matches UUID-1234 (consistent across sessions)
- profiles.authorized_devices empty (no device switches)

---

## Test 3: Platform API Failure → Fallback UUID

**Purpose:** Verify fallback UUID generated and persists when platform APIs unavailable.

### Setup
- Android device OR simulator with restricted permissions
- Account ready for signup

### Steps
1. **Simulate API failure (choose one method):**
   - **Android:** Disable "Storage" permission in Settings → Apps → [App] → Permissions
   - **iOS:** Restrict app permissions (Settings → Privacy)
   - OR manually test with mock: modify DeviceService to return error

2. **Sign up + email verification:**
   - Create new account
   - Verify email (OTP flow)
   - DeviceAuthDialog appears
   - Tap "Got it" to bind device

3. **Expected:** Fallback UUID generated and stored (per D-01)
   - Check logs: "Fallback UUID generated" or similar message
   - Device binds successfully despite API failure
   - Login succeeds

4. **Verify UUID persists:**
   - Close app
   - Reopen and login
   - Verify same fallback UUID used (recognized as same device)
   - No DeviceAuthorizationDialog appears

### Expected Behavior
- Platform API fail → trigger fallback logic
- Generate random UUID, store in flutter_secure_storage
- User can proceed with app (no blocking)
- UUID consistent on subsequent logins (same device recognized)

### Test Evidence
- Log output showing: "Platform API failed, using fallback UUID: uuid-fallback-xxxx"
- App continues normally despite failure
- Logout → Login: same UUID used (device recognized)
- Screenshot: LibraryScreen accessible after fallback binding

### Database Check
- profiles.device_id = uuid-fallback-xxxx (fallback format)
- Device still functions as bound device on subsequent login

---

## Test 4: VerificationCodeScreen Email Display & Countdown

**Purpose:** Verify email display and countdown timer functionality per D-02.

### Setup
- Fresh account signup attempt
- Email = "test_user_123@example.com"

### Steps
1. **Sign up with above email:**
   - Navigate to RegisterScreen
   - Enter email: test_user_123@example.com
   - Enter password, display name, role
   - Submit signup

2. **VerificationCodeScreen should display:**
   - Title: "Confirm Your Email"
   - Message: "Code sent to test_user_123@example.com"
   - Countdown: "Code expires in 10:00" (10 minutes)

3. **Monitor countdown:**
   - Countdown decrements every second
   - Format: m:ss (e.g., "10:00" → "9:59" → ... → "0:30")
   - After 10:00 elapses: Message changes to "Code expired. Tap 'Resend' to get a new code."

4. **Resend button behavior:**
   - Initial state: "Didn't get the code? Resend" (active)
   - Tap "Resend"
   - Button becomes: "Resend in 60s" (disabled/grayed)
   - Countdown from 60 to 0
   - At 0: Button becomes active again ("Didn't get the code? Resend")

### Expected Behavior
- Email always displayed with no truncation
- Countdown starts at 10:00 and decrements to 0:00
- After expiration, "Code expired" message shown
- Resend button disabled for exactly 60 seconds (1-minute rate limit per D-02)
- User can resend unlimited times, but each resend triggers 60-second cooldown

### Test Evidence
- Screenshot 1: Initial screen with email + 10:00 countdown
- Screenshot 2: Countdown at 5:30 mark
- Screenshot 3: "Code expired" message (after 10:00 elapses)
- Screenshot 4: "Resend in 60s" (after tap, button grayed)
- Screenshot 5: Button active again (after 60 seconds)

---

## Test 5: Multi-Device Authorization on Real Devices

**Purpose:** Verify Device B authorization and Device C quota enforcement with real physical devices.

### Setup
- **Device A:** Android or iOS with app already bound
- **Device B:** Different Android or iOS device
- **Device C (optional):** Third device to test quota exhaustion
- Shared test account email/password

### Phase 1 — Verify Device A (Primary)
1. Login on Device A
2. Verify: No authorization dialog, direct access to LibraryScreen
3. Note timestamp

### Phase 2 — Authorize Device B
1. Login on Device B with same credentials
2. **Expected:** DeviceAuthorizationDialog appears
   - Message: "This device is not authorized. Authorize it? (1 new device per 30 days)"
   - "Authorize" button active
3. Tap "Authorize"
4. **Expected:** Login succeeds → LibraryScreen
5. Verify in Supabase:
   - profiles.authorized_devices contains Device B entry with timestamp
   - profiles.last_device_switch = now
6. **Note timestamp for Device B switch**

### Phase 3 — Verify Device A Still Works
1. Return to Device A
2. Logout
3. Login again
4. **Expected:** No authorization dialog, direct to LibraryScreen
   - Verify original device always recognized
   - No quota consumed (original device exempt)

### Phase 4 — Block Device C (Quota Exhausted)
1. Login on Device C with same credentials
2. **Expected:** DeviceAuthorizationDialog appears with:
   - Message: "This device is not authorized. ... [Next available: 6/22/2026]" (30 days from Phase 2 timestamp)
   - "Authorize" button disabled/grayed
3. Tap "Cancel"
4. **Expected:** Return to LoginScreen without login
5. Verify in Supabase:
   - profiles.authorized_devices unchanged (no Device C entry)
   - profiles.last_device_switch unchanged (still Device B timestamp)

### Test Evidence
- Screenshot 1: Device A login (no dialog) → LibraryScreen
- Screenshot 2: Device B login with DeviceAuthorizationDialog
- Screenshot 3: Device B after "Authorize" → LibraryScreen
- Screenshot 4: Device C with disabled "Authorize" button + date message
- Screenshot 5: Device C after "Cancel" → LoginScreen
- Database dump: authorized_devices array and last_device_switch timestamp

---

## Test 6: Resend Rate Limiting (1 per Minute)

**Purpose:** Verify resend button rate limiting per D-02.

### Setup
- VerificationCodeScreen displayed (after signup)

### Steps
1. Tap "Resend" button (assuming button enabled)
2. **Expected:** Button immediately grays out: "Resend in 60s"
3. Countdown from 60 to 1 (should take 60 seconds real-time)
4. At 0: Button becomes active again ("Didn't get the code? Resend")
5. Tap "Resend" again
6. **Expected:** Another 60-second cooldown begins

### Test Evidence
- Video/GIF showing countdown from 60 → 1 → 0
- Multiple resend attempts each triggering 60-second cooldown

---

## Test 7: Incorrect Code Attempt

**Purpose:** Verify error handling for invalid codes.

### Setup
- VerificationCodeScreen displayed with valid code available

### Steps
1. **Enter wrong code** (e.g., 000000 instead of correct code)
2. Tap "Verify Code"
3. **Expected:**
   - Error message: "Incorrect code. Try again."
   - Input fields cleared
   - Focus reset to first field
4. **Enter correct code** (from email)
5. Tap "Verify Code"
6. **Expected:** Verification succeeds (no error)

### Test Evidence
- Screenshot 1: Error message after wrong code
- Screenshot 2: Fields cleared, ready for re-entry
- Screenshot 3: Success after correct code

---

## Test Execution Summary

| Test | Platform | Status | Notes |
|------|----------|--------|-------|
| 1. Factory Reset (Android) | Android | PENDING | Requires Android device + full reset |
| 2. iOS UUID Persistence | iOS | PENDING | Requires iOS device + app delete/reinstall |
| 3. Fallback UUID | Android/iOS | PENDING | Requires permission denial simulation |
| 4. VerificationCodeScreen UI | Android/iOS | PENDING | Can run on simulator |
| 5. Multi-Device Auth | Android/iOS (2-3 devices) | PENDING | Requires multiple devices |
| 6. Resend Rate Limiting | Android/iOS | PENDING | Can run on simulator |
| 7. Incorrect Code Handling | Android/iOS | PENDING | Can run on simulator |

---

## Execution Commands

To run manual tests, use:

```bash
# Navigate to Flutter app directory
cd enchiridion

# Build APK for Android device testing
flutter build apk --release

# Build IPA for iOS device testing
flutter build ios --release

# Run on connected device
flutter run

# View logs during testing
flutter logs
```

---

## Success Criteria

All 7 manual tests must PASS:
- ✅ Factory reset treated as new device (test 1)
- ✅ iOS UUID persisted across app delete/reinstall (test 2)
- ✅ Fallback UUID generated and stored (test 3)
- ✅ VerificationCodeScreen UI correct (test 4)
- ✅ Multi-device authorization working with quota (test 5)
- ✅ Resend rate limiting enforced (test 6)
- ✅ Error handling for invalid codes (test 7)

If any test fails, document failure and blocking issue in Phase 1 SUMMARY.md.

---

**Date Completed:** _________  
**Tester Name:** _________  
**Device(s) Used:** _________  
**Overall Result:** ✅ PASS / ❌ FAIL
