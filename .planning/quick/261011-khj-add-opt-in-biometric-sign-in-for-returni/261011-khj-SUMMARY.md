---
quick_id: 261011-khj
status: complete
---
Implemented optional biometric sign-in for returning Android users. Code commit: `14fe808`.

Users select “Use fingerprint next time” during successful password login. The app stores that login in a separate Android Keystore-protected secure-storage namespace, requiring fresh strong-biometric authentication per credential read. Fingerprints are never collected. Enrollment requires Android 9+ and enrolled supported biometrics. Other platforms and unsupported devices keep password login.

Biometric sign-in uses the existing server password authentication and AuthGate device authorization path. Cancellation does not sign in, invalid credentials disable enrollment, and network errors preserve it for retry. Login and Profile provide a Forget action. Explicit opt-in survives logout; UI states that anyone with enrolled biometrics can use it. Google login in the existing working copy clears previous biometric enrollment. Existing active-session behavior is unchanged.

Android integration: FlutterFragmentActivity, USE_BIOMETRIC permission, AppCompat themes including Android 12 variants, and backup disabled for device-bound credentials. Added local_auth; upgraded flutter_secure_storage to 11.2.0 to require biometrics per operation rather than reuse an in-memory decrypted key.

Validation:
- 13 service/channel tests passed: secure native options on every read, consent, unsupported devices, failed enrollment, successful backend login, cancellation, unavailable biometrics, invalid credentials, network failure, missing/malformed data, forgetting and concurrent taps.
- Flutter analysis of the changed Dart sources and test passed with no issues.
- Dart formatting check passed for all changed Dart files.
- Android debug APK build passed using installed Java 17. Artifact: enchiridion/build/app/outputs/flutter-apk/app-debug.apk.
- Real-device enrollment, biometric prompt and full live backend/device-gate login remain to be checked; no physical device was connected.

Existing uncommitted work was preserved. Only task changes were committed; existing Google-login integration remains in the user's working changes. Execution was inline under the skill adapter spawn restriction. ROADMAP unchanged.
