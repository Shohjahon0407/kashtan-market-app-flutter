# Manzil tanlash dizayni

## Savat uchun yetkazish manzilini tanlash

Savatda **Yetkazish manzilini tanlash** bosilganda popup emas, alohida
**Yetkazib berish manzili** sahifasi ochiladi. Savatga kirishda avtomatik
ochilmaydi. Asosiy vazifa — buyurtma boradigan saqlangan
manzilni tanlash; xaritadan yangi manzil yaratish ikkinchi darajali amal.

Saqlangan yaroqli manzil bo‘lsa, savat uning asosiy/birinchi manzilini avtomatik
olib server quote’ini tekshiradi; davom etishda ushbu picker ochilmaydi. Picker
faqat manzil bo‘lmaganda yoki foydalanuvchi uni almashtirishni bosganda kerak.

- Ichki URL: `/store/:type/cart/address/select`; shu route ostidagi
  `new` va `:addressId/edit` formalarida tugma **Manzilni saqlash** bo‘ladi.
  Eski checkout `address/select`, `address/new` va `address/:addressId/edit`
  URL’lari ham saqlangan.
- Birinchi tanlovda koordinatasi bor asosiy manzil vaqtincha belgilanadi;
  bunday manzil bo‘lmasa koordinatasi bor birinchi manzil olinadi. Manzilni
  almashtirishda avval savat uchun tasdiqlangan manzil belgilanadi.
  Koordinatasiz eski manzillar tahrirlash uchun ko‘rinadi, lekin yetkazish uchun
  tasdiqlanmaydi. Bo‘sh nom uchun lokalizatsiyalangan nom ishlatiladi.
- Karta bosilganda faqat vaqtinchalik tanlov o‘zgaradi. Account’dagi asosiy
  manzil o‘zgarmaydi; back esa avvalgi savat tanlovini saqlaydi.
- Faqat tanlangan manzil estimate qilinadi. So‘rov kaliti manzil ID/koordinata
  va savatdagi fizik do‘konlar to‘plamini hisobga oladi; kech kelgan javob
  yangi tanlov yoki yangi savat scope’ini bosib ketmaydi. Yuklanish, xato,
  yetkazish mumkin emasligi va narx yo‘qligida tasdiq o‘chiq, retry mavjud.
- Pastki paneldagi **Tanlangan manzilga yetkazish** tasdiqlangan manzil va
  server quote’ini savatga qaytaradi. Koordinata/do‘konlar o‘zgarsa quote
  qayta hisoblanadi; checkout kirishida ham tekshiruv yangilanadi. Minimum hisobi shu
  tasdiqlangan yetkazish narxini qo‘shadi: 8 000 + 5 000 → yana 7 000 so‘m.
- Yuqoridagi ixcham xarita joriy savat uchun `store_type` coverage’ini oladi;
  manzil yaratishdagi umumiy eng katta radiusdan foydalanmaydi. Bitta yetkazish
  chegarasi va do‘kon/tanlangan manzil/mavjud GPS markerlari bor, GPS aniqlik
  doirasi yo‘q. Ko‘cha nomi, ETA yoki narx taxmin qilib yozilmaydi.
- OS ruxsati route ochilishidan oldin tugaydi, GPS esa parallel olinadi va
  manzil ro‘yxatini bloklamaydi. GPS nuqtasi buyurtma manzilini almashtirmaydi.
  Mavjud modal ustiga yangi sahifa qo‘yilmaydi; modal yopilishini kutadi.
- Qo‘shish/tahrirlashdan saqlab qaytilganda karta belgilanadi, ko‘rinishga
  olib kelinadi va estimate olinadi. Buyurtma manzili yana alohida tasdiqlanadi.
  Formani bekor qilish draft va ro‘yxat scrollini saqlaydi. Pastki panel katta
  shriftda/landscape’da xabarni scroll qiladi, asosiy tugma ko‘rinib qoladi.
  Tor portretda sarlavha balandligi shriftga moslashadi; landscape’da ro‘yxat
  va tasdiqlash paneli yonma-yon joylashadi. Pastki store navbar saqlanadi.

Bu UX o‘zgarishi uchun backend/API, admin yoki database o‘zgartirilmaydi.
Yakuniy buyurtma/radius/minimum tekshiruvi serverda qoladi.

### Avvalgi manzil-picker UX’i uchun tekshiruv

