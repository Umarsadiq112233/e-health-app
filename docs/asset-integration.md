# Supplied artwork integration

Mappings are based on the supplied filenames: ring.png → standalone silver titanium ring; wellcomhandring.png → Welcome; introduction.png → Introduction; wearguided.png → Wear Your Ring. All four originals remain intact alongside descriptive registered copies. SHA-256 comparisons confirm each copy is byte-identical to its source. All sources are RGBA PNGs with alpha values from 0 to 255, with no embedded screen annotations or captured UI.

Updated screens: Splash, Welcome, Introduction, Connect E Sync, Device Found, Pairing, Pairing Successful, Wear Your Ring and Signal Check. The dashboard device status and Profile’s E Sync Ring entry also use supplied ring thumbnails.

AppArtworkImage centralizes contain sizing, high-quality filtering, semantic image descriptions and a finite 300 ms fade/slide entrance. It applies no tint, clip, rotation or background to the PNG. Existing Welcome and Introduction mint containers remain. Onboarding and pairing preload their artwork once per flow. Existing SafeArea, scroll layouts, navigation and local interactions remain intact.

Verification: clean flutter analyze; 18 regression tests passed, including phone widths 320/360/390/412/430, dark mode, 1.6× text and reduced motion. Rendered all 30 screens with decoded assets and reviewed every updated image screen. Browser inspection covered desktop Welcome and 320×740 Introduction, confirming alpha, aspect ratio, image containment and CTA access. Web build succeeded. See build/visual_qa/supplied-artwork-review.png and browser-introduction-artwork.jpg.

The earlier drawn ring and wellness painters have been removed. Profile avatar artwork was not supplied and remains unchanged. No backend or device integration was added.
