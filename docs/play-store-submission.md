# Besh Kashtan — Google Play release checklist

Release: `1.1.5 (8)` · package: `uz.beshkashtan.customer` · category:
`Shopping` · region: Uzbekistan · target audience: 13+.

## Release gate

```bash
export MAPBOX_ACCESS_TOKEN='pk....'
./tool/build_play_release.sh

# Mapbox tokeni hali olinmagan bo'lsa (vaqtinchalik OSM zaxirasi bilan):
ALLOW_OSM_TILES=1 ./tool/build_play_release.sh
```

Gate analyzer, tests, Android lint, Firebase package, upload signing, target API,
signed AAB, 16 KB alignment va SHA-256 checksumni tekshiradi. Play’ga faqat
gate muvaffaqiyatli tugagach `build/play-release/1.1.5-8/` ichiga ko‘chirilgan
`.aab` yuklanadi. `build/app/outputs/` ichida oldingi builddan qolgan fayl bo‘lsa
u release artefakti hisoblanmaydi. Play App Signing birinchi upload vaqtida
yoqiladi. Upload keystore va parollar repo/log ichiga kiritilmaydi va ikki
xavfsiz joyda zaxiralanadi.

Bu paketda Mapbox xaritalari, yangilangan Shashlik/Ofiyat/Go‘sht do‘koni
rasmlari va vaqtincha faqat naqd to‘lov mavjud (`PAYME_ENABLED=false`).
Mapbox public token README’dagi vaqtinchalik yozuvdan build muhitiga olinadi;
token release manifesti yoki loglarga yozilmaydi. Keyingi buildlarda tokenni
CI konfiguratsiyasi orqali berish tavsiya etiladi.

**Upload oldidan:** Play Console’dagi barcha track va draftlarda ishlatilgan
eng katta versionCode `8`dan kichik ekanini tekshiring. Console raqami hozircha
tasdiqlanmagan; agar `8` yoki kattaroq ishlatilgan bo‘lsa, build raqamini
oshirib qayta gate bajaring. Lokal tekshiruv Play Console holatini isbotlamaydi.
Paket tayyorlash uni avtomatik upload yoki publish qilmaydi.

Android yangilanish taklifini staged rollout paytida yoqmang. Release barcha
mo‘ljallangan foydalanuvchilarga mavjud bo‘lgach backenddagi release sozlamalari
yangilanadi; qarang `docs/app-updates.md`.

## Console qiymatlari

- Privacy: `https://api.beshkashtan.uz/privacy/`
- Account deletion: `https://api.beshkashtan.uz/delete-account/`
- Terms: `https://api.beshkashtan.uz/terms/`
- Community guidelines: `https://api.beshkashtan.uz/community-guidelines/`
- Support: `shohjahon.0407.19@gmail.com`
- Ads: yo‘q
- UGC: bor; policy acceptance, report, block va admin moderation bilan
- Payments: jismoniy mahsulotlar uchun; Google Play Billing talab qilinmaydi

## Reviewer access

Production secret (repo ichiga yozilmaydi):

```dotenv
TEST_OTP_ACCOUNTS=+998900000001:123456
```

Reviewer: telefon `+998900000001`, OTP `123456`. Hisobda kamida bitta
`delivered` order bo‘lishi kerak, shunda review/report oqimi tekshiriladi.
Batafsil matn: `docs/play-store/app-access.md`.

## Listing paketi

- `docs/play-store/listing/uz-UZ/`
- `docs/play-store/listing/ru-RU/`
- `docs/play-store/assets/app-icon-512.png`
- `docs/play-store/assets/feature-graphic-1024x500.png`
- `docs/play-store/screenshots/README.md`
- `docs/play-store/data-safety.md`
- `docs/play-store/console-declarations.md`

Screenshotlar real release builddan olinadi; debug banner, shaxsiy raqam va test
paneli bo‘lmasligi shart.

## Rollout

1. Internal test va Play pre-launch report.
2. Yangi personal accountda 12+ tester 14 kun uzluksiz closed testda opt-in.
3. Production access tasdiqlangach `20% → 50% → 100%`; bosqichlar orasida
   24–48 soat Crashlytics va Android vitals kuzatiladi.

Play review — Google boshqaradigan tashqi jarayon. Lokal gate va hujjatlar
tasdiq ehtimolini oshiradi, lekin review natijasini mutlaq kafolatlamaydi.
