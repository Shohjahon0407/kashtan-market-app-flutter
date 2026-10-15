// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appUpdateTitle => 'Yangilanish mavjud';

  @override
  String appUpdateBody(String version) {
    return 'Ilovaning $version versiyasi chiqdi. Yangi imkoniyatlar va yaxshilanishlardan foydalanish uchun yangilang.';
  }

  @override
  String get appUpdateDownload => 'Yuklab olish';

  @override
  String get appUpdateLater => 'Keyinroq';

  @override
  String get appUpdateOpenFailed =>
      'Google Play’ni ochib bo‘lmadi. Qayta urinib ko‘ring yoki keyinroq yangilang.';

  @override
  String get checkoutAddressActionHint =>
      'Xaritadan joy belgilang yoki saqlangan manzilni tanlang';

  @override
  String get checkoutReceiptTitle => 'Mahsulotlar cheki';

  @override
  String checkoutCartCount(int count) {
    return '$count ta mahsulot';
  }

  @override
  String get checkoutOptional => 'Ixtiyoriy';

  @override
  String get checkoutPaymentHint => 'Qulay usulni tanlang';

  @override
  String get checkoutPayOnline => 'Onlayn to‘lov';

  @override
  String get checkoutPayOnReceipt => 'Qabul qilganda';

  @override
  String get checkoutPayOnPickup => 'Olib ketganda';

  @override
  String get checkoutNotePlaceholder =>
      'Masalan, eshik kodi yoki yetkazish bo‘yicha izoh...';

  @override
  String get checkoutNoteNoBell => 'Eshik qo‘ng‘irog‘ini chalmang';

  @override
  String get checkoutNoteCall => 'Yetib kelganda qo‘ng‘iroq qiling';

  @override
  String get checkoutNoteNoOnion => 'Piyozsiz bo‘lsin';

  @override
  String get checkoutCostBreakdown => 'Hisob-kitob';

  @override
  String get checkoutGrandTotal => 'Jami to‘lov';

  @override
  String get checkoutSelectedAddress => 'Tanlangan';

  @override
  String get checkoutReviewHint =>
      'Tasdiqlashdan oldin manzil va buyurtmani tekshiring';

  @override
  String get checkoutHelpTitle => 'Buyurtma haqida';

  @override
  String get checkoutHelpBody =>
      'Yetkazish manzilini va to‘lov usulini tanlang. Yetkazish hududi xaritada ko‘rsatilgan. Buyurtma faqat manzil va yetkazish narxi tekshirilgach tasdiqlanadi. Olib ketishda mos filialni tanlang.';

  @override
  String get catalogImagelessPull =>
      'Rasmsiz mahsulotlarni ko‘rish uchun yana yuqoriga torting';

  @override
  String get catalogImagelessRelease => 'Qo‘yib yuboring';

  @override
  String get catalogImagelessShow => 'Rasmsizlarni ko‘rsatish';

  @override
  String get addressLocationUnavailable =>
      'Lokatsiyani aniqlab bo‘lmadi. GPS’ni tekshiring yoki xaritada nuqtani qo‘lda tanlang.';

  @override
  String get appName => 'Besh Kashtan';

  @override
  String get commonRetry => 'Qayta urinish';

  @override
  String get commonFieldRequired => 'Bu maydonni to\'ldiring';

  @override
  String get commonCancel => 'Bekor qilish';

  @override
  String get commonSave => 'Saqlash';

  @override
  String get commonContinue => 'Davom etish';

  @override
  String get commonClose => 'Yopish';

  @override
  String get commonSearch => 'Qidirish';

  @override
  String get commonAll => 'Barchasi';

  @override
  String get commonLoading => 'Yuklanmoqda...';

  @override
  String get commonEmpty => 'Hozircha bo\'sh';

  @override
  String get commonYes => 'Ha';

  @override
  String get commonNo => 'Yo\'q';

  @override
  String get offlineBanner => 'Offline rejim';

  @override
  String get connectionServerUnavailable => 'Serverga ulanib bo‘lmadi';

  @override
  String get offlineStaleData => 'eski ma\'lumotlar';

  @override
  String get errorNetwork => 'Internet aloqasi yo\'q. Ulanishni tekshiring.';

  @override
  String get errorServer =>
      'Serverda xatolik yuz berdi. Birozdan so\'ng urinib ko\'ring.';

  @override
  String get errorUnknown => 'Kutilmagan xatolik yuz berdi.';

  @override
  String get errorSessionExpired => 'Sessiya muddati tugadi. Qaytadan kiring.';

  @override
  String get errorThrottled => 'Juda ko\'p urinish. Biroz kuting.';

  @override
  String get errorNotFound => 'Topilmadi.';

  @override
  String get errorForbidden => 'Bu amalga ruxsat yo\'q.';

  @override
  String get authPhoneTitle => 'Telefon raqamingiz';

  @override
  String get authPhoneSubtitle => 'Kirish uchun raqamingizni kiriting';

  @override
  String get authRequiredTitle => 'Avval ilovaga kiring';

  @override
  String get authRequiredSubtitle =>
      'Davom etish uchun telefon raqamingizni kiriting';

  @override
  String get authPhoneHint => '90 123 45 67';

  @override
  String get authSendCode => 'Kod olish';

  @override
  String get authOtpTitle => 'Tasdiqlash kodi';

  @override
  String authOtpSubtitle(String phone) {
    return '$phone raqamiga yuborilgan 6 xonali kodni kiriting';
  }

  @override
  String get authOtpResend => 'Kodni qayta yuborish';

  @override
  String authOtpResendIn(int seconds) {
    return 'Qayta yuborish $seconds soniyadan keyin';
  }

  @override
  String authOtpExpiresIn(int seconds) {
    return 'Kod $seconds soniyadan keyin eskiradi';
  }

  @override
  String get authConsentPrefix => 'Davom etish orqali siz ';

  @override
  String get authConsentTerms => 'Foydalanish shartlari';

  @override
  String get authConsentAnd => ' va ';

  @override
  String get authConsentPrivacy => 'Maxfiylik siyosati';

  @override
  String get authConsentSuffix => 'ga rozilik bildirasiz.';

  @override
  String get authLogout => 'Chiqish';

  @override
  String get authErrorOtpCooldown => 'Kodni qayta yuborish uchun biroz kuting.';

  @override
  String get authErrorOtpHourLimit =>
      'Bir soatda 5 martadan ko\'p kod so\'rab bo\'lmaydi.';

  @override
  String get authErrorOtpInvalid => 'Kod noto\'g\'ri. Qaytadan tekshiring.';

  @override
  String get authErrorOtpExpired => 'Kod muddati tugadi. Yangi kod oling.';

  @override
  String get authErrorOtpAttempts => 'Urinishlar tugadi. Yangi kod oling.';

  @override
  String get authErrorSmsFailed =>
      'SMS yuborilmadi. Birozdan so\'ng urinib ko\'ring.';

  @override
  String get authErrorInvalidPhone => 'Telefon raqam noto\'g\'ri.';

  @override
  String get onboardingNameTitle => 'Ismingiz';

  @override
  String get onboardingNameSubtitle => 'Buyurtmalarda ko\'rsatiladi';

  @override
  String get onboardingLocationTitle => 'Manzilingiz';

  @override
  String get onboardingLocationSubtitle =>
      'Yetkazib berish narxini hisoblash uchun kerak';

  @override
  String get storeGrocery => 'Oziq-ovqat';

  @override
  String get storeHousehold => 'Uy jihozlari';

  @override
  String get storeRestaurant => 'Restoran';

  @override
  String get storeShashlik => 'Shashlik';

  @override
  String get storeMeat => 'Go\'sht mahsulotlari';

  @override
  String get meatProductLamb => 'Qo‘y go‘shti';

  @override
  String get meatProductBeef => 'Mol go‘shti';

  @override
  String get meatProductHorse => 'Ot go‘shti';

  @override
  String get meatProductQazi => 'Qazi';

  @override
  String get meatProductBeefLiver => 'Mol jigar';

  @override
  String get meatProductLambLiver => 'Qo‘y jigar';

  @override
  String get shashlikSectionKebabs => 'Shashliklar';

  @override
  String get shashlikSectionCharcoal => 'Ko‘mir';

  @override
  String get shashlikSectionOther => 'Boshqa';

  @override
  String get shashlikFamilyBeefJazz => 'Mol jazz';

  @override
  String get shashlikFamilyLambJazz => 'Qo‘y jazz';

  @override
  String get shashlikFamilyChicken => 'Tovuq';

  @override
  String get shashlikFamilyLiver => 'Jigar';

  @override
  String get shashlikFamilyMince => 'Qiyma';

  @override
  String get shashlikOptionSkewered => 'Zixlangan';

  @override
  String get shashlikOptionByKilo => 'Kilolik';

  @override
  String get shashlikOptionMince => 'Qiyma';

  @override
  String get shashlikOptionBreadMince => 'Non qiyma';

  @override
  String get shashlikOptionKiloMince => 'Kilolik qiyma';

  @override
  String get shashlikChooseProduct => 'Mahsulot turini va miqdorini tanlang';

  @override
  String get shashlikQuantity => 'Miqdor';

  @override
  String get shashlikAddToCart => 'Savatga qo‘shish';

  @override
  String shashlikPriceFrom(String price) {
    return '$price dan';
  }

  @override
  String shashlikKilogramPrice(String price) {
    return 'Kilogrammi $price';
  }

  @override
  String shashlikPieceQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dona',
      one: '1 dona',
    );
    return '$_temp0';
  }

  @override
  String shashlikKilogramQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kilogram',
      one: '1 kilogram',
    );
    return '$_temp0';
  }

  @override
  String shashlikInCart(int count) {
    return 'Savatda: $count ta';
  }

  @override
  String get cartTitle => 'Savat';

  @override
  String get cartEmpty => 'Savat bo\'sh';

  @override
  String get cartEmptyStore => 'savat bo\'sh';

  @override
  String get cartMainSubtitle =>
      'Har bir do\'kon alohida yetkazadi — buyurtmalar ham alohida beriladi';

  @override
  String cartItemsCount(int count) {
    return '$count ta';
  }

  @override
  String get cartCheckout => 'Buyurtma berish';

  @override
  String get cartTotal => 'Jami';

  @override
  String get cartSubtotal => 'Mahsulotlar';

  @override
  String get cartDeliveryFee => 'Yetkazib berish';

  @override
  String get ordersTitle => 'Buyurtmalar';

  @override
  String get ordersEmpty => 'Hozircha buyurtma yo\'q';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profilePrivacyPolicy => 'Maxfiylik siyosati';

  @override
  String profileAppVersion(String version) {
    return 'Versiya $version';
  }

  @override
  String get profileDeleteAccount => 'Hisobni o\'chirish';

  @override
  String get profileDeleteAccountTitle => 'Hisobni butunlay o\'chirish';

  @override
  String get profileDeleteAccountWarning =>
      'Ismingiz, telefon raqamingiz, manzillaringiz, savatingiz, sevimlilaringiz va sharhlaringiz o\'chiriladi. Bu amalni qaytarib bo\'lmaydi. Tasdiqlash uchun telefoningizga SMS kod yuboramiz.';

  @override
  String get profileDeleteAccountSendCode => 'Kod yuborish';

  @override
  String get profileDeleteAccountCodeHint =>
      'Telefoningizga yuborilgan kodni kiriting. Kod tasdiqlangach hisob darhol o\'chiriladi.';

  @override
  String get profileDeleteAccountConfirm => 'Butunlay o\'chirish';

  @override
  String get profileLanguage => 'Til';

  @override
  String get profileAddresses => 'Manzillar';

  @override
  String get profileNotifications => 'Bildirishnomalar';

  @override
  String get profileSupport => 'Yordam';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageUzCyrl => 'Ўзбекча';

  @override
  String get languageRu => 'Русский';

  @override
  String get devPlaygroundTitle => 'API tekshiruvi';

  @override
  String get devPlaygroundSubtitle => 'GET /home/ javobi va til almashtirish';

  @override
  String get devFetch => 'So\'rov yuborish';

  @override
  String get devApiLang => 'Serverga yuborilgan lang';

  @override
  String get devScript => 'Yozuv';

  @override
  String get devResponseSize => 'Javob hajmi';

  @override
  String devItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count element',
      one: '1 element',
      zero: 'Element yo\'\'q',
    );
    return '$_temp0';
  }

  @override
  String errorThrottledSeconds(int seconds) {
    return 'Juda ko\'p urinish. $seconds soniyadan keyin urinib ko\'ring.';
  }

  @override
  String get authChangeNumber => 'Raqamni o\'zgartirish';

  @override
  String get authOtpHint => 'SMS\'dagi 6 xonali kod';

  @override
  String get authOtpExpired => 'Kod muddati tugadi';

  @override
  String get authPhoneInvalidOperator => 'Bunday operator kodi mavjud emas.';

  @override
  String get homeGreeting => 'Xush kelibsiz!';

  @override
  String get homePlaceholder => 'Bosh sahifa keyingi bosqichda quriladi.';

  @override
  String get homeDeliverTitle => 'Uyingizga yetkazib beramiz';

  @override
  String get homeAddressNotSelected => 'Manzil tanlanmagan';

  @override
  String get homeStoresTitle => 'Do\'konlar';

  @override
  String get homeRequestText => 'Matn';

  @override
  String get homeRequestImage => 'Rasm';

  @override
  String get homeRequestVoice => 'Ovoz';

  @override
  String get searchHint => 'Mahsulot qidiring';

  @override
  String get searchStartTyping => 'Qidirish uchun yozishni boshlang';

  @override
  String get searchEmpty => 'Hech narsa topilmadi';

  @override
  String searchResultsCount(int count) {
    return 'Natijalar $count';
  }

  @override
  String get searchMissingTitle => 'Qidirganingiz topilmadi?';

  @override
  String get searchMissingSubtitle =>
      'Yo\'q tovar buyurtmasi bering — matn, rasm yoki ovoz';

  @override
  String get storeComingSoon => 'Bu bo\'lim keyingi bosqichda quriladi';

  @override
  String get profileSheetTitle => 'Profil';

  @override
  String get profileUnnamed => 'Foydalanuvchi';

  @override
  String get profileChooseStore => 'Do\'konni tanlang';

  @override
  String get notificationsComingSoon => 'Bildirishnomalar tez orada';

  @override
  String get commonDelete => 'O\'chirish';

  @override
  String get commonEdit => 'Tahrirlash';

  @override
  String get commonDone => 'Tayyor';

  @override
  String get commonAdd => 'Qo\'shish';

  @override
  String get navHome => 'Asosiy';

  @override
  String get navVideos => 'Videolar';

  @override
  String get navProducts => 'Mahsulotlar';

  @override
  String get navFavorites => 'Sevimlilar';

  @override
  String get navCart => 'Savat';

  @override
  String get navOrders => 'Buyurtmalar';

  @override
  String get catalogTitle => 'Mahsulotlar';

  @override
  String catalogProductVarietyCount(int count) {
    return '$count xil mahsulot';
  }

  @override
  String get catalogAllProducts => 'Barcha mahsulotlar';

  @override
  String get catalogEmpty => 'Bu do\'konda hozircha mahsulot yo\'q';

  @override
  String get catalogSearchHint => 'Shu do\'kondan qidiring';

  @override
  String get catalogCategoryFilter => 'Kategoriyalar';

  @override
  String get householdSectionHomeTools => 'Uy, qurilish va ustachilik';

  @override
  String get householdSectionTechTransport => 'Texnika va transport';

  @override
  String get householdSectionKitchenLiving => 'Oshxona va ro‘zg‘or';

  @override
  String get householdSectionClothingCare => 'Kiyim va shaxsiy parvarish';

  @override
  String get householdSectionKidsHobbyOther => 'Bolalar, hobbi va boshqa';

  @override
  String get restaurantSectionTraditional => 'An’anaviy taomlar';

  @override
  String get restaurantSectionGrillTandoor => 'Grill va tandir';

  @override
  String get restaurantSectionSaladsTable => 'Salatlar va dasturxon';

  @override
  String get restaurantSectionDessertsDrinks => 'Shirinlik va ichimliklar';

  @override
  String get catalogFeatured => 'Tavsiya etamiz';

  @override
  String get catalogDiscounted => 'Chegirmalar';

  @override
  String get catalogPopular => 'Ommabop';

  @override
  String get catalogNew => 'Yangi mahsulotlar';

  @override
  String get favoritesTitle => 'Sevimlilar';

  @override
  String get favoritesEmpty => 'Bu do\'konda sevimli mahsulot yo\'q';

  @override
  String get productUnavailable => 'Hozir xarid qilib bo\'lmaydi';

  @override
  String get productSoldOut => 'Tugadi';

  @override
  String get productSoldOutDetail => 'Bu taom hozircha tugagan.';

  @override
  String get paymePayButton => 'Payme orqali to\'lash';

  @override
  String get paymeCheckPayment => 'To\'lovni tekshirish';

  @override
  String get paymeUnavailable =>
      'Payme orqali to\'lov xizmati vaqtincha mavjud emas';

  @override
  String get paymePaymentPaid => 'To\'lov amalga oshirildi';

  @override
  String get paymePaymentPending =>
      'To\'lov hali tasdiqlanmadi. Birozdan so\'ng qayta tekshiring';

  @override
  String get paymePaymentFailed =>
      'To\'lov amalga oshmadi. Qayta urinib ko\'ring';

  @override
  String get paymePaymentCancelled => 'To\'lov bekor qilindi';

  @override
  String get paymeLinkOpenFailed => 'To\'lov sahifasini ochib bo\'lmadi';

  @override
  String get productInReview => 'Tekshiruvda';

  @override
  String get productInReviewDetail =>
      'Bu mahsulot tekshiruvda. Hozircha sotib olib bo\'lmaydi.';

  @override
  String get reportProductButton => 'Xato mahsulot';

  @override
  String get reportProductConfirmTitle => 'Adminga yuborilsinmi?';

  @override
  String get reportProductConfirmBody =>
      'Rasmi yoki kategoriyasi noto\'g\'ri mahsulot tekshiruvga yuboriladi va tuzatilguncha sotuvdan vaqtincha olinadi.';

  @override
  String get reportProductConfirmAction => 'Yuborish';

  @override
  String get reportProductSuccess => 'Yuborildi. Mahsulot tekshiruvga olindi.';

  @override
  String get productChooseOptions => 'Tanlash';

  @override
  String get productAddToCart => 'Savatga qo\'shish';

  @override
  String get productBuy => 'Xarid qilish';

  @override
  String get productAddShort => 'Savatga';

  @override
  String get productGoToCart => 'Savatga o\'tish';

  @override
  String get productAdded => 'Tovar savatga qo\'shildi';

  @override
  String productImageCount(int count) {
    return '$count ta rasm';
  }

  @override
  String get productDescription => 'Tavsif';

  @override
  String get productRelated => 'O\'xshash mahsulotlar';

  @override
  String get homeForYou => 'Siz uchun';

  @override
  String get homeForYouSubtitle => 'Qiziqishlaringizga qarab tanladik';

  @override
  String catalogSimilarTo(String name) {
    return '«$name»ga o\'xshashlar';
  }

  @override
  String get productVariant => 'Variantni tanlang';

  @override
  String get productAddons => 'Qo\'shimchalar';

  @override
  String get productRequired => 'Majburiy';

  @override
  String get productChooseMin => 'Kamida ko\'rsatilgan miqdorni tanlang';

  @override
  String get productChooseMax => 'Tanlash chegarasiga yetdingiz';

  @override
  String get productNote => 'Izoh';

  @override
  String get productNoteHint => 'Masalan, piyozsiz';

  @override
  String get cartClear => 'Savatni tozalash';

  @override
  String get cartClearConfirm => 'Savatdagi barcha mahsulotlar o\'chirilsinmi?';

  @override
  String get cartEmptyHint => 'Mahsulotlar bo\'limidan savatga qo\'shing';

  @override
  String get cartVariant => 'Variant';

  @override
  String get cartAddons => 'Qo\'shimchalar';

  @override
  String get checkoutTitle => 'Buyurtmani rasmiylashtirish';

  @override
  String get checkoutFulfillment => 'Qabul qilish usuli';

  @override
  String get checkoutDelivery => 'Yetkazib berish';

  @override
  String get checkoutPickup => 'Olib ketish';

  @override
  String get checkoutAddress => 'Yetkazish manzili';

  @override
  String get checkoutSelectAddress => 'Manzilni tanlang';

  @override
  String get checkoutAddAddress => 'Yangi manzil';

  @override
  String get checkoutLocationPromptTitle => 'Yetkazish joylashuvini tanlang';

  @override
  String get checkoutLocationPromptHint =>
      'Har bir buyurtma uchun yangi joylashuv qo\'shing yoki saqlangan manzilni qayta tanlang.';

  @override
  String get checkoutAddNewLocation => 'Yangi joylashuv qo\'shish';

  @override
  String get checkoutSavedLocations => 'Saqlangan manzillar';

  @override
  String get checkoutChooseOrChangeAddress =>
      'Manzilni tanlash yoki o\'zgartirish';

  @override
  String get checkoutBranch => 'Olib ketish filiali';

  @override
  String get checkoutSelectBranch => 'Filialni tanlang';

  @override
  String get checkoutMixedStorePickup =>
      'Savatdagi mahsulotlar turli jismoniy do\'konlardan. Olib ketish mavjud emas; yetkazib berishni tanlang yoki savatni ajrating.';

  @override
  String get checkoutEstimateUnavailable =>
      'Bu manzilga yetkazib berish mavjud emas';

  @override
  String get checkoutDistance => 'Masofa';

  @override
  String get checkoutPaymentMethod => 'To\'lov usuli';

  @override
  String get checkoutPayPayme => 'Payme';

  @override
  String get checkoutPayCashCourier => 'Kuryerga naqd';

  @override
  String get checkoutPayCashStore => 'Do\'konda naqd';

  @override
  String get checkoutNote => 'Buyurtmaga izoh';

  @override
  String get checkoutSubmit => 'Buyurtmani tasdiqlash';

  @override
  String get checkoutEmptyCart => 'Buyurtma berish uchun savat bo\'sh';

  @override
  String get addressTitle => 'Manzil nomi';

  @override
  String get addressTitleOptional => 'Manzil nomi (ixtiyoriy)';

  @override
  String get addressUnnamed => 'Xaritadagi manzil';

  @override
  String get addressDistrict => 'Tuman';

  @override
  String get addressNeighborhood => 'Mahalla';

  @override
  String get addressStreet => 'Ko\'cha';

  @override
  String get addressHouse => 'Uy';

  @override
  String get addressApartment => 'Xonadon';

  @override
  String get addressLandmark => 'Mo\'ljal';

  @override
  String get addressSetDefault => 'Asosiy manzil qilish';

  @override
  String get addressChooseOnMap => 'Xaritada nuqtani tanlang';

  @override
  String get addressCurrentLocation => 'Men turgan joylashuvni aniqlash';

  @override
  String get mapZoomIn => 'Xaritani kattalashtirish';

  @override
  String get mapZoomOut => 'Xaritani kichiklashtirish';

  @override
  String get addressLocationDenied =>
      'Lokatsiya ruxsati berilmadi. Nuqtani xaritada qo\'lda tanlang.';

  @override
  String get addressLocationRequired => 'Xaritada lokatsiyani tanlang';

  @override
  String get addressesEmpty => 'Hozircha manzil qo\'shilmagan';

  @override
  String get addressDefaultLabel => 'Asosiy';

  @override
  String get ordersToday => 'Bugungi';

  @override
  String get ordersHistory => 'Tarix';

  @override
  String get ordersTodayEmpty => 'Bugun buyurtmalar yo\'q';

  @override
  String get ordersHistoryEmpty => 'Buyurtmalar tarixi bo\'sh';

  @override
  String ordersMoreProducts(Object count) {
    return '+$count ta mahsulot';
  }

  @override
  String get ordersLoadMore => 'Yana ko\'rsatish';

  @override
  String get ordersRecommendedTitle => 'Sizga yoqishi mumkin';

  @override
  String get orderItems => 'Mahsulotlar';

  @override
  String get orderAddress => 'Manzil';

  @override
  String get orderPickupBranch => 'Olib ketish filiali';

  @override
  String get orderCourier => 'Kuryer';

  @override
  String get orderCancel => 'Buyurtmani bekor qilish';

  @override
  String get orderCancelConfirm => 'Buyurtmani bekor qilmoqchimisiz?';

  @override
  String get unsupportedStoreTitle => 'Noma\'lum do\'kon';

  @override
  String get unsupportedStoreMessage =>
      'Bu do\'kon turi ilova tomonidan qo\'llanmaydi.';

  @override
  String get unsupportedStoreBack => 'Bosh sahifaga qaytish';

  @override
  String get routeNotFoundTitle => 'Sahifa topilmadi';

  @override
  String get routeNotFoundMessage =>
      'Bu havola eskirgan yoki ilovaning yangi versiyasini talab qiladi.';

  @override
  String get supportCenterTitle => 'Yordam va murojaatlar';

  @override
  String get supportFormIntro =>
      'Kerakli mahsulotni topmadingizmi, taklifingiz yoki savolingiz bormi? Matn, rasm yoki ovoz orqali yuboring.';

  @override
  String get supportMissingProductTitle => 'Yo\'q tovarlar uchun zakaz berish';

  @override
  String get supportMissingProductSubtitle =>
      'Appda topilmagan mahsulotni bizga ayting';

  @override
  String get supportMissingProductHint =>
      'Qaysi mahsulot kerakligini batafsil yozing';

  @override
  String get supportSuggestionTitle => 'Taklif yuborish';

  @override
  String get supportSuggestionHint =>
      'Ilovani yaxshilash bo\'yicha taklifingizni yozing';

  @override
  String get supportHelpTitle => 'Yordam so\'rash';

  @override
  String get supportHelpHint => 'Muammo yoki savolingizni yozing';

  @override
  String get supportStoreLabel => 'Do\'kon';

  @override
  String get supportMessageLabel => 'Xabar';

  @override
  String get supportAddImage => 'Rasm qo\'shish';

  @override
  String get supportTakePhoto => 'Kameradan olish';

  @override
  String get supportChooseGallery => 'Galereyadan tanlash';

  @override
  String get supportRecordVoice => 'Ovoz yozish';

  @override
  String get supportStopRecording => 'To\'xtatish';

  @override
  String get supportRecording => 'Ovoz yozilmoqda';

  @override
  String get supportMicrophoneDenied =>
      'Mikrofonga ruxsat berilmadi. Matn yoki rasm yuborishingiz mumkin.';

  @override
  String get supportRecordingFailed =>
      'Ovoz yozib bo\'lmadi. Qayta urinib ko\'ring.';

  @override
  String get supportMediaReadFailed => 'Faylni o\'qib bo\'lmadi.';

  @override
  String get supportImageTooLarge => 'Rasm hajmi 8 MBdan oshmasligi kerak.';

  @override
  String get supportVoiceTooLarge => 'Ovoz hajmi 10 MBdan oshmasligi kerak.';

  @override
  String get supportAtLeastOne =>
      'Matn yoki rasm/ovozdan kamida bittasini yuboring.';

  @override
  String get supportSelectStore => 'Yo\'q tovar uchun do\'konni tanlang.';

  @override
  String get supportSend => 'Yuborish';

  @override
  String get supportSending => 'Yuborilmoqda...';

  @override
  String get supportSent => 'Murojaatingiz yuborildi';

  @override
  String get supportHistory => 'Murojaatlar tarixi';

  @override
  String get supportHistoryEmpty => 'Hozircha murojaat yubormagansiz';

  @override
  String get supportStatusOpen => 'Yangi';

  @override
  String get supportStatusInProgress => 'Ko\'rib chiqilmoqda';

  @override
  String get supportStatusClosed => 'Yakunlangan';

  @override
  String get supportContactMissing => 'Ism-familiya kiritilmagan';

  @override
  String get supportContactNeededTitle => 'Kontakt ma\'lumoti';

  @override
  String get supportContactNeededSubtitle =>
      'Admin siz bilan bog\'lanishi uchun ism va familiyangizni kiriting.';

  @override
  String get supportFirstName => 'Ism';

  @override
  String get supportLastName => 'Familiya';

  @override
  String get supportRequestProductAction => 'Shu mahsulotga zakaz berish';

  @override
  String get supportRemoveAttachment => 'Biriktirmani o\'chirish';

  @override
  String get supportImageAttached => 'Rasm biriktirildi';

  @override
  String get supportVoiceAttached => 'Ovoz biriktirildi';

  @override
  String get supportOneAttachment => '1 ta fayl';

  @override
  String get supportChooseStoreQuestion => 'Qaysi do\'kondan?';

  @override
  String get supportResponseHint => 'Operator murojaatingizni ko\'rib chiqadi';

  @override
  String get videoFeedTitle => 'Video lenta';

  @override
  String get videoProductView => 'Mahsulotni ko\'rish';

  @override
  String get videoCommentsTitle => 'Izohlar';

  @override
  String get videoCommentHint => 'Izoh yozing...';

  @override
  String get videoCommentSend => 'Yuborish';

  @override
  String get videoCommentsEmpty => 'Hali izoh yo\'q';

  @override
  String get videoLoadError => 'Videolarni yuklab bo\'lmadi.';

  @override
  String get videoLike => 'Yoqtirish';

  @override
  String get videoUnmute => 'Ovozni yoqish';

  @override
  String get videoMute => 'Ovozni o\'chirish';

  @override
  String get videoGoToStore => 'Do\'konga o\'tish';

  @override
  String get videoProductsTitle => 'Siz uchun mahsulotlar';

  @override
  String get videoSeeAllProducts => 'Barchasini ko\'rish';

  @override
  String get videoProductsLoadError => 'Mahsulotlarni yuklab bo\'lmadi.';

  @override
  String get videoYou => 'Siz';

  @override
  String orderWaitingElapsed(Object elapsed) {
    return 'Kutilmoqda: $elapsed';
  }

  @override
  String get orderStatusDelivering => 'Kuryer yo\'lda';

  @override
  String get orderStageAwaiting => 'Buyurtma tasdiqlanishi kutilmoqda';

  @override
  String get orderStageAwaitingHint =>
      'Kuryer buyurtmangizni ko\'rib chiqmoqda';

  @override
  String get orderStagePreparing => 'Buyurtmangiz tayyorlanmoqda';

  @override
  String get orderStagePreparingHint => 'Kuryer do\'konga yo\'l oldi';

  @override
  String get orderStageOnWay => 'Kuryer siz tomon yo\'lga chiqdi';

  @override
  String get orderStageOnWayHint => 'Buyurtmangiz manzilingiz tomon kelmoqda';

  @override
  String get orderStageDelivered => 'Buyurtma yetkazildi';

  @override
  String get orderStageDeliveredHint => 'Xaridingiz uchun rahmat!';

  @override
  String get orderDeliveryWindowTitle => 'Yetkazib beradigan vaqtimiz';

  @override
  String get orderDeliveryWindowPending => 'Kuryer tasdiqlagach aniqlanadi';

  @override
  String orderDeliveredAt(String time) {
    return 'Yetkazildi · $time';
  }

  @override
  String get orderSummaryTitle => 'Buyurtma tafsilotlari';

  @override
  String orderSummaryProducts(int count) {
    return '$count ta mahsulot';
  }

  @override
  String get orderDeliveryDetails => 'Yetkazish tafsilotlari';

  @override
  String get orderRecipientPhone => 'Oluvchining raqami';

  @override
  String get orderPaymentMethodLabel => 'To\'lov usuli';

  @override
  String get orderPaymentCash => 'Naqd, kuryerga';

  @override
  String get orderPaymentPayme => 'Payme';

  @override
  String get orderDeliveryFree => 'Bepul';

  @override
  String get orderBackToOrder => 'Buyurtmaga qaytish';

  @override
  String get orderHelp => 'Yordam';

  @override
  String get orderOpenMap => 'Xaritani kattalashtirish';

  @override
  String get orderStatusAwaiting => 'Tasdiqlanishi kutilmoqda';

  @override
  String get orderStatusPreparing => 'Tayyorlanmoqda';

  @override
  String get orderCourierRole => 'Kuryer';

  @override
  String get orderVehicleFoot => 'Piyoda';

  @override
  String get orderVehicleBicycle => 'Velosiped';

  @override
  String get orderVehicleMotorcycle => 'Mototsikl';

  @override
  String get orderVehicleCar => 'Avtomobil';

  @override
  String get orderStatusDelivered => 'Yetkazildi';

  @override
  String get orderStatusCancelled => 'Bekor qilindi';

  @override
  String get orderStatusProcessing => 'Jarayonda';

  @override
  String orderArrivesInMinutes(Object minutes) {
    return '$minutes daqiqa ichida';
  }

  @override
  String get orderCallCourier => 'Qo\'ng\'iroq qilish';

  @override
  String get orderCopyPhone => 'Raqamni nusxalash';

  @override
  String get orderPhoneCopied => 'Telefon raqami nusxalandi';

  @override
  String orderLocationUpdated(Object seconds) {
    return 'Lokatsiya $seconds soniya oldin yangilandi';
  }

  @override
  String get orderLocationDelayed => 'Lokatsiya yangilanishi kechikmoqda';

  @override
  String get orderLocationUnavailable =>
      'Kuryer lokatsiyasi vaqtincha mavjud emas';

  @override
  String get orderRouteUnavailable =>
      'Yo\'l ma\'lumoti olinmadi. Kuryerning joriy nuqtasi ko\'rsatilmoqda.';

  @override
  String orderMapEta(Object minutes) {
    return 'Xarita bo\'yicha: $minutes daqiqa';
  }

  @override
  String get orderVehicle => 'Transport';

  @override
  String get notificationsTitle => 'Bildirishnomalar';

  @override
  String get notificationsEmpty => 'Hozircha bildirishnoma yo\'q';

  @override
  String get notificationsReadAll => 'Barchasini o\'qish';

  @override
  String get notificationOpen => 'Ochish';

  @override
  String get productReviewsTitle => 'Baho va izohlar';

  @override
  String get productReviewsEmpty => 'Hozircha izohlar yo\'q';

  @override
  String get productReviewWrite => 'Baho va izoh yozish';

  @override
  String get productReviewPurchasedOnly =>
      'Bu mahsulot yetkazilgandan keyin izoh yozishingiz mumkin';

  @override
  String get productReviewAlreadyWritten =>
      'Siz bu mahsulotga allaqachon izoh yozgansiz';

  @override
  String get productReviewCommentHint => 'Mahsulot haqidagi fikringiz';

  @override
  String get productReviewSubmit => 'Yuborish';

  @override
  String get productReviewSuccess => 'Baho va izohingiz yuborildi';

  @override
  String get orderDeliveryWithinOneDay => '1 kun ichida yetkaziladi';

  @override
  String get orderDeliveryWithinTwoDays => '2 kun ichida yetkaziladi';

  @override
  String get ugcPolicyTitle => 'Hamjamiyat qoidalari';

  @override
  String get ugcPolicySummary =>
      'Izoh yozishdan oldin foydalanish shartlari va hamjamiyat qoidalariga rozilik bildiring. Haqorat, spam va nomaqbul kontent taqiqlanadi.';

  @override
  String get ugcPolicyConsent =>
      'Foydalanish shartlari va hamjamiyat qoidalarini o\'qidim va qabul qilaman';

  @override
  String get ugcAccept => 'Qabul qilish';

  @override
  String get ugcTerms => 'Foydalanish shartlari';

  @override
  String get ugcCommunityGuidelines => 'Hamjamiyat qoidalari';

  @override
  String get ugcContentActions => 'Kontent amallari';

  @override
  String get ugcReport => 'Shikoyat qilish';

  @override
  String get ugcReportTitle => 'Shikoyat sababini tanlang';

  @override
  String get ugcReportSubmit => 'Shikoyatni yuborish';

  @override
  String get ugcReportSent => 'Shikoyatingiz yuborildi';

  @override
  String get ugcReportDetails => 'Qo\'shimcha ma\'lumot (ixtiyoriy)';

  @override
  String get ugcReasonSpam => 'Spam';

  @override
  String get ugcReasonAbuse => 'Haqorat yoki ta\'qib';

  @override
  String get ugcReasonInappropriate => 'Nomaqbul kontent';

  @override
  String get ugcReasonOther => 'Boshqa sabab';

  @override
  String get ugcBlockUser => 'Foydalanuvchini bloklash';

  @override
  String get ugcBlock => 'Bloklash';

  @override
  String get ugcUnblock => 'Blokdan chiqarish';

  @override
  String get ugcUserBlocked =>
      'Foydalanuvchi bloklandi. Uning izohlari sizga ko\'rinmaydi.';

  @override
  String get ugcBlockedUsers => 'Bloklangan foydalanuvchilar';

  @override
  String get ugcBlockedUsersEmpty => 'Bloklangan foydalanuvchilar yo\'q';

  @override
  String ugcBlockConfirmation(String name) {
    return '$name foydalanuvchisini bloklaysizmi? Uning public izoh va sharhlari sizga ko\'rinmaydi.';
  }

  @override
  String get checkoutDeliveryMapTitle => 'Yetkazish xaritasi';

  @override
  String get checkoutMapStore => 'Do‘kon';

  @override
  String get checkoutMapAddress => 'Yetkazish manzili';

  @override
  String get checkoutMapYou => 'Siz turgan joy';

  @override
  String get checkoutMapFit => 'Hammasini ko‘rsatish';

  @override
  String get checkoutMapExpand => 'Kengaytirish';

  @override
  String get checkoutMapLocating => 'Joylashuv aniqlanmoqda';

  @override
  String get checkoutMapGpsUnavailable =>
      'Telefon joylashuvini aniqlab bo‘lmadi. Manzilni qo‘lda tanlashingiz mumkin.';

  @override
  String get checkoutGpsDenied =>
      'Lokatsiya ruxsati berilmadi. Yetkazish manzilini qo‘lda tanlashingiz mumkin.';

  @override
  String get checkoutGpsDeniedForever =>
      'Lokatsiya ruxsatini telefon sozlamalaridan yoqing yoki manzilni qo‘lda tanlang.';

  @override
  String get checkoutGpsDisabled =>
      'GPS o‘chiq. Uni yoqing yoki manzilni qo‘lda tanlang.';

  @override
  String get checkoutGpsTimeout =>
      'GPS javobi kechikdi. Qayta urinib ko‘ring yoki manzilni qo‘lda tanlang.';

  @override
  String get checkoutGpsStale =>
      'GPS nuqtasi eskirgan. Joylashuvni qayta aniqlang yoki manzilni qo‘lda tanlang.';

  @override
  String get checkoutGpsApproximate =>
      'Joylashuv taxminiy. Telefoningizda aniq lokatsiyani yoqing yoki GPS’ni qayta tekshiring.';

  @override
  String get checkoutGpsSettings => 'Sozlamalarni ochish';

  @override
  String get checkoutMapTilesUnavailable =>
      'Xarita rasmlari yuklanmadi. Markerlar va radius ishlaydi.';

  @override
  String get checkoutMapCoverageUnavailable =>
      'Yetkazish hududini yuklab bo‘lmadi.';

  @override
  String checkoutCoverageRadius(String radius) {
    return 'Yetkazish radiusi: $radius km';
  }

  @override
  String checkoutOutsideRadius(String radius) {
    return 'Manzil $radius km yetkazish radiusidan tashqarida. Boshqa manzil yoki olib ketishni tanlang.';
  }

  @override
  String get checkoutTariffUnavailable =>
      'Bu masofa uchun yetkazish tarifi sozlanmagan.';

  @override
  String get checkoutMapPreviewHint =>
      'Bu filial hududi ko‘rinishi. Buyurtma uchun yetkazish manzilini tanlang.';
}

