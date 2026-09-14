# PRD: User Authentication & Access

## Introduction

Enchiridion requires authenticated access to all book content and calculators. This PRD covers the full authentication lifecycle: registration, login, session persistence, password reset, user profile, and logout. The backend is Supabase (Auth + Postgres). The app targets Android and iOS via Flutter.

---

## Goals

- Allow users to register with email and password
- Allow registered users to log in and remain logged in across app restarts
- Allow users to reset their password via email
- Store a basic user profile (display name, role)
- Restrict all book content and calculator access to authenticated users
- Allow users to log out

---

## User Stories

### US-001: Email & Password Registration
**Description:** As a new user, I want to register with my email and password so that I can access Enchiridion.

**Acceptance Criteria:**
- [x] Registration screen has fields: display name, email, password, confirm password, role selector (student / clinician / other)
- [x] Password must be at least 8 characters; confirm password must match
- [x] On submit, creates a Supabase Auth user and inserts a matching row in the `profiles` table (id, display_name, role, created_at)
- [x] On success, navigates to the Library Landing Page
- [x] On failure (email already taken, weak password), shows an inline error message below the relevant field
- [x] "Already have an account? Log in" link navigates to the login screen
- [x] Flutter analyzer passes with no errors

### US-002: Email & Password Login
**Description:** As a registered user, I want to log in with my email and password so that I can access my account.

**Acceptance Criteria:**
- [x] Login screen has fields: email, password
- [x] On submit, calls Supabase `signInWithPassword`
- [x] On success, navigates to the Library Landing Page
- [x] On failure (wrong credentials), shows "Incorrect email or password" error message
- [x] "Forgot password?" link navigates to the password reset screen
- [x] "Don't have an account? Sign up" link navigates to the registration screen
- [x] Flutter analyzer passes with no errors

### US-003: Session Persistence
**Description:** As a returning user, I want to remain logged in after closing and reopening the app so that I don't have to log in every time.

**Acceptance Criteria:**
- [x] On cold app start, the app reads the Supabase session from local storage
- [x] If a valid session exists, the app navigates directly to the Library Landing Page, skipping the login screen
- [x] If no valid session exists, the app navigates to the login screen
- [x] A splash/loading screen is shown while the session is being checked (no flash of wrong screen)
- [x] Flutter analyzer passes with no errors

### US-004: Password Reset via Email
**Description:** As a user who has forgotten their password, I want to receive a reset link by email so that I can set a new password.

**Acceptance Criteria:**
- [x] Password reset screen has a single email field and a "Send reset link" button
- [x] On submit, calls Supabase `resetPasswordForEmail` with the entered email
- [x] On success (regardless of whether the email exists), shows a confirmation message: "If an account exists for this email, a reset link has been sent."
- [x] "Back to login" link navigates back to the login screen
- [x] Flutter analyzer passes with no errors

### US-005: User Profile Display
**Description:** As a logged-in user, I want to see my display name and role in a profile section so that I can confirm my account details.

**Acceptance Criteria:**
- [x] Profile screen shows: display name, email (read-only), role
- [x] Data is fetched from the `profiles` table in Supabase using the current user's ID
- [x] Profile screen is accessible from a settings/account icon in the app (location TBD by navigation PRD)
- [x] Flutter analyzer passes with no errors

### US-006: Access Control Guard
**Description:** As a developer, I need unauthenticated users to be redirected to the login screen so that book content and calculators are protected.

**Acceptance Criteria:**
- [x] A route guard (or auth wrapper widget) checks session state before rendering any protected screen
- [x] Unauthenticated navigation attempts to any protected route redirect to the login screen
- [x] After login, the user is sent to the originally requested screen (or the Library if no specific route)
- [x] Flutter analyzer passes with no errors

### US-007: Logout
**Description:** As a logged-in user, I want to log out so that my session is ended on this device.

**Acceptance Criteria:**
- [x] A "Log out" action is accessible from the profile/settings screen
- [x] On tap, calls Supabase `signOut`
- [x] On success, clears local session and navigates to the login screen
- [x] Flutter analyzer passes with no errors

---

## Functional Requirements

- FR-1: The app must use Supabase Auth for all authentication operations (sign up, sign in, sign out, password reset)
- FR-2: On registration, the system must create a row in the `profiles` table: `id` (UUID, FK to auth.users), `display_name` (text), `role` (enum: student | clinician | other), `created_at` (timestamp)
- FR-3: Session state must persist across app restarts using Supabase's built-in session storage
- FR-4: All screens except login, registration, and password reset must be wrapped in an auth guard that redirects unauthenticated users to login
- FR-5: Password validation: minimum 8 characters, confirmation must match
- FR-6: All auth error messages must be human-readable (no raw Supabase error codes shown to users)
- FR-7: The password reset flow must not reveal whether an email is registered (security: always show the same confirmation message)

---

## Non-Goals

- Social login (Google, Apple) â€” not in this version
- Two-factor authentication â€” not in this version
- Email verification on signup â€” not in this version (may be enabled later via Supabase settings)
- In-app password change â€” not in this version
- Account deletion â€” not in this version

---

## Technical Considerations

- Use `supabase_flutter` package for all Supabase interactions
- Store Supabase URL and anon key in environment variables / `--dart-define` flags; never hardcode in source
- Use a `StreamBuilder` or `ValueListenableBuilder` on `supabase.auth.onAuthStateChange` to reactively update the auth guard
- The `profiles` table should have Row Level Security (RLS) enabled: users can only read/update their own row
- Route management: use GoRouter with a redirect callback that reads auth state

---

## Success Metrics

- A new user can complete registration and reach the Library in under 60 seconds
- A returning user reaches the Library on cold start in under 2 seconds (no login prompt)
- Zero unauthenticated access to protected routes in any navigation path

---

## Open Questions

- Should role be editable after registration, or fixed at signup?
- Should the app support offline mode for previously loaded content even when the session expires?
