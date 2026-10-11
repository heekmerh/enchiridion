# Google sign-in: step-by-step setup

"Continue with Google" works in the Android app and on the website and signs into the same
Supabase account as email and password.

- **App:** signs in natively through Android's account picker, then hands Google's ID token to Supabase. A one-time nonce stops a captured token from being replayed.
- **Website:** uses Supabase's Google redirect and returns to `/auth/callback`.

The code is done. What remains is the Google Cloud and Supabase configuration below, and one build flag for the app.

You need:

- Your Supabase project ref (the `xxxx` in `https://xxxx.supabase.co`), written `<PROJECT_REF>` below.
- The app's final application ID ([payment-provider-setup.md](payment-provider-setup.md), step B1), written `<APPLICATION_ID>`.

## 1. Google Cloud: consent screen

Use the same Google Cloud project as Play Billing, or a new one.

1. Open **Google Auth Platform → Branding** (older consoles: **APIs & Services → OAuth consent screen**).
2. Fill in:
   - App name: **Enchiridion**
   - Support email: yours
   - App logo: optional. Adding one triggers Google's brand verification, which takes a few days.
   - Authorised domains: `enchiridion.site` and `supabase.co`
   - Developer contact email: yours
3. Set **Audience** to **External**, then **Publish app** to move it out of Testing.

Only the basic `openid`, `email` and `profile` scopes are used, so no sensitive-scope review is needed.

## 2. Google Cloud: Web client (used by Supabase and the website)

1. Open **Google Auth Platform → Clients → Create client**. Application type: **Web application**. Name: `Enchiridion Supabase`.
2. **Authorised JavaScript origins:** `https://enchiridion.site`, plus `http://localhost:3000` for development.
3. **Authorised redirect URIs:** `https://<PROJECT_REF>.supabase.co/auth/v1/callback`
4. Create, then copy the **Client ID** (ends in `.apps.googleusercontent.com`) and the **Client secret**.

## 3. Google Cloud: Android clients (used by the app)

Android sign-in only works if Google recognises the certificate the installed app is signed with. Create one **Android** client per certificate, all with package name `<APPLICATION_ID>`:

| Certificate | Where to get its SHA-1 |
| --- | --- |
| Debug (your machine) | `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` |
| Upload key | `keytool -list -v -keystore <your-upload-keystore>.jks -alias <alias>` |
| Play app signing key (what Play Store installs use) | **Play Console → Test and release → App integrity → App signing** → *App signing key certificate* → SHA-1 |

For each one, open **Clients → Create client**, choose **Android**, and enter the package name and SHA-1. Android clients have no secret; the app never uses their IDs directly.

## 4. Supabase

1. **Authentication → Sign In / Providers → Google → Enable.**
2. **Client IDs:** the **Web** client ID from step 2. You can also add the Android client IDs, comma-separated; the Web one is required because the app requests tokens for it.
3. **Client secret:** the Web client secret.
4. Leave **Skip nonce check** **off**; the app sends a nonce.
5. Save.
6. **Authentication → URL Configuration → Redirect URLs:** add `https://enchiridion.site/auth/callback` and `http://localhost:3000/auth/callback`.

Leave automatic identity linking on (Supabase's default). Someone who registered with email and password and later taps "Continue with Google" with the same address then lands in the **same** account, with the same Premium, notes and referral balance.

## 5. App build flag

The Google button stays hidden until the app is built with the Web client ID:

```bash
cd enchiridion-app/enchiridion
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
flutter build appbundle --dart-define=GOOGLE_WEB_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
```

Use the **Web** client ID here, not an Android one; Google issues the token to the Web client, and Supabase checks it. Add the flag to whatever script or CI job builds your releases.

The website needs no extra variable; it uses the Supabase provider settings from step 4.

## 6. Test

1. **App, Log in screen:** tap *Continue with Google*, pick an account. You should pass the device check and reach the library.
2. **App, Sign up screen:** the Google button stays disabled until the Terms box is ticked.
3. **Website:** use *Partner Login → Continue with Google* in the header, and on `/refer` tick Terms, then *Continue with Google*. Each should end on `/dashboard` with your name shown.
4. In Supabase, check the new account:

   ```sql
   select u.email, u.raw_app_meta_data->>'provider' as provider, p.terms_version, w.referral_code, w.referred_by, w.is_verified
   from auth.users u
   join public.profiles p on p.id = u.id
   join enchiridion_web.partners w on w.id = u.id
   where u.email = 'you@gmail.com';
   ```

   Expect `google`, terms `1.2`, a referral code, `is_verified = true`, and `referred_by` set if you arrived through a `?ref=` link.
5. Sign out and sign in with email and password for the same address, if it had one. It should be the same account.

## What happens on a Google sign-up

- **Terms:** acceptance is recorded with the server's time, the first time only, through `public.accept_terms`. The app requires the tick on Sign up and states the agreement under the button on Log in; the website does the same.
- **Email:** counts as verified immediately, so there is no confirmation email, and Premium checkout and referral rewards are available straight away.
- **Profile:** name and photo come from Google. If the display name is already taken, it stays blank for the user to choose.
- **Referral:** a website visitor who arrived with `?ref=CODE` is credited to that partner. The link can only be attached within an hour of account creation and only once.
- **Offers email:** only if the visitor ticked the optional offers box on `/refer` before continuing. App sign-ups never receive it.