/// The translations for Uzbek, using the Cyrillic script (`uz_Cyrl`).
class AppLocalizationsUzCyrl extends AppLocalizationsUz {
  AppLocalizationsUzCyrl() : super('uz_Cyrl');

  @override
  String get appUpdateTitle => 'Янгиланиш мавжуд';

  @override
  String appUpdateBody(String version) {
    return 'Илованинг $version версияси чиқди. Янги имкониятлар ва яхшиланишлардан фойдаланиш учун янгиланг.';
  }

  @override
  String get appUpdateDownload => 'Юклаб олиш';

  @override
  String get appUpdateLater => 'Кейинроқ';

  @override
  String get appUpdateOpenFailed =>
      'Google Play’ни очиб бўлмади. Қайта уриниб кўринг ёки кейинроқ янгиланг.';

  @override
  String get checkoutAddressActionHint =>
      'Харитадан жой белгиланг ёки сақланган манзилни танланг';

  @override
  String get checkoutReceiptTitle => 'Маҳсулотлар чеки';

  @override
  String checkoutCartCount(int count) {
    return '$count та маҳсулот';
  }

  @override
  String get checkoutOptional => 'Ихтиёрий';

  @override
  String get checkoutPaymentHint => 'Қулай усулни танланг';

  @override
  String get checkoutPayOnline => 'Онлайн тўлов';

