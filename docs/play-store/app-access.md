# Play reviewer access

Play Console’da “All or some functionality is restricted” tanlanadi.

```text
Phone: +998900000001
OTP: 123456
```

English instructions:

> The public catalog and cart are available without signing in. Checkout,
> orders, notifications and user-generated content require phone OTP. Enter
> +998900000001 and use the fixed code 123456; no SMS is sent for this reviewer
> account. The account contains a delivered order so product review, report,
> block and moderation-related user flows can be tested. Account deletion is
> available under Profile.

Productionda `TEST_OTP_ACCOUNTS=+998900000001:123456` secret sifatida beriladi.
Test account oddiy SMS cooldown/charge’ga tushmaydi; boshqa raqamlar uchun fixed
OTP ishlamasligi smoke-test qilinadi. Seed qilingan orderda shaxsiy real data
bo‘lmasligi kerak.
