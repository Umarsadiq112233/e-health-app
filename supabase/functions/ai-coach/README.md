# AI Coach Edge Function

Powers the in-app AI Coach chat. The Flutter app calls this function
(`ai-coach`) through supabase_flutter; the function adds the coach system
prompt plus the user's health context and forwards the conversation to
Groq's chat completions API. The Groq API key exists only as a Supabase
secret — it is never stored in the app or in this repository.

- Project: the Supabase project whose URL is in
  `lib/core/config/supabase_config.dart`
  (`https://oamqpmqlydxmxeeipyha.supabase.co`, ref `oamqpmqlydxmxeeipyha`).

## Deploy

1. Install the Supabase CLI: https://supabase.com/docs/guides/cli
2. Log in and link this repo to the project:

   ```bash
   supabase login
   supabase link --project-ref oamqpmqlydxmxeeipyha
   ```

3. Set the Groq secret (use your own key — never commit a real key):

   ```bash
   supabase secrets set GROQ_API_KEY=<your-groq-api-key>
   ```

   Optional: override the model (default `openai/gpt-oss-120b`):

   ```bash
   supabase secrets set GROQ_MODEL=<model-id>
   ```

4. Deploy the function:

   ```bash
   supabase functions deploy ai-coach
   ```

## Test

Use the project's publishable (anon) key — the same key the app uses, in
`lib/core/config/supabase_config.dart`:

```bash
curl -s https://oamqpmqlydxmxeeipyha.supabase.co/functions/v1/ai-coach \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <publishable-key>" \
  -H "apikey: <publishable-key>" \
  -d '{
    "messages": [{ "role": "user", "content": "Give me a healthy breakfast idea." }],
    "context": "steps today: 4200, latest heart rate: 72 bpm"
  }'
```

Expected response:

```json
{ "reply": "..." }
```

If `GROQ_API_KEY` is missing or Groq rejects the request, the function
returns a non-200 status with a JSON `error` message, and the app shows
its "Coach is unavailable" panel with a Retry button.
