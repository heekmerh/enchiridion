# Enchiridion — Privacy Policy

**Last updated: 25 September 2026**

Enchiridion ("we", "us") provides an offline-first clinical companion app
with textbooks, calculators, instrumentation guides, OSCE stations, and
exam preparation with spaced repetition. This policy explains what personal
data we collect, why, and the choices you have. Contact:
**support@enchiridion.site**.

## 1. Data we collect

**Account data.** When you register: email address, password (stored only as
a one-way hash by our authentication provider — we cannot see it), display
name, and role (student, clinician, or other). If you add a profile photo,
the image is stored in our file storage and served through a public link
tied to your account.

**Device data.** To enforce one account per device, the app records a device
identifier (on Android, the platform device ID; on iPhone and other
platforms, a randomly generated ID stored securely on your device), the date
the device was bound, and a history of previously authorised devices with
their authorisation dates.

**Study data.** Your answers, per-question review progress (attempts, lapses,
due dates), daily statistics (questions answered, correct answers,
performance points), and module/exam-prep progress. This is stored on your
device first and synced to your account when you are signed in, so it
follows you across devices.

**Entitlements and payments.** Which Premium access you hold, its start and
expiry dates, and how it was granted. Website payments are processed by
**Flutterwave** and in-app payments by **Google Play**; we never see or store
your card number, bank details, or USSD PIN. We keep the payment reference
(Flutterwave transaction ID or Google Play order ID and purchase token),
plan, amount, currency, and verification result so we can verify purchases,
prevent one purchase being used by two accounts, and avoid double charges.

**Subscription records.** For a subscription we store the plan, provider,
status, whether it renews, the current paid period, cancellation and refund
dates, and an audit history of those changes, so the app and website can
show when you will next be billed and how to cancel. Renewals are run by the
provider you bought through.

**Email preferences.** Whether you asked to receive Enchiridion offers, when
and where you gave or withdrew that consent, and your region if you told us.
Account, security and billing emails are sent regardless of that choice.

**Terms acceptance.** The version of the Terms and Conditions you accepted
at sign-up, and when — kept as our record that you agreed to them.

**Support and content reports.** Anything you send to support@enchiridion.site,
and any question you flag in-app (question ID and reason).

**Synced to your account.** When you are signed in, the following sync to
your account so a new device recovers everything: reading notes, pinned
margin notes and their collections, text clips, bookmarks, per-question
answers, reading settings (theme, font), recently opened books, review
progress, and daily statistics. Sync is last-write-wins per item, and
deletions propagate to your other devices (deletion records are kept for
90 days, then purged).

**Stored on your device only.** Question-rotation state, reading position,
and the subscription check timestamp. These never leave your device.

**What we do not collect.** No advertising identifiers, no location data, no
analytics or crash-reporting SDKs, no contact lists. Study-buddy reminders
are scheduled and delivered entirely on your device.

## 2. Why we use your data (lawful bases, NDPA 2023)

- **Contract** — to create your account, sync your study progress, unlock
  content you paid for, and run the leaderboard.
- **Legitimate interests** — to keep accounts secure (one-device binding,
  fraud and replay prevention on payments), maintain the service, and
  respond to support requests.
- **Consent** — profile photo and any optional data you choose to provide.
  You may withdraw consent by deleting the photo or your account.

## 3. Who sees your data

- **You.** Your study records and entitlements are visible only to you,
  protected by database access rules that isolate every account.
- **Other users — limited.** The leaderboard shows display names and total
  points only (never email or device data). Your profile photo is served
  from a public storage link: anyone who obtains the link can view it.
- **Service providers (sub-processors).**
  - *Supabase* — hosting, authentication (including sign-up codes and
    password-reset emails), database, and file storage.
  - *Flutterwave* — website payment processing (card/bank/USSD), in Nigerian
    naira (₦). Their own privacy terms apply to payment details.
  - *Google Play* — in-app subscription billing. Google's own privacy terms
    apply to payment details.
- **Authorities** — only where required by Nigerian law.

We do not sell personal data and we do not share it for marketing.

## 4. How long we keep data

Account, study, and entitlement records are kept while your account is
active. Payment references are kept for our financial records. If you delete
your account, your profile, study records, and entitlements are removed
(see §6). Device-only data is erased when you uninstall the app or clear
its data.

## 5. Security

 transport encryption on all connections; database access rules that confine
each user to their own rows; server-side verification of every payment
before access is granted (the app cannot grant itself access); and
single-device binding with a 30-day cooldown on device switches. No method
is foolproof — report suspected breaches to support@enchiridion.site and we
will act, including notifying the Nigeria Data Protection Commission and
affected users where the law requires it.

## 6. Your rights

Under the Nigeria Data Protection Act 2023 you may request, free of charge:
a copy of your personal data; correction of inaccurate data; deletion of
your data and account; restriction or objection to certain processing; and
withdrawal of consent. Email **support@enchiridion.site** with the subject
"Data request". We will verify you own the account and respond within the
statutory timeframe.

To change your display name or photo, use the Profile screen in the app. To
delete your account, contact support (in-app deletion is on our roadmap —
see the compliance notes below).

## 7. Children

Enchiridion is intended for medical students and clinicians. If you are
under 18, use the app only with a parent's or guardian's permission. If we
learn we hold a young child's data without proper consent, we will delete it.

## 8. Changes

Material changes will be announced in-app and on this page with a new
"last updated" date. Continued use after changes take effect means you
accept the updated policy.

---

### Implementation notes (not for publication)

Facts assumed above that must stay true: RLS isolates per-user rows;
leaderboard RPCs return display-name + points only; avatars bucket is
public-read; no analytics SDKs; notifications are local-only; payments are
one-time website purchases in NGN verified server-side; user notes,
bookmarks, clips, answers, settings, and history sync last-write-wins with
90-day deletion tombstones; support is email-only. Outstanding gaps are
tracked in `docs/legal/ndpa-gap-review.md`.
