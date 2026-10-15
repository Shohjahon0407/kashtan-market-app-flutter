# Catalog image boundary

Only product discovery lists change; category cards, search results, carts,
favorites and explicit product/variant detail views are not filtered.

The catalog cursor response retains `results`, `next`, `previous` and adds
`page_phase` / `next_phase` (`image`, `no_image`; `next_phase: null` at the end).
Deploy the backend API before the new app. No migration or admin change is
required. Older clients ignore these fields and continue paging normally.
Existing public response caches expire normally; the new client also handles
responses without phase metadata by buffering and hiding imageless rows.

Automatic pagination stops before `no_image`. A new primary touch must begin
at the bottom (within 8 logical pixels), move upward at least 120 logical
pixels and be released. A release velocity of 1500 logical pixels/second or
more is a fling, not an intentional reveal. Cancellation, multi-touch,
horizontal dragging, wheel/trackpad and mouse dragging never trigger reveal.
The footer is visually blank: no explanatory text, release hint or button.
Screen readers retain a custom “Show products without photos” action on the
empty footer. Mouse/wheel users can find imageless products through search.

Image existence is determined from the product URL or a known product-specific
meat fallback photo, not network download success. Generic store pictures and
placeholder icons do not count. Shashlik families retain all children and use
any child's image for the family card; imageless families remain gated.

Disclosure survives detail/back within the live catalog, but resets on a new
catalog instance, category/section change, clearing search or pull-to-refresh.
It is not persisted to memory/disk cache. Connection recovery revalidates
without intentionally closing an already disclosed section. Offline clients
can reveal only products already in their cache.

Verify backend catalog/cursor tests, Flutter controller and raw-touch widget
tests, full Flutter tests, analyzer and release Web build. Manual device smoke:
slow pull versus fast fling at the bottom, short lists, screen-reader action,
offline reopen, category/search changes and returning from detail.
