# AI Coach — Deploy

Sirf 5 step. Project folder mein terminal kholo, ek ek karke chalao.

**Step 1 — CLI install (sirf pehli dafa)**
```
brew install supabase/tap/supabase
```

**Step 2 — Login**
```
supabase login
```

**Step 3 — Project link**
```
supabase link --project-ref oamqpmqlydxmxeeipyha
```

**Step 4 — Function deploy**
```
supabase functions deploy ai-coach
```

**Step 5 — Groq key**
```
supabase secrets set GROQ_API_KEY=YAHAN_APNI_KEY
```
`YAHAN_APNI_KEY` ki jagah apni Groq key likhni hai.

Bas, khatam.
