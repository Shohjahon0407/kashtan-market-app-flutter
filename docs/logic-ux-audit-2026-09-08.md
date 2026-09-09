# Customer app: logic va funksional UX auditi

2026-09-08. Customer Flutter kodi o‘zgartirildi; backend, production server,
API kontrakti va dizayn tili o‘zgarmadi. Bu barcha mumkin bo‘lgan buglar
tugaganini yoki Play release to‘liq tayyorligini anglatmaydi.

## Tuzatilgan holatlar

| Muammo | Tuzatish |
| --- | --- |
| Manzil/order/favorite/notification cache’i accountlar orasida aralashishi | Private cache user ID bilan alohida namespace’da saqlanadi; guest o‘qimaydi, eski accountning kechikkan yozuvi rad qilinadi. |
| Oldingi accountning kechikkan HTTP javobi yoki refresh tokeni yangi sessiyani buzishi | So‘rov egasi tekshiriladi; account o‘zgargan javob bekor qilinadi. Refresh natijasi yozilishidan oldin refresh token hali o‘sha sessiyaga tegishliligi tekshiriladi. |
| Logoutdan keyin kechikkan session restore yana login qilishi | Restore uchun generation guard; logout/expiry/OTP verification uni eskirtiradi. |
| Refreshdan keyingi 403 userni chiqarib yuborishi | 403 permission xatosi sifatida qoladi; qayta yuborilgan 401 expiry bo‘lib qoladi. |
| Timeoutda mutating HTTP request avtomatik takrorlanishi | Oddiy retry faqat GET/HEAD yoki haqiqiy Idempotency-Key berilgan request uchun. |
| Savatga yozish muvaffaqiyatli, keyingi GET timeout: ikkinchi add navbatga tushishi | Server yozuvi va GET reconciliation xatosi ajratildi; muvaffaqiyatli yozuv qayta navbatga qo‘yilmaydi. |
| Bir store’da quantity/clear amallari bir-birining optimistic holatini buzishi | Store savat mutatsiyalari bitta in-flight amal bilan cheklangan; card/detail/savat boshqaruvlari va checkout shu paytda disabled. |
| Navbat flush paytida qo‘shilgan amal yo‘qolishi | Lokal navbat yozuvlari serial; acknowledgement faqat stable operation ID’ni o‘chiradi, eski ro‘yxat snapshotini emas. |
| 429/500/auth xatosida queued amal tashlab yuborilishi | Bunday amallar saqlanadi. Faqat yo‘q itemga tegishli set/remove 404’i obsolete deb olinadi. |
| Boshqa accountning offline amali yuborilishi | Navbat account namespace’iga ajratildi; eski owner instansi flush qilmaydi, egasi qayta kirganda yoki resume’da o‘z navbati davom etadi. |
| Fon katalog javobi yangi categoryni almashtirishi | Category/search o‘zgarishi plain-catalog revalidation generationini ham eskirtiradi. |
| GPS qo‘lda tanlangan nuqtani almashtirishi | Kechikkan auto-GPS natijasi manual selectiondan keyin qabul qilinmaydi. GPS 15 soniyalik timeoutga ega; permission va boshqa lokatsiya xatolari alohida matn bilan chiqadi. |
| Checkout load/merge xatosi “savat bo‘sh”ga aylanishi | Alohida error + retry ko‘rinishi; tayyorlash muvaffaqiyatsiz bo‘lsa submit ochilmaydi. |
| Eski delivery estimate yangi tanlovga ta’sir qilishi | Estimate revision guard; pickupga o‘tilganda pending estimate bekor hisoblanadi. Manzil ro‘yxatda bo‘lmasa submit bloklanadi. |
| Login ortidan navbar/bell build-time exception | Unread API/cache resolution auth o‘zgarishidan keyingi microtaskda bajariladi. Real router testlari o‘tadi. |

## Saqlash va moslik

- Yangi private cache va offline navbat `v2` namespace ishlatadi.
- Eski owner’siz cache/navbat kimga tegishli ekanini xavfsiz aniqlab bo‘lmaydi;
  ular boshqa accountga avtomatik ko‘chirilmaydi yoki yuborilmaydi. Eski
  navbat yozuvi diskdan o‘chirilmagan. Cache odatdagi expiry bilan tozalanadi.
- Yangi owner-scoped yuborilmagan amallar logoutda o‘chirilmaydi; faqat egasi
  qayta kirganda ishlatiladi. Server savatlari o‘zgartirib/tozalab yuborilmadi.
- Yangi GPS xato matni o‘zbek lotin, o‘zbek kirill va rus tillariga qo‘shildi.

## Hali ochiq, keyingi bosqich talab qiladigan topilmalar

1. **Offline yangi itemni to‘liq lokal ko‘rsatish va restartdan tiklash.**
   Navbat saqlanadi, ammo to‘liq cart snapshot/temporary item UI hali yo‘q.
   Queued natija bilan serverda tasdiqlangan natija uchun alohida UX kerak.
2. **Yozuvning o‘zi timeout bo‘lgan noaniq add.** Oddiy HTTP avtomatik retry
   tuzatildi, lekin offline outbox replay uchun server idempotency yoki alohida
   uncertainty/reconciliation protokoli kerak. “Write OK → GET failed” holati
   tuzatildi; barcha network timeoutlarda exactly-once kafolati berilmaydi.
3. **Guest offline intentlarini OTP merge’da ko‘chirish.** Server guest cart
   merge’i saqlangan, lekin yangi local owner-scoped outbox uchun alohida
   guest→user transfer/reconciliation hali kerak; guest navbat boshqa userga
   taxmin asosida yuborilmaydi.
4. **Checkout idempotency route/restart davomida saqlanishi.** Hozir kalit
   controller umriga bog‘liq; noaniq timeoutdan keyin sahifadan chiqib qaytish
   uchun persisted checkout intent va server holatini tekshirish kerak.
5. **Barcha noodatiy exceptionlarda busy-state va katta text-scale auditi.**
   Ushbu patch targeted holatlarni tuzatadi; barcha payment/media/permission
   oqimlari real qurilmada to‘liq tekshirilgan deb hisoblanmaydi.

## Tekshiruv

- `flutter analyze --no-pub`: toza.
- `flutter test --no-pub`: 367 ta test o‘tdi.
- `flutter build web --no-pub`: muvaffaqiyatli.
- Chrome’da network/session regression testlari: 17 ta test o‘tdi.
- `git diff --check`: toza.
- Alohida yangi testlar: cache owner isolation/late writes, account queue
  restore, enqueue-during-flush, 429/500 retention, GET failure after successful
  add, concurrent clear/quantity, delayed category/GPS, checkout error/retry,
  no mutation retry, idempotent retry, 403 va logoutdan keyingi late restore.
- Android real-device smoke hali kerak; bu bosqich APKni telefonga o‘rnatmaydi.

## Xulosa

Eng muhim xavfsizlik, retry va bir nechta foydalanuvchiga ko‘rinadigan UX
xatolari tuzatildi. Keyingi alohida ish — offline savatning temporary-item,
guest-transfer va noaniq mutation reconciliation qismini birgalikda yakunlash.
