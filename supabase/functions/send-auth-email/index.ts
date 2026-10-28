import { createHandler } from "./handler.ts";
// Credentials are read exclusively from deployed Edge Function secrets.
Deno.serve(createHandler({
  apiKey: Deno.env.get("BREVO_API_KEY") ?? "",
  hookSecret: Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "",
  senderEmail: Deno.env.get("BREVO_SENDER_EMAIL") ?? "",
  senderName: Deno.env.get("BREVO_SENDER_NAME") ?? "E-Health",
  supportEmail: Deno.env.get("EHEALTH_SUPPORT_EMAIL") ?? "",
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  expirySeconds: Number(Deno.env.get("AUTH_EMAIL_OTP_EXPIRY_SECONDS")),
  recoveryMode: (Deno.env.get("AUTH_RECOVERY_MODE") ?? "otp") as "otp" | "link",
  codeLength: Number(Deno.env.get("AUTH_EMAIL_OTP_LENGTH") ?? "6"),
}));
