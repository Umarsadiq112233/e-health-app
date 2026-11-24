// AI Coach edge function.
//
// Proxies chat requests from the E Health app to Groq's chat completions
// API so the Groq API key never ships inside the app. The key lives only
// in this project's Supabase secrets:
//
//   supabase secrets set GROQ_API_KEY=<key>
//   supabase secrets set GROQ_MODEL=<model id>   (optional)
//
// Request:  POST { messages: [{ role, content }], context?: string }
// Response: 200 { reply: string }  |  non-200 { error: string }

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const systemPrompt = `You are the friendly AI health coach inside the E Health app.
You help the user with meal guidance and nutrition, sleep habits, workouts,
hydration and everyday wellness, in a warm and encouraging tone.
When health context about the user is provided (for example steps, heart
rate or sleep), use it to personalise your advice instead of giving generic
answers.
Keep answers concise and practical: a few short sentences or a short list.
You are not a doctor and you do not diagnose conditions or prescribe
treatment. For medical concerns, symptoms or anything urgent, advise the
user to see a qualified health professional.`;

interface ChatMessage {
  role: string;
  content: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  const apiKey = Deno.env.get('GROQ_API_KEY');
  if (!apiKey) {
    return json({ error: 'GROQ_API_KEY secret is not set' }, 500);
  }
  const model = Deno.env.get('GROQ_MODEL') ?? 'openai/gpt-oss-120b';

  let messages: ChatMessage[] = [];
  let context = '';
  try {
    const body = await req.json();
    if (Array.isArray(body?.messages)) {
      messages = body.messages
        .filter(
          (m: ChatMessage) =>
            m != null &&
            typeof m.content === 'string' &&
            (m.role === 'user' || m.role === 'assistant'),
        )
        .map((m: ChatMessage) => ({ role: m.role, content: m.content }));
    }
    if (typeof body?.context === 'string') context = body.context;
  } catch {
    return json({ error: 'Invalid JSON body' }, 400);
  }
  if (messages.length === 0) {
    return json({ error: 'No messages provided' }, 400);
  }

  const system = context.trim()
    ? `${systemPrompt}\n\nHealth context for this user right now: ${context.trim()}`
    : systemPrompt;

  let upstream: Response;
  try {
    upstream = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        temperature: 0.7,
        messages: [{ role: 'system', content: system }, ...messages],
      }),
    });
  } catch (e) {
    return json({ error: `Could not reach Groq: ${e}` }, 502);
  }

  if (!upstream.ok) {
    const detail = await upstream.text();
    return json(
      { error: `Groq request failed (${upstream.status})`, detail },
      502,
    );
  }

  const data = await upstream.json();
  const reply = data?.choices?.[0]?.message?.content;
  if (typeof reply !== 'string' || reply.trim().isEmpty) {
    return json({ error: 'Groq returned an empty reply' }, 502);
  }
  return json({ reply: reply.trim() });
});
