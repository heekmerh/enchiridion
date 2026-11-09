# Phase 1: Email Confirmation & Device Binding — Context

**Date:** 2026-05-22  
**Status:** Context captured, ready for planning

---

## Domain

This phase secures app access by requiring email confirmation at signup and tying each account to a specific device. Users can authorize one additional device per 30-day rolling period. Together, email confirmation + device binding create a two-factor access control system that reduces unauthorized app sharing while remaining user-friendly.

---

## Locked Requirements (From ROADMAP.md)

- [ ] Supabase Auth setup — enable email confirmation
- [ ] Supabase schema — add device_id, email_confirmed, authorized_devices columns
- [ ] Device fingerprint service — get platform-specific device ID
- [ ] SignUpScreen — create with email, password, name, role
- [ ] ConfirmEmailScreen — "Check your email" + resend button
- [ ] Device binding logic — tie first device on login
- [ ] Device auth dialog — prompt for monthly device switch
- [ ] Block app access if unconfirmed/unauthorized
- [ ] Test end-to-end on 2 devices
- [ ] Update login flow UI

---

## Decisions Captured

### Device Fingerprint Strategy

**Android Identifier:**
- Use `ANDROID_ID` (unique per app, survives reinstalls, Google-recommended)
- Implement via platform channel to `Settings.Secure.ANDROID_ID`

**iOS Identifier:**
- Use UUID stored locally in secure storage (more control than `identifierForVendor`)
- Generate on first app launch, store in `flutter_secure_storage`
- Rationale: gives us control over UUID lifecycle; identifierForVendor resets if app deleted