  @override
  String get checkoutPayOnReceipt => 'Қабул қилганда';

  @override
  String get checkoutPayOnPickup => 'Олиб кетганда';

  @override
  String get checkoutNotePlaceholder =>
      'Масалан, эшик коди ёки етказиш бўйича изоҳ...';

  @override
  String get checkoutNoteNoBell => 'Эшик қўнғироғини чалманг';

  @override
  String get checkoutNoteCall => 'Етиб келганда қўнғироқ қилинг';

  @override
  String get checkoutNoteNoOnion => 'Пиёзсиз бўлсин';

  @override
  String get checkoutCostBreakdown => 'Ҳисоб-китоб';

  @override
  String get checkoutGrandTotal => 'Жами тўлов';

  @override
  String get checkoutSelectedAddress => 'Танланган';

  @override
  String get checkoutReviewHint =>
      'Тасдиқлашдан олдин манзил ва буюртмани текширинг';

  @override
  String get checkoutHelpTitle => 'Буюртма ҳақида';

  @override
  String get checkoutHelpBody =>
      'Етказиш манзилини ва тўлов усулини танланг. Етказиш ҳудуди харитада кўрсатилган. Буюртма фақат манзил ва етказиш нархи текширилгач тасдиқланади. Олиб кетишда мос филиални танланг.';

