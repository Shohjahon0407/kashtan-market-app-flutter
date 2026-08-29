# Besh Kashtan Customer

Flutter asosidagi marketplace mijoz ilovasi. Default User API:
`https://api.beshkashtan.uz/api/user`.

## Ishga tushirish

Oddiy production API bilan Chrome:

```bash
flutter run -d chrome
```

Lokal backend uchun:

```bash
flutter run -d chrome \
  --dart-define=BACKEND_ORIGIN=http://127.0.0.1:8000 \
  --dart-define=APP_FLAVOR=dev
```

Backend CORS sozlamasi Flutter tanlagan `http://localhost:<port>` yoki
`http://127.0.0.1:<port>` originiga ruxsat berishi kerak. Web Push, mikrofon va
geolocation productionda HTTPS, developmentda esa `localhost` talab qiladi.

## Mapbox tracking

Jonli kuryer xaritasida Mapbox tile va Directions route ishlashi uchun public
tokenni faqat build-time orqali bering:

```bash
flutter run -d chrome \
  --dart-define=MAPBOX_ACCESS_TOKEN=pk.example
```

Token Mapbox dashboardida Web domain, Android package va iOS bundle ID bilan
cheklanishi kerak. Token bo‘lmasa ilova buzilmaydi: OpenStreetMap tile,
to‘g‘ri-chiziq route va server ETA fallback ishlaydi.

## Firebase push

Firebase konfiguratsiyasi bo‘lmasa ham ilova build bo‘ladi; order WebSocket,
REST reconciliation va notification history ishlaydi, ammo background system
push o‘chiq bo‘ladi. Hech qanday service-account yoki private APNs kalitini bu
repositoryga qo‘ymang.

### Android

1. `kashtan-5feea` Firebase Android appidagi package ID
   `uz.beshkashtan.customer` ekanini tekshiring.
2. `google-services.json`ni `android/app/google-services.json`ga CI secretdan
   joylang. Gradle plagini fayl mavjud bo‘lsagina avtomatik qo‘llanadi.
3. Firebase Console’da Cloud Messaging yoqilganini tekshiring.

### iOS

1. `GoogleService-Info.plist`ni `ios/Runner/`ga qo‘ying va Xcode Runner targetga
   biriktiring.
2. Runner’da Push Notifications capability va Background Modes → Remote
   notifications yoqilgan bo‘lishi kerak. Repositorydagi
   `Runner.entitlements` `APS_ENVIRONMENT` build settingini ishlatadi: Debug
   `development`, Profile/Release `production`. Release signing uchun baribir
   production Push Notifications provisioning profile talab qilinadi.
3. APNs `.p8` keyini Firebase Console’ga yuklang. Keyning o‘zi repo yoki
   `--dart-define`ga kiritilmaydi.

### Web / Chrome

Flutter Firebase app config va VAPID public key build-time orqali beriladi:

```bash
flutter build web --no-pub \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=kashtan-5feea \
  --dart-define=FIREBASE_AUTH_DOMAIN=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=... \
  --dart-define=FIREBASE_WEB_VAPID_KEY=...
```

Deploy pipeline `web/firebase-config.js`dagi `null` qiymatni ayni Firebase Web
App public config obyektiga almashtirishi kerak. `firebase-messaging-sw.js`
default Firebase Messaging service-worker yo‘lida turadi va data-only push/tap
deep-linklarini boshqaradi. `firebase-config.js` `null` qolsa Web Push xavfsiz
o‘chadi. Chrome’da notification permission user tomonidan berilishi shart;
brauzer yopiq va permission bloklangan bo‘lsa OS banner kafolatlanmaydi, ammo
event notification history’da REST sync orqali tiklanadi.

## Tekshiruv va build

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
flutter build apk --debug --no-pub
```

iOS signing/build faqat macOS + Xcode, haqiqiy provisioning profile va Firebase
konfiguratsiyasi bilan tekshiriladi.
