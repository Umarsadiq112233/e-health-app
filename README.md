# Beam Clinician Portal

Responsive Next.js + TypeScript + Tailwind UI for the E-Health clinician portal.

## Run locally

```bash
cd /Users/mc/projects/e_health_app/clinician-portal
npm install
cp .env.example .env.local
npm run dev
```

Add the following values to `.env.local` from Supabase Dashboard → Project Settings → API:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-publishable-key
NEXT_PUBLIC_UI_TEST_MODE=true
```

Use only the publishable/anon key in this browser app. Never put a service-role key in `.env.local` or commit it.

With `NEXT_PUBLIC_UI_TEST_MODE=true`, the login and social buttons navigate directly to `/dashboard` so the UI can be tested before Supabase Auth is ready. Set it to `false` or remove it before production.

For Google/Microsoft OAuth, add these redirect URLs in Supabase → Authentication → URL Configuration:

- `http://localhost:3000/auth/callback`
- Your production portal URL followed by `/auth/callback`

## Routes

- `/` — responsive clinician login
- `/auth/callback` — OAuth callback
- `/dashboard` — responsive clinician dashboard starter

`npm run build` passes successfully. Dashboard metrics and patient rows are currently presentation data; wire them to protected Supabase queries after the live schema is ready.
# e-health-app