  @override
  String get catalogImagelessPull =>
      'Расмсиз маҳсулотларни кўриш учун яна юқорига тортинг';

  @override
  String get catalogImagelessRelease => 'Қўйиб юборинг';

  @override
  String get catalogImagelessShow => 'Расмсизларни кўрсатиш';

  @override
  String get addressLocationUnavailable =>
      'Локацияни аниқлаб бўлмади. ГПСъни текширинг ёки харитада нуқтани қўлда танланг.';

  @override
  String get appName => 'Besh Kashtan';

  @override
  String get commonRetry => 'Қайта уриниш';

  @override
  String get commonFieldRequired => 'Бу майдонни тўлдиринг';

  @override
  String get commonCancel => 'Бекор қилиш';

  @override
  String get commonSave => 'Сақлаш';

  @override
  String get commonContinue => 'Давом этиш';

  @override
  String get commonClose => 'Ёпиш';

  @override
  String get commonSearch => 'Қидириш';

  @override
  String get commonAll => 'Барчаси';

  @override
  String get commonLoading => 'Юкланмоқда...';

  @override
  String get commonEmpty => 'Ҳозирча бўш';

  @override
  String get commonYes => 'Ҳа';

  @override
  String get commonNo => 'Йўқ';

  @override
  String get offlineBanner => 'Оффлине режим';

