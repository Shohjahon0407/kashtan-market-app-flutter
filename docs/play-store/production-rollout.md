# Production rollout

Har bosqich oldidan yangi AAB checksum, release notes va backend compatibility
qayd etiladi.

1. `20%` — 24–48 soat: crash-free users, ANR, startup, OTP, checkout, push.
2. `50%` — 24–48 soat: yuqoridagilar + payment/order mismatch va support.
3. `100%` — blocker/regressiya bo‘lmasa.

Stop mezonlari: fatal auth/checkout xatosi, duplicate order, PII leak,
notification deep-link crash, crash-free users keskin pasayishi yoki Play vitals
bad behavior threshold. Stop bo‘lsa rollout halt qilinadi; eski AAB o‘chirilmaydi,
versionCode oshirilgan hotfix tayyorlanadi.
