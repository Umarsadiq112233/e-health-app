# Supabase authentication and account profiles

The app now requires real Supabase authentication. There is no production mock login or opt-in switch. Production health readings stay empty until genuine data arrives. BLE discovery/connection/service discovery are native; vendor health sync awaits a verified protocol. The official Flutter SDK restores sessions, persists its own session and refreshes tokens; the app never manually stores tokens or passwords. AppFlowCubit stores signed-in setup progress through ProfileRepository. SharedPreferences retains only device-level introductory onboarding/privacy overview flags, so onboarding can be completed before registration and is not repeated after logout. Old local mock sessions and account profile data are discarded on startup.

## Required configuration

1. Copy `config/supabase.example.json` to the ignored `config/supabase.json`. Set `SUPABASE_URL` to `https://agigsbwjaupsfvhcnseg.supabase.co` and `SUPABASE_PUBLISHABLE_KEY` to the project's public publishable key. Legacy `SUPABASE_ANON_KEY` also works. Keep `AUTH_REDIRECT_URL` as `io.ehealth.app://auth-callback`. Never use secret/service-role keys or database credentials in Flutter. No real credentials are in the example or Dart defaults.
2. Apply `supabase/migrations/202610060001_profiles.sql` through the project's SQL Editor as database owner, or your normal Supabase CLI migration deployment. The migration creates/backfills profiles, an idempotent new-user trigger, updated_at trigger, owner-only SELECT/INSERT/UPDATE RLS policies, and column grants. Clients cannot change IDs or timestamps. Users have no profile delete permission; deleting an auth account cascades its profile. No role or health measurement fields are stored.
3. Run `supabase/tests/profiles_rls.sql` in SQL Editor as owner. It creates two dedicated transactional test users, checks isolation, own updates, cross-user reads/updates/inserts and protected timestamp permissions, then rolls back all fixtures. This test has not been run on the live project.
4. Authentication → Sign In / Providers: enable Email; keep Confirm email enabled. Use standard link-based confirmation and recovery templates. Password minimum length should be at least 8. Configure SMTP and production email rate limits. No six-digit OTP UI is used.
5. Authentication → URL Configuration: set Site URL to your deployed web origin. Add `io.ehealth.app://auth-callback` and exact web origins such as `http://localhost:3000` and your production origin to Redirect URLs. Do not rely on broad production wildcards.

```sh
flutter pub get
flutter run --dart-define-from-file=config/supabase.json
flutter run -d chrome --web-port=3000 --dart-define-from-file=config/supabase.json
```

VS Code's E-Health (Supabase) launch entry loads the ignored configuration. Initialization runs once; an expired restored session is refreshed before routing. Missing environment settings show a configuration error with retry.

## Native and web callbacks

Android `android/app/src/main/AndroidManifest.xml` registers a VIEW intent filter with DEFAULT and BROWSABLE, scheme `io.ehealth.app`, host `auth-callback`. Internet permission is enabled and `flutter_deeplinking_enabled=false` lets Supabase's app_links integration handle authentication callbacks.

iOS `ios/Runner/Info.plist` registers URL scheme `io.ehealth.app` in CFBundleURLTypes and sets FlutterDeepLinkingEnabled=false. If you change the redirect scheme, update both platform registrations and the Supabase allowlist. Rebuild/reinstall the app after native configuration changes.

Web requests use `Uri.base.origin` as the redirect. Add that exact origin to the allowlist and use the normal Flutter hash URL strategy. Hosting must serve the app at that origin over HTTPS in production. The SDK processes both cold-start and running-app links. AuthBloc listens to its auth stream; passwordRecovery selects the password-update form and stays there across token refresh until a successful password update. Expired/invalid callbacks show a request-new-link error.

## Routing and persistence

Signed-out first launch: Splash → Welcome → three introduction slides → Privacy overview → Authentication. Returning signed-out launch: Splash → Login. Confirmation-required registration remains signed out and shows inbox instructions, resend with a 60-second cooldown and Back to Login.

Signed-in launch: Splash → load database profile → first unfinished Profile / Consent / Ring step → Dashboard. Successful authentication uses the same guard. Profile network/schema errors show Retry and Log Out, never an empty setup record. Only a successful empty query invokes safe ID-only profile creation. Writes complete before setup advances; failures can be retried. Logout clears protected route history and displayed identity without clearing the device onboarding preference or server setup progress. Settings onboarding replay preserves all progress.

Account profile edits now update `public.profiles`, not auth metadata. Signup name metadata is used only to seed the server-created profile. Account email remains read-only. Simulated health data and pairing interactions are unchanged.

## Verification and remaining work (6 October 2026)

Live read-only checks: `/auth/v1/settings` returned 200 with email confirmation required and signup enabled. `/rest/v1/profiles` returned 404/PGRST205: the migration is not applied yet. No database-owner connection or signed-in dashboard is available in this workspace. The app-side integration is complete, but signed-in profile functionality needs the migration before use.

Passed: `flutter analyze` (no issues), all 51 Flutter tests, configured web build and Android debug APK build. A separate live SDK smoke test passed: invalid credentials were rejected without a session. Database repository HTTP tests verify owner filters, ID-only idempotent creation, database error propagation and profile/setup updates without protected columns.

Automated tests use injected test repositories, covering auth confirmation-required signup, login failure/success, session restoration, recovery/update, invalid callback, duplicate submission, logout and guarded navigation, profile updates/setup restart, offline load/save retry, stale responses after logout, separate accounts and device-only storage cleanup. These tests do not prove email delivery, device callback round trips or live RLS.

After migration and redirect configuration, verify with two dedicated real email accounts: signup → inbox link → login → profile/setup → restart → resume; reset password → link → update → logout → Back; confirm each account sees only its own profile. Live email confirmation, restored SDK session/token refresh, real password recovery, Android/iOS callback behavior and two-user RLS remain unverified. Previously shared secret/service-role keys should be rotated in Supabase; they are not used or stored by this app.

Official references consulted: [Flutter initialization](https://supabase.com/docs/reference/dart/initializing), [Flutter user management and RLS](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter), [mobile deep links](https://supabase.com/docs/guides/auth/native-mobile-deep-linking).

## Device-ready update

Connection settings, auth callbacks, profile table and RLS remain unchanged. device_complete records the setup choice (including Continue without device); it never proves a Bluetooth connection. No wearable health table/migration was added. HealthRepository currently stores only legitimate readings in session memory, isolated by account. See DEVICE_READY.md for future persistence requirements.
