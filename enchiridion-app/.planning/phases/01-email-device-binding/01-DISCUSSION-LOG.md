# Phase 1 — Discussion Log

**Date:** 2026-05-22  
**Participants:** User, Claude

---

## Areas Discussed

### 1. Device Fingerprint Strategy

**Questions:**

1. **Which device identifier for Android?**
   - Options: ANDROID_ID, Android Serial Number, Combination approach
   - Selected: **ANDROID_ID**
   - Rationale: Native Google recommendation, unique per app, survives reinstalls

2. **Which identifier for iOS?**
   - Options: identifierForVendor, UUID stored locally
   - Selected: **UUID stored locally**
   - Rationale: More control over UUID lifecycle; independent of app deletion

3. **If device fingerprint retrieval fails?**
   - Options: Skip device binding, Generate fallback UUID, Block login
   - Selected: **Prompt user and generate fallback UUID**
   - Rationale: Graceful degradation; keep app functional with fallback identifier

4. **If device fingerprint changes after first login (e.g., factory reset)?**
   - Options: Treat as new device, Allow login with re-verification, Block with recovery flow
   - Selected: **Treat as new device**
   - Rationale: Factory reset ≈ new device; same device switch policy applies

---

### 2. Email Confirmation UX

**Questions:**

1. **After signup, what flow?**
   - Options: Check email screen, App with banner, In-app code entry
   - Selected: **In-app verification code entry**
   - Rationale: Better mobile UX than email link; easier to support

2. **Code expiration & resends?**
   - Options: 10 min / 1/min resend, 30 min / 60s resend, 60 min / no limit
   - Selected: **10 minutes, once per minute**
   - Rationale: Security-conscious approach; limits brute-force attacks

3. **If user skips verification?**
   - Options: Locked out completely, Limited access with banner, Access with reminder
   - Selected: **Locked out of app completely**
   - Rationale: Email confirmation is primary security control; no workarounds

4. **Verification screen appearance?**
   - Options: Minimal code input, Informative with email + countdown, Educational with spam tips
   - Selected: **Informative with email + countdown timer**
   - Rationale: Gives user context and time pressure; reduces confusion

---

### 3. Device Authorization Flow

**Questions:**

1. **When to show authorization dialog?**
   - Options: First login ever, Only on new device, Every login
   - Selected: **First login ever**
   - Rationale: Inform user about device binding upfront; no surprises

2. **What device info to show?**
   - Options: Minimal message, Device name + policy, Device name + quota + date
   - Selected: **Minimal: "This device is now tied to your account"**
   - Rationale: Avoid overwhelming user; keep first-time experience simple

3. **When user logs in from 2nd device?**
   - Options: Dialog with option to switch, Dialog showing remaining switches, Block login
   - Selected: **Dialog: "This device not authorized. Switch device? (1 per month)"**
   - Rationale: Clear choice; user understands they're consuming a monthly switch

4. **How to calculate monthly quota?**
   - Options: Calendar month, Rolling 30 days, Paid model
   - Selected: **Rolling 30 days from last switch**
   - Rationale: Fairer than calendar month; no edge-case penalties at month-end

---

## Key Insights Captured

- **Security Posture:** User prioritizes security (strict lockout, rate limiting, fingerprint verification)
- **UX Philosophy:** Minimal friction on happy path, but enforced constraints at boundaries
- **Device Model:** Fair treatment of devices (factory reset = new device; rolling 30-day window)
- **Code-First:** In-app verification code (not email link) indicates user values seamless mobile experience

---

## Deferred Ideas

1. **Biometric authentication** (fingerprint/Face ID) — Phase 5 or later
2. **Device recovery flow** ("I lost my device") — Phase 5 or later
3. **Admin portal** for viewing/revoking devices — future feature
4. **Device naming** ("My iPhone", "Work Phone") — nice-to-have for v2

---

## Next Phase

All discussion areas resolved. User is ready for planning.

---

*Discussion completed: 2026-05-22*
