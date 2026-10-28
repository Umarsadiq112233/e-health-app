# Supabase profile editing

The existing My Profile route opens Edit Profile. The existing Supabase repository remains authoritative for name, weight and setup progress. Email comes from Auth and changes use Auth.updateUser with the configured redirect/verification flow. Birth date and gender are not added: the current profiles schema does not support them.

## Required hosted setup

Apply `supabase/migrations/202610060001_profiles.sql` if not already installed, then `supabase/migrations/202610070001_profile_avatars.sql` using the Supabase migration workflow or SQL editor with project-owner privileges. The app's public anon key cannot apply migrations. No hosted migration was applied from this workspace.

The avatar migration creates **ehealth-avatars**, private, JPEG-only, maximum 2 MiB, and adds `avatar_path`/`avatar_url` when missing. Objects use `{auth.uid()}/{uuid}.jpg`; the bucket name is separate from the stable path stored in profiles.avatar_path. Own-folder and owner checks permit only the authenticated owner's operations. A restrictive boundary also constrains pre-existing broad Storage policies. Profile update validation rejects another user's path and new expiring/public URL references. Existing avatar_url values remain readable HTTPS fallbacks until replaced or removed; existing public buckets and other objects are not altered.

Confirm Auth redirect allowlisting for the existing `SupabaseConfig.redirectUrl` and keep your configured secure email-change verification enabled. The separate email dialog reports a request, not an already verified email change. Never place a service-role key in Flutter.

## Photos and lifecycle

The current image_picker API uses system camera/gallery UI and Android lost-selection recovery. iOS camera/photo usage descriptions are provided. JPEG, PNG and WebP content is decoded, EXIF orientation baked, resized to a maximum 1024-pixel edge, metadata discarded and encoded as JPEG. Inputs are limited to 12 MiB and 25 megapixels; normalized uploads are limited to 2 MiB on client and bucket. If native selection does not convert HEIC, the editor asks for JPEG conversion. Desktop cameras may be unavailable; gallery remains available where supported.

Only confirmed database updates refresh shared Home/Profile name/photo state. A private signed URL is transient and refreshed after 50 minutes or app resume; the stable path persists across login. Upload precedes profile update; replacement/removal deletes the old owned object only after the reference update succeeds. Failed database updates re-read the profile before cleanup to handle committed requests whose responses were lost. Confirmed failures clean newly uploaded objects where possible. If both the update response and reconciliation read fail, the object is deliberately retained because it might be referenced; retry/administrative cleanup may be needed. Failed old-object deletion is reported as a successful profile save with a cleanup warning. Legacy external URLs are never passed to object deletion.

## Verification

Tests cover real Supabase SDK HTTP request shapes, name persistence, stable avatar paths, Auth email requests, upload/DB failures, compensation and ambiguous outcomes, old-photo cleanup, orientation/resizing, draft retention, picker cancellation/denial, duplicate actions, replacement/removal, shared shell updates, unsaved-change confirmation and 320/430-pixel layouts with enlarged text/reduced motion.

`supabase/tests/avatars_rls.sql` verifies two-user isolation, foreign upload/update/delete denial, profile-path validation, and the restrictive boundary against a deliberately broad policy. Run alongside profiles_rls.sql in a disposable Supabase environment. Local execution used isolated PostgreSQL with compatible minimal auth/storage tables and passed both migrations/tests. This validates SQL policy behavior, not the hosted Storage HTTP service or MIME enforcement at that service.

Hosted Supabase account persistence, signed-image retrieval, bucket byte/MIME enforcement, actual email delivery, physical camera/gallery permissions and process-death recovery require external project/device testing. No live account credentials or administrator deployment connection were available.

## Official references consulted

- https://pub.dev/packages/image_picker
- https://supabase.com/docs/guides/storage/security/access-control
- https://supabase.com/docs/guides/storage/buckets/fundamentals
- https://supabase.com/docs/reference/dart/storage-from-createsignedurl
- https://supabase.com/docs/reference/dart/auth-updateuser

Final local results: `flutter analyze` reported no issues; the full existing regression run passed 104 tests; all 6 new editor tests passed, and the final focused profile/auth/regression run passed 32 tests after the last typography change. Android debug APK and iOS simulator builds succeeded. Both profile and avatar SQL suites completed successfully in isolated PostgreSQL. Enlarged-text screenshots were inspected at 320 and 430 pixels (`build/profile_qa`).