2026-10-17: 179 ta tegishli test ikki muvaffaqiyatli yurishda tekshirildi
(97 + 100, shundan 18 tasi ikkala yurishda ham bor). Yangi selector testlari
0/1/ko‘p manzil, kechikkan quote, offline/retry, tarif/radius/narx yo‘qligi,
koordinatasiz/bo‘sh nomli manzil, fizik do‘kon o‘zgarishi, qo‘shish va edit
cancel’ini qamraydi. Uch locale, 320/430 px, landscape, 1×/2× shrift va haqiqiy
80px navbar uchun layout tekshirildi. Real app-router testlari eski/yangi
URL’lar, nested form, system/route back, yangi checkout va narxni qayta
ishlatishni tekshiradi. Mavjud modal tugashini kutish ham alohida tekshirildi.

Yangi savat → ixcham checkout oqimi va uning alohida tekshiruvlari
[`cart-order-flow.md`](cart-order-flow.md)da hujjatlashtiriladi. Yuqoridagi
avtomatik picker ochilishiga tegishli eski testlar yangi oqimga moslashtirilgan.

Mapbox bilan production Web build muvaffaqiyatli. Bu testlar telefondagi GPS,
Android gesture back, haqiqiy Chrome history yoki screen-reader’ning qurilmadagi
qo‘lda smoke-testini almashtirmaydi. To‘liq test to‘plami bu ish uchun yakuniy
pass sifatida da’vo qilinmaydi; yuqoridagi tegishli testlar tasdiqlangan.
Production deploy, real order va telefonga APK o‘rnatish bajarilmadi.

## Manzil yaratish va tahrirlash

Yangi manzil va saqlangan manzilni tahrirlash bir xil map-first ekran ishlatadi:
oq floating sarlavha, suriladigan xarita va yumaloq pastki panel. Qidiruv olib tashlangan.
Portretda panel pastda, landscape’da xarita yonida joylashadi. Panel ichidagi
maydonlar scroll bo‘ladi; tasdiqlash tugmasi alohida qoladi. Katta shriftda
qo‘shimcha sarlavha ko‘rsatmasi help oynasida mavjud, asosiy nom qisqartirilmaydi.

- Xaritani bosish yoki surish yetkazish nuqtasini o‘zgartiradi. GPS avtomatik
  bir marta so‘raladi; nuqta tasdiqlashsiz backendga saqlanmaydi.
- Kech kelgan GPS javobi qo‘lda tanlangan nuqtani almashtirmaydi.
- Uy / Ishxona / Boshqa tanlovi mavjud `title` maydonidan foydalanadi.
  Boshqa uchun nom ixtiyoriy. Kuryer izohi mavjud `landmark` maydonida saqlanadi
  (255 belgigacha). Backend modeli yoki migration o‘zgarmaydi.
- Edit’da eski manzil komponentlari va `is_default` saqlanadi. Nuqta ko‘chirilsa
  eski ko‘cha/uy ma’lumotlari yangi koordinataga noto‘g‘ri bog‘lanib qolmaydi;
  kuryer izohi saqlanadi.
- Do‘kon savatidan yangi va tahrirlash ekranlari
  `GET /api/user/delivery/coverage/?store_type=<type>` orqali shu savat do‘konining
  radiuslarini oladi. Xatoda umumiy maksimumga yoki 8 km defaultga qaytilmaydi.
  Profil orqali umumiy manzil yaratish esa `?scope=address` orqali barcha faol,
  ko‘rinadigan do‘konlar orasidagi eng katta radiusli filialni oladi; savat bo‘sh
  bo‘lsa ham ishlaydi. Do‘konlar soni yoki radius hardcode qilinmaydi.
  Doira eng katta radiusga ega filialning haqiqiy koordinatasidan chiziladi.
  Teng radiuslarda filial ID bo‘yicha deterministik tanlov ishlatiladi.
- Radius ma’lum bo‘lganda kamera markazi va tanlanadigan nuqta yashil doiradan chiqmaydi. GPS
  tashqarida bo‘lsa, u boshqa joyga yashirincha ko‘chirilmaydi;
  tasdiqlash bloklanadi. Eski tashqi manzil ham yangi ichki nuqta tanlanmaguncha
  qayta saqlanmaydi. Coverage yo‘q/xato/yuklanayotgan bo‘lsa tasdiqlash o‘chiq.
- Saqlash oldidan coverage qayta olinadi: admin radiusni kamaytirgan bo‘lsa
  eskirgan limit bilan manzil yuborilmaydi. Koordinata yaxlitlanishi uchun qo‘lda
  chegaraga olib borilgan nuqta doiradan 10 sm ichkarida ushlanadi.
- Bu umumiy manzil tanlash chegarasi, barcha do‘konlardan yetkazish kafolati emas.
  Checkout’dagi `store_type` coverage API va har do‘konning radius/tarif/order
  tekshiruvi o‘zgarmaydi. Backend address CRUD’dagi eski koordinatalar o‘chirilmaydi.
- Tile xatosida retry bor. Mapbox logosi va attribution amali xaritada qoladi.

## Nuqtani tanlash

