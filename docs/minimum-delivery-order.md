# Yetkazish uchun minimal buyurtma summasi

Har bir fizik do‘kon (`Store`) uchun `minimum_delivery_order_amount` saqlanadi.
Boshlang‘ich qiymat **20 000 so‘m**; do‘konning barcha filiallari shu qiymatdan
foydalanadi. Admin → Do‘konlar → Tahrirlash orqali o‘zgartiriladi. `0` qiymati
cheklovni o‘chiradi. Manfiy yoki ikkitadan ortiq kasr xonali qiymat rad etiladi.

Mahsulotlar summasi (variant va addon narxlari bilan) va server tasdiqlagan
yetkazish haqi birga hisoblanadi. Olib ketishga cheklov qo‘llanmaydi.
8 000 so‘mlik savat + 5 000 so‘m yetkazish va 20 000 so‘mlik minimumda savat
“Minimal buyurtmagacha yana 7 000 so‘m” ko‘rsatadi. 15 000 + 5 000 tengligida
yetkazish mumkin. Manzil/estimate hali yo‘q bo‘lsa yetkazish narxi taxmin qilinmaydi:
app manzil tanlashni so‘raydi. Eski yoki yuklanayotgan estimate hisobga olinmaydi.
Kasrli farq yaxlitlab yo‘qotilmaydi; taqqoslash floating-point bilan bajarilmaydi.

## API va checkout

- Admin `/api/admin/stores/` va store detail PATCH yangi maydonni qabul qiladi.
  Mavjud do‘kon bo‘yicha admin ruxsatlari saqlanadi.
- Public store va cart javoblariga additive `minimum_delivery_order_amount`
  maydoni qo‘shilgan. Cart uni ayni savat mahsulotlari do‘konidan oladi.
- Do‘kon savati delivery’da progress, yetishmayotgan summa va faol “Mahsulot
  qo‘shish” tugmasini ko‘rsatadi. Tugma shu sahifadagi tavsiyalarga olib boradi.
  Minimum yetmaguncha ixcham checkout’ga o‘tib bo‘lmaydi. Manzil yoki server
  tasdig‘i yo‘q bo‘lsa aniq qolgan summa hamda yashil muvaffaqiyat ko‘rsatilmaydi.
  Olib ketishda delivery minimumi qo‘llanmaydi.
- Buyurtma serverda amaldagi narxlar bilan qayta tekshiriladi. Admin minimumni
  o‘zgartirgan bo‘lsa eski klient ham cheklovni chetlab o‘tolmaydi.
  400 javob: `reason_code=minimum_delivery_order_not_met`,
  `minimum_delivery_order_amount`, `remaining_for_delivery`, `delivery` xabari.
  Bu xatoda order yaratilmaydi va savat tozalanmaydi. App cart’ni yangilaydi.
  Serverdan kelgan `remaining_for_delivery` mahsulotlar-only mahalliy hisob bilan
  almashtirilmaydi. Request’dagi soxta `delivery_fee`/`total` hisobga olinmaydi.
- Eski API/cache’da maydon bo‘lmasa app do‘kon siyosatini taxmin qilmaydi;
  server tekshiruvi yakuniy hisoblanadi. Backend app’dan avval chiqarilishi kerak.
- Oldingi orderlar va narxlari o‘zgartirilmaydi; idempotent order qayta olinishi
  minimum o‘zgarganda ham mavjud orderni qaytarishda davom etadi.

## Chiqarish

1. Backendni yangilang va `python manage.py migrate` bajaring.
   Additive migration: `stores.0016_store_minimum_delivery_order_amount`.
   Mavjud do‘konlar ham 20 000 so‘m bilan boshlanadi.
   `stores.0017_update_delivery_minimum_help_text` faqat modeldagi yordam matnini
   yangi qoida bilan moslaydi; mavjud minimum qiymatlari o‘zgarmaydi.
2. Admin panelni chiqaring; zarur do‘kon limitlarini sozlang.
3. App’ning yangi buildini tarqating. Backendni kutmasdan eski endpointlarga
   ulanayotgan app yangi maydonni olmaguncha minimum panelini ko‘rsatmaydi.

## Xarita manbalari

Mapbox logotipi xaritada kichik, o‘zgartirilmagan holatda qoladi. Keng matnli
blok o‘rniga yonidagi ⓘ tugmasi pastdan ochiladigan manba panelini ko‘rsatadi.
Unda © Mapbox, © OpenStreetMap va Improve this map havolalari saqlanadi.
OSM fallback’da mavjud © OpenStreetMap havolasi ko‘rinadi.
Logotipni chegara ortiga yashirish qo‘llanmaydi:
[Mapbox attribution talablari](https://docs.mapbox.com/help/dive-deeper/attribution/).

## Tekshiruv holati — 2026-10-17

- Tegishli 79 ta backend testi: order, cart, delivery va admin store API.
- Tegishli 83 ta Flutter testi: minimum, checkout, xarita, savat va tavsiyalar.
- Admin: typecheck, production build va 6 ta schema/form testi o‘tdi.
- Flutter analyzer xatosiz; Mapbox konfiguratsiyasida Web release build o‘tdi.
- Alohida PostgreSQL bazasida migration qo‘llanib, mavjud do‘konga 20 000 so‘m
  default qiymati yozilishi va model/migration mosligi tekshirildi.
- To‘liq test to‘plamlari oldingi seans uzilishida to‘xtagan; ularning to‘liq
  muvaffaqiyati da’vo qilinmaydi. Yuqoridagi tegishli testlar qayta bajarildi.
- Bu o‘zgarishlar production serverga chiqarilmagan va telefonga yangi APK
  sifatida qayta o‘rnatilmagan.

### Yetkazish haqini qo‘shish va bitta xarita doirasi

Yangi qoida uchun qayta tekshiruv: 61 ta backend order/cart/delivery testi
PostgreSQL scratch bazasida va 56 ta Flutter minimum/checkout/map/rules/controller
testi o‘tdi. 8 000 + 5 000 uchun 7 000 qoldiq, 15 000 + 5 000 chegarasi,
0.01 kasrli yetishmovchilik va client yuborgan soxta to‘lovni inkor qilish sinaldi.
Admin typecheck/build o‘tdi; model va migration holati mos (`No changes detected`).
Checkout mini va fullscreen xaritalarida GPS aniqlik doirasi chizilmaydi:
faqat delivery chegarasi va uch marker qoladi. GPS aniqligi ogohlantirishda
ishlatilishda davom etadi. Yangi qoida ishlashi uchun backend app’dan oldin
yangilanishi kerak; production deploy va telefon install bajarilmadi.
