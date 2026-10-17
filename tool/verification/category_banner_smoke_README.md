# Category product banner local walkthrough

This harness renders the **actual compiled admin and Flutter app**, calling the
actual Django endpoints against a fresh local SQLite database. It does not
replace the UI with mock HTML, mock API data, or touch existing backend data.

## Run

From `app_new_version`, use a **new** directory below
`build/category-banner-smoke/` for every independent seed setup:

```bash
CATEGORY_BANNER_SMOKE_ROOT="$PWD/build/category-banner-smoke/local-run" \
  ../backend/.venv/bin/python tool/verification/category_banner_smoke_backend.py
```

In another terminal, after building the current admin `dist` and Flutter
`build/web` through the normal project checks:

```bash
CATEGORY_BANNER_SMOKE_ROOT="$PWD/build/category-banner-smoke/local-run" \
  node tool/verification/category_banner_smoke_browser.mjs admin 01
CATEGORY_BANNER_SMOKE_ROOT="$PWD/build/category-banner-smoke/local-run" \
  node tool/verification/category_banner_smoke_browser.mjs customer 01
```

The browser harness starts local static servers on `127.0.0.1:8878/8879` and
routes the builds' API calls to the actual isolated backend on `127.0.0.1:8877`.
Only the hardcoded **local fixture administrator** is used. Local API request
evidence excludes tokens and passwords. Video recordings and screenshots are
written under the selected build directory.

## Isolation and scope

- Settings require a dedicated build directory; database and media are local.
- Redis/channel layers/Celery use memory; SMS, push and object storage are off.
- Current Django models are synced with `run_syncdb`, because production
  migrations include PostgreSQL-only concurrent index operations. This is a UI
  smoke test, **not** evidence of production migration compatibility.
- The six clearly seeded demonstration products use existing bundled category
  photography; they are not real customer/order data or production ads.
- Admin verifies login, category/product selection, live image/price preview,
  create (201), and edit (200).
- Customer verifies current-category banners/recommendations/grid, 2.5-second
  autoplay, manual carousel controls, category-first search, empty-result
  Xozmak fallback, opening the matching category, back, and clearing search.
- Product detail is deliberately excluded: an existing PostgreSQL-only SQL
  expression fails under SQLite. Production SQL is not altered for this test.
- Imperative `context.push` does not reflect a new browser URL under the app's
  existing GoRouter setting. Assertions use actual headings and backend query
  parameters rather than incorrectly requiring browser history URL changes.

Only successful, visually reviewed recordings should be copied to an evidence
folder and linked to users. Exploratory/failed attempts are not user evidence.

## 2026-10-16 verified evidence

Successful current-build runs: `admin-01` and `customer-10` in the isolated
`build/category-banner-smoke/20261016-live02` seed directory. The latter runs
after the stable keyed search/banner slot fix and types the query incrementally
through the real keyboard, rather than atomically filling the text controller.
The earlier test found first-character focus loss; the final run confirms it is
fixed, including return/back preserving the full query and clearing it to restore
the banner and recommendations.

The final minimal evidence is in
`build/category-banner-smoke/evidence_20261016_01/`. Videos were reviewed via
representative extracted frames because RecordScreen/videoReview tooling was
unavailable. The customer video's initial application bootstrap was trimmed;
only the successful real-UI sequence remains. No failure recordings are included
in that evidence directory. Parent verification separately validates the full
production migration graph on an isolated PostgreSQL 16 database; this SQLite UI
harness does not claim to exercise PostgreSQL-specific detail SQL.