  @override
  String get connectionServerUnavailable => 'Серверга уланиб бўлмади';

  @override
  String get offlineStaleData => 'эски маълумотлар';

  @override
  String get errorNetwork => 'Интернет алоқаси йўқ. Уланишни текширинг.';

  @override
  String get errorServer =>
      'Серверда хатолик юз берди. Бироздан сўнг уриниб кўринг.';

  @override
  String get errorUnknown => 'Кутилмаган хатолик юз берди.';

  @override
  String get errorSessionExpired => 'Сессия муддати тугади. Қайтадан киринг.';

  @override
  String get errorThrottled => 'Жуда кўп уриниш. Бироз кутинг.';

  @override
  String get errorNotFound => 'Топилмади.';

  @override
  String get errorForbidden => 'Бу амалга рухсат йўқ.';

  @override
  String get authPhoneTitle => 'Телефон рақамингиз';

  @override
  String get authPhoneSubtitle => 'Кириш учун рақамингизни киритинг';

  @override
  String get authRequiredTitle => 'Аввал иловага киринг';

  @override
  String get authRequiredSubtitle =>
      'Давом этиш учун телефон рақамингизни киритинг';

  @override
  String get authPhoneHint => '90 123 45 67';

  @override
  String get authSendCode => 'Код олиш';

  @override
  String get authOtpTitle => 'Тасдиқлаш коди';

  @override
  String authOtpSubtitle(String phone) {
    return '$phone рақамига юборилган 6 хонали кодни киритинг';
  }

  @override
  String get authOtpResend => 'Кодни қайта юбориш';

  @override
  String authOtpResendIn(int seconds) {
    return 'Қайта юбориш $seconds сониядан кейин';
  }

  @override
  String authOtpExpiresIn(int seconds) {
    return 'Код $seconds сониядан кейин эскиради';
  }

  @override
  String get authConsentPrefix => 'Давом этиш орқали сиз ';

  @override
  String get authConsentTerms => 'Фойдаланиш шартлари';

  @override
  String get authConsentAnd => ' ва ';

  @override
  String get authConsentPrivacy => 'Махфийлик сиёсати';

  @override
  String get authConsentSuffix => 'га розилик билдирасиз.';

  @override
  String get authLogout => 'Чиқиш';

  @override
  String get authErrorOtpCooldown => 'Кодни қайта юбориш учун бироз кутинг.';

  @override
  String get authErrorOtpHourLimit =>
      'Бир соатда 5 мартадан кўп код сўраб бўлмайди.';

  @override
  String get authErrorOtpInvalid => 'Код нотўғри. Қайтадан текширинг.';

  @override
  String get authErrorOtpExpired => 'Код муддати тугади. Янги код олинг.';

  @override
  String get authErrorOtpAttempts => 'Уринишлар тугади. Янги код олинг.';

  @override
  String get authErrorSmsFailed =>
      'SMS юборилмади. Бироздан сўнг уриниб кўринг.';

  @override
  String get authErrorInvalidPhone => 'Телефон рақам нотўғри.';

  @override
  String get onboardingNameTitle => 'Исмингиз';

  @override
  String get onboardingNameSubtitle => 'Буюртмаларда кўрсатилади';

  @override
  String get onboardingLocationTitle => 'Манзилингиз';

  @override
  String get onboardingLocationSubtitle =>
      'Етказиб бериш нархини ҳисоблаш учун керак';

  @override
  String get storeGrocery => 'Озиқ-овқат';

  @override
  String get storeHousehold => 'Уй жиҳозлари';

  @override
  String get storeRestaurant => 'Ресторан';

  @override
  String get storeShashlik => 'Шашлик';

  @override
  String get storeMeat => 'Гўшт маҳсулотлари';

  @override
  String get meatProductLamb => 'Қўй гўшти';

  @override
  String get meatProductBeef => 'Мол гўшти';

  @override
  String get meatProductHorse => 'От гўшти';

  @override
  String get meatProductQazi => 'Қази';

  @override
  String get meatProductBeefLiver => 'Мол жигар';

  @override
  String get meatProductLambLiver => 'Қўй жигар';

  @override
  String get shashlikSectionKebabs => 'Шашликлар';

  @override
  String get shashlikSectionCharcoal => 'Кўмир';

  @override
  String get shashlikSectionOther => 'Бошқа';

  @override
  String get shashlikFamilyBeefJazz => 'Мол жазз';

  @override
  String get shashlikFamilyLambJazz => 'Қўй жазз';

  @override
  String get shashlikFamilyChicken => 'Товуқ';

  @override
  String get shashlikFamilyLiver => 'Жигар';

  @override
  String get shashlikFamilyMince => 'Қийма';

  @override
  String get shashlikOptionSkewered => 'Зихланган';

  @override
  String get shashlikOptionByKilo => 'Килолик';

  @override
  String get shashlikOptionMince => 'Қийма';

  @override
  String get shashlikOptionBreadMince => 'Нон қийма';

  @override
  String get shashlikOptionKiloMince => 'Килолик қийма';

  @override
  String get shashlikChooseProduct => 'Маҳсулот турини ва миқдорини танланг';

  @override
  String get shashlikQuantity => 'Миқдор';

  @override
  String get shashlikAddToCart => 'Саватга қўшиш';

  @override
  String shashlikPriceFrom(String price) {
    return '$price дан';
  }

  @override
  String shashlikKilogramPrice(String price) {
    return 'Килограмми $price';
  }