Manzil faqat xaritani bosish/surish yoki bir martalik GPS orqali tanlanadi.
Qidiruv maydoni, uning client servisi va geocoding so‘rovlari olib tashlangan.
Manzil yonidagi tahrirlash amali mavjud nuqtani xaritada yaqinlashtiradi.
Mapbox faqat avvalgidek xarita tile’lari uchun ishlaydi, permanent geocoding
endi bu ekran uchun talab qilinmaydi. Checkout mini-xaritasining rangi o‘zgarmaydi.

## Test qamrovi

`address_form_screen_test.dart`: create/edit, izoh, eski manzilni saqlash/tozalash,
bir martalik GPS va kechikkan GPS, barcha location xatolari, qidiruv yo‘qligi,
yashil doira, haqiqiy coverage, xaritani surish, help/system/AppBar back, qaytuvchi
address ID, klaviatura, uch til, 320/430 px, landscape va 1×/2× shrift.

Telefon GPS’i va production Mapbox tile’lari widget
testlar bilan tasdiqlanmaydi; ular qurilmada smoke-test qilinishi kerak.

Qidiruv olib tashlanishidan oldingi 2026-10-17 tekshiruvi: 60 ta manzil/search/model testi va 57 ta checkout, GPS,
back va real router testi o‘tdi. `flutter analyze --no-pub` xatosiz.
Mapbox tokeni bilan production Web build ham muvaffaqiyatli bajarildi.
To‘liq Flutter test yurishi muhit sessiyasi uzilishi bilan yakunlanmay qoldi;
uning to‘liq muvaffaqiyati da’vo qilinmaydi. Telefonga yangi APK o‘rnatilmadi.

### Umumiy eng katta radius cheklovi

Qo‘shimcha tekshiruv: 90 ta tegishli Flutter testi va 13 ta backend delivery
testi PostgreSQL 16 scratch bazasida o‘tdi; analyzer xatosiz va Mapbox production
Web build muvaffaqiyatli. Boshqa foydalanuvchi/production bazasi o‘zgartirilmadi.
Yangi dependency yoki migration yo‘q. Chiqarish tartibi: avval backend’dagi
`scope=address` qo‘llovi, keyin app. Eski backend 400/404 qaytarsa, app mavjud
public do‘konlar ro‘yxati va filiallar API’sidan haqiqiy radiuslarni olib,
eng kattasini tanlaydi. Hech bir do‘kon so‘rovi xatosi kichikroq, qisman limitga
almashtirilmaydi. Chet hostdagi pagination havolalari qabul qilinmaydi.

Admin panelidagi mavjud filial radiusi sozlamasi ishlatiladi; yangi qiymatlar
o‘ylab topilmaydi yoki mavjud radiuslar avtomatik kattalashtirilmaydi.

### Yashil doira va qidiruvsiz ekran

Manzil qo‘shish/tahrirlashdagi radius chegarasi yashil rangga o‘zgartirildi.
Qidiruv UI’i, geocoding servisi va unga tegishli testlar olib tashlandi. Mavjud
manzilni tahrirlash tugmasi qidiruv emas, xaritadagi nuqtani yaqinlashtiradi.
87 ta tegishli Flutter testi o‘tdi: yashil chegara, qidiruv yo‘qligi va tahrirlash
amali ham tekshiriladi. Backend radius siyosati va checkout mini-xaritasi o‘zgarmadi.

### Yuklanish va pointer regressiyasi

Coverage provider’da avtomatik takrorlash o‘chirilgan: xato uzoq vaqt loading
sifatida qolmaydi. Umumiy kutish chegarasi 20 soniya, qayta urinish foydalanuvchi
tugmasi orqali bajariladi. Loading/xatoda xaritadan draft nuqta tanlash mumkin,
ammo radius aniqlanmaguncha tasdiqlash o‘chiq. Radius kech kelsa ham kamera butun
yashil doirani sig‘diradi; draft nuqta o‘zgarmaydi. Chiziq 2px, ichki tint 12%.
Bu tuzatish backend deploy’isiz ham avvaldan mavjud public filial API’lari
`delivery_radius_km` qaytargan serverlar bilan ishlaydi; sun’iy 8km fallback yo‘q.

Tekshiruv: 82 ta tegishli Flutter testi, analyzer va Mapbox production Web build
muvaffaqiyatli. Testlar yangi API, 400/404 eski API fallback’i, pagination,
qisman/chetdagi host xatosi, 20 soniya timeout va avtomatik retry yo‘qligi,
kech kelgan radiusda butun doira ko‘rinishi hamda loading/xatoda pointer
siljishini qamraydi. Production public filial API’sida haqiqiy 2km/8km qiymatlar
read-only tekshirildi. Serverga yozish, deploy va telefonga install qilinmadi.
