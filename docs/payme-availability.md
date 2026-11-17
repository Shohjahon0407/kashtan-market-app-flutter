# Payme availability

Play release 1.1.7+10 includes Payme support with `PAYME_ENABLED=true` and
`PAYME_ALLOW_SANDBOX=false`. Ordinary local builds still default to disabled.
Public releases show Payme only for Xozmak and only when the backend explicitly
reports production readiness. Until then checkout keeps cash available.
Existing order payment methods and statuses are never rewritten.

One shared `paymeEnabledProvider` reads `AppConfig.paymeEnabled`. Checkout
submission also enforces cash when disabled; payment initiation never calls
the API or URL launcher. Payme implementation and its enabled-path tests
remain intact.

Controlled debug tests can enable `--dart-define=PAYME_ENABLED=true`.
The backend capability must also allow `household`; other stores stay hidden.

## Backend-controlled production readiness

The existing availability response adds `payme_production_ready`, a boolean.
It is true only with enabled, configured Xozmak payments and
`PAYME_MODE=production`. It exposes no keys and is sent with
`Cache-Control: no-store`. A missing field (older backend), test mode, an
unreachable endpoint or disabled payment configuration fails closed in the Play
build. Sandbox/debug tooling is unchanged.

Release payment attempts recheck readiness before creating a checkout, and
refuse `test.paycom.uz` even if the server changes mode between requests.
The checkout screen refreshes capabilities on entry/resume; payment actions
also refresh them before each attempt. No timers, keys or URLs are embedded to
guess approval. After Payme approval, deploy the additive availability change
and configure the backend's production mode/keys. The same AAB then works;
do not rebuild merely to switch environments.

Preparing this bundle did not deploy the backend, change its environment or
perform a real payment. Do not publish a listing promising active Payme payment
until provider acceptance and fiscalisation are actually confirmed.

## Phone acceptance test (no release APK required)

1. Before creating a payment, verify **inside the running backend container**
   that `PAYME_MODE=test`. The public availability endpoint does not report
   mode. The Flutter define only exposes Payme: it does **not** force sandbox.
   Keep the server in test mode for the entire session. Merchant keys remain
   on the server and must never be added to Flutter arguments or launch files.
2. Connect the phone with USB debugging enabled; check `adb devices` shows it
   as `device`, not `unauthorized`.
3. In VS Code, choose `Payme sinovi — avval server test rejimini tekshiring`
   and the connected phone, then press F5. This compiles/installs a **debug**
   app when explicitly started; it does not create a release APK. The normal
   `Mijoz ilovasi` launch keeps Payme disabled. Alternatively, after selecting
   a device, use `flutter run --no-pub --dart-define=PAYME_ENABLED=true`.
4. Sign in using the designated test account. Create a separate Xozmak
   test order; never reuse an ordinary customer's order. Confirm Payme is
   absent in the other stores. The prior synthetic Merchant HTTP test orders
   are cancelled audit records, not reusable orders.
5. Choose Payme and confirm once. The server URL must open on
   `https://test.paycom.uz/`. If it opens `checkout.paycom.uz`, stop without
   paying: that is the production payment host.
6. First test closing the external window without payment. Returning must
   refresh REST status, keep the order unpaid, and not create another order.
7. In the sandbox test flow, complete the test transaction; return and verify
   that only backend `paid` enables the normal order stages. Repeated taps,
   returning again and reopening the app must not duplicate the order/payment.
   Test offline/retry and cancelled/refund states as separate scenarios.

Sandbox confirmation still activates normal staff notifications in the live
backend. Coordinate the test and clearly label the order; do not fulfil it.
Phone/external-browser acceptance and Payme's own sandbox runner approval
are separate from mocked Flutter tests or Merchant HTTP protocol checks.

## Production and the installed Payme application

Production checkout keeps the server's original allowlisted HTTPS URL and
first uses `externalNonBrowserApplication`. If no native handler is available
or that launch fails, it falls back to `externalApplication` for the same URL.
It never fabricates a `paycom:` URL or rewrites a sandbox host to production.
Android app-link settings and the installed Payme version determine whether
the native handler is available. Sandbox remains external HTTPS/browser only.

On 2026-11-04 the connected phone's installed `uz.dida.payme` package declared
support for `https://checkout.paycom.uz/…`. No real payment was initiated by
that package inspection. A real payment may only be confirmed by the user;
the customer app still reads payment outcome from authenticated backend REST.
