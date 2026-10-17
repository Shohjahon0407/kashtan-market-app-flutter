# Savat → ixcham tasdiqlash → buyurtma

## Oqim

Umumiy Savat ekranida do‘konning nomi, mahsulot soni va o‘z summasi ko‘rsatiladi.
Do‘konlar summasi/minimumi birlashtirilmaydi. Do‘kon savatida ketma-ket:
yetkazish/olib ketish, manzil/filial, minimum, mahsulotlar va tavsiyalar mavjud.
Bo‘sh savat katta bo‘sh savat belgisi va tavsiyalarni ko‘rsatadi; buyurtma paneli yo‘q.

Pastki panel navbar ustida turadi. Manzil yo‘q bo‘lsa uni tanlash, hisoblanayotganda
kutish, xatoda retry/manzilni almashtirish, minimum yetmaganda tavsiyalarga scroll,
tayyor holatda **Buyurtmani davom ettirish** amali chiqadi. Yetishmayotgan summa
faqat server tasdiqlagan narx bilan hisoblanadi: 8 000 + 5 000 → yana 7 000 so‘m.
Offline navbatdagi yoki hali tasdiqlanmagan quantity bilan davom etish bloklanadi.

Manzil sahifasi avtomatik ochilmaydi. Mehmon manzilni tanlash/davom etishda login
qiladi; estimate oldidan offline navbat, guest merge va server savati tekshiriladi.
OS ruxsati manzil tanlashdan oldin ketma-ket so‘raladi, GPS natijasi esa ro‘yxatni
bloklamaydi va buyurtma manzilini almashtirmaydi. Picker faqat tasdiqlangan
natijani savatga qo‘llaydi; account asosiy manzili o‘zgarmaydi.

Olib ketishda minimum talab qilinmaydi. Bitta mos faol filial avtomatik olinadi,
ko‘p filial bo‘lsa tanlanadi; aralash fizik do‘konli savatda pickup cheklovi qoladi.

## Holat va xavfsizlik

`orderDraftProvider(StoreType)` account/do‘kon bo‘yicha xotiradagi holatni saqlaydi:
fulfillment, tasdiqlangan manzil/quote, filial, izoh va to‘lov usuli. Katalogga borish
uni yo‘qotmaydi; logout, tasdiqlangan bo‘sh savat yoki muvaffaqiyatli order tozalaydi.
Quote manzil ID/koordinata va fizik do‘konlar bilan bog‘langan. O‘zgarganda eski
narx yaroqsiz bo‘ladi; kechikkan estimate yangi holatga yozilmaydi.

Checkout’da katta xarita va mahsulotlar ro‘yxati yo‘q. Manzil/filial xulosasi,
to‘lov, izoh va hisob qoladi; mahsulot qatori rasmli chekni ochadi. Tahrirlash
savatning tegishli qismiga qaytaradi. Kirish va yuborish oldidan server savati
va quote qayta tekshiriladi. Tayyor bo‘lmagan direct-link savatga qaytadi.
Order API, server tekshiruvlari va idempotency saqlanadi. Payme o‘chiq; yakuniy
tugma **Buyurtmani tasdiqlash**. ETA, slot, chegirma yoki qadoqlash haqi o‘ylab topilmaydi.

## URL mosligi

- `/store/:type/cart?focus=location|fulfillment|products|recommendations`
- `/store/:type/cart/address/select` va uning `new`, `:addressId/edit` yo‘llari.
- Eski `/store/:type/cart/checkout` va checkout ostidagi manzil URL’lari saqlangan.

## Tekshiruv

2026-10-17: bitta yakuniy yurishda **316 ta tegishli Flutter testi o‘tdi**.
Accessibility tooltip qo‘shilgach savat UI’ining 35 testi yana o‘tdi (bu son
316 ga qo‘shilmaydi). `flutter analyze --no-pub` — `No issues found`.
Mapbox tokeni, production flavor va `PAYME_ENABLED=false` bilan Web release
build muvaffaqiyatli (`build/web`).

Avtomatik testlar do‘kon isolation, unknown/confirmed fee, minimum chegaralari,
pickup, tavsiyadan qo‘shish, mutation pending/xato/offline, draft va manzil
tanlovini qamraydi. Guest pickup tanlovi login/merge’dan keyin saqlanishi,
variant/qo‘shimcha/miqdor uchun haqiqiy line total, har tasdiq oldidan fresh
preflight va idempotency ham sinalgan. Layout: uch locale, 320/430 px,
landscape, 2× shrift va navbar. To‘liq loyiha test to‘plami emas, ushbu oqimga
tegishli 29 test fayli tekshirildi.

Android system/gesture back, haqiqiy Chrome history, GPS va screen reader
qurilmada alohida qo‘lda smoke-test talab qiladi. Yakuniy tekshiruvda `adb devices`
ro‘yxati bo‘sh edi; telefonga o‘rnatish yoki qurilma testi da’vo qilinmaydi.
Backend, admin, database,
production deploy va real buyurtmalar bu o‘zgarish doirasida o‘zgartirilmaydi.
