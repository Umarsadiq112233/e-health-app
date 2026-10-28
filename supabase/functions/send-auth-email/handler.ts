import { Webhook } from "standardwebhooks";

export interface MailConfig {
  apiKey: string;
  hookSecret: string;
  senderEmail: string;
  senderName: string;
  supportEmail: string;
  supabaseUrl: string;
  expirySeconds: number;
  codeLength: number;
  recoveryMode?: "otp" | "link";
}
interface Payload {
  user: { id: string; email: string; new_email?: string };
  email_data: {
    token: string;
    token_hash: string;
    token_new?: string;
    token_hash_new?: string;
    email_action_type: string;
    redirect_to?: string;
  };
}
interface Message {
  email: string;
  token: string;
  hash: string;
  action: string;
}
const actions = new Set([
  "signup",
  "magiclink",
  "recovery",
  "invite",
  "email_change",
  "reauthentication",
]);
const isEmail = (s: unknown): s is string =>
  typeof s === "string" && /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(s);
const escape = (s: string) =>
  s.replace(
    /[&<>"']/g,
    (c) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    }[c]!),
  );
const failure = (status: number, message: string) =>
  Response.json({ error: { http_code: status, message } }, { status });

export function validConfig(c: MailConfig): boolean {
  try {
    const url = new URL(c.supabaseUrl);
    return !!c.apiKey && !!c.hookSecret && isEmail(c.senderEmail) &&
      isEmail(c.supportEmail) &&
      !!c.senderName && url.protocol === "https:" && !url.username &&
      !url.password &&
      Number.isInteger(c.expirySeconds) && c.expirySeconds > 0 &&
      c.expirySeconds <= 86400 &&
      Number.isInteger(c.codeLength) && c.codeLength >= 6 &&
      c.codeLength <= 10 &&
      (c.recoveryMode == null || ["otp", "link"].includes(c.recoveryMode));
  } catch {
    return false;
  }
}
export function messages(p: Payload, config: MailConfig): Message[] {
  const d = p?.email_data, u = p?.user;
  if (
    !d || !u || typeof u.id !== "string" || !actions.has(d.email_action_type)
  ) throw new Error("Invalid payload");
  const item = (email: unknown, token: unknown, hash: unknown): Message => {
    if (
      !isEmail(email) || typeof token !== "string" ||
      !new RegExp(`^[0-9]{${config.codeLength}}$`).test(token) ||
      typeof hash !== "string" || !/^[a-zA-Z0-9_-]{20,256}$/.test(hash)
    ) throw new Error("Invalid payload");
    return { email, token, hash, action: d.email_action_type };
  };
  if (d.email_action_type === "email_change") {
    // Supabase's hash suffixes are intentionally reversed (backward compatibility).
    if (d.token && d.token_new && d.token_hash_new && d.token_hash) {
      return [
        item(u.email, d.token, d.token_hash_new),
        item(u.new_email, d.token_new, d.token_hash),
      ];
    }
    return [item(u.new_email, d.token_new || d.token, d.token_hash)];
  }
  return [item(u.email, d.token, d.token_hash)];
}
export function renderEmail(m: Message, p: Payload, c: MailConfig) {
  const heading: Record<string, string> = {
    signup: "Verify your email",
    magiclink: "Sign in to E-Health",
    recovery: "Reset your password",
    invite: "You’re invited to E-Health",
    email_change: "Confirm your email change",
    reauthentication: "Confirm it’s you",
  };
  const link = new URL("/auth/v1/verify", c.supabaseUrl);
  link.searchParams.set("token", m.hash);
  link.searchParams.set("type", m.action);
  if (p.email_data.redirect_to) {
    link.searchParams.set("redirect_to", p.email_data.redirect_to);
  }
  const showLink = ["invite", "email_change", "magiclink"].includes(m.action) ||
    (m.action === "recovery" && c.recoveryMode === "link");
  const guidance = m.action === "signup"
    ? "Enter this code in the E-Health app to verify your account."
    : m.action === "recovery"
    ? c.recoveryMode === "link"
      ? "Use the secure link below to choose a new password. Your password has not changed yet."
      : "Enter this recovery code in E-Health before choosing a new password. Your password has not changed yet."
    : m.action === "email_change"
    ? "Confirm this request using the secure link below. If secure email change is enabled, confirm both inboxes."
    : m.action === "invite"
    ? "Use the secure link below to accept your invitation."
    : "Enter this code only in E-Health.";
  const expiry = `This code${
    showLink ? " and link" : ""
  } expires after ${c.expirySeconds} seconds from the request. Use your latest email.`;
  const html =
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:#f3faf7;font-family:Arial,sans-serif;color:#15252a"><table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:32px 16px"><table role="presentation" width="100%" style="max-width:560px;background:#fff;border:1px solid #e1eee8;border-radius:24px"><tr><td style="padding:32px"><div style="color:#005747;font-size:24px;font-weight:700">E-Health</div><h1 style="font-size:26px;line-height:1.3">${
      heading[m.action]
    }</h1><p style="line-height:1.6">${guidance}</p><div style="padding:24px 12px;background:#e6f5ed;border-radius:16px;text-align:center;font-size:36px;font-weight:700;letter-spacing:6px;color:#005747">${
      escape(m.token)
    }</div><p style="font-size:14px;line-height:1.6;color:#64727c">${expiry}</p>${
      showLink
        ? `<p><a href="${
          escape(link.toString())
        }" style="display:inline-block;background:#005747;color:#fff;padding:16px 24px;border-radius:12px;text-decoration:none">${
          heading[m.action]
        }</a></p>`
        : ""
    }<p style="line-height:1.6">Never share this code. If you didn’t request this email, you can ignore it.</p><hr style="border:0;border-top:1px solid #e1eee8"><p style="font-size:14px;color:#64727c">Need help? <a href="mailto:${
      escape(c.supportEmail)
    }" style="color:#005747">${
      escape(c.supportEmail)
    }</a></p></td></tr></table></td></tr></table></body></html>`;
  return { subject: `E-Health · ${heading[m.action]}`, htmlContent: html };
}
async function idempotencyKey(p: Payload, ms: Message[]): Promise<string> {
  // Stable across hook retries; never include a raw OTP/email in the header.
  const digest = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(
        JSON.stringify([p.user.id, ms.map((m) => [m.action, m.email, m.hash])]),
      ),
    ),
  );
  digest[6] = (digest[6] & 0x0f) | 0x80;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  const h = [...digest.slice(0, 16)].map((v) => v.toString(16).padStart(2, "0"))
    .join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${
    h.slice(16, 20)
  }-${h.slice(20)}`;
}
async function boundedBody(req: Request): Promise<string> {
  const reader = req.body?.getReader();
  if (!reader) throw new Error("Empty body");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 65536) {
        await reader.cancel();
        throw new Error("Body too large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const body = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.length;
  }
  return new TextDecoder().decode(body);
}
export function createHandler(config: MailConfig, send: typeof fetch = fetch) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return failure(405, "POST required");
    if (!validConfig(config)) {
      return failure(503, "Email service is not configured");
    }
    let payload: Payload;
    try {
      const raw = await boundedBody(req);
      const secret = config.hookSecret.replace(/^v1,whsec_/, "");
      payload = new Webhook(secret).verify(
        raw,
        Object.fromEntries(req.headers),
      ) as Payload;
    } catch {
      return failure(401, "Invalid webhook signature");
    }
    let ms: Message[];
    try {
      ms = messages(payload, config);
    } catch {
      return failure(400, "Unsupported or invalid Auth email payload");
    }
    const key = await idempotencyKey(payload, ms);
    const versions = ms.map((m) => ({
      to: [{ email: m.email }],
      ...renderEmail(m, payload, config),
    }));
    // Batch idempotency is documented by Brevo. No local retry loop or fake delay.
    const body = {
      sender: { email: config.senderEmail, name: config.senderName },
      ...renderEmail(ms[0], payload, config),
      messageVersions: versions,
      headers: { idempotencyKey: key },
      tags: ["ehealth-auth"],
    };
    try {
      const result = await send("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": config.apiKey,
          "content-type": "application/json",
          "accept": "application/json",
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(3500),
      });
      if (result.ok) {
        await result.body?.cancel();
        return Response.json({});
      }
      // Do not echo or log provider response: it may contain sensitive data.
      if (result.status === 400) {
        const error = await result.json().catch(() => null);
        if (
          error?.code === "duplicate_parameter" &&
          /idempoten/i.test(error?.message ?? "")
        ) return Response.json({});
      } else await result.body?.cancel();
      return failure(502, "Auth email delivery failed. Please retry later");
    } catch {
      return failure(502, "Auth email delivery could not be confirmed");
    }
  };
}
