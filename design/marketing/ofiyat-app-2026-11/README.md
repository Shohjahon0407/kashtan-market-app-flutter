# Ofiyat — ilovadan buyurtma qilish reklamasi

Format: vertikal A3, 297×420 mm. A4 ga mutanosib kichraytirish mumkin.
Matbaa uchun asosiy fayl: `ofiyat-app-banner-A3.pdf`. PDF/SVG ichidagi QR va
matn vektor; rasm — ilustrativ reklama fotosi, restoranda olingan haqiqiy surat emas.
Fayllar RGB: matbaa o‘z printer/profiliga mos rang konvertatsiyasi va sinovini qiladi.
300dpi PNG umumiy 3508×4961 px formatda; hero fotosining originali 1774×887 px,
shuning uchun PDFdagi matn/QR kabi vektor aniqligiga ega emas.

QR’ni qirqmang, cho‘zmang yoki ustiga logotip qo‘ymang. Ichidagi manzil:
`https://api.beshkashtan.uz/app/`. Chop etishdan oldin ikki telefonda tekshiring.
Narx, chegirma, bepul yetkazish yoki yetkazish muddati haqidagi va’dalar qo‘shilmagan.

2026-11-13: `/app/` production yo‘naltirishi chiqarildi. PNG preview, katta PNG
va PDF’dan render qilingan sahifadagi QR ZXing bilan qayta o‘qilib, aynan shu
manzil chiqishi tekshirildi. PDF A3 o‘lchamda, shriftlar ichiga joylangan.
Haqiqiy telefon kamerasi va yakuniy bosma namunadagi sinov hali talab qilinadi.

## Qayta eksport qilish

`poster-template.svg` — tahrirlanadigan maket; `build_poster.py` haqiqiy QR va
foto faylini o‘z ichiga joylaydi. CairoSVG bilan ishga tushiring.

## Foto generatsiyasi

Built-in `imagegen` ishlatildi; matn va QR generativ modelda chizilmadi.
Prompt: “Photorealistic landscape 2:1 restaurant advertising food photograph
for Ofiyat milliy taomlari: authentic Uzbek to‘y oshi/plov with beef, carrots,
chickpeas, two grilled shashlik skewers behind and achichuk salad on a clean
white tabletop. Soft side daylight, appetizing realistic ingredients, subtle
shadows, no text, no QR, no logo, no people, no smartphone.”
