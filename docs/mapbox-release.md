# Mapbox xaritalari — 1.1.5+8

Public `pk.…` token build-time `MAPBOX_ACCESS_TOKEN` bilan beriladi. Tokenni
README yoki release loglarida tarqatish o‘rniga keyingi buildlar uchun CI
konfiguratsiyasiga ko‘chirish tavsiya etiladi. Private `sk.…` token klientga
kiritilmaydi. Tokenning to‘g‘ri ishlashi real tile so‘rovi bilan tekshirildi.

## Tasvir va tezlik

- Mapbox Streets v12’ning asl ranglari, 512px WebP tile’lar.
- `tileDimension=512`, `zoomOffset=-1`: 256px OSM projection’dan farqi hisobga
  olingan, marker koordinatalari o‘zgarmaydi.
- Retina ekranda server `{r}` orqali `@2x` beradi. Client to‘rtta qo‘shimcha
  tile yuklab retina’ni sun’iy yaratmaydi.
- `flutter_map` mavjud HTTP-aware disk cache’ini Android’da ishlatadi;
  Web’da brauzer cache’i ishlaydi. Offline xarita kafolatlanmaydi.
- Radiusning 128 nuqtasi faqat filial koordinatasi/radiusi o‘zgarganda hisoblanadi.
- Xarita yuklanmasa checkout manzil oqimi ishlashda davom etadi; retry
  tile layer’ni qayta yaratadi, savat yoki kamerani reset qilmaydi.
- Mapbox logosi, © Mapbox, © OpenStreetMap va Improve this map havolalari saqlanadi.

## Lokatsiya

Yangi yuqori aniqlikdagi GPS uchun 15 soniya kutish chegarasi mavjud. GPS
markeri atrofida telefon qaytargan accuracy metrlik doira chiqadi: bu
yetkazish radiusi emas. Past aniqlik alohida xabar bilan belgilanadi; bir
daqiqadan eski nuqta ko‘rsatilmaydi. Yetkazish manzili avtomatik tanlanmaydi.
Telefon/GPS/tarmoq sababli har doim mukammal aniqlik kafolatlanmaydi.

## Manbalar

- [Mapbox Static Tiles API](https://docs.mapbox.com/api/maps/static-tiles/)
- [Mapbox attribution](https://docs.mapbox.com/help/dive-deeper/attribution/)
- [flutter_map caching](https://docs.fleaflet.dev/layers/tile-layer/caching)
- Logo: Mapbox’ning rasmiy `mapbox/mcp-server` repository’sidagi
  `assets/mapbox-logo-black.svg`; boshqa do‘kon/logotiplarga aloqasi yo‘q.
