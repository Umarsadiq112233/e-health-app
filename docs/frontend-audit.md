# Reference audit

The existing Flutter implementation contains the 30 reference screens, five-tab navigation, form validation and timed local pairing. Preserve these routes.

Gaps found: chart labels always show hours regardless of period; chart values are normalized random heights without units or selection; sleep uses generic bars; reports hide charts and retain the same summary for every period; profile Save does not save data; theme is light-only; cards and navigation are larger and rounder than the compact reference; no screen entrance motion or skeleton state; back actions lack semantic labels.

Visual source: the supplied 1536 × 1024 contact sheet. Its phone screens are approximately 140 pixels wide. No source photography or ring renders exist in assets. Enlarging photographic crops would blur them. Keep explicitly approximate, resolution-independent ring/wear/wellness illustrations; improve the logo as a native vector. Exact photographs, avatar and hand illustration remain unmatched.

Scope: frontend and session-local demo state only, with no services, BLE or external notification behavior.
