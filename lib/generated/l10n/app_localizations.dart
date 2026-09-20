import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('uz'),
    Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    Locale('ru'),
  ];

  /// No description provided for @addressLocationUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Lokatsiyani aniqlab bo‘lmadi. GPS’ni tekshiring yoki xaritada nuqtani qo‘lda tanlang.'**
  String get addressLocationUnavailable;

  /// Ilova nomi
  ///
  /// In uz, this message translates to:
  /// **'Besh Kashtan'**
  String get appName;

  /// No description provided for @commonRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qayta urinish'**
  String get commonRetry;

  /// No description provided for @commonFieldRequired.
  ///
  /// In uz, this message translates to:
  /// **'Bu maydonni to\'ldiring'**
  String get commonFieldRequired;

  /// No description provided for @commonCancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get commonSave;

  /// No description provided for @commonContinue.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get commonContinue;

  /// No description provided for @commonClose.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get commonClose;

  /// No description provided for @commonSearch.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get commonAll;

  /// No description provided for @commonLoading.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda...'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha bo\'sh'**
  String get commonEmpty;

  /// No description provided for @commonYes.
  ///
  /// In uz, this message translates to:
  /// **'Ha'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q'**
  String get commonNo;

  /// No description provided for @offlineBanner.
  ///
  /// In uz, this message translates to:
  /// **'Offline rejim'**
  String get offlineBanner;

  /// No description provided for @connectionServerUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Serverga ulanib bo‘lmadi'**
  String get connectionServerUnavailable;

  /// No description provided for @offlineStaleData.
  ///
  /// In uz, this message translates to:
  /// **'eski ma\'lumotlar'**
  String get offlineStaleData;

  /// Tarmoq xatosi
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo\'q. Ulanishni tekshiring.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In uz, this message translates to:
  /// **'Serverda xatolik yuz berdi. Birozdan so\'ng urinib ko\'ring.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmagan xatolik yuz berdi.'**
  String get errorUnknown;

  /// No description provided for @errorSessionExpired.
  ///
  /// In uz, this message translates to:
  /// **'Sessiya muddati tugadi. Qaytadan kiring.'**
  String get errorSessionExpired;

  /// No description provided for @errorThrottled.
  ///
  /// In uz, this message translates to:
  /// **'Juda ko\'p urinish. Biroz kuting.'**
  String get errorThrottled;

  /// No description provided for @errorNotFound.
  ///
  /// In uz, this message translates to:
  /// **'Topilmadi.'**
  String get errorNotFound;

  /// No description provided for @errorForbidden.
  ///
  /// In uz, this message translates to:
  /// **'Bu amalga ruxsat yo\'q.'**
  String get errorForbidden;

  /// No description provided for @authPhoneTitle.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqamingiz'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Kirish uchun raqamingizni kiriting'**
  String get authPhoneSubtitle;

  /// No description provided for @authRequiredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Avval ilovaga kiring'**
  String get authRequiredTitle;

  /// No description provided for @authRequiredSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish uchun telefon raqamingizni kiriting'**
  String get authRequiredSubtitle;

  /// No description provided for @authPhoneHint.
  ///
  /// In uz, this message translates to:
  /// **'90 123 45 67'**
  String get authPhoneHint;

  /// No description provided for @authSendCode.
  ///
  /// In uz, this message translates to:
  /// **'Kod olish'**
  String get authSendCode;

  /// No description provided for @authOtpTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash kodi'**
  String get authOtpTitle;

  /// No description provided for @authOtpSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'{phone} raqamiga yuborilgan 6 xonali kodni kiriting'**
  String authOtpSubtitle(String phone);

  /// No description provided for @authOtpResend.
  ///
  /// In uz, this message translates to:
  /// **'Kodni qayta yuborish'**
  String get authOtpResend;

  /// No description provided for @authOtpResendIn.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuborish {seconds} soniyadan keyin'**
  String authOtpResendIn(int seconds);

  /// No description provided for @authOtpExpiresIn.
  ///
  /// In uz, this message translates to:
  /// **'Kod {seconds} soniyadan keyin eskiradi'**
  String authOtpExpiresIn(int seconds);

  /// No description provided for @authConsentPrefix.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish orqali siz '**
  String get authConsentPrefix;

  /// No description provided for @authConsentTerms.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari'**
  String get authConsentTerms;

  /// No description provided for @authConsentAnd.
  ///
  /// In uz, this message translates to:
  /// **' va '**
  String get authConsentAnd;

  /// No description provided for @authConsentPrivacy.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get authConsentPrivacy;

  /// No description provided for @authConsentSuffix.
  ///
  /// In uz, this message translates to:
  /// **'ga rozilik bildirasiz.'**
  String get authConsentSuffix;

  /// No description provided for @authLogout.
  ///
  /// In uz, this message translates to:
  /// **'Chiqish'**
  String get authLogout;

  /// No description provided for @authErrorOtpCooldown.
  ///
  /// In uz, this message translates to:
  /// **'Kodni qayta yuborish uchun biroz kuting.'**
  String get authErrorOtpCooldown;

  /// No description provided for @authErrorOtpHourLimit.
  ///
  /// In uz, this message translates to:
  /// **'Bir soatda 5 martadan ko\'p kod so\'rab bo\'lmaydi.'**
  String get authErrorOtpHourLimit;

  /// No description provided for @authErrorOtpInvalid.
  ///
  /// In uz, this message translates to:
  /// **'Kod noto\'g\'ri. Qaytadan tekshiring.'**
  String get authErrorOtpInvalid;

  /// No description provided for @authErrorOtpExpired.
  ///
  /// In uz, this message translates to:
  /// **'Kod muddati tugadi. Yangi kod oling.'**
  String get authErrorOtpExpired;

  /// No description provided for @authErrorOtpAttempts.
  ///
  /// In uz, this message translates to:
  /// **'Urinishlar tugadi. Yangi kod oling.'**
  String get authErrorOtpAttempts;

  /// No description provided for @authErrorSmsFailed.
  ///
  /// In uz, this message translates to:
  /// **'SMS yuborilmadi. Birozdan so\'ng urinib ko\'ring.'**
  String get authErrorSmsFailed;

  /// No description provided for @authErrorInvalidPhone.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqam noto\'g\'ri.'**
  String get authErrorInvalidPhone;

  /// No description provided for @onboardingNameTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz'**
  String get onboardingNameTitle;

  /// No description provided for @onboardingNameSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalarda ko\'rsatiladi'**
  String get onboardingNameSubtitle;

  /// No description provided for @onboardingLocationTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzilingiz'**
  String get onboardingLocationTitle;

  /// No description provided for @onboardingLocationSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish narxini hisoblash uchun kerak'**
  String get onboardingLocationSubtitle;

  /// No description provided for @storeGrocery.
  ///
  /// In uz, this message translates to:
  /// **'Oziq-ovqat'**
  String get storeGrocery;

  /// No description provided for @storeHousehold.
  ///
  /// In uz, this message translates to:
  /// **'Uy jihozlari'**
  String get storeHousehold;

  /// No description provided for @storeRestaurant.
  ///
  /// In uz, this message translates to:
  /// **'Restoran'**
  String get storeRestaurant;

  /// No description provided for @storeShashlik.
  ///
  /// In uz, this message translates to:
  /// **'Shashlik'**
  String get storeShashlik;

  /// No description provided for @storeMeat.
  ///
  /// In uz, this message translates to:
  /// **'Go\'sht mahsulotlari'**
  String get storeMeat;

  /// No description provided for @cartTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savat'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Savat bo\'sh'**
  String get cartEmpty;

  /// No description provided for @cartEmptyStore.
  ///
  /// In uz, this message translates to:
  /// **'savat bo\'sh'**
  String get cartEmptyStore;

  /// No description provided for @cartMainSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Har bir do\'kon alohida yetkazadi — buyurtmalar ham alohida beriladi'**
  String get cartMainSubtitle;

  /// No description provided for @cartItemsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta'**
  String cartItemsCount(int count);

  /// No description provided for @cartCheckout.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish'**
  String get cartCheckout;

  /// No description provided for @cartTotal.
  ///
  /// In uz, this message translates to:
  /// **'Jami'**
  String get cartTotal;

  /// No description provided for @cartSubtotal.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get cartSubtotal;

  /// No description provided for @cartDeliveryFee.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish'**
  String get cartDeliveryFee;

  /// No description provided for @ordersTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get ordersTitle;

  /// No description provided for @ordersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha buyurtma yo\'q'**
  String get ordersEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiylik siyosati'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileAppVersion.
  ///
  /// In uz, this message translates to:
  /// **'Versiya {version}'**
  String profileAppVersion(String version);

  /// No description provided for @profileDeleteAccount.
  ///
  /// In uz, this message translates to:
  /// **'Hisobni o\'chirish'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hisobni butunlay o\'chirish'**
  String get profileDeleteAccountTitle;

  /// No description provided for @profileDeleteAccountWarning.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz, telefon raqamingiz, manzillaringiz, savatingiz, sevimlilaringiz va sharhlaringiz o\'chiriladi. Bu amalni qaytarib bo\'lmaydi. Tasdiqlash uchun telefoningizga SMS kod yuboramiz.'**
  String get profileDeleteAccountWarning;

  /// No description provided for @profileDeleteAccountSendCode.
  ///
  /// In uz, this message translates to:
  /// **'Kod yuborish'**
  String get profileDeleteAccountSendCode;

  /// No description provided for @profileDeleteAccountCodeHint.
  ///
  /// In uz, this message translates to:
  /// **'Telefoningizga yuborilgan kodni kiriting. Kod tasdiqlangach hisob darhol o\'chiriladi.'**
  String get profileDeleteAccountCodeHint;

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Butunlay o\'chirish'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileLanguage.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get profileLanguage;

  /// No description provided for @profileAddresses.
  ///
  /// In uz, this message translates to:
  /// **'Manzillar'**
  String get profileAddresses;

  /// No description provided for @profileNotifications.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get profileNotifications;

  /// No description provided for @profileSupport.
  ///
  /// In uz, this message translates to:
  /// **'Yordam'**
  String get profileSupport;

  /// No description provided for @languageUz.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekcha'**
  String get languageUz;

  /// No description provided for @languageUzCyrl.
  ///
  /// In uz, this message translates to:
  /// **'Ўзбекча'**
  String get languageUzCyrl;

  /// No description provided for @languageRu.
  ///
  /// In uz, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @devPlaygroundTitle.
  ///
  /// In uz, this message translates to:
  /// **'API tekshiruvi'**
  String get devPlaygroundTitle;

  /// No description provided for @devPlaygroundSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'GET /home/ javobi va til almashtirish'**
  String get devPlaygroundSubtitle;

  /// No description provided for @devFetch.
  ///
  /// In uz, this message translates to:
  /// **'So\'rov yuborish'**
  String get devFetch;

  /// No description provided for @devApiLang.
  ///
  /// In uz, this message translates to:
  /// **'Serverga yuborilgan lang'**
  String get devApiLang;

  /// No description provided for @devScript.
  ///
  /// In uz, this message translates to:
  /// **'Yozuv'**
  String get devScript;

  /// No description provided for @devResponseSize.
  ///
  /// In uz, this message translates to:
  /// **'Javob hajmi'**
  String get devResponseSize;

  /// No description provided for @devItemCount.
  ///
  /// In uz, this message translates to:
  /// **'{count, plural, =0{Element yo\'\'q} =1{1 element} other{{count} element}}'**
  String devItemCount(int count);

  /// No description provided for @errorThrottledSeconds.
  ///
  /// In uz, this message translates to:
  /// **'Juda ko\'p urinish. {seconds} soniyadan keyin urinib ko\'ring.'**
  String errorThrottledSeconds(int seconds);

  /// No description provided for @authChangeNumber.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni o\'zgartirish'**
  String get authChangeNumber;

  /// No description provided for @authOtpHint.
  ///
  /// In uz, this message translates to:
  /// **'SMS\'dagi 6 xonali kod'**
  String get authOtpHint;

  /// No description provided for @authOtpExpired.
  ///
  /// In uz, this message translates to:
  /// **'Kod muddati tugadi'**
  String get authOtpExpired;

  /// No description provided for @authPhoneInvalidOperator.
  ///
  /// In uz, this message translates to:
  /// **'Bunday operator kodi mavjud emas.'**
  String get authPhoneInvalidOperator;

  /// No description provided for @homeGreeting.
  ///
  /// In uz, this message translates to:
  /// **'Xush kelibsiz!'**
  String get homeGreeting;

  /// No description provided for @homePlaceholder.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa keyingi bosqichda quriladi.'**
  String get homePlaceholder;

  /// No description provided for @homeDeliverTitle.
  ///
  /// In uz, this message translates to:
  /// **'Uyingizga yetkazib beramiz'**
  String get homeDeliverTitle;

  /// No description provided for @homeAddressNotSelected.
  ///
  /// In uz, this message translates to:
  /// **'Manzil tanlanmagan'**
  String get homeAddressNotSelected;

  /// No description provided for @homeStoresTitle.
  ///
  /// In uz, this message translates to:
  /// **'Do\'konlar'**
  String get homeStoresTitle;

  /// No description provided for @homeRequestText.
  ///
  /// In uz, this message translates to:
  /// **'Matn'**
  String get homeRequestText;

  /// No description provided for @homeRequestImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm'**
  String get homeRequestImage;

  /// No description provided for @homeRequestVoice.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz'**
  String get homeRequestVoice;

  /// No description provided for @searchHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot qidiring'**
  String get searchHint;

  /// No description provided for @searchStartTyping.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish uchun yozishni boshlang'**
  String get searchStartTyping;

  /// No description provided for @searchEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hech narsa topilmadi'**
  String get searchEmpty;

  /// No description provided for @searchResultsCount.
  ///
  /// In uz, this message translates to:
  /// **'Natijalar {count}'**
  String searchResultsCount(int count);

  /// No description provided for @searchMissingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qidirganingiz topilmadi?'**
  String get searchMissingTitle;

  /// No description provided for @searchMissingSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q tovar buyurtmasi bering — matn, rasm yoki ovoz'**
  String get searchMissingSubtitle;

  /// No description provided for @storeComingSoon.
  ///
  /// In uz, this message translates to:
  /// **'Bu bo\'lim keyingi bosqichda quriladi'**
  String get storeComingSoon;

  /// No description provided for @profileSheetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get profileSheetTitle;

  /// No description provided for @profileUnnamed.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvchi'**
  String get profileUnnamed;

  /// No description provided for @profileChooseStore.
  ///
  /// In uz, this message translates to:
  /// **'Do\'konni tanlang'**
  String get profileChooseStore;

  /// No description provided for @notificationsComingSoon.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar tez orada'**
  String get notificationsComingSoon;

  /// No description provided for @commonDelete.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In uz, this message translates to:
  /// **'Tahrirlash'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor'**
  String get commonDone;

  /// No description provided for @commonAdd.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'shish'**
  String get commonAdd;

  /// No description provided for @navHome.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get navHome;

  /// No description provided for @navVideos.
  ///
  /// In uz, this message translates to:
  /// **'Videolar'**
  String get navVideos;

  /// No description provided for @navProducts.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get navProducts;

  /// No description provided for @navFavorites.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilar'**
  String get navFavorites;

  /// No description provided for @navCart.
  ///
  /// In uz, this message translates to:
  /// **'Savat'**
  String get navCart;

  /// No description provided for @navOrders.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar'**
  String get navOrders;

  /// No description provided for @catalogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get catalogTitle;

  /// No description provided for @catalogProductVarietyCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} xil mahsulot'**
  String catalogProductVarietyCount(int count);

  /// No description provided for @catalogAllProducts.
  ///
  /// In uz, this message translates to:
  /// **'Barcha mahsulotlar'**
  String get catalogAllProducts;

  /// No description provided for @catalogEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu do\'konda hozircha mahsulot yo\'q'**
  String get catalogEmpty;

  /// No description provided for @catalogSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Shu do\'kondan qidiring'**
  String get catalogSearchHint;

  /// No description provided for @catalogCategoryFilter.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriyalar'**
  String get catalogCategoryFilter;

  /// No description provided for @householdSectionHomeTools.
  ///
  /// In uz, this message translates to:
  /// **'Uy, qurilish va ustachilik'**
  String get householdSectionHomeTools;

  /// No description provided for @householdSectionTechTransport.
  ///
  /// In uz, this message translates to:
  /// **'Texnika va transport'**
  String get householdSectionTechTransport;

  /// No description provided for @householdSectionKitchenLiving.
  ///
  /// In uz, this message translates to:
  /// **'Oshxona va ro‘zg‘or'**
  String get householdSectionKitchenLiving;

  /// No description provided for @householdSectionClothingCare.
  ///
  /// In uz, this message translates to:
  /// **'Kiyim va shaxsiy parvarish'**
  String get householdSectionClothingCare;

  /// No description provided for @householdSectionKidsHobbyOther.
  ///
  /// In uz, this message translates to:
  /// **'Bolalar, hobbi va boshqa'**
  String get householdSectionKidsHobbyOther;

  /// No description provided for @catalogFeatured.
  ///
  /// In uz, this message translates to:
  /// **'Tavsiya etamiz'**
  String get catalogFeatured;

  /// No description provided for @catalogDiscounted.
  ///
  /// In uz, this message translates to:
  /// **'Chegirmalar'**
  String get catalogDiscounted;

  /// No description provided for @catalogPopular.
  ///
  /// In uz, this message translates to:
  /// **'Ommabop'**
  String get catalogPopular;

  /// No description provided for @catalogNew.
  ///
  /// In uz, this message translates to:
  /// **'Yangi mahsulotlar'**
  String get catalogNew;

  /// No description provided for @favoritesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sevimlilar'**
  String get favoritesTitle;

  /// No description provided for @favoritesEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bu do\'konda sevimli mahsulot yo\'q'**
  String get favoritesEmpty;

  /// No description provided for @productUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Hozir xarid qilib bo\'lmaydi'**
  String get productUnavailable;

  /// No description provided for @productSoldOut.
  ///
  /// In uz, this message translates to:
  /// **'Tugadi'**
  String get productSoldOut;

  /// No description provided for @productSoldOutDetail.
  ///
  /// In uz, this message translates to:
  /// **'Bu taom hozircha tugagan.'**
  String get productSoldOutDetail;

  /// No description provided for @paymePayButton.
  ///
  /// In uz, this message translates to:
  /// **'Payme orqali to\'lash'**
  String get paymePayButton;

  /// No description provided for @paymeCheckPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni tekshirish'**
  String get paymeCheckPayment;

  /// No description provided for @paymeUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Payme orqali to\'lov xizmati vaqtincha mavjud emas'**
  String get paymeUnavailable;

  /// No description provided for @paymePaymentPaid.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov amalga oshirildi'**
  String get paymePaymentPaid;

  /// No description provided for @paymePaymentPending.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov hali tasdiqlanmadi. Birozdan so\'ng qayta tekshiring'**
  String get paymePaymentPending;

  /// No description provided for @paymePaymentFailed.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov amalga oshmadi. Qayta urinib ko\'ring'**
  String get paymePaymentFailed;

  /// No description provided for @paymePaymentCancelled.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov bekor qilindi'**
  String get paymePaymentCancelled;

  /// No description provided for @paymeLinkOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov sahifasini ochib bo\'lmadi'**
  String get paymeLinkOpenFailed;

  /// No description provided for @productInReview.
  ///
  /// In uz, this message translates to:
  /// **'Tekshiruvda'**
  String get productInReview;

  /// No description provided for @productInReviewDetail.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot tekshiruvda. Hozircha sotib olib bo\'lmaydi.'**
  String get productInReviewDetail;

  /// No description provided for @reportProductButton.
  ///
  /// In uz, this message translates to:
  /// **'Xato mahsulot'**
  String get reportProductButton;

  /// No description provided for @reportProductConfirmTitle.
  ///
  /// In uz, this message translates to:
  /// **'Adminga yuborilsinmi?'**
  String get reportProductConfirmTitle;

  /// No description provided for @reportProductConfirmBody.
  ///
  /// In uz, this message translates to:
  /// **'Rasmi yoki kategoriyasi noto\'g\'ri mahsulot tekshiruvga yuboriladi va tuzatilguncha sotuvdan vaqtincha olinadi.'**
  String get reportProductConfirmBody;

  /// No description provided for @reportProductConfirmAction.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get reportProductConfirmAction;

  /// No description provided for @reportProductSuccess.
  ///
  /// In uz, this message translates to:
  /// **'Yuborildi. Mahsulot tekshiruvga olindi.'**
  String get reportProductSuccess;

  /// No description provided for @productChooseOptions.
  ///
  /// In uz, this message translates to:
  /// **'Tanlash'**
  String get productChooseOptions;

  /// No description provided for @productAddToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga qo\'shish'**
  String get productAddToCart;

  /// No description provided for @productBuy.
  ///
  /// In uz, this message translates to:
  /// **'Xarid qilish'**
  String get productBuy;

  /// No description provided for @productAddShort.
  ///
  /// In uz, this message translates to:
  /// **'Savatga'**
  String get productAddShort;

  /// No description provided for @productGoToCart.
  ///
  /// In uz, this message translates to:
  /// **'Savatga o\'tish'**
  String get productGoToCart;

  /// No description provided for @productAdded.
  ///
  /// In uz, this message translates to:
  /// **'Tovar savatga qo\'shildi'**
  String get productAdded;

  /// No description provided for @productImageCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta rasm'**
  String productImageCount(int count);

  /// No description provided for @productDescription.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif'**
  String get productDescription;

  /// No description provided for @productRelated.
  ///
  /// In uz, this message translates to:
  /// **'O\'xshash mahsulotlar'**
  String get productRelated;

  /// No description provided for @productVariant.
  ///
  /// In uz, this message translates to:
  /// **'Variantni tanlang'**
  String get productVariant;

  /// No description provided for @productAddons.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'shimchalar'**
  String get productAddons;

  /// No description provided for @productRequired.
  ///
  /// In uz, this message translates to:
  /// **'Majburiy'**
  String get productRequired;

  /// No description provided for @productChooseMin.
  ///
  /// In uz, this message translates to:
  /// **'Kamida ko\'rsatilgan miqdorni tanlang'**
  String get productChooseMin;

  /// No description provided for @productChooseMax.
  ///
  /// In uz, this message translates to:
  /// **'Tanlash chegarasiga yetdingiz'**
  String get productChooseMax;

  /// No description provided for @productNote.
  ///
  /// In uz, this message translates to:
  /// **'Izoh'**
  String get productNote;

  /// No description provided for @productNoteHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan, piyozsiz'**
  String get productNoteHint;

  /// No description provided for @cartClear.
  ///
  /// In uz, this message translates to:
  /// **'Savatni tozalash'**
  String get cartClear;

  /// No description provided for @cartClearConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Savatdagi barcha mahsulotlar o\'chirilsinmi?'**
  String get cartClearConfirm;

  /// No description provided for @cartEmptyHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar bo\'limidan savatga qo\'shing'**
  String get cartEmptyHint;

  /// No description provided for @cartVariant.
  ///
  /// In uz, this message translates to:
  /// **'Variant'**
  String get cartVariant;

  /// No description provided for @cartAddons.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'shimchalar'**
  String get cartAddons;

  /// No description provided for @checkoutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani rasmiylashtirish'**
  String get checkoutTitle;

  /// No description provided for @checkoutFulfillment.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish usuli'**
  String get checkoutFulfillment;

  /// No description provided for @checkoutDelivery.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazib berish'**
  String get checkoutDelivery;

  /// No description provided for @checkoutPickup.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketish'**
  String get checkoutPickup;

  /// No description provided for @checkoutAddress.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish manzili'**
  String get checkoutAddress;

  /// No description provided for @checkoutSelectAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni tanlang'**
  String get checkoutSelectAddress;

  /// No description provided for @checkoutAddAddress.
  ///
  /// In uz, this message translates to:
  /// **'Yangi manzil'**
  String get checkoutAddAddress;

  /// No description provided for @checkoutLocationPromptTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazish joylashuvini tanlang'**
  String get checkoutLocationPromptTitle;

  /// No description provided for @checkoutLocationPromptHint.
  ///
  /// In uz, this message translates to:
  /// **'Har bir buyurtma uchun yangi joylashuv qo\'shing yoki saqlangan manzilni qayta tanlang.'**
  String get checkoutLocationPromptHint;

  /// No description provided for @checkoutAddNewLocation.
  ///
  /// In uz, this message translates to:
  /// **'Yangi joylashuv qo\'shish'**
  String get checkoutAddNewLocation;

  /// No description provided for @checkoutSavedLocations.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangan manzillar'**
  String get checkoutSavedLocations;

  /// No description provided for @checkoutChooseOrChangeAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzilni tanlash yoki o\'zgartirish'**
  String get checkoutChooseOrChangeAddress;

  /// No description provided for @checkoutBranch.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketish filiali'**
  String get checkoutBranch;

  /// No description provided for @checkoutSelectBranch.
  ///
  /// In uz, this message translates to:
  /// **'Filialni tanlang'**
  String get checkoutSelectBranch;

  /// No description provided for @checkoutMixedStorePickup.
  ///
  /// In uz, this message translates to:
  /// **'Savatdagi mahsulotlar turli jismoniy do\'konlardan. Olib ketish mavjud emas; yetkazib berishni tanlang yoki savatni ajrating.'**
  String get checkoutMixedStorePickup;

  /// No description provided for @checkoutEstimateUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Bu manzilga yetkazib berish mavjud emas'**
  String get checkoutEstimateUnavailable;

  /// No description provided for @checkoutDistance.
  ///
  /// In uz, this message translates to:
  /// **'Masofa'**
  String get checkoutDistance;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov usuli'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutPayPayme.
  ///
  /// In uz, this message translates to:
  /// **'Payme'**
  String get checkoutPayPayme;

  /// No description provided for @checkoutPayCashCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryerga naqd'**
  String get checkoutPayCashCourier;

  /// No description provided for @checkoutPayCashStore.
  ///
  /// In uz, this message translates to:
  /// **'Do\'konda naqd'**
  String get checkoutPayCashStore;

  /// No description provided for @checkoutNote.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmaga izoh'**
  String get checkoutNote;

  /// No description provided for @checkoutSubmit.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani tasdiqlash'**
  String get checkoutSubmit;

  /// No description provided for @checkoutEmptyCart.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtma berish uchun savat bo\'sh'**
  String get checkoutEmptyCart;

  /// No description provided for @addressTitle.
  ///
  /// In uz, this message translates to:
  /// **'Manzil nomi'**
  String get addressTitle;

  /// No description provided for @addressTitleOptional.
  ///
  /// In uz, this message translates to:
  /// **'Manzil nomi (ixtiyoriy)'**
  String get addressTitleOptional;

  /// No description provided for @addressUnnamed.
  ///
  /// In uz, this message translates to:
  /// **'Xaritadagi manzil'**
  String get addressUnnamed;

  /// No description provided for @addressDistrict.
  ///
  /// In uz, this message translates to:
  /// **'Tuman'**
  String get addressDistrict;

  /// No description provided for @addressNeighborhood.
  ///
  /// In uz, this message translates to:
  /// **'Mahalla'**
  String get addressNeighborhood;

  /// No description provided for @addressStreet.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'cha'**
  String get addressStreet;

  /// No description provided for @addressHouse.
  ///
  /// In uz, this message translates to:
  /// **'Uy'**
  String get addressHouse;

  /// No description provided for @addressApartment.
  ///
  /// In uz, this message translates to:
  /// **'Xonadon'**
  String get addressApartment;

  /// No description provided for @addressLandmark.
  ///
  /// In uz, this message translates to:
  /// **'Mo\'ljal'**
  String get addressLandmark;

  /// No description provided for @addressSetDefault.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy manzil qilish'**
  String get addressSetDefault;

  /// No description provided for @addressChooseOnMap.
  ///
  /// In uz, this message translates to:
  /// **'Xaritada nuqtani tanlang'**
  String get addressChooseOnMap;

  /// No description provided for @addressCurrentLocation.
  ///
  /// In uz, this message translates to:
  /// **'Men turgan joylashuvni aniqlash'**
  String get addressCurrentLocation;

  /// No description provided for @mapZoomIn.
  ///
  /// In uz, this message translates to:
  /// **'Xaritani kattalashtirish'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In uz, this message translates to:
  /// **'Xaritani kichiklashtirish'**
  String get mapZoomOut;

  /// No description provided for @addressLocationDenied.
  ///
  /// In uz, this message translates to:
  /// **'Lokatsiya ruxsati berilmadi. Nuqtani xaritada qo\'lda tanlang.'**
  String get addressLocationDenied;

  /// No description provided for @addressLocationRequired.
  ///
  /// In uz, this message translates to:
  /// **'Xaritada lokatsiyani tanlang'**
  String get addressLocationRequired;

  /// No description provided for @addressesEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha manzil qo\'shilmagan'**
  String get addressesEmpty;

  /// No description provided for @addressDefaultLabel.
  ///
  /// In uz, this message translates to:
  /// **'Asosiy'**
  String get addressDefaultLabel;

  /// No description provided for @ordersToday.
  ///
  /// In uz, this message translates to:
  /// **'Bugungi'**
  String get ordersToday;

  /// No description provided for @ordersHistory.
  ///
  /// In uz, this message translates to:
  /// **'Tarix'**
  String get ordersHistory;

  /// No description provided for @ordersTodayEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bugun buyurtmalar yo\'q'**
  String get ordersTodayEmpty;

  /// No description provided for @ordersHistoryEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmalar tarixi bo\'sh'**
  String get ordersHistoryEmpty;

  /// No description provided for @ordersMoreProducts.
  ///
  /// In uz, this message translates to:
  /// **'+{count} ta mahsulot'**
  String ordersMoreProducts(Object count);

  /// No description provided for @ordersLoadMore.
  ///
  /// In uz, this message translates to:
  /// **'Yana ko\'rsatish'**
  String get ordersLoadMore;

  /// No description provided for @orderItems.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlar'**
  String get orderItems;

  /// No description provided for @orderAddress.
  ///
  /// In uz, this message translates to:
  /// **'Manzil'**
  String get orderAddress;

  /// No description provided for @orderPickupBranch.
  ///
  /// In uz, this message translates to:
  /// **'Olib ketish filiali'**
  String get orderPickupBranch;

  /// No description provided for @orderCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer'**
  String get orderCourier;

  /// No description provided for @orderCancel.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilish'**
  String get orderCancel;

  /// No description provided for @orderCancelConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmani bekor qilmoqchimisiz?'**
  String get orderCancelConfirm;

  /// No description provided for @unsupportedStoreTitle.
  ///
  /// In uz, this message translates to:
  /// **'Noma\'lum do\'kon'**
  String get unsupportedStoreTitle;

  /// No description provided for @unsupportedStoreMessage.
  ///
  /// In uz, this message translates to:
  /// **'Bu do\'kon turi ilova tomonidan qo\'llanmaydi.'**
  String get unsupportedStoreMessage;

  /// No description provided for @unsupportedStoreBack.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifaga qaytish'**
  String get unsupportedStoreBack;

  /// No description provided for @routeNotFoundTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sahifa topilmadi'**
  String get routeNotFoundTitle;

  /// No description provided for @routeNotFoundMessage.
  ///
  /// In uz, this message translates to:
  /// **'Bu havola eskirgan yoki ilovaning yangi versiyasini talab qiladi.'**
  String get routeNotFoundMessage;

  /// No description provided for @supportCenterTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yordam va murojaatlar'**
  String get supportCenterTitle;

  /// No description provided for @supportFormIntro.
  ///
  /// In uz, this message translates to:
  /// **'Kerakli mahsulotni topmadingizmi, taklifingiz yoki savolingiz bormi? Matn, rasm yoki ovoz orqali yuboring.'**
  String get supportFormIntro;

  /// No description provided for @supportMissingProductTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q tovarlar uchun zakaz berish'**
  String get supportMissingProductTitle;

  /// No description provided for @supportMissingProductSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Appda topilmagan mahsulotni bizga ayting'**
  String get supportMissingProductSubtitle;

  /// No description provided for @supportMissingProductHint.
  ///
  /// In uz, this message translates to:
  /// **'Qaysi mahsulot kerakligini batafsil yozing'**
  String get supportMissingProductHint;

  /// No description provided for @supportSuggestionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Taklif yuborish'**
  String get supportSuggestionTitle;

  /// No description provided for @supportSuggestionHint.
  ///
  /// In uz, this message translates to:
  /// **'Ilovani yaxshilash bo\'yicha taklifingizni yozing'**
  String get supportSuggestionHint;

  /// No description provided for @supportHelpTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yordam so\'rash'**
  String get supportHelpTitle;

  /// No description provided for @supportHelpHint.
  ///
  /// In uz, this message translates to:
  /// **'Muammo yoki savolingizni yozing'**
  String get supportHelpHint;

  /// No description provided for @supportStoreLabel.
  ///
  /// In uz, this message translates to:
  /// **'Do\'kon'**
  String get supportStoreLabel;

  /// No description provided for @supportMessageLabel.
  ///
  /// In uz, this message translates to:
  /// **'Xabar'**
  String get supportMessageLabel;

  /// No description provided for @supportAddImage.
  ///
  /// In uz, this message translates to:
  /// **'Rasm qo\'shish'**
  String get supportAddImage;

  /// No description provided for @supportTakePhoto.
  ///
  /// In uz, this message translates to:
  /// **'Kameradan olish'**
  String get supportTakePhoto;

  /// No description provided for @supportChooseGallery.
  ///
  /// In uz, this message translates to:
  /// **'Galereyadan tanlash'**
  String get supportChooseGallery;

  /// No description provided for @supportRecordVoice.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz yozish'**
  String get supportRecordVoice;

  /// No description provided for @supportStopRecording.
  ///
  /// In uz, this message translates to:
  /// **'To\'xtatish'**
  String get supportStopRecording;

  /// No description provided for @supportRecording.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz yozilmoqda'**
  String get supportRecording;

  /// No description provided for @supportMicrophoneDenied.
  ///
  /// In uz, this message translates to:
  /// **'Mikrofonga ruxsat berilmadi. Matn yoki rasm yuborishingiz mumkin.'**
  String get supportMicrophoneDenied;

  /// No description provided for @supportRecordingFailed.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz yozib bo\'lmadi. Qayta urinib ko\'ring.'**
  String get supportRecordingFailed;

  /// No description provided for @supportMediaReadFailed.
  ///
  /// In uz, this message translates to:
  /// **'Faylni o\'qib bo\'lmadi.'**
  String get supportMediaReadFailed;

  /// No description provided for @supportImageTooLarge.
  ///
  /// In uz, this message translates to:
  /// **'Rasm hajmi 8 MBdan oshmasligi kerak.'**
  String get supportImageTooLarge;

  /// No description provided for @supportVoiceTooLarge.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz hajmi 10 MBdan oshmasligi kerak.'**
  String get supportVoiceTooLarge;

  /// No description provided for @supportAtLeastOne.
  ///
  /// In uz, this message translates to:
  /// **'Matn yoki rasm/ovozdan kamida bittasini yuboring.'**
  String get supportAtLeastOne;

  /// No description provided for @supportSelectStore.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'q tovar uchun do\'konni tanlang.'**
  String get supportSelectStore;

  /// No description provided for @supportSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get supportSend;

  /// No description provided for @supportSending.
  ///
  /// In uz, this message translates to:
  /// **'Yuborilmoqda...'**
  String get supportSending;

  /// No description provided for @supportSent.
  ///
  /// In uz, this message translates to:
  /// **'Murojaatingiz yuborildi'**
  String get supportSent;

  /// No description provided for @supportHistory.
  ///
  /// In uz, this message translates to:
  /// **'Murojaatlar tarixi'**
  String get supportHistory;

  /// No description provided for @supportHistoryEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha murojaat yubormagansiz'**
  String get supportHistoryEmpty;

  /// No description provided for @supportStatusOpen.
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rib chiqilmoqda'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusClosed.
  ///
  /// In uz, this message translates to:
  /// **'Yakunlangan'**
  String get supportStatusClosed;

  /// No description provided for @supportContactMissing.
  ///
  /// In uz, this message translates to:
  /// **'Ism-familiya kiritilmagan'**
  String get supportContactMissing;

  /// No description provided for @supportContactNeededTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kontakt ma\'lumoti'**
  String get supportContactNeededTitle;

  /// No description provided for @supportContactNeededSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Admin siz bilan bog\'lanishi uchun ism va familiyangizni kiriting.'**
  String get supportContactNeededSubtitle;

  /// No description provided for @supportFirstName.
  ///
  /// In uz, this message translates to:
  /// **'Ism'**
  String get supportFirstName;

  /// No description provided for @supportLastName.
  ///
  /// In uz, this message translates to:
  /// **'Familiya'**
  String get supportLastName;

  /// No description provided for @supportRequestProductAction.
  ///
  /// In uz, this message translates to:
  /// **'Shu mahsulotga zakaz berish'**
  String get supportRequestProductAction;

  /// No description provided for @supportRemoveAttachment.
  ///
  /// In uz, this message translates to:
  /// **'Biriktirmani o\'chirish'**
  String get supportRemoveAttachment;

  /// No description provided for @supportImageAttached.
  ///
  /// In uz, this message translates to:
  /// **'Rasm biriktirildi'**
  String get supportImageAttached;

  /// No description provided for @supportVoiceAttached.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz biriktirildi'**
  String get supportVoiceAttached;

  /// No description provided for @supportOneAttachment.
  ///
  /// In uz, this message translates to:
  /// **'1 ta fayl'**
  String get supportOneAttachment;

  /// No description provided for @supportChooseStoreQuestion.
  ///
  /// In uz, this message translates to:
  /// **'Qaysi do\'kondan?'**
  String get supportChooseStoreQuestion;

  /// No description provided for @supportResponseHint.
  ///
  /// In uz, this message translates to:
  /// **'Operator murojaatingizni ko\'rib chiqadi'**
  String get supportResponseHint;

  /// No description provided for @videoFeedTitle.
  ///
  /// In uz, this message translates to:
  /// **'Video lenta'**
  String get videoFeedTitle;

  /// No description provided for @videoProductView.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotni ko\'rish'**
  String get videoProductView;

  /// No description provided for @videoCommentsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Izohlar'**
  String get videoCommentsTitle;

  /// No description provided for @videoCommentHint.
  ///
  /// In uz, this message translates to:
  /// **'Izoh yozing...'**
  String get videoCommentHint;

  /// No description provided for @videoCommentSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get videoCommentSend;

  /// No description provided for @videoCommentsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hali izoh yo\'q'**
  String get videoCommentsEmpty;

  /// No description provided for @videoLoadError.
  ///
  /// In uz, this message translates to:
  /// **'Videolarni yuklab bo\'lmadi.'**
  String get videoLoadError;

  /// No description provided for @videoLike.
  ///
  /// In uz, this message translates to:
  /// **'Yoqtirish'**
  String get videoLike;

  /// No description provided for @videoUnmute.
  ///
  /// In uz, this message translates to:
  /// **'Ovozni yoqish'**
  String get videoUnmute;

  /// No description provided for @videoMute.
  ///
  /// In uz, this message translates to:
  /// **'Ovozni o\'chirish'**
  String get videoMute;

  /// No description provided for @videoGoToStore.
  ///
  /// In uz, this message translates to:
  /// **'Do\'konga o\'tish'**
  String get videoGoToStore;

  /// No description provided for @videoProductsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Siz uchun mahsulotlar'**
  String get videoProductsTitle;

  /// No description provided for @videoSeeAllProducts.
  ///
  /// In uz, this message translates to:
  /// **'Barchasini ko\'rish'**
  String get videoSeeAllProducts;

  /// No description provided for @videoProductsLoadError.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulotlarni yuklab bo\'lmadi.'**
  String get videoProductsLoadError;

  /// No description provided for @videoYou.
  ///
  /// In uz, this message translates to:
  /// **'Siz'**
  String get videoYou;

  /// No description provided for @orderSearchingCourier.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer qidirilmoqda'**
  String get orderSearchingCourier;

  /// No description provided for @orderSearchingSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmangizni yetkazadigan eng yaqin kuryerni izlayapmiz'**
  String get orderSearchingSubtitle;

  /// No description provided for @orderWaitingElapsed.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda: {elapsed}'**
  String orderWaitingElapsed(Object elapsed);

  /// No description provided for @orderCourierAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer buyurtmani qabul qildi'**
  String get orderCourierAccepted;

  /// No description provided for @orderCourierAcceptedSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmangiz yetkazishga tayyorlanmoqda'**
  String get orderCourierAcceptedSubtitle;

  /// No description provided for @orderCourierOnWay.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer yo\'lda'**
  String get orderCourierOnWay;

  /// No description provided for @orderCourierOnWaySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmangiz manzilingiz tomon kelmoqda'**
  String get orderCourierOnWaySubtitle;

  /// No description provided for @orderStatusAccepted.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilindi'**
  String get orderStatusAccepted;

  /// No description provided for @orderStatusDelivering.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazilmoqda'**
  String get orderStatusDelivering;

  /// No description provided for @orderStatusDelivered.
  ///
  /// In uz, this message translates to:
  /// **'Yetkazildi'**
  String get orderStatusDelivered;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilindi'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusProcessing.
  ///
  /// In uz, this message translates to:
  /// **'Jarayonda'**
  String get orderStatusProcessing;

  /// No description provided for @orderDeliveredSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Buyurtmangiz muvaffaqiyatli yetkazildi'**
  String get orderDeliveredSubtitle;

  /// No description provided for @orderEstimatedArrival.
  ///
  /// In uz, this message translates to:
  /// **'Taxminiy yetib kelish'**
  String get orderEstimatedArrival;

  /// No description provided for @orderArrivesInMinutes.
  ///
  /// In uz, this message translates to:
  /// **'{minutes} daqiqa ichida'**
  String orderArrivesInMinutes(Object minutes);

  /// No description provided for @orderCourierNote.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer izohi'**
  String get orderCourierNote;

  /// No description provided for @orderCallCourier.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq qilish'**
  String get orderCallCourier;

  /// No description provided for @orderCopyPhone.
  ///
  /// In uz, this message translates to:
  /// **'Raqamni nusxalash'**
  String get orderCopyPhone;

  /// No description provided for @orderPhoneCopied.
  ///
  /// In uz, this message translates to:
  /// **'Telefon raqami nusxalandi'**
  String get orderPhoneCopied;

  /// No description provided for @orderLiveTracking.
  ///
  /// In uz, this message translates to:
  /// **'Jonli kuzatuv'**
  String get orderLiveTracking;

  /// No description provided for @orderLocationUpdated.
  ///
  /// In uz, this message translates to:
  /// **'Lokatsiya {seconds} soniya oldin yangilandi'**
  String orderLocationUpdated(Object seconds);

  /// No description provided for @orderLocationDelayed.
  ///
  /// In uz, this message translates to:
  /// **'Lokatsiya yangilanishi kechikmoqda'**
  String get orderLocationDelayed;

  /// No description provided for @orderLocationUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Kuryer lokatsiyasi vaqtincha mavjud emas'**
  String get orderLocationUnavailable;

  /// No description provided for @orderRouteUnavailable.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'l ma\'lumoti olinmadi. Kuryerning joriy nuqtasi ko\'rsatilmoqda.'**
  String get orderRouteUnavailable;

  /// No description provided for @orderMapEta.
  ///
  /// In uz, this message translates to:
  /// **'Xarita bo\'yicha: {minutes} daqiqa'**
  String orderMapEta(Object minutes);

  /// No description provided for @orderVehicle.
  ///
  /// In uz, this message translates to:
  /// **'Transport'**
  String get orderVehicle;

  /// No description provided for @notificationsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bildirishnomalar'**
  String get notificationsTitle;

  /// No description provided for @notificationsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha bildirishnoma yo\'q'**
  String get notificationsEmpty;

  /// No description provided for @notificationsReadAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasini o\'qish'**
  String get notificationsReadAll;

  /// No description provided for @notificationOpen.
  ///
  /// In uz, this message translates to:
  /// **'Ochish'**
  String get notificationOpen;

  /// No description provided for @productReviewsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Baho va izohlar'**
  String get productReviewsTitle;

  /// No description provided for @productReviewsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hozircha izohlar yo\'q'**
  String get productReviewsEmpty;

  /// No description provided for @productReviewWrite.
  ///
  /// In uz, this message translates to:
  /// **'Baho va izoh yozish'**
  String get productReviewWrite;

  /// No description provided for @productReviewPurchasedOnly.
  ///
  /// In uz, this message translates to:
  /// **'Bu mahsulot yetkazilgandan keyin izoh yozishingiz mumkin'**
  String get productReviewPurchasedOnly;

  /// No description provided for @productReviewAlreadyWritten.
  ///
  /// In uz, this message translates to:
  /// **'Siz bu mahsulotga allaqachon izoh yozgansiz'**
  String get productReviewAlreadyWritten;

  /// No description provided for @productReviewCommentHint.
  ///
  /// In uz, this message translates to:
  /// **'Mahsulot haqidagi fikringiz'**
  String get productReviewCommentHint;

  /// No description provided for @productReviewSubmit.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get productReviewSubmit;

  /// No description provided for @productReviewSuccess.
  ///
  /// In uz, this message translates to:
  /// **'Baho va izohingiz yuborildi'**
  String get productReviewSuccess;

  /// No description provided for @orderDeliveryWithinOneDay.
  ///
  /// In uz, this message translates to:
  /// **'1 kun ichida yetkaziladi'**
  String get orderDeliveryWithinOneDay;

  /// No description provided for @orderDeliveryWithinTwoDays.
  ///
  /// In uz, this message translates to:
  /// **'2 kun ichida yetkaziladi'**
  String get orderDeliveryWithinTwoDays;

  /// No description provided for @ugcPolicyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyat qoidalari'**
  String get ugcPolicyTitle;

  /// No description provided for @ugcPolicySummary.
  ///
  /// In uz, this message translates to:
  /// **'Izoh yozishdan oldin foydalanish shartlari va hamjamiyat qoidalariga rozilik bildiring. Haqorat, spam va nomaqbul kontent taqiqlanadi.'**
  String get ugcPolicySummary;

  /// No description provided for @ugcPolicyConsent.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari va hamjamiyat qoidalarini o\'qidim va qabul qilaman'**
  String get ugcPolicyConsent;

  /// No description provided for @ugcAccept.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish'**
  String get ugcAccept;

  /// No description provided for @ugcTerms.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanish shartlari'**
  String get ugcTerms;

  /// No description provided for @ugcCommunityGuidelines.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyat qoidalari'**
  String get ugcCommunityGuidelines;

  /// No description provided for @ugcContentActions.
  ///
  /// In uz, this message translates to:
  /// **'Kontent amallari'**
  String get ugcContentActions;

  /// No description provided for @ugcReport.
  ///
  /// In uz, this message translates to:
  /// **'Shikoyat qilish'**
  String get ugcReport;

  /// No description provided for @ugcReportTitle.
  ///
  /// In uz, this message translates to:
  /// **'Shikoyat sababini tanlang'**
  String get ugcReportTitle;

  /// No description provided for @ugcReportSubmit.
  ///
  /// In uz, this message translates to:
  /// **'Shikoyatni yuborish'**
  String get ugcReportSubmit;

  /// No description provided for @ugcReportSent.
  ///
  /// In uz, this message translates to:
  /// **'Shikoyatingiz yuborildi'**
  String get ugcReportSent;

  /// No description provided for @ugcReportDetails.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'shimcha ma\'lumot (ixtiyoriy)'**
  String get ugcReportDetails;

  /// No description provided for @ugcReasonSpam.
  ///
  /// In uz, this message translates to:
  /// **'Spam'**
  String get ugcReasonSpam;

  /// No description provided for @ugcReasonAbuse.
  ///
  /// In uz, this message translates to:
  /// **'Haqorat yoki ta\'qib'**
  String get ugcReasonAbuse;

  /// No description provided for @ugcReasonInappropriate.
  ///
  /// In uz, this message translates to:
  /// **'Nomaqbul kontent'**
  String get ugcReasonInappropriate;

  /// No description provided for @ugcReasonOther.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa sabab'**
  String get ugcReasonOther;

  /// No description provided for @ugcBlockUser.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvchini bloklash'**
  String get ugcBlockUser;

  /// No description provided for @ugcBlock.
  ///
  /// In uz, this message translates to:
  /// **'Bloklash'**
  String get ugcBlock;

  /// No description provided for @ugcUnblock.
  ///
  /// In uz, this message translates to:
  /// **'Blokdan chiqarish'**
  String get ugcUnblock;

  /// No description provided for @ugcUserBlocked.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvchi bloklandi. Uning izohlari sizga ko\'rinmaydi.'**
  String get ugcUserBlocked;

  /// No description provided for @ugcBlockedUsers.
  ///
  /// In uz, this message translates to:
  /// **'Bloklangan foydalanuvchilar'**
  String get ugcBlockedUsers;

  /// No description provided for @ugcBlockedUsersEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Bloklangan foydalanuvchilar yo\'q'**
  String get ugcBlockedUsersEmpty;

  /// No description provided for @ugcBlockConfirmation.
  ///
  /// In uz, this message translates to:
  /// **'{name} foydalanuvchisini bloklaysizmi? Uning public izoh va sharhlari sizga ko\'rinmaydi.'**
  String ugcBlockConfirmation(String name);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'uz':
      {
        switch (locale.scriptCode) {
          case 'Cyrl':
            return AppLocalizationsUzCyrl();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