  @override
  String shashlikPieceQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дона',
      one: '1 дона',
    );
    return '$_temp0';
  }

  @override
  String shashlikKilogramQuantity(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count килограм',
      one: '1 килограм',
    );
    return '$_temp0';
  }

  @override
  String shashlikInCart(int count) {
    return 'Саватда: $count та';
  }

  @override
  String get cartTitle => 'Сават';

  @override
  String get cartEmpty => 'Сават бўш';

  @override
  String get cartEmptyStore => 'сават бўш';

  @override
  String get cartMainSubtitle =>
      'Ҳар бир дўкон алоҳида етказади — буюртмалар ҳам алоҳида берилади';

  @override
  String cartItemsCount(int count) {
    return '$count та';
  }

  @override
  String get cartCheckout => 'Буюртма бериш';

  @override
  String get cartTotal => 'Жами';

  @override
  String get cartSubtotal => 'Маҳсулотлар';

  @override
  String get cartDeliveryFee => 'Етказиб бериш';

  @override
  String get ordersTitle => 'Буюртмалар';

  @override
  String get ordersEmpty => 'Ҳозирча буюртма йўқ';

  @override
  String get profileTitle => 'Профил';

  @override
  String get profilePrivacyPolicy => 'Махфийлик сиёсати';

  @override
  String profileAppVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get profileDeleteAccount => 'Ҳисобни ўчириш';

  @override
  String get profileDeleteAccountTitle => 'Ҳисобни бутунлай ўчириш';

  @override
  String get profileDeleteAccountWarning =>
      'Исмингиз, телефон рақамингиз, манзилларингиз, саватингиз, севимлиларингиз ва шарҳларингиз ўчирилади. Бу амални қайтариб бўлмайди. Тасдиқлаш учун телефонингизга SMS код юборамиз.';

  @override
  String get profileDeleteAccountSendCode => 'Код юбориш';

  @override
  String get profileDeleteAccountCodeHint =>
      'Телефонингизга юборилган кодни киритинг. Код тасдиқлангач ҳисоб дарҳол ўчирилади.';

  @override
  String get profileDeleteAccountConfirm => 'Бутунлай ўчириш';

  @override
  String get profileLanguage => 'Тил';

  @override
  String get profileAddresses => 'Манзиллар';

  @override
  String get profileNotifications => 'Билдиришномалар';

  @override
  String get profileSupport => 'Ёрдам';

  @override
  String get languageUz => 'O\'zbekcha';

  @override
  String get languageUzCyrl => 'Ўзбекча';

  @override
  String get languageRu => 'Русский';

  @override
  String get devPlaygroundTitle => 'API текшируви';

  @override
  String get devPlaygroundSubtitle => 'GET /ҳоме/ жавоби ва тил алмаштириш';

  @override
  String get devFetch => 'Сўров юбориш';

  @override
  String get devApiLang => 'Серверга юборилган ланг';

  @override
  String get devScript => 'Ёзув';

  @override
  String get devResponseSize => 'Жавоб ҳажми';

  @override
  String devItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемент',
      one: '1 элемент',
      zero: 'Элемент йўқ',
    );
    return '$_temp0';
  }

  @override
  String errorThrottledSeconds(int seconds) {
    return 'Жуда кўп уриниш. $seconds сониядан кейин уриниб кўринг.';
  }

  @override
  String get authChangeNumber => 'Рақамни ўзгартириш';

  @override
  String get authOtpHint => 'СМСъдаги 6 хонали код';

  @override
  String get authOtpExpired => 'Код муддати тугади';

  @override
  String get authPhoneInvalidOperator => 'Бундай оператор коди мавжуд эмас.';

  @override
  String get homeGreeting => 'Хуш келибсиз!';

  @override
  String get homePlaceholder => 'Бош саҳифа кейинги босқичда қурилади.';

  @override
  String get homeDeliverTitle => 'Уйингизга етказиб берамиз';

  @override
  String get homeAddressNotSelected => 'Манзил танланмаган';

  @override
  String get homeStoresTitle => 'Дўконлар';

  @override
  String get homeRequestText => 'Матн';

  @override
  String get homeRequestImage => 'Расм';

  @override
  String get homeRequestVoice => 'Овоз';

  @override
  String get searchHint => 'Маҳсулот қидиринг';

  @override
  String get searchStartTyping => 'Қидириш учун ёзишни бошланг';

  @override
  String get searchEmpty => 'Ҳеч нарса топилмади';

  @override
  String searchResultsCount(int count) {
    return 'Натижалар $count';
  }

  @override
  String get searchMissingTitle => 'Қидирганингиз топилмади?';

  @override
  String get searchMissingSubtitle =>
      'Йўқ товар буюртмаси беринг — матн, расм ёки овоз';

  @override
  String get storeComingSoon => 'Бу бўлим кейинги босқичда қурилади';

  @override
  String get profileSheetTitle => 'Профил';

  @override
  String get profileUnnamed => 'Фойдаланувчи';

  @override
  String get profileChooseStore => 'Дўконни танланг';

  @override
  String get notificationsComingSoon => 'Билдиришномалар тез орада';

  @override
  String get commonDelete => 'Ўчириш';

  @override
  String get commonEdit => 'Таҳрирлаш';

  @override
  String get commonDone => 'Тайёр';

  @override
  String get commonAdd => 'Қўшиш';

  @override
  String get navHome => 'Асосий';

  @override
  String get navVideos => 'Видеолар';

  @override
  String get navProducts => 'Маҳсулотлар';

  @override
  String get navFavorites => 'Севимлилар';

  @override
  String get navCart => 'Сават';

  @override
  String get navOrders => 'Буюртмалар';

  @override
  String get catalogTitle => 'Маҳсулотлар';

  @override
  String catalogProductVarietyCount(int count) {
    return '$count хил маҳсулот';
  }

  @override
  String get catalogAllProducts => 'Барча маҳсулотлар';

  @override
  String get catalogEmpty => 'Бу дўконда ҳозирча маҳсулот йўқ';

  @override
  String get catalogSearchHint => 'Шу дўкондан қидиринг';

  @override
  String get catalogCategoryFilter => 'Категориялар';

  @override
  String get householdSectionHomeTools => 'Уй, қурилиш ва устачилик';

  @override
  String get householdSectionTechTransport => 'Техника ва транспорт';

  @override
  String get householdSectionKitchenLiving => 'Ошхона ва рўзғор';

  @override
  String get householdSectionClothingCare => 'Кийим ва шахсий парвариш';

  @override
  String get householdSectionKidsHobbyOther => 'Болалар, ҳобби ва бошқа';

  @override
  String get restaurantSectionTraditional => 'Анъанавий таомлар';

  @override
  String get restaurantSectionGrillTandoor => 'Грилл ва тандир';

  @override
  String get restaurantSectionSaladsTable => 'Салатлар ва дастурхон';

  @override
  String get restaurantSectionDessertsDrinks => 'Ширинлик ва ичимликлар';

  @override
  String get catalogFeatured => 'Тавсия этамиз';

  @override
  String get catalogDiscounted => 'Чегирмалар';

  @override
  String get catalogPopular => 'Оммабоп';

  @override
  String get catalogNew => 'Янги маҳсулотлар';

  @override
  String get favoritesTitle => 'Севимлилар';

  @override
  String get favoritesEmpty => 'Бу дўконда севимли маҳсулот йўқ';

  @override
  String get productUnavailable => 'Ҳозир харид қилиб бўлмайди';

  @override
  String get productSoldOut => 'Тугади';

  @override
  String get productSoldOutDetail => 'Бу таом ҳозирча тугаган.';

  @override
  String get paymePayButton => 'Пайме орқали тўлаш';

  @override
  String get paymeCheckPayment => 'Тўловни текшириш';

  @override
  String get paymeUnavailable =>
      'Пайме орқали тўлов хизмати вақтинча мавжуд эмас';

  @override
  String get paymePaymentPaid => 'Тўлов амалга оширилди';

  @override
  String get paymePaymentPending =>
      'Тўлов ҳали тасдиқланмади. Бироздан сўнг қайта текширинг';

  @override
  String get paymePaymentFailed => 'Тўлов амалга ошмади. Қайта уриниб кўринг';

  @override
  String get paymePaymentCancelled => 'Тўлов бекор қилинди';

  @override
  String get paymeLinkOpenFailed => 'Тўлов саҳифасини очиб бўлмади';

  @override
  String get productInReview => 'Текширувда';

  @override
  String get productInReviewDetail =>
      'Бу маҳсулот текширувда. Ҳозирча сотиб олиб бўлмайди.';

  @override
  String get reportProductButton => 'Хато маҳсулот';

  @override
  String get reportProductConfirmTitle => 'Админга юборилсинми?';

  @override
  String get reportProductConfirmBody =>
      'Расми ёки категорияси нотўғри маҳсулот текширувга юборилади ва тузатилгунча сотувдан вақтинча олинади.';

  @override
  String get reportProductConfirmAction => 'Юбориш';

  @override
  String get reportProductSuccess => 'Юборилди. Маҳсулот текширувга олинди.';

  @override
  String get productChooseOptions => 'Танлаш';

  @override
  String get productAddToCart => 'Саватга қўшиш';

  @override
  String get productBuy => 'Харид қилиш';

  @override
  String get productAddShort => 'Саватга';

  @override
  String get productGoToCart => 'Саватга ўтиш';

  @override
  String get productAdded => 'Товар саватга қўшилди';

  @override
  String productImageCount(int count) {
    return '$count та расм';
  }

  @override
  String get productDescription => 'Тавсиф';

  @override
  String get productRelated => 'Ўхшаш маҳсулотлар';

  @override
  String get homeForYou => 'Сиз учун';

  @override
  String get homeForYouSubtitle => 'Қизиқишларингизга қараб танладик';

  @override
  String catalogSimilarTo(String name) {
    return '«$name»га ўхшашлар';
  }

  @override
  String get productVariant => 'Вариантни танланг';

  @override
  String get productAddons => 'Қўшимчалар';

  @override
  String get productRequired => 'Мажбурий';

  @override
  String get productChooseMin => 'Камида кўрсатилган миқдорни танланг';

  @override
  String get productChooseMax => 'Танлаш чегарасига етдингиз';

  @override
  String get productNote => 'Изоҳ';

  @override
  String get productNoteHint => 'Масалан, пиёзсиз';

  @override
  String get cartClear => 'Саватни тозалаш';

  @override
  String get cartClearConfirm => 'Саватдаги барча маҳсулотлар ўчирилсинми?';

  @override
  String get cartEmptyHint => 'Маҳсулотлар бўлимидан саватга қўшинг';

  @override
  String get cartVariant => 'Вариант';

  @override
  String get cartAddons => 'Қўшимчалар';

  @override
  String get checkoutTitle => 'Буюртмани расмийлаштириш';

  @override
  String get checkoutFulfillment => 'Қабул қилиш усули';

  @override
  String get checkoutDelivery => 'Етказиб бериш';

  @override
  String get checkoutPickup => 'Олиб кетиш';

  @override
  String get checkoutAddress => 'Етказиш манзили';

  @override
  String get checkoutSelectAddress => 'Манзилни танланг';

  @override
  String get checkoutAddAddress => 'Янги манзил';

  @override
  String get checkoutLocationPromptTitle => 'Етказиш жойлашувини танланг';

  @override
  String get checkoutLocationPromptHint =>
      'Ҳар бир буюртма учун янги жойлашув қўшинг ёки сақланган манзилни қайта танланг.';

  @override
  String get checkoutAddNewLocation => 'Янги жойлашув қўшиш';

  @override
  String get checkoutSavedLocations => 'Сақланган манзиллар';

  @override
  String get checkoutChooseOrChangeAddress => 'Манзилни танлаш ёки ўзгартириш';

  @override
  String get checkoutBranch => 'Олиб кетиш филиали';

  @override
  String get checkoutSelectBranch => 'Филиални танланг';

  @override
  String get checkoutMixedStorePickup =>
      'Саватдаги маҳсулотлар турли жисмоний дўконлардан. Олиб кетиш мавжуд эмас; етказиб беришни танланг ёки саватни ажратинг.';

  @override
  String get checkoutEstimateUnavailable =>
      'Бу манзилга етказиб бериш мавжуд эмас';

  @override
  String get checkoutDistance => 'Масофа';

  @override
  String get checkoutPaymentMethod => 'Тўлов усули';

  @override
  String get checkoutPayPayme => 'Пайме';

  @override
  String get checkoutPayCashCourier => 'Курерга нақд';

  @override
  String get checkoutPayCashStore => 'Дўконда нақд';

  @override
  String get checkoutNote => 'Буюртмага изоҳ';

  @override
  String get checkoutSubmit => 'Буюртмани тасдиқлаш';

  @override
  String get checkoutEmptyCart => 'Буюртма бериш учун сават бўш';

  @override
  String get addressTitle => 'Манзил номи';

  @override
  String get addressTitleOptional => 'Манзил номи (ихтиёрий)';

  @override
  String get addressUnnamed => 'Харитадаги манзил';

  @override
  String get addressDistrict => 'Туман';

  @override
  String get addressNeighborhood => 'Маҳалла';

  @override
  String get addressStreet => 'Кўча';

  @override
  String get addressHouse => 'Уй';

  @override
  String get addressApartment => 'Хонадон';

  @override
  String get addressLandmark => 'Мўлжал';

  @override
  String get addressSetDefault => 'Асосий манзил қилиш';

  @override
  String get addressChooseOnMap => 'Харитада нуқтани танланг';

  @override
  String get addressCurrentLocation => 'Мен турган жойлашувни аниқлаш';

  @override
  String get mapZoomIn => 'Харитани катталаштириш';

  @override
  String get mapZoomOut => 'Харитани кичиклаштириш';

  @override
  String get addressLocationDenied =>
      'Локация рухсати берилмади. Нуқтани харитада қўлда танланг.';

  @override
  String get addressLocationRequired => 'Харитада локацияни танланг';

  @override
  String get addressesEmpty => 'Ҳозирча манзил қўшилмаган';

  @override
  String get addressDefaultLabel => 'Асосий';

  @override
  String get ordersToday => 'Бугунги';

  @override
  String get ordersHistory => 'Тарих';

  @override
  String get ordersTodayEmpty => 'Бугун буюртмалар йўқ';

  @override
  String get ordersHistoryEmpty => 'Буюртмалар тарихи бўш';

  @override
  String ordersMoreProducts(Object count) {
    return '+$count та маҳсулот';
  }

  @override
  String get ordersLoadMore => 'Яна кўрсатиш';

  @override
  String get ordersRecommendedTitle => 'Сизга ёқиши мумкин';

  @override
  String get orderItems => 'Маҳсулотлар';

  @override
  String get orderAddress => 'Манзил';

  @override
  String get orderPickupBranch => 'Олиб кетиш филиали';

  @override
  String get orderCourier => 'Курер';

  @override
  String get orderCancel => 'Буюртмани бекор қилиш';

  @override
  String get orderCancelConfirm => 'Буюртмани бекор қилмоқчимисиз?';

  @override
  String get unsupportedStoreTitle => 'Номаълум дўкон';

  @override
  String get unsupportedStoreMessage =>
      'Бу дўкон тури илова томонидан қўлланмайди.';

  @override
  String get unsupportedStoreBack => 'Бош саҳифага қайтиш';

  @override
  String get routeNotFoundTitle => 'Саҳифа топилмади';

  @override
  String get routeNotFoundMessage =>
      'Бу ҳавола эскирган ёки илованинг янги версиясини талаб қилади.';

  @override
  String get supportCenterTitle => 'Ёрдам ва мурожаатлар';

  @override
  String get supportFormIntro =>
      'Керакли маҳсулотни топмадингизми, таклифингиз ёки саволингиз борми? Матн, расм ёки овоз орқали юборинг.';

  @override
  String get supportMissingProductTitle => 'Йўқ товарлар учун заказ бериш';

  @override
  String get supportMissingProductSubtitle =>
      'Аппда топилмаган маҳсулотни бизга айтинг';

  @override
  String get supportMissingProductHint =>
      'Қайси маҳсулот кераклигини батафсил ёзинг';

  @override
  String get supportSuggestionTitle => 'Таклиф юбориш';

  @override
  String get supportSuggestionHint =>
      'Иловани яхшилаш бўйича таклифингизни ёзинг';

  @override
  String get supportHelpTitle => 'Ёрдам сўраш';

  @override
  String get supportHelpHint => 'Муаммо ёки саволингизни ёзинг';

  @override
  String get supportStoreLabel => 'Дўкон';

  @override
  String get supportMessageLabel => 'Хабар';

  @override
  String get supportAddImage => 'Расм қўшиш';

  @override
  String get supportTakePhoto => 'Камерадан олиш';

  @override
  String get supportChooseGallery => 'Галереядан танлаш';

  @override
  String get supportRecordVoice => 'Овоз ёзиш';

  @override
  String get supportStopRecording => 'Тўхтатиш';

  @override
  String get supportRecording => 'Овоз ёзилмоқда';

  @override
  String get supportMicrophoneDenied =>
      'Микрофонга рухсат берилмади. Матн ёки расм юборишингиз мумкин.';

  @override
  String get supportRecordingFailed =>
      'Овоз ёзиб бўлмади. Қайта уриниб кўринг.';

  @override
  String get supportMediaReadFailed => 'Файлни ўқиб бўлмади.';

  @override
  String get supportImageTooLarge => 'Расм ҳажми 8 МБдан ошмаслиги керак.';

  @override
  String get supportVoiceTooLarge => 'Овоз ҳажми 10 МБдан ошмаслиги керак.';

  @override
  String get supportAtLeastOne =>
      'Матн ёки расм/овоздан камида биттасини юборинг.';

  @override
  String get supportSelectStore => 'Йўқ товар учун дўконни танланг.';

  @override
  String get supportSend => 'Юбориш';

  @override
  String get supportSending => 'Юборилмоқда...';

  @override
  String get supportSent => 'Мурожаатингиз юборилди';

  @override
  String get supportHistory => 'Мурожаатлар тарихи';

  @override
  String get supportHistoryEmpty => 'Ҳозирча мурожаат юбормагансиз';

  @override
  String get supportStatusOpen => 'Янги';

  @override
  String get supportStatusInProgress => 'Кўриб чиқилмоқда';

  @override
  String get supportStatusClosed => 'Якунланган';

  @override
  String get supportContactMissing => 'Исм-фамилия киритилмаган';

  @override
  String get supportContactNeededTitle => 'Контакт маълумоти';

  @override
  String get supportContactNeededSubtitle =>
      'Админ сиз билан боғланиши учун исм ва фамилиянгизни киритинг.';

  @override
  String get supportFirstName => 'Исм';

  @override
  String get supportLastName => 'Фамилия';

  @override
  String get supportRequestProductAction => 'Шу маҳсулотга заказ бериш';

  @override
  String get supportRemoveAttachment => 'Бириктирмани ўчириш';

  @override
  String get supportImageAttached => 'Расм бириктирилди';

  @override
  String get supportVoiceAttached => 'Овоз бириктирилди';

  @override
  String get supportOneAttachment => '1 та файл';

  @override
  String get supportChooseStoreQuestion => 'Қайси дўкондан?';

  @override
  String get supportResponseHint => 'Оператор мурожаатингизни кўриб чиқади';

  @override
  String get videoFeedTitle => 'Видео лента';

  @override
  String get videoProductView => 'Маҳсулотни кўриш';

  @override
  String get videoCommentsTitle => 'Изоҳлар';

  @override
  String get videoCommentHint => 'Изоҳ ёзинг...';

  @override
  String get videoCommentSend => 'Юбориш';

  @override
  String get videoCommentsEmpty => 'Ҳали изоҳ йўқ';

  @override
  String get videoLoadError => 'Видеоларни юклаб бўлмади.';

  @override
  String get videoLike => 'Ёқтириш';

  @override
  String get videoUnmute => 'Овозни ёқиш';

  @override
  String get videoMute => 'Овозни ўчириш';

  @override
  String get videoGoToStore => 'Дўконга ўтиш';

  @override
  String get videoProductsTitle => 'Сиз учун маҳсулотлар';

  @override
  String get videoSeeAllProducts => 'Барчасини кўриш';

  @override
  String get videoProductsLoadError => 'Маҳсулотларни юклаб бўлмади.';

  @override
  String get videoYou => 'Сиз';

  @override
  String orderWaitingElapsed(Object elapsed) {
    return 'Кутилмоқда: $elapsed';
  }

  @override
  String get orderStatusDelivering => 'Курер йўлда';

  @override
  String get orderStageAwaiting => 'Буюртма тасдиқланиши кутилмоқда';

  @override
  String get orderStageAwaitingHint => 'Курер буюртмангизни кўриб чиқмоқда';

  @override
  String get orderStagePreparing => 'Буюртмангиз тайёрланмоқда';

  @override
  String get orderStagePreparingHint => 'Курер дўконга йўл олди';

  @override
  String get orderStageOnWay => 'Курер сиз томон йўлга чиқди';

  @override
  String get orderStageOnWayHint => 'Буюртмангиз манзилингиз томон келмоқда';

  @override
  String get orderStageDelivered => 'Буюртма етказилди';

  @override
  String get orderStageDeliveredHint => 'Харидингиз учун раҳмат!';

  @override
  String get orderDeliveryWindowTitle => 'Етказиб берадиган вақтимиз';

  @override
  String get orderDeliveryWindowPending => 'Курер тасдиқлагач аниқланади';

  @override
  String orderDeliveredAt(String time) {
    return 'Етказилди · $time';
  }

  @override
  String get orderSummaryTitle => 'Буюртма тафсилотлари';

  @override
  String orderSummaryProducts(int count) {
    return '$count та маҳсулот';
  }

  @override
  String get orderDeliveryDetails => 'Етказиш тафсилотлари';

  @override
  String get orderRecipientPhone => 'Олувчининг рақами';

  @override
  String get orderPaymentMethodLabel => 'Тўлов усули';

  @override
  String get orderPaymentCash => 'Нақд, курерга';

  @override
  String get orderPaymentPayme => 'Пайме';

  @override
  String get orderDeliveryFree => 'Бепул';

  @override
  String get orderBackToOrder => 'Буюртмага қайтиш';

  @override
  String get orderHelp => 'Ёрдам';

  @override
  String get orderOpenMap => 'Харитани катталаштириш';

  @override
  String get orderStatusAwaiting => 'Тасдиқланиши кутилмоқда';

  @override
  String get orderStatusPreparing => 'Тайёрланмоқда';

  @override
  String get orderCourierRole => 'Курер';

  @override
  String get orderVehicleFoot => 'Пиёда';

  @override
  String get orderVehicleBicycle => 'Велосипед';

  @override
  String get orderVehicleMotorcycle => 'Мотоцикл';

  @override
  String get orderVehicleCar => 'Автомобил';

  @override
  String get orderStatusDelivered => 'Етказилди';

  @override
  String get orderStatusCancelled => 'Бекор қилинди';

  @override
  String get orderStatusProcessing => 'Жараёнда';

  @override
  String orderArrivesInMinutes(Object minutes) {
    return '$minutes дақиқа ичида';
  }

  @override
  String get orderCallCourier => 'Қўнғироқ қилиш';

  @override
  String get orderCopyPhone => 'Рақамни нусхалаш';

  @override
  String get orderPhoneCopied => 'Телефон рақами нусхаланди';

  @override
  String orderLocationUpdated(Object seconds) {
    return 'Локация $seconds сония олдин янгиланди';
  }

  @override
  String get orderLocationDelayed => 'Локация янгиланиши кечикмоқда';

  @override
  String get orderLocationUnavailable => 'Курер локацияси вақтинча мавжуд эмас';

  @override
  String get orderRouteUnavailable =>
      'Йўл маълумоти олинмади. Курернинг жорий нуқтаси кўрсатилмоқда.';

  @override
  String orderMapEta(Object minutes) {
    return 'Харита бўйича: $minutes дақиқа';
  }

  @override
  String get orderVehicle => 'Транспорт';

  @override
  String get notificationsTitle => 'Билдиришномалар';

  @override
  String get notificationsEmpty => 'Ҳозирча билдиришнома йўқ';

  @override
  String get notificationsReadAll => 'Барчасини ўқиш';

  @override
  String get notificationOpen => 'Очиш';

  @override
  String get productReviewsTitle => 'Баҳо ва изоҳлар';

  @override
  String get productReviewsEmpty => 'Ҳозирча изоҳлар йўқ';

  @override
  String get productReviewWrite => 'Баҳо ва изоҳ ёзиш';

  @override
  String get productReviewPurchasedOnly =>
      'Бу маҳсулот етказилгандан кейин изоҳ ёзишингиз мумкин';

  @override
  String get productReviewAlreadyWritten =>
      'Сиз бу маҳсулотга аллақачон изоҳ ёзгансиз';

  @override
  String get productReviewCommentHint => 'Маҳсулот ҳақидаги фикрингиз';

  @override
  String get productReviewSubmit => 'Юбориш';

  @override
  String get productReviewSuccess => 'Баҳо ва изоҳингиз юборилди';

  @override
  String get orderDeliveryWithinOneDay => '1 кун ичида етказилади';

  @override
  String get orderDeliveryWithinTwoDays => '2 кун ичида етказилади';

  @override
  String get ugcPolicyTitle => 'Ҳамжамият қоидалари';

  @override
  String get ugcPolicySummary =>
      'Изоҳ ёзишдан олдин фойдаланиш шартлари ва ҳамжамият қоидаларига розилик билдиринг. Ҳақорат, спам ва номақбул контент тақиқланади.';

  @override
  String get ugcPolicyConsent =>
      'Фойдаланиш шартлари ва ҳамжамият қоидаларини ўқидим ва қабул қиламан';

  @override
  String get ugcAccept => 'Қабул қилиш';

  @override
  String get ugcTerms => 'Фойдаланиш шартлари';

  @override
  String get ugcCommunityGuidelines => 'Ҳамжамият қоидалари';

  @override
  String get ugcContentActions => 'Контент амаллари';

  @override
  String get ugcReport => 'Шикоят қилиш';

  @override
  String get ugcReportTitle => 'Шикоят сабабини танланг';

  @override
  String get ugcReportSubmit => 'Шикоятни юбориш';

  @override
  String get ugcReportSent => 'Шикоятингиз юборилди';

  @override
  String get ugcReportDetails => 'Қўшимча маълумот (ихтиёрий)';

  @override
  String get ugcReasonSpam => 'Спам';

  @override
  String get ugcReasonAbuse => 'Ҳақорат ёки таъқиб';

  @override
  String get ugcReasonInappropriate => 'Номақбул контент';

  @override
  String get ugcReasonOther => 'Бошқа сабаб';

  @override
  String get ugcBlockUser => 'Фойдаланувчини блоклаш';

  @override
  String get ugcBlock => 'Блоклаш';

  @override
  String get ugcUnblock => 'Блокдан чиқариш';

  @override
  String get ugcUserBlocked =>
      'Фойдаланувчи блокланди. Унинг изоҳлари сизга кўринмайди.';

  @override
  String get ugcBlockedUsers => 'Блокланган фойдаланувчилар';

  @override
  String get ugcBlockedUsersEmpty => 'Блокланган фойдаланувчилар йўқ';

  @override
  String ugcBlockConfirmation(String name) {
    return '$name фойдаланувчисини блоклайсизми? Унинг публик изоҳ ва шарҳлари сизга кўринмайди.';
  }

  @override
  String get checkoutDeliveryMapTitle => 'Етказиш харитаси';

  @override
  String get checkoutMapStore => 'Дўкон';

  @override
  String get checkoutMapAddress => 'Етказиш манзили';

  @override
  String get checkoutMapYou => 'Сиз турган жой';

  @override
  String get checkoutMapFit => 'Ҳаммасини кўрсатиш';

  @override
  String get checkoutMapExpand => 'Кенгайтириш';

  @override
  String get checkoutMapLocating => 'Жойлашув аниқланмоқда';

  @override
  String get checkoutMapGpsUnavailable =>
      'Телефон жойлашувини аниқлаб бўлмади. Манзилни қўлда танлашингиз мумкин.';

  @override
  String get checkoutGpsDenied =>
      'Локация рухсати берилмади. Етказиш манзилини қўлда танлашингиз мумкин.';

  @override
  String get checkoutGpsDeniedForever =>
      'Локация рухсатини телефон созламаларидан ёқинг ёки манзилни қўлда танланг.';

  @override
  String get checkoutGpsDisabled =>
      'GPS ўчиқ. Уни ёқинг ёки манзилни қўлда танланг.';

  @override
  String get checkoutGpsTimeout =>
      'GPS жавоби кечикди. Қайта уриниб кўринг ёки манзилни қўлда танланг.';

  @override
  String get checkoutGpsStale =>
      'GPS нуқтаси эскирган. Жойлашувни қайта аниқланг ёки манзилни қўлда танланг.';

  @override
  String get checkoutGpsApproximate =>
      'Жойлашув тахминий. Телефонингизда аниқ локацияни ёқинг ёки GPS’ни қайта текширинг.';

  @override
  String get checkoutGpsSettings => 'Созламаларни очиш';

  @override
  String get checkoutMapTilesUnavailable =>
      'Харита расмлари юкланмади. Маркерлар ва радиус ишлайди.';

  @override
  String get checkoutMapCoverageUnavailable =>
      'Етказиш ҳудудини юклаб бўлмади.';

  @override
  String checkoutCoverageRadius(String radius) {
    return 'Етказиш радиуси: $radius км';
  }

  @override
  String checkoutOutsideRadius(String radius) {
    return 'Манзил $radius км етказиш радиусидан ташқарида. Бошқа манзил ёки олиб кетишни танланг.';
  }

  @override
  String get checkoutTariffUnavailable =>
      'Бу масофа учун етказиш тарифи созланмаган.';

  @override
  String get checkoutMapPreviewHint =>
      'Бу филиал ҳудуди кўриниши. Буюртма учун етказиш манзилини танланг.';
}
