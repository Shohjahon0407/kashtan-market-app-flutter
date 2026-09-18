import '../../../generated/l10n/app_localizations.dart';
import '../data/checkout_models.dart';

extension UserAddressDisplay on UserAddress {
  /// Ekranda ko'rsatiladigan nom.
  ///
  /// Manzil nomi IXTIYORIY — foydalanuvchi faqat xaritadan nuqta tanlashi
  /// yetarli. Bo'sh nom o'rniga umumiy yozuv ko'rsatiladi (bazaga yozilmaydi),
  /// aniq joy esa pastdagi [UserAddress.formattedAddress] — koordinata — bilan
  /// ko'rinadi.
  String displayTitle(AppLocalizations l10n) =>
      title.trim().isEmpty ? l10n.addressUnnamed : title.trim();
}
