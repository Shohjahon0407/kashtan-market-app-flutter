# Store-local minimum-order footer

- Every store cart uses the shared preparation flow: fulfillment, address or
  branch, products, recommendations, then a confirmed checkout. Main-cart
  overview cards remain separate and never combine minimums or money.
- The minimum explanation is a compact actionable row above the footer action,
  with a 4 px green progress indicator. It disappears at the exact minimum and
  reappears if quantity drops. Reduced-motion and accessible-navigation modes
  disable its 300 ms transition.
- Catalogue, scoped search/category and product-detail footers reuse
  `StoreMinimumPanel`. The existing add/configuration/quantity controls remain;
  catalogue cart navigation is never disabled by the delivery minimum.
- Catalogue rendering does not call `prepare` or request an estimate. A quote
  must match the current address coordinates and physical-store scope. Loading,
  invalidated, failed, pending-write and unconfirmed states do not supply a fee.
- Only confirmed delivery totals contribute to the minimum. No address/quote
  means no exact remainder or progress; pickup bypasses the delivery minimum.
  `8000 + 5000`, minimum `20000`, therefore displays a `7000` remainder.
- Cart minimum rows scroll to store-local recommendations. Catalogue/detail rows
  open that store's cart. A stale/direct-link checkout below the minimum returns
  to the cart recommendations rather than showing a second warning card.
- Short landscape layouts and large text keep primary actions visible; only
  explanatory information scrolls when the footer has insufficient height.

## Verification

`store_minimum_panel_test.dart` covers every store, quote scope/invalidation,
pending writes, rollback, empty carts, navigation and three locales at 200% text
in portrait and landscape. Existing minimum, cart-flow, routing, checkout,
catalogue and product-detail tests cover the surrounding behavior.

No backend/API/database changes, APK build, installation, production deployment
or real orders/payments are part of this change. Payme settings are untouched.
