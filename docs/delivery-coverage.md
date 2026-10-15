# Delivery coverage rollout

Deploy backend, apply `stores.0015_storebranch_delivery_radius`, then deploy the admin panel and customer app. Existing branches start at 8.00 km. Existing orders and saved prices are not changed. Do not deploy the app's new coverage UI before the backend migration/API.

The authenticated `GET /api/user/delivery/coverage/?store_type=household` returns `branches` containing `id`, localized `name`, `latitude`, `longitude`, and `delivery_radius_km`. Only active, public stores represented in this user's cart are included. Empty carts return no coverage branches.

`POST /api/user/delivery/estimate/` retains existing fields and adds `branch`, `coverage_radius_km`, and `reason_code`. Reasons include `outside_delivery_radius`, `delivery_tariff_unavailable`, and `delivery_branch_unavailable`. Coverage failure is an HTTP 400; a valid but unavailable location remains an HTTP 200 estimate with `available=false`.

Radius checks use the unrounded haversine distance with Earth radius 6371 km. App map rings use the same geometry. A supplied branch is never silently replaced; without one, the nearest geographically covered eligible branch is selected. A valid price band is still required within the radius. The backend repeats the check when an order is created.

Edit each branch's radius (0.10–100.00 km) in Admin → Branches. The form warns about tariff gaps and insufficient tariff coverage. A radius edit does not set a price or cancel existing orders.

The phone GPS point is transient, foreground-only and independent of the user's explicitly selected delivery address. A denied permission or unavailable GPS does not prevent manual selection. Map tile failure does not disable address selection or server estimates.

Delivery checkout requests location permission before opening the address
chooser. The fresh high-accuracy GPS request then runs alongside the chooser,
with a 15-second limit; it never selects an address or sends an estimate by
itself. Coordinates retain their timestamp and accuracy. Fixes older than
60 seconds are rejected/expired; accuracy above 100 m or unknown accuracy is
labelled approximate. Denied/permanently denied, disabled GPS and timeout
have distinct guidance. Returning from location settings retries one fix,
without periodic or background tracking. Manual selection remains available.
Checkout starts location independently of loading saved addresses. After
returning from Quick Settings or app settings, missing/stale GPS is retried
automatically if existing permission and GPS are enabled. Passive resume
checks never re-open an OS permission dialog. Android does not show the
permission dialog again when this app already has location permission.

Checkout shows original-color map tiles with a blue coverage boundary and no gray mask. The mini-map supports touch pan/pinch and manual recentering; moving the camera does not change the selected delivery address or radius decision. Scroll outside the map to move through checkout; Web mouse-wheel scrolling remains with the page. The final read-only product receipt shows cart line names, quantities, variants/addons and server-calculated subtotals. It is an order preview, not a fiscal receipt.

Checks:

- Backend: `.venv/bin/python manage.py check`, `makemigrations --check --dry-run`, and `test api.user --keepdb --noinput`.
- Admin: `npm run typecheck`, `npm run build`, and `./node_modules/.bin/tsx scripts/test-delivery-coverage.ts`.
- Customer: Flutter analyze, full Flutter tests, release Web build. Release Android requires the existing valid public Mapbox token; do not disable the signing/map-provider gates.

Manual smoke: choose an inside/outside delivery address, deny/allow GPS, verify GPS never substitutes for that address, expand/back the map, change radius in admin then resume/re-estimate, and verify an outside order cannot be submitted by bypassing the app. Test Android button/gesture back and Chrome at mobile widths.
