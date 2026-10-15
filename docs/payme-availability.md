# Payme availability

Payme is disabled by default in all customer app builds until the integration
is ready. Checkout shows only cash (courier for delivery, store for pickup).
Order tracking hides Payme actions, including automatic payment initiation
from an old `autoPay` route. Existing order payment methods and statuses are
not rewritten.

One shared `paymeEnabledProvider` reads `AppConfig.paymeEnabled`. Checkout
submission also enforces cash when disabled; payment initiation never calls
the API or URL launcher. Payme implementation and its enabled-path tests
remain intact.

After end-to-end integration validation, build a new release with
`--dart-define=PAYME_ENABLED=true` to restore the Payme option and actions.
Do not enable this define in current releases. No backend or migration change
is needed for this temporary client-side switch.
