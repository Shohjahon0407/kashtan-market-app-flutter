# Yetkazib berish reklamasi — yashil/sariq fotografik uslub (v2)

Foydalanuvchining ikkita referensiga mos yangi to‘plam: to‘q/yorqin yashil fon,
sariq-to‘q sariq urg‘ular, yirik oq-sariq sarlavha, yog‘och stol, mahsulotlar,
zarur maketlarda telefon, katta haqiqiy QR.

To‘rtta alohida A3: 1005 xil mahsulot, Pokiza Halol shashlik/marinovka,
Go‘sht do‘koni va barcha faol yo‘nalishlar uchun umumiy Besh Kashtan reklamasi.
Eski oq fonli maketlar `../delivery-launch-2026-11/` ichida saqlangan.

Asosiy brend **Besh Kashtan**, app’dagi mavjud savat/bargli to‘q sariq tutqich
logosi qayta ishlatiladi. Namunadagi “Kashtan market” yangi yuridik yoki ilova
nomi sifatida olinmagan. Pokiza Halol nomi sertifikat da’vosi emas; mahsulot
pishirishga tayyor xom marinovka sifatida tasvirlanadi. AI fotosi real do‘kon
yoki mahsulotning hujjatli fotosurati emas. 20 yil, bepul/tezkor yetkazish,
chegirma, har kuni yangi, halol sertifikati kabi tasdiqlanmagan va’dalar yo‘q.
Telefon ekranidagi katalog illyustrativ xira ko‘rinish, haqiqiy app skrinshoti
emas. Do‘kon nomli qora download belgilari generatsiya qilingan dekorativ
tasvirlar, rasmiy store badge vektor fayllari emas.

## Fayllar

- `*-artwork.png`: ichki imagegen vositasida yaratilgan asosiy dizayn.
- `*-preview.png`: ko‘rish uchun yakuniy reklama.
- `*-banner-A3.pdf`: 297×420 mm bosma PDF.
- `*-banner-A3-300dpi.png`: 3508×4961 px PNG eksporti.
- `*-banner-A3.svg`: hamma rasm/QR/logo fayl ichiga joylangan layout.
- `prompts.json`: to‘liq generatsiya promptlari, built-in tool usuli.
- `placements.json`: original QR/logo joylashuvi, source piksel koordinatalari.

PNG’dagi 300dpi nomi eksport kanvas o‘lchamini bildiradi; AI asosiy rasm
rezolyutsiyasi yuqori kanvasga chiqarilganda qo‘shimcha foto detali paydo bo‘lmaydi.
Asosiy rasmlar 1054/1055×1491/1492 px: A3’da taxminan 90 native ppi.
Asosiy dizayn/matn raster, QR esa PDF/SVG’da vektor. Bosma RGB; matbaa o‘z
profilida CMYK sinovini qiladi. Yorqin yashil/sariq ranglar qog‘ozga qarab
farq qiladi. Full-bleed talab qilinsa 3 mm qo‘shimcha trim maydonini matbaa
bilan kelishing: kesish muhim sarlavha, QR va tugmalarga yetmasin.

## QR va tekshiruv

Kod eski bilan bir xil: `https://api.beshkashtan.uz/app/`. QR generatsiya
modelida chizilmaydi: ataylab bo‘sh qoldirilgan joyga asl SVG joylanadi,
asl quiet-zone saqlanadi. Telefonga qarab do‘konga yo‘naltirish backendda,
skanerning “Open in Browser” bosqichi esa uning o‘z sozlamasida qoladi.

`build_campaign.py` faqat native SVG layout/format eksporti qiladi; Python
bilan fotosurat tahriri qilinmaydi. QR/banner biror do‘konni avtomatik ochish
emas, marketplace ilovasini yuklash uchun. Matbaadan oldin haqiqiy telefon va
bosma namunada tekshiring. App kodi, API, deploy, APK/AAB o‘zgarmaydi.

## Yakuniy sifat tekshiruvi (2026-11-13)

To‘rttala rasm va o‘zbekcha yozuvlar ko‘rib chiqildi; QR va logoning bo‘sh
panellarga to‘g‘ri sig‘ishi tekshirildi. Har bir preview PNG, katta PNG va
PDF’dan render qilingan tasvir ZXing orqali qayta o‘qildi: 12/12 holatda
`https://api.beshkashtan.uz/app/` chiqdi. Jismoniy bosma namunani va telefon
kamerasini tekshirish matbaadan oldin alohida bajariladi.

`barcha-reklamalar-A3.pdf` — ketma-ket 4 sahifa. `yangi-uslub-reklamalar-A3.zip`
ichida 4 ta alohida PDF, 4 ta katta PNG, ushbu izoh va to‘liq promptlar bor.
Oldingi oq dizayn fayllari almashtirilmadi.
