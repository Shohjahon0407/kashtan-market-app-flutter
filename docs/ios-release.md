# Besh Kashtan (mijoz ilovasi): iPhone va App Store relizi

Kod va iOS sozlamalari tayyor. Quyidagi qadamlar Mac'da (Xcode 16 yoki undan yangi, Flutter `>=3.44`) bajariladi.

- Bundle ID: `uz.beshkashtan.customer`
- Faqat iPhone, minimal iOS 15.0

## 0. Loyihani Mac'ga ko'chirish
Zip qilishdan oldin keraksiz katta papkalarni chiqarib tashlang:

```
zip -r app_new_version.zip app_new_version \
  -x "*/build/*" "*/.dart_tool/*" "*/ios/Pods/*" "*/android/.gradle/*"
```

Mac'da:

```
cd app_new_version
flutter clean && flutter pub get
```

## 1. Firebase: iOS ilova (push uchun shart)
Fayl qo'shilmasa ham ilova ishlaydi, lekin push bildirishnomalar kelmaydi.

1. https://console.firebase.google.com → `kashtan-5feea` loyihasi → **Add app → iOS**.
2. Bundle ID: `uz.beshkashtan.customer`, nickname: `Besh Kashtan iOS`.
3. `GoogleService-Info.plist` ni yuklab oling.
4. `open ios/Runner.xcworkspace` → faylni Xcode'dagi chap paneldagi **Runner** papkasiga sudrab tashlang.
   - **Copy items if needed** ✅
   - Target: **Runner** ✅
5. "Add Firebase SDK" va "initialization code" qadamlarini o'tkazib yuboring: Flutter plaginlari buni o'zi qiladi.

