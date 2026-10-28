# Fix the default reset-link email and enable Brevo OTP

The supplied email screenshot shows the Supabase Auth default sender and a reset link. This indicates that the hosted mail configuration differs from the checked-in OTP delivery configuration. Local Flutter code and local Supabase templates do not update a hosted project automatically.

The user chose code and setup steps only; no hosted changes or inbox delivery tests were performed.

## Recommended: existing signed Send Email Hook

1. Brevo → Settings → Senders, Domains: verify `developer.fluxtonx@gmail.com` as a sender. Use display name `United Union Health`. A Gmail address cannot have its domain DNS authenticated by you; for domain authentication use a domain you own and follow Brevo's exact DNS instructions.
2. Rotate the credentials shared in chat. Enter the replacement REST API key directly in Supabase → Edge Functions → Secrets as `BREVO_API_KEY`. The SMTP key is a different credential and cannot be used by this REST hook. Never paste credentials into `.env.example`, Flutter or committed files.
3. Deploy `supabase/functions/send-auth-email` as `send-auth-email` with JWT verification disabled. Its handler verifies the Supabase hook signature instead. CLI command after authenticating/linking:

   ```sh
   supabase functions deploy send-auth-email --project-ref agigsbwjaupsfvhcnseg --no-verify-jwt
   ```

4. Supabase → Authentication → Hooks → Send Email: configure the HTTP endpoint `https://agigsbwjaupsfvhcnseg.supabase.co/functions/v1/send-auth-email`. Generate its signing secret and store it as `SEND_EMAIL_HOOK_SECRET`. Set the following Edge Function settings:

   | Name | Value |
   | --- | --- |
   | BREVO_SENDER_EMAIL | developer.fluxtonx@gmail.com (must be verified) |
   | BREVO_SENDER_NAME | United Union Health |
   | EHEALTH_SUPPORT_EMAIL | Your monitored support address |
   | AUTH_EMAIL_OTP_LENGTH | 6 |
   | AUTH_EMAIL_OTP_EXPIRY_SECONDS | 3600 |
   | AUTH_RECOVERY_MODE | otp |

5. Enable the hook after deployment and secrets are ready. It renders separate signup and recovery code emails using Supabase's actual token. Setting SMTP alone does not change the enabled hook's behavior.
6. Supabase → Authentication → Email: enable Confirm email; match OTP length 6, expiration 3600 seconds and minimum send interval 60 seconds to these settings. Preserve password login and secure email change. Keep `io.ehealth.app://auth-callback` allowlisted in URL configuration.
7. Test with a dedicated account: registration code → verify → onboarding/setup; forgot password → recovery code → verify → new password → success. Test invalid/expired codes and server resend limits. Delivery acceptance is never authentication.

## Alternative: Brevo SMTP, without deploying a hook

Disable the Send Email Hook for this route. Supabase → Authentication → Email → SMTP Settings:

- Host: `smtp-relay.brevo.com`.
- Port: `587` with the provider's TLS/STARTTLS configuration.
- Username: the SMTP login shown by Brevo, not an assumed sender address.
- Password: newly rotated Brevo SMTP key, not the REST API key.
- Sender email/name: the verified address above / United Union Health.

Then Supabase → Authentication → Email Templates:

- **Confirm signup**: copy all HTML from `supabase/templates/confirmation.html`.
- **Reset password**: copy all HTML from `supabase/templates/recovery.html`.

Both must include `{{ .Token }}`. The current screenshot's link-only default template cannot supply an OTP field. Save both templates, keep the same length/expiry settings, then request a NEW email. Previously delivered emails will not change. Do not use `recovery-link.html` unless intentionally setting the app and server to link mode.

## What was fixed locally

Bluetooth-off no longer disables the action needed to request native enablement. Both the Bluetooth row and Turn on Bluetooth button reach the permission/adapter controller. On Android this invokes the system enable prompt after permissions; on iOS the app requests authorization when needed and provides power-on instructions, since it cannot turn Bluetooth on itself. Physical dialog behavior remains unverified.

Profile no longer includes View Onboarding or its replay route. New, incomplete accounts see onboarding after actual authentication/verification, followed by the existing profile, consent and device setup. Signed-out users see Login first; complete accounts go through their existing Home route.

See [BREVO_AUTH_EMAIL.md](BREVO_AUTH_EMAIL.md) for signature verification, idempotency, secret names and provider failure handling.

Official references: [Supabase email templates](https://supabase.com/docs/guides/auth/auth-email-templates), [Send Email Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook), [custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Brevo SMTP](https://developers.brevo.com/docs/smtp-integration).

Latest automated results (2026-10-07): flutter analyze — no issues; full Flutter suite — 128 passed; Android debug APK — built successfully. New tests exercise both Bluetooth-row and Bluetooth-off button taps through actual controller gating, and account confirmation before onboarding. Existing navigation tests cover swipe/back/skip, restart, consent and recovery. No physical native dialogs or live email delivery were tested.
