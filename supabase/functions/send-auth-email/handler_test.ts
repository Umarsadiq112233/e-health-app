import { Webhook } from "standardwebhooks";
import {
  createHandler,
  type MailConfig,
  messages,
  renderEmail,
} from "./handler.ts";

const assert = (ok: unknown, message = "Assertion failed") => {
  if (!ok) throw new Error(message);
};
const config: MailConfig = {
  apiKey: "unit-test-provider-key",
  hookSecret: `v1,whsec_${btoa("unit-test-secret-only-32-characters")}`,
  senderEmail: "auth@example.test",
  senderName: "E-Health",
  supportEmail: "support@example.test",
  supabaseUrl: "https://example.supabase.co",
  expirySeconds: 3600,
  codeLength: 6,
};
const payload = (action = "signup") => ({
  user: {
    id: "test-user",
    email: "recipient@example.test",
    new_email: "new@example.test",
  },
  email_data: {
    token: "123456",
    token_hash: "a".repeat(64),
    token_new: "654321",
    token_hash_new: "b".repeat(64),
    email_action_type: action,
    redirect_to: "io.ehealth.app://auth-callback",
  },
});
function signed(p = payload(), time = new Date(), id = "test-webhook-id") {
  const raw = JSON.stringify(p);
  const signature = new Webhook(config.hookSecret.replace("v1,whsec_", ""))
    .sign(id, time, raw);
  return new Request("https://example.test/hook", {
    method: "POST",
    body: raw,
    headers: {
      "webhook-id": id,
      "webhook-timestamp": `${Math.floor(time.getTime() / 1000)}`,
      "webhook-signature": signature,
    },
  });
}
Deno.test("Unsigned, tampered, expired and wrong-secret requests cannot send email", async () => {
  let calls = 0;
  const handler = createHandler(config, () => {
    calls++;
    return Promise.resolve(Response.json({}));
  });
  assert(
    (await handler(
      new Request("https://example.test", {
        method: "POST",
        body: JSON.stringify(payload()),
      }),
    )).status === 401,
  );
  const original = signed();
  assert(
    (await handler(
      new Request(original.url, {
        method: "POST",
        headers: original.headers,
        body: "{}",
      }),
    )).status === 401,
  );
  assert(
    (await handler(signed(payload(), new Date(Date.now() - 600000)))).status ===
      401,
  );
  const wrong = createHandler({
    ...config,
    hookSecret: btoa("different-test-secret"),
  }, () => {
    calls++;
    return Promise.resolve(Response.json({}));
  });
  assert((await wrong(signed())).status === 401);
  assert(calls === 0);
});
Deno.test("Signup uses exact Supabase token, private key header and branded email", async () => {
  let calls = 0;
  const handler = createHandler(config, (_input, init) => {
    calls++;
    const body = JSON.parse(init!.body as string);
    assert(
      (init!.headers as Record<string, string>)["api-key"] === config.apiKey,
    );
    assert(body.messageVersions[0].to[0].email === "recipient@example.test");
    assert(
      body.htmlContent.includes("123456") &&
        body.htmlContent.includes("E-Health"),
    );
    assert(!body.htmlContent.includes("/auth/v1/verify"));
    assert(body.htmlContent.includes("3600 seconds"));
    assert(!body.htmlContent.includes(config.apiKey));
    return Promise.resolve(
      Response.json({ messageIds: ["provider-message"] }, { status: 201 }),
    );
  });
  assert((await handler(signed())).status === 200);
  assert(calls === 1);
});
Deno.test("Recovery retains Supabase verification endpoint, type and deep-link redirect", async () => {
  const handler = createHandler(
    { ...config, recoveryMode: "link" },
    (_input, init) => {
      const body = JSON.parse(init!.body as string);
      assert(body.subject.includes("Reset your password"));
      assert(body.htmlContent.includes("type=recovery"));
      assert(body.htmlContent.includes("io.ehealth.app%3A%2F%2Fauth-callback"));
      assert(body.htmlContent.includes("token=" + "a".repeat(64)));
      return Promise.resolve(Response.json({}, { status: 201 }));
    },
  );
  assert((await handler(signed(payload("recovery")))).status === 200);
});
Deno.test("Secure email-change pairs both inboxes with the correct reversed hashes", () => {
  const p = payload("email_change");
  const ms = messages(p, config);
  assert(
    ms.length === 2 && ms[0].email === p.user.email &&
      ms[0].hash === p.email_data.token_hash_new,
  );
  assert(
    ms[1].email === p.user.new_email &&
      ms[1].token === p.email_data.token_new &&
      ms[1].hash === p.email_data.token_hash,
  );
  p.email_data.token_new = "";
  p.email_data.token_hash_new = "";
  const single = messages(p, config);
  assert(single.length === 1 && single[0].email === p.user.new_email);
});
Deno.test("Retries reuse one batch idempotency key, including secure email changes", async () => {
  const keys: string[] = [];
  const handler = createHandler(config, (_input, init) => {
    const body = JSON.parse(init!.body as string);
    keys.push(body.headers.idempotencyKey);
    assert(body.messageVersions.length === 2);
    return Promise.resolve(
      keys.length === 1 ? Response.json({}, { status: 201 }) : Response.json({
        code: "duplicate_parameter",
        message: "idempotency key already used",
      }, { status: 400 }),
    );
  });
  assert((await handler(signed(payload("email_change")))).status === 200);
  assert(
    (await handler(
      signed(payload("email_change"), new Date(), "another-delivery-id"),
    )).status === 200,
  );
  assert(keys[0] === keys[1] && /^[\da-f-]{36}$/.test(keys[0]));
});
Deno.test("Provider denial, limits and network errors fail without echoing sensitive response", async () => {
  for (const status of [400, 401, 429, 500]) {
    const handler = createHandler(
      config,
      () =>
        Promise.resolve(Response.json({
          message: "sensitive-provider-body",
          code: "bad_request",
        }, { status })),
    );
    const result = await handler(signed());
    assert(result.status === 502);
    assert(!(await result.text()).includes("sensitive-provider-body"));
  }
  const handler = createHandler(config, () => {
    throw new Error("sensitive-network-error");
  });
  assert((await handler(signed())).status === 502);
});
Deno.test("Missing settings, wrong methods and unsupported payloads fail closed", async () => {
  let calls = 0;
  const send = () => {
    calls++;
    return Promise.resolve(Response.json({}));
  };
  assert(
    (await createHandler({ ...config, apiKey: "" }, send)(signed())).status ===
      503,
  );
  assert(
    (await createHandler(config, send)(new Request("https://example.test")))
      .status === 405,
  );
  assert(
    (await createHandler(config, send)(signed(payload("unsupported"))))
      .status === 400,
  );
  const p = payload();
  p.email_data.token = "1234";
  assert((await createHandler(config, send)(signed(p))).status === 400);
  assert(calls === 0);
});
Deno.test("Email content safely escapes signed redirect/support values", () => {
  const p = payload("recovery");
  p.email_data.redirect_to = 'https://example.test/?q="<bad>';
  const html =
    renderEmail(messages(p, config)[0], p, { ...config, recoveryMode: "link" })
      .htmlContent;
  assert(!html.includes("<bad>"));
  assert(html.includes("%3Cbad%3E"));
});

Deno.test("Recovery OTP email uses the supplied recovery token without a link", () => {
  const p = payload("recovery");
  const mail = renderEmail(messages(p, config)[0], p, {
    ...config,
    recoveryMode: "otp",
  });
  assert(mail.htmlContent.includes(p.email_data.token));
  assert(mail.htmlContent.includes("recovery code"));
  assert(!mail.htmlContent.includes("/auth/v1/verify"));
});
