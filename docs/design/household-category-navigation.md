# Xozmak root catalogue navigation — 2026-11-04

Implemented from the approved two-screen design concept. Scope is the customer
app's Xozmak root landing and its new category index. Existing category grids,
product routes, other store designs, backend and Payme settings are unchanged.

## Navigation

- A pinned search entry opens the existing store-wide search route.
- A separate Categories action opens `/store/household/catalog/categories`
  under the existing store shell, retaining the navbar and back behaviour.
- The index searches the cached category labels/canonical Uzbek names locally,
  reuses existing grouping/order/empty-category rules, and opens the existing
  category URL. Its query and scroll survive visiting a category and returning.
- Underlined shortcuts filter the root ribbons; All restores every section.
- Returning from a product/category/index retains the mounted landing state.

## Cards and actions

- Two complete compact cards plus a next-card peek at ordinary phone widths;
  wider cards at large text sizes and capped widths on large screens.
- Heading plus a small All link replaces repeated full-width green buttons.
- Photo, favourite, name, price, then cart controls: quantity no longer overlays
  the photograph. Add is visually 30px with a 48px hit area; stepper end buttons
  retain 48px widths. The existing mutation/configuration flow is reused.
- Hardware ribbons never auto-advance. Other stores keep their existing timers.
- Store-scoped quantity and subtotal appear in an existing adaptive cart bar
  above the navbar, with reserved layout space rather than an overlay.
- On short landscape screens only search and a labelled Categories icon remain
  pinned; shortcuts scroll with content so large text/cart/nav cannot hide the
  category action.

## Verification

243 targeted widget/controller/routing and other-store regression tests passed;
Flutter analyzer reported no issues. Coverage includes three locales, 320/430px,
landscape, 200% text, real route opening/closing and system back, local category
search/retry, static/manual ribbons, cart addition/configuration, and scroll
restoration. Existing app/category/search URLs are retained.

No APK build/install, server mutation, deployment or real order/payment occurred
in this design implementation. Physical-device visual acceptance remains a
separate step when the user requests a new build.
