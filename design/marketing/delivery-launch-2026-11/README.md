# Besh Kashtan — yetkazib berish reklama to‘plami

To‘rtta alohida **vertikal A3 (297×420 mm)** maket:

1. **1005 xil mahsulot** — uy-ro‘zg‘or, asboblar va kundalik mahsulotlar.
2. **Pokiza Halol** — xom, pishirishga tayyor shashlik va marinovka.
3. **Go‘sht do‘koni** — go‘sht mahsulotlari.
4. **Umumiy Besh Kashtan** — faol do‘konlar, shu jumladan Ofiyat taomlari.

Asosiy matn: **“Yetkazib berish xizmati ishga tushdi!”**
Chaqiruv: **“Ilovani hoziroq yuklab oling! QR kodni skanerlang.
Telefoningizdan buyurtma qiling.”**

Har birida `*-banner-A3.pdf`, o‘z ichiga foto/QR joylangan `*.svg`,
`*-preview.png` va `*-banner-A3-300dpi.png` bo‘ladi. Bosma uchun PDF afzal:
matn va QR vektor, shriftlar fayl ichida. PNG 3508×4961 px formatda eksport
qilinadi; bu original AI fotosuratining detali 300dpi degani emas.
Fayllar RGB; yakuniy matbaa profili va bosma namuna tekshiruvi printerga bog‘liq.
Ko‘rinadigan matn xavfsiz ichki chetlarda, to‘liq oq fon: bleed talab qilinsa
matbaa sahifa atrofini oq rang bilan kengaytirishi mumkin.

## Haqiqiy QR

To‘rtta maketda **bir xil mavjud QR** ishlatiladi:
`https://api.beshkashtan.uz/app/`. Rasmlar generatsiyasi QR yaratmaydi.
Kod ustiga matn/logo qo‘yilmaydi, o‘z oq cheti saqlanadi. Android/iPhone
yo‘naltirishini backend bajaradi; skanerning o‘z “Open in Browser” tasdig‘i
telefon sozlamasiga bog‘liq. Har maketni chop etishdan avval telefonlarda sinang.

Bu reklama ommaviy marketplace yuklash havolasiga olib boradi; ilovada biror
do‘konni avtomatik ochadigan deep link emas. Foydalanuvchi ilovada kerakli
do‘konni tanlaydi. Bepul yetkazish, aniq vaqt, narx, chegirma, 24/7 va’da yoki
halol sertifikati haqida tekshirilmagan da’volar yo‘q. “Pokiza Halol” —
foydalanuvchi tasdiqlagan do‘kon nomi, sertifikat belgisi chizilmagan.

## Tayyorlash usuli

Fotosuratlar built-in **imagegen** orqali to‘rtta alohida generatsiyada
yaratilgan. Bu haqiqiy do‘konda olingan suratlar emas, reklama illyustratsiyalari.
`prompts.json` har birining to‘liq matnini saqlaydi. Yakuniy matn va QR native
SVG bilan joylanib, CairoSVG orqali PDF/PNG eksport qilinadi; Python orqali
foto kontentini tahrirlash yoki QR’ni generativ qayta chizish bajarilmaydi.

`build_campaign.py` ichidagi matnlar/joylashuv tahrirlanadi. CairoSVG o‘rnatilgan
izolyatsiyalangan Python muhitida qayta eksport qilish:

```bash
python design/marketing/delivery-launch-2026-11/build_campaign.py
```

APK/AAB, deploy, haqiqiy buyurtma va to‘lov amallari bu vazifaga kirmaydi.

## Yakuniy tekshiruv

2026-11-13: har to‘rtta maket vizual ko‘rildi; A3 o‘lchami va PDF matnlarining
sahifa chetlaridan chiqmasligi tekshirildi. Asosiy sarlavha, yuklab olish
chaqiruvi hamda ikkala do‘kon nomi PDF’dan qayta o‘qildi. Preview PNG, katta
PNG va PDF’dan render qilingan har bir tasvirdagi QR ZXing orqali aynan
`https://api.beshkashtan.uz/app/` ekaniga tekshirildi: jami 12 ta skan o‘tdi.

`barcha-reklamalar-A3.pdf` — to‘rtta banner ketma-ket joylangan 4 sahifali PDF.
`besh-kashtan-reklamalar-A3.zip` — to‘rtta alohida PDF va to‘rtta katta PNG,
ushbu yo‘riqnoma va to‘liq generatsiya promptlari. Yakuniy bosma/telefon
tekshiruvi matbaadan chiqarganda baribir bajariladi.
