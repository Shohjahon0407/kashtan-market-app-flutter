# Xozmak: kategoriya mahsulotlari reklamasi

Faqat `household` kategoriya mahsulotlari sahifasida: banner → qidiruv →
tavsiyalar → grid. Banner bo‘lmasa bo‘sh joy ajratilmaydi. Boshqa do‘konlar
va kategoriya landing kartalari o‘zgarmaydi.

## Backend va admin

1. Backendni chiqarib `python manage.py migrate` bajaring. Yangi additive
   migration: `promotions.0011_category_product_banner`. U real reklama
   yozuvlarini yaratmaydi, mavjud mahsulot/narx/orderlarni o‘zgartirmaydi.
2. Admin panelni yangilang. Marketing menyusida “Kategoriya mahsulotlari
   reklamasi” orqali kategoriya, shu kategoriyadagi mahsulot va matn tanlanadi.
3. Rasm ixtiyoriy: yuklangan banner rasmi → mahsulot thumbnail → original.
   Rasmsiz reklamani faol qilish serverda rad etiladi. “Mahsulot rasmiga
   qaytish” maxsus rasmni tozalaydi. Narx mahsulotning public narxidan olinadi.
4. App `1.1.6+9` yoki keyingi buildni tarqating. Play upload’dan oldin Console’da
   versionCode `9` ishlatilmaganini tekshiring. Avtomatik publish yo‘q.

API:

- Admin CRUD `/api/admin/category-product-banners/`: mavjud admin auth;
  `category`, `q`, `is_active`, `page` filtrlari. JSON yoki multipart.
  `remove_image=true` custom rasmni tozalaydi. Matnlar `*_uz` va `*_ru`.
- Public `/api/user/catalog/categories/{id}/banners/`: login shart emas,
  `lang=uz|ru`, 20 tadan `{count,next,previous,results}`.
- Tavsiyalar `/api/user/recommendations/for-you/` uchun additive `category`
  va `images_only=true`. Filtrlar feed chegarasidan oldin qo‘llanadi.

Reklamalar soni cheklanmagan; carousel keyingi API sahifalarini yuklaydi.
Yashirilgan/faol bo‘lmagan store, kategoriya yoki mahsulot reklamada chiqmaydi;
mahsulot ko‘chirilsa yoki o‘chirilsa ham chiqmaydi. Kontent o‘zgarishlari public
cache’ni yangilaydi; tavsiya cache’i kategoriya va rasm filtriga ajratilgan.

## App oqimi

Bannerlar 5 soniyada almashadi; offscreen/background/boshqa route va reduced
motion’da auto-slide to‘xtaydi. Qo‘lda swipe va keyingi/oldingi amallari bor.
Banner/detaildan back eski carousel va katalog scrollini saqlaydi.

Qidiruv 350 ms’dan keyin avval joriy kategoriyaga yuboriladi. Faqat nol natijali
muvaffaqiyatli javobdan keyin Xozmak bo‘yicha fallback qilinadi. Tarmoq xatosida
fallback yo‘q. Boshqa kategoriya natijasi bosilsa o‘sha kategoriya `?q=...` bilan
ochiladi; keyingi karta bosilishi mahsulot detailiga olib boradi. Back avvalgi
qidiruvni qaytaradi. Qidiruvda rasmsizlar ham ko‘rinadi.

Banner/tavsiya so‘rovlari katalogni bloklamaydi. Birinchi banner sahifasi
Android’da locale/account ajratilgan cache’ga yoziladi; offline’da bir kungacha
fallback bo‘lishi mumkin. 403/404 yoki buzilgan javobda eski banner tiklanmaydi.
Banner xatosi checkout yoki manzil oqimiga ta’sir qilmaydi.

Bu funksiya ichki mahsulot promosi; tashqi reklama SDK’i, yangi reklama narxi,
soxta chegirma, impression billing yoki avtomatik demo kampaniya qo‘shilmagan.
