# Connectivity fix and follow-up audit

Follow-up: several findings below were addressed in the next patch. See
[the current logic/UX audit](logic-ux-audit-2026-09-08.md) for fixed and remaining items.

Date: 2026-09-08. Scope: customer Flutter app only. No backend deployment,
database changes, production writes, cache deletion or account mutations.

## Fixed in this change

- Intermediate timeout/retry errors no longer set a global offline flag. The
  API client records the final outcome, including bare-Dio retry/auth replay.
- Confirmed offline requires no interface for one second AND a failed,
  independent `/health/` probe. Wi-Fi/mobile with an unreachable server uses
  a separate server-unavailable banner; normal API requests remain enabled.
- The unauthenticated probe has a four-second total deadline and a unique URL
  to bypass caches. No custom `Cache-Control` request header: the production
  CORS allowlist does not include it, so that header would break Chrome probes.
- Foreground recovery uses single-flight checks with 5/10/20/30-second backoff.
  Interface changes, resume, banner retry and blocked actions recheck promptly.
  Backgrounding cancels probes/timers; stale probe/request failures cannot
  override newer successful network evidence.
- Open controllers refresh after recovery. In-flight catalog filters/mutations
  are not interrupted; loaded reels retain their feed/player state. Probe
  success does not pretend that cached application data was refreshed.

## Follow-up findings (not fixed in this stage)

These are code-path findings, not claims of observed production incidents.

### High: private cache is not account-scoped

`lib/core/storage/json_disk_cache.dart` defines address, order, favorite and
notification keys using language/store/period, without a user ID.
`AuthController.logout()` / `expireSession()` call `_clearLocal()`, which removes
tokens and the cached profile, but not these caches. Full cache deletion exists
for account deletion only. Account B can therefore fall back to account A's
cached data when a request fails.

Next fix: scope private cache keys and in-memory providers to an account,
invalidate them on logout/account switch, and guard late writes with a session
generation. Test A → logout → B → failed fetch, including pending A responses.

### High: retry can repeat non-idempotent mutations

`lib/core/network/interceptors/retry_interceptor.dart` checks transport error
type, not HTTP method or an idempotency contract. A receive timeout can happen
after the server commits a cart add/favorite toggle, then replay it.

Next fix: automatic replay only for safe methods or explicitly idempotent
operations; reconcile uncertain mutations via GET. Test server-committed timeout.

### High: offline cart queue discards temporary HTTP failures

`OfflineCartQueue.flush()` in
`lib/features/cart/domain/offline_cart_queue.dart` retains `NetworkFailure`,
but catches every other `ApiFailure` and removes the operation. This includes
temporary 500/429 responses, not only obsolete items.

Next fix: retain retryable operations with backoff; explicitly classify permanent
failures and surface them. Also test queue creation after an isolated timeout
when the independent health endpoint remains healthy (no offline→online edge).

### High: enqueue during flush can be overwritten

The same queue loads a snapshot before awaiting HTTP, then saves that snapshot
minus its first operation. An `enqueue*()` during the await writes a newer list;
the flush's subsequent `_save(ops)` can overwrite the newly appended operation.

Next fix: persist stable operation IDs and serialize queue updates, removing
only acknowledged IDs from the latest queue. Test enqueue while HTTP is pending.

### Medium: incomplete offline cart rendering/persistence

`CartController.addProduct()` queues a new product without inserting a temporary
visible cart item (the source explicitly notes the missing server ID). Its
`build()` fetches the server cart without restoring a local cart snapshot.

Next fix: local pending-item identity, persisted cart snapshot and deterministic
server reconciliation. Test offline add → restart → recover without duplicates.

## Conclusion

The false-offline latch is a connectivity-state bug, not proof that the user's
Internet or production server is down. Private-cache isolation is the highest
priority next change, followed by mutation/queue reliability. Passing this
connectivity fix does not make all offline cart behavior production-ready.

## Verification

Automated checks cover retry/auth replay, stale evidence, debounce, foreground
backoff/resume, single-flight cancellation, HTTP-vs-transport classification,
three banner locales, and catalog recovery preserving the selected category.
The production health GET and CORS configuration were inspected read-only.

Completed checks:

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 353 tests passed.
- `flutter build web --no-pub`: passed, including the Wasm compatibility dry run.
- Chrome: 14 tests passed (retry/HTTP/probe tests plus a real production health
  GET using the same standalone probe). The live check is deliberately opt-in:
  `flutter test --no-pub --platform chrome --dart-define=LIVE_HEALTH_SMOKE=true test/core/network/connectivity_recovery_test.dart test/core/network/connectivity_health_smoke_test.dart`.
- `git diff --check`: passed.

Real Android airplane-mode/Wi-Fi/mobile/background smoke testing remains a
rollout requirement: `adb devices` currently reports no attached device.
The Chrome tests verify network behavior; they are not a substitute for a full
manual checkout/network-toggle smoke test on an installed Android build.
