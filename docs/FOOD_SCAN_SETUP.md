# Food Scan setup

The Flutter app opens the camera, converts the captured JPEG to a data URL,
and posts it to the project's Supabase Edge Function:

`https://<project-ref>.supabase.co/functions/v1/analyze-meal`

The app never contains a provider API key. Deploy the function and set its
secret before testing a real scan:

```sh
supabase secrets set OPENAI_API_KEY=your-key
supabase functions deploy analyze-meal
```

The default model is `gpt-4o-mini`. It can be changed with the server-side
`FOOD_VISION_MODEL` secret. For a different backend, pass the endpoint at
build time without changing Dart code:

```sh
flutter run --dart-define=NUTRITION_ANALYSIS_URL=https://example.com/analyze
```

The client accepts a response shaped as either `{ "data": { ... } }` or the
nutrition object directly. The expected fields are `mealName`, `calories`,
`protein`, `carbs`, `fat`, and an optional `ingredients` array.
