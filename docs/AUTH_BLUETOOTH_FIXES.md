# Authentication and Bluetooth fixes — 2026-10-07

## Behavior implemented

Permission authorization and Bluetooth adapter power remain separate controller state. Scan and Connect request native permissions on explicit taps: foreground Location on Android 24–30, Nearby Bluetooth scan/connect on Android 31+, and Bluetooth authorization on iOS. Permanently denied/restricted states direct users to Settings without repeated requests. Returning from Settings refreshes status without starting a scan.

The installed flutter_reactive_ble version has no adapter-enable API. Android therefore uses a small native MethodChannel bridge to the documented ACTION_REQUEST_ENABLE system prompt, without introducing a second BLE implementation. Cancellation leaves Bluetooth off. Permission must be granted and the existing BLE adapter stream must report ready before scanning. iOS provides Settings instructions when power is off. Existing filters, connection handling, scan timeout, BLE protocol and assets remain intact.

Registration confirmation uses Supabase's email OTP type. Password recovery uses its distinct recovery OTP type; email/password login stays unchanged. Confirmation-required signup opens the submitted email's code form automatically. A real immediate signup session routes through existing setup state. Recovery verification must create a real session before password updates are allowed. Token refresh cannot redirect away from recovery; a confirmed password update shows success before Continue opens the existing profile/setup route.

SDK callbacks are handled centrally, serialized and deduplicated. Initial links are processed before initial routing, and warm callbacks show processing state. The Supabase SDK owns token exchange, session persistence and refresh. Login and Sign Up have no visible AppBar and retain SafeArea/keyboard scrolling and in-screen back controls. OTP supports paste and large text, actual errors/loading, resend cooldown and change email.

## Required hosted configuration

Follow [BREVO_AUTH_EMAIL.md](BREVO_AUTH_EMAIL.md). No live deployment was performed: sender, recipient and dashboard availability were placeholders, and credentials were not available.

1. Verify a Brevo sender and authenticate its sending domain. Rotate all keys pasted in chat; enter the new API key only in Edge Function secrets.
2. Deploy send-auth-email with JWT verification disabled and enable Supabase's signed Send Email Hook. Configure its generated signing secret; unsigned requests are rejected by the handler.
3. Required server settings: BREVO_API_KEY, SEND_EMAIL_HOOK_SECRET, BREVO_SENDER_EMAIL, BREVO_SENDER_NAME, EHEALTH_SUPPORT_EMAIL, AUTH_EMAIL_OTP_EXPIRY_SECONDS, AUTH_EMAIL_OTP_LENGTH, AUTH_RECOVERY_MODE. Values for OTP length/expiry must match Supabase Auth. Default proposed values are six digits, 3600 seconds and 60 seconds minimum resend interval; server rate limits remain authoritative.
4. Use AUTH_RECOVERY_MODE=otp on both server and Flutter (the default). For SMTP fallback publish confirmation.html and recovery.html; both contain the Supabase Token. For deliberate link mode publish recovery-link.html and use AUTH_RECOVERY_MODE=link on both sides. Hook-rendered messages ignore SMTP templates.
5. Keep email confirmation enabled and allowlist io.ehealth.app://auth-callback plus the actual deployed web origin. Existing Android/iOS deep-link declarations and Bluetooth usage descriptions/permissions remain required.

## Verification boundaries

Automated tests exercise synthetic Auth responses and fake adapter events; they cannot verify inbox delivery, hosted expiration/rate limits or native system dialogs. A connected Pixel XL Android 10 was detected, but the user requested automated checks only. No interactive device dialogs were tested. Test Android permission grant/denial, enable accept/cancel, Settings return and iOS authorization/off instructions on physical devices before release.

Live acceptance still requires a dedicated test recipient: signup delivery, invalid/expired/valid confirmation code, resend limits, password recovery delivery and verification, password update, logout/new-password login and cold/warm recovery links. Also verify authenticated sender/domain and provider retry behavior in staging.

Automated results: flutter analyze — no issues; complete Flutter suite — 125 passed; Deno type check and lint — clean; signed email-hook suite — 9 passed. Android debug APK built successfully. Final iOS simulator build succeeded. Tests include correct Supabase recovery verification type, cold/duplicate callbacks, recovery routing across token refresh, invalid OTP handling, cooldown, duplicate commands, permission denial and adapter enable gating, plus small/large screen and enlarged-text coverage.

Official references: [Android enable prompt](https://developer.android.com/develop/connectivity/bluetooth/setup), [Supabase verifyOTP](https://supabase.com/docs/reference/dart/auth-verifyotp), [Supabase password recovery](https://supabase.com/docs/guides/auth/passwords), and the Supabase/Brevo references in the email setup guide.

Follow-up screenshot fixes: removed the UI Bluetooth-off block that prevented reaching the already-implemented native enable flow; made the Bluetooth row tappable; removed Profile's View Onboarding entry and replay route; moved introductory onboarding after actual authentication for incomplete profiles. Updated regression suite: 128 passed, analysis clean and Android APK built. Hosted email configuration remains unapplied by user choice; see OTP_EMAIL_SETUP.md for the default-link email fix.
