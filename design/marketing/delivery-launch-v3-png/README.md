# Delivery launch — PNG-only revision

Final files: `1005-reklama.png`, `pokiza-halol-reklama.png`, `gosht-reklama.png`, `umumiy-reklama.png`, `ofiyat-reklama.png`.

The 1005 and general artwork now use upright phones containing sharp Flutter-rendered home screens, not generated blurred UI. The new Ofiyat poster contains the restaurant category landing screen. Captures use production widgets and repository photos in an offline marketing harness; they are not live customer/device captures. Only screens without invented product prices are embedded. The unused household fixture capture in `sources/` is not a deliverable.

Photographic artwork was generated/edited with the built-in `image_gen` tool. Final prompts are in `sources/prompts.json` (1005 and Ofiyat) and `sources/general-prompt.json` (general). QR, existing app logo and captured UI are deterministically composed using in-memory SVG; only PNG deliverables are written. Pokiza Halol and meat PNGs are unchanged copies of the previously validated v2 campaign.

All final PNGs are 3508×4961 px (A3 aspect). The original generated artwork is approximately1054×1492 px, upscaled for output; this is not native300-dpi photographic/type detail. Phone UI, QR and logo are inserted at higher quality independently of the photographic source. Store badges are generated visual approximations rather than official vector badge artwork. Food/product scenes are advertising illustrations, not guaranteed exact catalog photography.

Every final QR is decoded and checked against `https://api.beshkashtan.uz/app/`. Phone screenshots are clipped inside the white screen below the physical notch. No APK, bundle, production deployment, app/backend changes or live order creation were performed for this revision. Previous poster folders are preserved.

To re-export the three phone posters, run `sources/export_png.py` with CairoSVG, Pillow and zxing-cpp available. Original generated art is retained under `sources/`.
