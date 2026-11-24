# Food Scan setup

The Flutter app opens the camera, converts the captured JPEG to a data URL,
and posts it to the existing working nutrition Supabase Edge Function:

`https://bnineticuomwftfnjhrk.supabase.co/functions/v1/analyze-meal-ingredients-v8`

The app never contains a provider API key. The existing scanner function must
already have its provider secret configured on its own Supabase project. No
new `analyze-meal` function deployment is required for the current app.

The Flutter client sends only that function project's public anon/publishable
key and never sends the provider secret. This endpoint is intentionally kept
as the scanner's existing nutrition backend; the app's Auth/profile data still
uses the configured E-Health Supabase project.

For a different backend, pass the endpoint at build time without changing Dart
code:

```sh
flutter run --dart-define=NUTRITION_ANALYSIS_URL=https://example.com/analyze
```

The client accepts a response shaped as either `{ "data": { ... } }` or the
nutrition object directly. The expected fields are `mealName`, `calories`,
`protein`, `carbs`, `fat`, and an optional `ingredients` array.
