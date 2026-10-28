# E-Health Auth email delivery through Brevo

## Implementation and rollout status

Supabase Auth remains the only identity/session provider. The existing email/password signup creates the account/password; registration confirmation uses the Supabase-generated email OTP and Flutter `verifyOTP(type: OtpType.email)`. Password login still uses `signInWithPassword`. No passwordless login or client-generated OTPs were added. A successful delivery does not authenticate anyone. Existing Supabase SDK persistence, refresh, recovery callback handling and repository-based profile/setup routing remain intact.

`supabase/functions/send-auth-email` implements a signed Send Email Hook. Raw bytes are validated with pinned Standard Webhooks before any message is built. Missing/wrong/expired signatures cannot send email, and the function rejects malformed payloads and unsupported actions. Only server-side environment secrets provide provider credentials; the implementation does not require a service-role credential. No keys, codes, token hashes, email payloads or provider error bodies are logged.

The hook renders separate account-confirmation and password-recovery emails. Signup has an actual OTP; recovery defaults to a Supabase-generated OTP verified with `OtpType.recovery` before password updates. Optional link mode retains the Supabase verification link and allowed redirect. It also preserves invite, magic-link, reauthentication and email-change delivery; secure email changes send both inboxes using Supabase's documented reversed token-hash mapping. No health data is included.

The Flutter OTP field is labeled, keyboard-accessible, accepts a pasted code and platform one-time-code autofill, supports 6–10 digits, and keeps entered codes after an invalid attempt. Verification and resend have real busy/error states. Change Email returns to registration to enter the intended address; it does not silently edit an existing Auth identity. The client cooldown uses the send timestamp and survives reopening the screen in the same AuthBloc. Supabase's server limits and expiration remain authoritative.

**Live integration is not yet verified.** A sender address and display name have now been supplied, but their Brevo verification status is unknown. Browser inventory contained no connected Supabase or Brevo tab, and no deployment access or dedicated recipient was available. The user chose code and setup steps only. No real email was sent and no hosted Auth configuration was changed. Local tests below do not substitute for the live checklist.

## Required server secret names (no credential values in this repository)

Set these in Supabase Dashboard → Edge Functions → Secrets:

| Name | Purpose |
| --- | --- |
| `BREVO_API_KEY` | A newly rotated transactional API key, entered directly in server secrets |
| `SEND_EMAIL_HOOK_SECRET` | Signing secret generated in Supabase Auth Hooks, including its `v1,whsec_` prefix |
| `BREVO_SENDER_EMAIL` | The verified sender address |
| `BREVO_SENDER_NAME` | Display name, typically E-Health |
| `EHEALTH_SUPPORT_EMAIL` | Real monitored support address |
| `AUTH_EMAIL_OTP_EXPIRY_SECONDS` | Must match the configured Supabase email OTP expiration |
| `AUTH_EMAIL_OTP_LENGTH` | Must match Supabase's generated code length |
| `AUTH_RECOVERY_MODE` | `otp` (default), or `link`; match the Flutter build setting |

Hosted Edge Functions inject `SUPABASE_URL`; do not enter an unrelated project URL. The checked-in `.env.example` contains names only for credentials. Keep actual local env files ignored and outside Flutter assets. Rotate both API keys previously pasted in chat, since the replacement was also exposed; use only the newly rotated secret. Never send that value in chat or commit it.

## Exact hosted setup