**Fallback Strategy:**
- If device fingerprint retrieval fails (permission denial, platform issue): generate random UUID, store in secure storage, show user confirmation dialog
- Allow user to proceed (don't block login)
- Rationale: app should remain functional even if platform APIs unavailable

**Device Change Handling:**
- If device fingerprint changes after first login (e.g., factory reset): treat as new device
- Show device authorization prompt (user can switch if monthly quota available)
- Rationale: treat factory reset like a new physical device; enforce same device switch policy

---

### Email Confirmation Flow

**Verification Method:**
- Use in-app code entry (not email link click-through)
- Supabase sends 6-digit OTP to user email
- User enters code in VerificationCodeScreen
- Rationale: better mobile UX than email link; easier to support via deep linking

**Code Expiration & Resends:**
- Code expires after 10 minutes
- User can resend once per minute (rate-limited)
- Rationale: security-conscious; prevents brute-force guessing

**Access Control:**
- User is locked out of app completely until email verified
- Cannot browse books, calculators, or questions without verification
- Can view only the verification screen + resend button
- Rationale: enforces email as primary security control before device binding applies

**Verification Screen UI:**
- Informative approach: shows "Code sent to [email]", countdown timer, Resend button
- Include helpful text: "Check your email for a 6-digit code. This expires in X minutes."
- Rationale: gives user context + time pressure awareness; reduces support questions

---

### Device Authorization Flow

**Timing of Authorization Dialog:**
- Show on first login ever (immediately after email verification confirms)
- Dialog: "This device is now tied to your account."
- User must acknowledge before accessing app
- Rationale: inform user upfront about device binding policy; no surprises later

**Minimal Device Info:**
- Show only: "This device is now tied to your account."
- Don't show device name, model, or switch quota in initial dialog
- Rationale: avoid overwhelming user with details; keep first-time experience simple

**Second Device Scenario (Within 30 Days):**
- When user logs in from Device B: show dialog: "This device not authorized. Authorize device? (1 per month available)"
- User can tap "Authorize" (consumes 1 monthly switch) or "Cancel" (return to login)
- Rationale: clear choice; user understands consequence of authorizing new device

**Monthly Switch Quota Model:**
- Rolling 30 days from date of last device switch
- Reset timestamp: `last_device_switch + 30 days`
- User gets 1 fresh switch on month boundary (not calendar month, which would create unfair edge cases)
- Rationale: rolling window is fairer than calendar month; users at month-end won't suddenly hit limit

---

## Code Context

### Existing Infrastructure

**AuthService** (`lib/services/auth_service.dart`):
- Supabase auth configured with email confirmation enabled
- `signUp()` method returns null session until user confirms email
- `ensureProfile()` creates user profile after email confirmation
- `currentSession` and `authStateChanges` stream available for listening

**AuthProvider** (`lib/providers/auth_provider.dart`):
- Listens to `AuthService.authStateChanges`
- Returns `'confirm_email'` status after signup (indicates email verification needed)
- Loads AccessService on successful auth

**LoginScreen** + **RegisterScreen**:
- Login/register UI already exists
- RegisterScreen takes email, password, display_name, role
- Routing after signup exists

**Database:**
- Supabase `profiles` table exists with columns: `id`, `display_name`, `role`
- Need to add: `device_id`, `email_confirmed`, `authorized_devices`, `last_device_switch`, `bound_at`

### New Components to Create

1. **VerificationCodeScreen** — 6-digit code entry + resend button + countdown timer
2. **DeviceService** — get platform-specific device fingerprint (Android: ANDROID_ID, iOS: UUID from secure storage)
3. **DeviceAuthDialog** — "Device tied to account" confirmation dialog
4. **DeviceAuthorizationDialog** — "Authorize new device?" prompt with quota display

### Integration Points

- **PostSignup Flow:** SignUp → VerificationCodeScreen (new) → DeviceService.getFingerprint() → DeviceAuthDialog (new) → LibraryScreen
- **PostLogin Flow:** Login → DeviceService.getFingerprint() + check against bound device → if mismatch, show DeviceAuthorizationDialog (new) → LibraryScreen
- **Supabase Migration:** Run migration to add device columns to profiles table before Phase 1 implementation begins

---

## Deferred Ideas

- **Biometric authentication** (fingerprint/Face ID) — consider for v2 (Phase 5 or later)
- **Device recovery flow** — "I lost my device" account recovery — out of scope, consider for Phase 5
- **Admin portal** — view/revoke authorized devices — future feature
- **Device naming** — let users name their devices (e.g., "My iPhone") — nice-to-have for v2

---

## Success Criteria

- [ ] Email verification with in-app code entry working end-to-end
- [ ] User locked out until email confirmed (no bypass)
- [ ] Device fingerprint correctly identified on Android + iOS
- [ ] First device bound on initial login
- [ ] Second device prompts for authorization within same 30-day window
- [ ] Monthly quota resets on rolling 30-day boundary
- [ ] Fallback UUID generation works if platform APIs fail
- [ ] Factory reset treated as new device (requires re-authorization)
- [ ] All dialogs and screens display correct messaging
- [ ] End-to-end testing on 2+ physical devices (Android + iOS)

---

## Next Steps

→ `/gsd:plan-phase 1`

This will create `.planning/phases/01-email-device-binding/01-PLAN.md` with:
- Detailed task breakdown (Supabase schema, DeviceService, UI screens, integration, testing)
- Dependency graph
- Implementation sequence
- Effort estimates per subtask

---

## Canonical References

- [ROADMAP.md](.planning/ROADMAP.md) — Phase 1 overview and task list
- [REQUIREMENTS.md](.planning/REQUIREMENTS.md) — Detailed requirement specs for email + device binding
- [PROJECT.md](.planning/PROJECT.md) — Project context, tech stack (Flutter, Supabase)
- [AuthService](.enchiridion/lib/services/auth_service.dart) — Existing Supabase integration
- [AuthProvider](.enchiridion/lib/providers/auth_provider.dart) — State management for auth
- [LoginScreen](.enchiridion/lib/screens/login_screen.dart) — Login UI
- [RegisterScreen](.enchiridion/lib/screens/register_screen.dart) — Signup UI

---

*Context captured: 2026-05-22*
