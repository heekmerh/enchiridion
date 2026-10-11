---
quick_id: 261011-khj
---
Add opt-in fingerprint sign-in for returning Android app users.

1. Add local_auth capability detection and a separate hardware biometric protected secure-storage namespace for optional saved login credentials. Support enrolled strong biometrics on Android 9+, with password fallback everywhere. Never store fingerprints or plaintext credentials in preferences.
2. Add opt-in setup on successful password login, biometric login through normal backend authentication and AuthGate, cancellation/error feedback and a forget option in login/Profile. Keep logout functional while retaining explicitly opted-in biometric login on that device.
3. Add meaningful service tests for capability, consent, cancellation, invalid credentials and forget; run analysis, tests and Android compilation where available. Commit only this task's changes and update STATE/SUMMARY.

Inline execution per skill adapter. Preserve existing work; no ROADMAP edits.
