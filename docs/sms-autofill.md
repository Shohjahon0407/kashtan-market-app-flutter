# SMS OTP autofill (Android)

Kirish kodini foydalanuvchi qo'lda ko'chirmaydi — SMS kelganda kod maydonga
o'zi yoziladi. iOS'da bu allaqachon ishlaydi (`AutofillHints.oneTimeCode`),
bu hujjat Android haqida.

## Ikki rejim

| | SMS User Consent | SMS Retriever |
|---|---|---|
| Foydalanuvchi | tizim oynasida 1 marta "Ruxsat" | hech narsa bosmaydi |
| SMS matni | o'zgarmaydi | oxirida 11 belgilik app hash SHART |
| Eskiz | tegilmaydi | shablonni qayta tasdiqlatish kerak |
| Ruxsatlar | yo'q (`RECEIVE_SMS` kerak emas) | yo'q |

**Rejimni server tanlaydi.** `POST /auth/send-otp/` javobidagi
`sms_app_hash` bayrog'i SMS'da hash borligini bildiradi:

* `false` → ilova `consent` rejimini yoqadi (1 tap);
* `true` → `both` rejimi: Retriever (0 tap) + zaxira sifatida User Consent
  (Play imzosi bo'lmagan, sideload qilingan build'lar uchun).

Shu sababli 0-tap rejimiga o'tish uchun **ilovani yangilash shart emas** —
serverdagi `SMS_APP_HASH` sozlamasi yetarli.

## Kod qayerda

| Fayl | Vazifa |
|---|---|
| `lib/core/platform/sms_autofill_service.dart` | interfeys, no-op default, rejim provideri |
| `lib/core/platform/android_sms_autofill_service.dart` | MethodChannel/EventChannel |
| `lib/core/platform/otp_sms_parser.dart` | SMS matnidan kodni ajratish |
| `android/.../MainActivity.kt` | GMS receiver, consent oynasi, `debugAppHash` |
| `lib/main.dart` | Android'da haqiqiy servisni provider'ga berish |
| `apps/common/sms/sender.py` (backend) | hash'ni SMS oxiriga qo'shish |

## 2-bosqich: 0-tap ni yoqish

1. Play Console → Test and release → Setup → **App integrity** → App signing →
   **Download app signing certificate** (`deployment_cert.der`).
   Play ilovani o'z kaliti bilan qayta imzolaydi — bizdagi upload kaliti
   TO'G'RI KELMAYDI.
2. Hash'ni hisoblang:
   ```bash
   tool/app_hash.py uz.beshkashtan.customer ~/Downloads/deployment_cert.der
   ```
3. Yangi SMS matnini **Eskiz'ga tasdiqlating**:
   ```
   Assalomu alaykum hurmatli mijoz! Beshkashtan savdo majmuasi ilovasiga kirish kodi : 123456 <HASH>
   ```
   Tasdiqdan OLDIN sozlamani qo'ysangiz har bir SMS `provider_error` beradi
   va **hech kim login qila olmaydi**.
4. Serverda `.env` ga `SMS_APP_HASH=<HASH>`, so'ng **gunicorn VA celery
   worker ikkalasini ham** qayta ishga tushiring (matn worker ichida
   render qilinadi).
5. Tekshirish: **Play'dan o'rnatilgan** build'da kod hech narsa bosmasdan
   yozilishi kerak. Sideload qilingan APK'da Retriever mos kelmaydi va
   tizim oynasi chiqadi — bu normal, server xatosi emas.

Orqaga qaytarish: `SMS_APP_HASH` ni o'chirib, ikkala servisni qayta yuklash —
ilova avtomatik 1-tap rejimiga tushadi.

## Qurilmada tekshirish ro'yxati

- [ ] Kod kelganda tizim oynasi chiqadi, "Ruxsat" bosilgach 6 ta box to'ladi
      va login avtomatik yakunlanadi
- [ ] "Rad et" bosilsa — crash yo'q, qo'lda kiritish ishlaydi
- [ ] Hisob o'chirish oynasida kod to'ladi, lekin **hisob o'chmaydi**
- [ ] Qayta yuborishdan keyin kechikkan eski SMS avtomatik yuborilmaydi
- [ ] Ilovani fonga olib, SMS kelganda qaytish — crash yo'q
- [ ] 5 daqiqadan keyin (GMS listener o'ladi) qayta yuborish ishlaydi
- [ ] **`image_picker` (support rasm/ovoz), `geolocator` ruxsat oynasi va
      `url_launcher` hamon ishlaydi** — `MainActivity.onActivityResult`
      regressiyasi shu yerda ko'rinadi
- [ ] iOS: klaviatura ustidagi kod taklifi saqlanib qolgan
- [ ] Eskiz raqami kontaktlarda saqlangan bo'lsa oyna chiqmaydi — GMS
      xususiyati, xato emas

## Nima uchun paket emas

`smart_auth` paketi ikkala API'ni qo'llaydi, lekin oxirgi marta ~20 oy oldin
chiqqan va o'z Gradle moduli bor. Loyiha AGP 9.0.1 / Kotlin 2.3.20 da —
eski plagin moduli qurilmasligi ehtimoli yuqori. O'z Kotlin kodimiz
ilovaning aynan shu toolchain'ida quriladi, bog'liqlik esa oddiy Google AAR.
`SmsAutofillService` abstraksiyasi tufayli kerak bo'lsa paketga o'tish
bitta fayl o'zgarishi.
