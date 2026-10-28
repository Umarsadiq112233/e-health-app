# BEAM visual assets

These assets replace the low-resolution screenshot atlas. Screens do not crop
or draw pixels from the supplied screenshots. All UI text, metric cards, charts,
feature labels, orbit effects and splash background are native Flutter widgets
or painters. The BEAM mark and interface icons are scalable SVG assets.

## Original generated artwork

Generated with the built-in image generation tool, with transparent background
requested for each asset. The PNG alpha channels are preserved.

| Asset | Resolution | Purpose |
| --- | --- | --- |
| `images/beam-pulse-watch.png` | 1145 × 1374 | Welcome, Pulse introduction, sharing and auth heroes |
| `images/beam-ai-coach.png` | 1200 × 1311 | AI wellness introduction |
| `images/beam-doctor-call.png` | 1024 × 1536 | Doctor sharing introduction |

The chart values and product dial in onboarding are illustrative marketing
content. Actual dashboard readings continue to come from the existing health
repository.

## Prompt set

### Watch

Use case: product-mockup. Asset type: standalone premium mobile health app product hero asset, NOT an app screen. Generate a high-resolution beautifully detailed isolated smartwatch for BEAM Pulse. Square or portrait composition with the entire watch and curved strap visible, centered with 8 percent transparent margins. Premium midnight navy silicone strap with round perforations and rectangular rounded polished dark titanium watch case; three-quarter perspective, face toward viewer, crown on right. Glass face shows a clean cyan heart symbol, 72 BPM, fine cyan ECG trace and three small circular cyan activity symbols. Tiny brand text BEAM near upper left of dial. Dark blue materials and vibrant turquoise/cyan edge lighting, photorealistic luxury 3D product advertising render, sharp detailed glass and metal edges. Watch closely resembles the premium rounded rectangular dark blue watch in the user's Beam Care UI design. No Apple logos. Genuine transparent alpha background, no scenery, no large typography, no UI panels, no phone frame, no watermark. This is new original artwork to replace blurry screenshot crops.

### AI coach

Use case: stylized-concept. Asset type: premium BEAM Care onboarding illustration, isolated original high resolution 3D mascot, NOT an app screen. Friendly floating compact healthcare AI robot on genuinely transparent alpha background. Rounded pearl-silver and midnight-navy shell, glossy black rounded rectangular face with two bright turquoise eyes and a gentle smiling cyan mouth. Two small raised antenna arcs, small rounded arms, curved compact torso with a simple luminous cyan medical plus in center. Front three-quarter view, facing slightly right, welcoming, arms relaxed, polished rounded product design. Very sharp high resolution refined 3D render, realistic reflections and cyan rim light, subtle cyan hover glow beneath the body only. Center the entire mascot with good margin; no cropping. Color palette navy #001321, icy metallic blue, turquoise #00D7E8. No text, no labels, no panels, no phone frame, no scenery, no watermark. Consistent luxury connected-wellness aesthetic with a dark blue smartwatch product. Original asset to replace a low resolution screenshot crop.

### Doctor call

Use case: product-mockup. Asset type: BEAM Care doctor sharing onboarding hero illustration, a standalone isolated object on genuine transparent alpha background, NOT an app screen. Premium modern midnight-navy smartphone upright in gentle three-quarter perspective with cyan edge lighting and perfectly sharp glass and metal details. On its screen a realistic friendly middle-aged male physician with short salt-and-pepper hair and trimmed beard, white medical coat, blue shirt, stethoscope, warm professional smile, waist-up portrait. Thin cyan call-interface accents and three small round cyan controls at the bottom of phone display, no text. Entire phone fully visible with ample transparent margin, centered, no other objects. High resolution photoreal luxury 3D product composition combined with realistic portrait. Palette dark navy #001321, electric cyan #00D7E8, cool whites. No typography, no large symbols, no scenery, no panels, no cropped frame, no watermark. This will be combined with native cloud and data-sharing graphics in a Flutter screen.

## Reference alignment update

`images/beam-pulse-scene.png`: original built-in ImageGen artwork, 1254 px square. Reference supplied only for visual direction; no screenshot pixels cropped. Prompt: luxury navy smartwatch, strap left and face right in three-quarter view; rocky navy terrain, cyan elliptical orbit, navy edges, no external captions or UI. Used for welcome, Pulse and authentication headers. Native SVG filled shoes, feather, battery, shield, people and water icons replace the previous outline shapes. Cutouts remain visible under Flutter tinting.

Authentication header: `images/beam-auth-watch.png`, built-in ImageGen; prompt: portrait premium navy watch, face left, strap right, small rocky base, cyan crescent, transparent background, no external text. Native edge fade blends artwork into navy header.

Verification artwork uses native editable vector drawing in `lib/features/auth/presentation/widgets/beam_verification_art.dart`: envelope, cyan orbit, error badge, success check and lock shield. No screenshot crops or raster scaling.

## Setup screens

`images/beam-setup-complete.png`: built-in ImageGen, original transparent artwork. Prompt: realistic navy smartwatch left and slim health-dashboard phone right on dark rocks, cyan orbit, no captions. Profile card illustration and setup icons are editable native/vector assets.

Wellness setup values are namespaced as `_wellness` inside the existing account-owned `profiles.permissions` JSON object. The repository separates boolean permission choices from structured preferences on load; no database migration is needed. Pairing, consent and profile edits preserve these preferences.

Native setup permissions use Bluetooth, notification and optional location prompts, plus read-only HealthKit/Health Connect authorization. HealthKit read permission is reported as requested because iOS does not reveal individual read grants. Android minimum is API 26 (Android 8), required by the native health package; iOS minimum remains 15. Physical-device prompts require device validation.

Optional foreground Location access on Android 12+ was explicitly approved by the user. Both approximate and precise location are declared; the OS prompt runs only after tapping Allow on the Location card. No background location permission is requested.

User-supplied full-screen backgrounds `beam-auth-watch1.png` and `beam-setup-complete1.png` are used directly behind native signup/sign-in and setup summary content. Duplicate foreground product images are removed. Portrait views use cover; wide layouts preserve the full portrait artwork at the right.
