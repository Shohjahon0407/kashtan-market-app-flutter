# Grocery basket app icon

White was selected to keep the deep-green basket and orange handle legible.
Only launcher/PWA/listing artwork changes; in-app brand colors stay unchanged.

Source: user-supplied `Glossy Eco Grocery Basket Logo (1).png`.
The built-in imagegen tool cleaned the background/edges in transparent edit mode.
Its selected output is saved as `tool/launcher_icon_logo.png`.

## Exact imagegen prompt

Use case: background-extraction. Input image: edit target, the user's existing grocery basket logo. Prepare this EXACT existing glossy deep-green basket with orange handle and three green leaves as a clean app-icon foreground on a genuinely transparent background. Preserve the logo identity, shapes, basket holes, exact object arrangement, proportions, orange/green colors and glossy shading; do not redesign. Remove all black background wherever it is actual background, including between leaves, inside the handle and inside basket holes. Remove jagged green/orange fringes and stray noisy edge pixels while keeping the silhouette intact. Single centered logo, full design visible with transparent margins, no white outline, no added text, no watermark, no other objects. This foreground will be placed on a pure white app icon; its edges must be clean against white.

## Regeneration

```sh
dart run tool/prepare_launcher_assets.dart
dart run flutter_launcher_icons
dart run tool/prepare_launcher_assets.dart --maskable-only
```

The last command restores dedicated PWA maskable padding after launcher generation.
Legacy/iOS artwork has 10% padding on each side of the longest dimension.
Android adaptive foreground fits a central 60% diameter circle (no additional
generator inset); PWA maskable artwork fits a 76% diameter circle. The adaptive
background is white and its foreground keeps transparency. The Android themed
icon uses the same alpha silhouette. iOS and Play listing exports are opaque.

Outputs: `tool/launcher_icon.png`, Android launcher resources, iOS AppIcon,
`web/icons/`, `web/favicon.png`, and `docs/play-store/assets/app-icon-512.png`.
Updating these files does not install an APK or upload a store listing.
