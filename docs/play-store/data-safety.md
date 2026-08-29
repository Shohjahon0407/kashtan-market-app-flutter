# Data Safety deklaratsiyasi

Console formasi productiondagi real sozlamalar bilan yana bir marta solishtiriladi.
Ilova ma’lumotni sotmaydi, HTTPS ishlatadi va account deletion beradi.

| Play turi | Ma’lumot | Maqsad | Optional | Saqlash/izoh |
|---|---|---|---|---|
| Personal info | Telefon raqami | Account, autentifikatsiya, order aloqasi | Checkoutgacha ha | Account bilan |
| Personal info | Ism | Order va kuryer aloqasi | Ha | Account bilan |
| Location | Precise location | Yetkazish manzili va route | Ha | Saqlangan address; Mapboxga faqat koordinata |
| App activity | Purchase history | Checkout, order history, support | Yo‘q, orderda | Backend audit/soliq talablariga mos |
| User content | Comment/review | UGC | Ha | User o‘chirishi/moderatsiya qilishi mumkin |
| User content | Support matn/rasm/audio | Yordam va topilmagan mahsulot | Ha | Private support media |
| Device or other IDs | FCM token/stable device ID | Push notification | Ha | Logout/token invalidda deaktivatsiya |
| App info/performance | Crash va diagnostics | Crashlytics stability | Ha | Release’da, PII va API payloadsiz |

Service providerlar: Firebase Cloud Messaging/Crashlytics va Mapbox. Ular faqat
xizmatni bajarish uchun ishlatiladi; telefon, ism va order ID Mapboxga
yuborilmaydi. Console’dagi “shared” javobi Google’ning amaldagi service-provider
istisnosi va real DPA/sozlamalar asosida tanlanadi.

Deletion:

- Ilova: Profil → Hisobni o‘chirish
- Web: `https://api.beshkashtan.uz/delete-account/`

Public hujjatlar privacy sahifasida yig‘ish, saqlash, UGC moderation,
Crashlytics va aloqa emailini bir xil bayon qilishi kerak.
