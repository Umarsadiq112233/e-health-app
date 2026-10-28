# Startup and onboarding flow

Default execution uses Supabase Auth and database profile/setup persistence. Run with `--dart-define-from-file=config/supabase.json`; see [Supabase setup](SUPABASE_SETUP.md) for the required migration and callbacks. Generic BLE is real; vendor health sync awaits the physical device/protocol.

## Sequence

Splash → Welcome → Sleep insights → Activity & daily goals → Personal health trends / E Sync Ring → Privacy overview → Login / Sign Up → Profile → Consent → E Sync Ring setup (or Continue without device) → Dashboard.

Welcome has Next and Skip. Three swipeable introductions share one PageController, selected-page state and accessible page indicators. The final slide uses Get Started. Only Get Started or Skip writes introductory completion. Skip always leads to Privacy; required setup consent remains mandatory after authentication. Hardware Back walks the slides and Welcome and never returns to Splash.

Native Android (including API 31+) and iOS launch screens use the same dark teal surface as Flutter. Native launch contains no second branded splash or white placeholder. Flutter owns the logo, E-Health name, supplied silver ring and 300 ms fade. Local introductory preferences, SDK-restored Supabase session and supplied art initialize while this screen is visible. There is no fixed startup timer; navigation waits only for initialization and fade completion. Startup has a retry state and checks mounting before continuing asynchronous work.

## Local persistence

SharedPreferences contains only `ehealth.flow.v1` introductory/privacy overview flags. Authentication comes exclusively from the SDK. Profile, consent choices and last ring step live in `public.profiles`, isolated by user ID and RLS. No application password or token storage is added. AppFlowCubit owns progress, AuthBloc owns auth events and AppSessionCubit owns theme/profile/manual goals; DeviceCubit owns native connection state and HealthCubit owns legitimate readings.

Return launches show Splash once, then Login when signed out, the first unfinished setup stage when signed in, or Dashboard when setup is complete. Profile loading failures show Retry rather than assuming missing setup. Logout retains device onboarding and server setup progress. Different accounts receive separate setup records. Privacy interrupted after Skip resumes at Privacy. Interrupted ring setup resumes the device setup page; native connections are never inferred from saved setup flags. Writes finish before advancing.

Settings → View Onboarding replays Welcome/slides/Privacy without resetting progress or routing into authentication/setup. Done returns to Settings. Setup Profile and Consent have separate pages. Consent Back allows profile review without clearing completion. Ring setup now offers real user-initiated discovery/connection/service discovery and Continue without device. Firmware, signal, baseline and health sync are not simulated. The device_complete profile flag records completion of the setup choice, not a live connection.

## Layout and checks

Images retain their full transparency and aspect ratios through BoxFit.contain. Intro content scrolls independently from fixed bottom controls within SafeArea. Tap targets for indicators are 44 px. Fade and page/route transitions use 300 ms and respect reduced motion. PageController is disposed; scan subscriptions/timeouts cancel on disposal; startup results do not navigate after unmount.

`flutter analyze` and `flutter test` cover fresh initialization, every introduction, swipe/indicator synchronization, Get Started, Skip, Back, restart, returning session, logout, settings replay, interrupted consent and ring setup, profile edits, separate account progress, malformed storage and startup disposal. Layout coverage includes 320×568, 430×932 and 800×1000 with 1.8× text, reduced motion and system insets. Native launch resources are additionally checked by Android build and iOS storyboard compilation. Physical Samsung launch/system-navigation appearance still requires a device check.