## 2. Apple Developer: push kaliti
1. https://developer.apple.com/account → **Certificates, IDs & Profiles → Keys → +**.
2. Nom: `Besh Kashtan APNs`. **Apple Push Notifications service (APNs)** ✅ → yarating va `.p8` faylni yuklab oling (faqat bir marta beriladi, saqlab qo'ying).
3. Key ID va Team ID ni yozib oling.
4. Firebase → Project settings → **Cloud Messaging** → iOS ilova → **APNs Authentication Key** → `.p8`, Key ID va Team ID ni kiriting.
5. **Identifiers** → `uz.beshkashtan.customer` → **Push Notifications** ✅. Identifier yo'q bo'lsa, Xcode uni avtomatik yaratadi (3-qadam).

## 3. Xcode: imzo va imkoniyatlar
`ios/Runner.xcworkspace` → Runner target → **Signing & Capabilities**:

- **Automatically manage signing** ✅, Team — sizning akkauntingiz.
- **+ Capability → Push Notifications**. Entitlements fayli allaqachon bor (`aps-environment`).
- **+ Capability → Background Modes → Remote notifications** ✅. `Info.plist` da bor, shu yerda belgilanganini tekshiring.

## 4. Haqiqiy iPhone'da sinash
iPhone'ni kabel bilan ulang → Settings → Privacy & Security → **Developer Mode** ni yoqing.

```
flutter run --release
```

Tekshiriladigan narsalar:

- [ ] Ilova ochiladi, logo va launch ekran ko'rinadi.
- [ ] Telefon va SMS kod bilan kirish ishlaydi.
- [ ] Joylashuv ruxsati so'raladi va xaritada manzil tanlanadi.
- [ ] Bildirishnoma ruxsati so'raladi. Buyurtma berib, kassada qabul qilinganda push keladi (ilova yopiq paytda ham).
- [ ] Payme to'lovi Safari yoki Payme ilovasida ochiladi va ilovaga qaytish ishlaydi.
- [ ] Orqaga qaytish: chap chetdan o'ngga surish va AppBar'dagi orqaga tugmasi.
- [ ] Profil → Akkauntni o'chirish oqimi ochiladi (Apple buni albatta tekshiradi).
- [ ] Yordam: rasm, kamera va ovozli xabar ruxsatlari so'raladi.

## 5. App Store Connect: ilova yaratish
https://appstoreconnect.apple.com → **Apps → + → New App**:

- Platform: iOS, Name: `Besh Kashtan`, Primary language: Uzbek (yoki Russian).
- Bundle ID: `uz.beshkashtan.customer`, SKU: `beshkashtan-customer`.

## 6. Yig'ish va yuklash
1. `pubspec.yaml` dagi `version:` ni tekshiring. Har yangi yuklashda `+` dan keyingi build raqami oshishi shart.
2. Yig'ish:

   ```
   flutter build ipa --release --obfuscate --split-debug-info=build/ios-symbols
   ```

3. Natija: `build/ios/ipa/*.ipa`.
4. Yuklash: Mac App Store'dan **Transporter** → ipa'ni sudrab tashlang → Deliver. Muqobil yo'l: Xcode → Window → Organizer → Distribute App.
5. 10–30 daqiqadan so'ng build App Store Connect → TestFlight'da paydo bo'ladi. Avval TestFlight orqali o'zingiz sinab ko'ring.

## 7. App Store Connect: tekshiruvga topshirish
**App Privacy (maxfiylik yorliqlari).** `ios/Runner/PrivacyInfo.xcprivacy` bilan mos javob bering:

| Ma'lumot | Shaxsga bog'langan | Kuzatuv (tracking) | Maqsad |
|---|---|---|---|
| Telefon raqami, ism | Ha | Yo'q | App Functionality |
| Yetkazish manzili, aniq joylashuv | Ha | Yo'q | App Functionality |
| Xaridlar tarixi | Ha | Yo'q | App Functionality |
| Mijoz yordami, rasm/video, audio, sharhlar | Ha | Yo'q | App Functionality |
| Qurilma ID (push tokeni) | Ha | Yo'q | App Functionality |
| Crash ma'lumotlari | Yo'q | Yo'q | App Functionality |

Umumiy savolga "Do you or your third-party partners use data for tracking?" → **No**.

**Majburiy URL'lar:**
- Privacy Policy URL: `https://api.beshkashtan.uz/privacy/`
- Support URL: sayt yoki Telegram bot havolasi.

**Export Compliance:** savol berilmaydi, chunki `Info.plist` da `ITSAppUsesNonExemptEncryption = NO` bor.

**App Review Information → Sign-in required ✅.** Apple sharhlovchisi SMS ololmaydi, unga test raqam bering:
- **Login:** backend `.env` dagi `TEST_OTP_ACCOUNTS` ga yozilgan raqam. Play Store uchun ishlatilgani ham bo'ladi.
- **Kod:** o'sha raqamga belgilangan doimiy kod.
- **Demo buyurtma:** sharhlovchi akkauntida yetkazilgan buyurtma bo'lishi uchun serverda bir marta `python manage.py seed_reviewer_demo` ni ishga tushiring.
- **Notes**ga yozing (inglizcha):
  > Phone + SMS login. Use the demo number above; the code is fixed for review. Payments for physical food/goods are handled by Payme in Safari (no digital goods). Account deletion: Profile → Delete account.

**Skrinshotlar:** iPhone 6.9" (1320×2868), simulyatorda iPhone 16 Pro Max bilan olinadi, 3–10 ta. iPad skrinshoti kerak emas, chunki ilova faqat iPhone uchun.

**Yosh reytingi:** 4+. Foydalanuvchi sharhlari va moderatsiya bor, so'rovnomada "User Generated Content" bandini belgilang.

## 8. Tez-tez uchraydigan rad etishlar
| Sabab | Holat |
|---|---|
| 2.1: kirish ishlamadi | Test raqam va kod ishlashini topshirishdan oldin tekshiring |
| 5.1.1(v): akkauntni o'chirish | Bor: Profil → Akkauntni o'chirish |
| 5.1.1: ruxsat matni noaniq | Joylashuv, kamera, mikrofon va foto matnlari `Info.plist` da o'zbekcha va aniq |
| 3.1.1: to'lov | Jismoniy mahsulot, Payme tashqarida ochiladi. IAP talab qilinmaydi |
| 4.0: iPad'da buzilgan dizayn | Ilova faqat iPhone (`TARGETED_DEVICE_FAMILY = 1`) |
| ATT matni bor-u, so'ralmaydi | `NSUserTrackingUsageDescription` olib tashlangan |

## Xato chiqsa
`flutter build ipa` yoki Xcode xatosining to'liq matnini (yoki skrinshotini) yuboring.

Mumkin bo'lgan xatolar:
- **Swift Package / CocoaPods.** `ios/Podfile` tayyor (`platform :ios, '15.0'`). Pod xatosida:

  ```
  cd ios && pod repo update && pod install
  ```

- **"Signing requires a development team".** 3-qadamdagi Team tanlanmagan.
- **"Module 'firebase_core' not found".** `flutter clean && flutter pub get` qiling, so'ng Xcode'ni qayta oching.