1. In Brevo, register the real sender and authenticate its domain under Senders/Domains. Add the Brevo-provided verification, DKIM and DMARC DNS records and wait until Brevo reports success. Use the exact records provided for that account/domain; do not invent DNS values. Confirm transactional sending is enabled and sufficient sending quota is available. Prefer disabling link tracking on security emails so verification links are preserved.
2. In Supabase Authentication, keep Email provider, signup and **Confirm email** enabled. Preserve **Secure email change** and the existing password flow. Configure Email OTP length **6**, expiration **3600 seconds**, and minimum email-send interval **60 seconds**, or deliberately choose different values and synchronize all configuration below. Configure project/IP email and verification limits appropriate to the product; the Flutter timer is not a security boundary. The local `supabase/config.toml` records the proposed 6/3600/60 settings; it does **not** apply them to a hosted project.
3. Keep `io.ehealth.app://auth-callback` (or the app's existing `AUTH_REDIRECT_URL`) allowlisted under Auth URL Configuration; add the exact deployed web origin when using Flutter web. Keep Android/iOS deep-link configuration and Supabase SDK callback/session handling enabled. Reset links are verified by Supabase before redirecting the recovery session to the password form.
4. Deploy from the project root with the official Supabase CLI after linking/authenticating the project:

   ```sh
   supabase functions deploy send-auth-email --project-ref agigsbwjaupsfvhcnseg --no-verify-jwt
   ```

   Alternatively create the `send-auth-email` Edge Function in the Dashboard editor with all checked-in source files and pinned dependency. JWT verification must be off for this signed server webhook; the handler still requires a valid Auth hook signature. Do not expose a generic client-invoked mail API.
5. Create/configure **Authentication → Hooks → Send Email → HTTP** with endpoint `https://agigsbwjaupsfvhcnseg.supabase.co/functions/v1/send-auth-email`. Generate the hook signing secret there, then enter it as `SEND_EMAIL_HOOK_SECRET` in Edge Function secrets. Enter the other secrets above. Keep the hook disabled until the function is deployed, secrets are set, the sender is verified and the signed local checks pass; enable it for a dedicated test run. When enabled it replaces SMTP for all Auth emails, including recovery. If delivery fails, Auth receives an error; the app must not report authentication success.
6. Keep UI values aligned. The current app defaults to 6 digits and a 60-second UX resend interval. These **nonsecret** build settings may be changed with `AUTH_EMAIL_OTP_LENGTH` and `AUTH_EMAIL_RESEND_SECONDS`. The hook reads actual token values from Supabase and rejects a mismatched length. Its expiry guidance is configured server-side through `AUTH_EMAIL_OTP_EXPIRY_SECONDS`; that setting describes Auth's expiry and does not enforce or change it.
7. Run both live flows below using an explicitly dedicated test address. Do not enable production rollout until delivery, verification and recovery work.

No SQL migration is required for this email hook: user identities and OTP verification stay inside Supabase Auth.

## Failure/retry behavior

Brevo receives a single batch request with per-recipient message versions, including the two secure email-change messages. Its documented batch idempotency key is a deterministic UUID derived from the Auth identity, action, recipient and Supabase token hash. The same generated email reuses the key even if a hook retry has a different delivery ID. No raw OTP/email is placed in the key. Brevo's idempotency window is 30 minutes; signed webhook timestamps are verified by Standard Webhooks (five-minute tolerance). A documented idempotency-duplicate response is acknowledged; other provider errors fail the hook. The 3.5-second provider timeout leaves room within Auth's short hook timeout. There is no retry loop, fake success, or client-controlled send endpoint. A failed or ambiguous request should be retried through the real Auth flow; Brevo's acceptance is not proof of inbox arrival. Verify idempotency behavior against the actual provider in staging.

## SMTP fallback if the HTTP hook is unavailable

Supabase supports Brevo custom SMTP while continuing to generate/verify all tokens. Disable the Send Email Hook before selecting this fallback; an enabled hook takes precedence over SMTP.

Configure Supabase Authentication → Email → Custom SMTP:

| Setting | Value/source |
| --- | --- |
| Host | `smtp-relay.brevo.com` |
| Port | `587` (Brevo relay; use configured TLS/STARTTLS handling) |
| Username | Actual SMTP login from Brevo SMTP & API → SMTP |
| Password | Newly generated **SMTP key**, not the Brevo REST API key |
| Sender email/name | Verified sender / E-Health |

Paste `supabase/templates/confirmation.html` into **Confirm signup** and `supabase/templates/recovery.html` into **Reset password** in Supabase Email Templates. Confirmation uses `{{ .Token }}`; recovery uses `{{ .Token }}`. For link mode instead publish `recovery-link.html`, which uses `{{ .ConfirmationURL }}`, and set `AUTH_RECOVERY_MODE=link` in both server and Flutter configuration. Set the subjects from `supabase/config.toml`. The fallback template's 60-minute expiry text matches the proposed 3600-second setting; change that wording when changing Auth expiry. Set a real support contact in those templates before publishing. Leave secure email-change/invite templates with their correct Supabase confirmation URLs. With the HTTP hook enabled, Supabase template edits do not change the hook-rendered messages.

## Local verification and live checklist

Commands:

```sh
deno task --config supabase/functions/send-auth-email/deno.json check
deno task --config supabase/functions/send-auth-email/deno.json test
flutter analyze
flutter test
```

Local tests use synthetic tokens/keys and mocked provider/Auth HTTP responses. They check signature rejection (unsigned/tampered/wrong secret/stale timestamp), separate signup/recovery messages, exact supplied OTP, configured length, secure email-change mapping, stable batch retry keys, provider/network failures, safe error responses, Supabase OTP type/session requirement, invalid/expired/rate-limited verification, original password/signup/recovery endpoints, paste/change-email behavior, resend cooldown and post-verification profile-completion navigation. Existing tests cover session restoration, recovery-state token refresh, password update and logout/restart routing.

Before reporting live success, record these results without keys/codes/full payloads:

- Dedicated new account receives the Brevo signup OTP; invalid and expired codes fail; valid code creates a Supabase session and routes to unfinished setup or Home according to persisted profile completion.
- Resend works after the configured interval; immediate resend and direct repeated Auth requests are rejected by server limits. Verify the latest code and confirm the earlier one cannot be reused.
- Restart/login restores the verified session through the existing SDK; password login works without creating another user.
- Forgot Password delivers the separate recovery email. Wrong/expired/used recovery codes fail. A valid recovery OTP (or link in link mode) opens the recovery password form, refresh does not leave recovery state, and the new password works after logout while the old one fails. Confirm no password changes before Supabase accepts the update.
- Direct unsigned function requests fail without Brevo delivery; signed retry produces no duplicate messages; sender/domain authentication and quota behavior are checked in Brevo.

## Official documentation consulted

- [Supabase Send Email Hook and secure email-change mapping](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook)
- [Flutter verifyOTP and verification types](https://supabase.com/docs/reference/dart/auth-verifyotp)
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)
- [Supabase local Auth configuration](https://supabase.com/docs/guides/local-development/cli/config)
- [Brevo transactional email API](https://developers.brevo.com/reference/send-transac-email)
- [Brevo batch idempotency](https://developers.brevo.com/docs/heterogenous-versions-batch-emails)
- [Brevo SMTP credentials](https://developers.brevo.com/docs/smtp-integration)
- [Brevo domain authentication](https://help.brevo.com/hc/en-us/articles/12163873383186-Authenticate-your-domain-with-Brevo-Brevo-code-DKIM-DMARC)

Current automated results are recorded in docs/AUTH_BLUETOOTH_FIXES.md. Real delivery, hosted verification and native permission dialogs remain unverified until external configuration and interactive device testing are available.
