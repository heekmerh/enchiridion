# NDPA 2023 — Compliance gap review (Enchiridion)

> Reviewed against the app's actual implementation (September 2026,
> pre-launch). "Done" = already handled in code. "Gap" = must be closed
> before or shortly after launch, roughly in priority order. Section
> references are to the Nigeria Data Protection Act 2023.

## Already compliant (keep true)

1. **Data minimisation.** No analytics, crash-reporting, advertising IDs,
   location, or contacts collection. Local notifications only — no push
   provider sees user data.
2. **Access control.** Per-user RLS on profiles, daily_study_stats,
   question_reviews, flagged_questions, processed_payments; user_book_access
   readable only when granted and unexpired (server-enforced expiry, no
   client override possible — the client cannot grant itself access).
3. **Payment data.** Card/bank/USSD details go to Flutterwave only; the Edge
   Function verifies amounts server-side with anti-replay ledger.
4. **Leaderboard privacy.** SECURITY DEFINER RPCs expose display-name +
   points only, never user IDs or emails.
5. **Purpose limitation by architecture.** Notes, bookmarks, clips, reading
   history stay on-device; they cannot leak server-side because no API
   exists for them.
6. **Account security.** Email-verification codes, hashed passwords (GoTrue),
   one-device binding with 30-day switch cooldown.
7. **Deletion cascade.** All user tables reference `auth.users(id) on delete
   cascade`, so deleting the auth user wipes profile, stats, reviews,
   entitlements, and payment references in one operation.

## Gaps to close

### P0 — before launch

1. **Privacy notice + lawful-basis at signup (ss. 24, 25, 39).** The
   register screen collects email, display name, and role with no privacy
   notice, no consent record, and no link to the website policy. Add: a
   short notice + checkbox/link on `register_screen.dart`, and record
   acceptance (timestamp + policy version) in the profile row.
2. **Data-subject rights workflow (ss. 34–38).** Users can edit display
   name/photo, but there is no in-app path for data export, correction of
   other fields, or account deletion. Minimum viable: a support-operated
   process at support@enchiridion.site (export via SQL, delete via
   service-role auth admin delete) with response-time tracking; then build
   in-app delete-account. Note: deleting the auth user does NOT remove the
   user's avatar objects from storage — add a cleanup step (Edge Function
   or admin runbook) or avatars of deleted users persist publicly.
3. **Avatar bucket is public (over-collection of exposure).** Any profile
   photo is world-readable to anyone with the link. Disclosed in the draft
   policy, but consider signed URLs or access-checked serving before
   launch; at minimum keep the disclosure.
4. **Breach response plan (s. 40).** No incident runbook exists for the
   72-hour NDPC notification duty or user notification. Draft a one-page
   plan: detection (Supabase logs), containment (revoke keys, rotate
   service_role), assessment, notification, review. Owner + deputy named.
5. **Children/minors.** Role list includes "student" with no age assurance.
   The draft policy requires under-18s to have guardian permission, but
   nothing in-app establishes age. Decide: minimum-age self-declaration at
   signup (and a parental-consent path for under-13s) or an explicit 18+
   positioning.

### P1 — shortly after launch

6. **DPO + NDPC filing assessment (ss. 32, 33; NDPC guidance).** Assess
   whether Enchiridion is a Data Controller of Major Importance (volume,
   health-adjacent data, device identifiers). If yes: designate a Data
   Protection Officer, register with the NDPC, and file the annual audit
   return. If no: minute the assessment so the decision is documented.
7. **Retention schedule (storage-limitation principle, s. 24(1)(d)).**
   Stats, reviews, flags, and payment references currently live forever.
   Adopt explicit retention (e.g. anonymise inactive accounts after N
   years; keep payment references per financial-record duties) and
   implement purge jobs.
8. **Sub-processor paperwork.** Confirm Supabase hosting region for the
   project and execute/obtain its DPA; confirm Flutterwave's data
   processing terms cover the transaction metadata we store; document the
   email/OTP delivery path. Disclose transfers outside Nigeria if any
   (adequacy/contract safeguards, s. 41).
9. **Leaderboard consent/choice.** Display names are public to all
   authenticated users by design. Add an opt-out (or pseudonymous default)
   for users who do not want to appear.
10. **Device identifier DPIA note.** Android's ANDROID_ID persists across
    reinstalls and is stored server-side. Record the necessity/
    proportionality reasoning (account sharing prevention) and the
    fallback-UUID design in a short DPIA note.
11. **Cookie/website tracking.** When the marketing site goes live, its own
    trackers (if any) need a cookie notice consistent with this policy —
    the app itself sets no cookies.

### Watchlist

- Institutional sales (schools/hospitals) will need Data Processing
  Agreements and possibly joint-controller terms — not required for
  direct-to-learner sales.
- If push notifications or analytics are ever added, update the policy,
  add consent where required, and re-run this review.
- The seeded QA account and any manual `device_binding_exempt` flags must
  never exist in the production project.
