import 'dart:ui' show Locale;

import 'uzbek_transliterator.dart';

/// Ilova qo'llab-quvvatlaydigan tillar.
///
/// Backend faqat `uz` va `ru` ni biladi, shuning uchun kirill o'zbek uchun ham
/// serverga `lang=uz` yuboriladi va javob client'da transliteratsiya qilinadi.
enum AppLocale {
  /// O'zbekcha, lotin yozuvi. Default.
  uz(
    locale: Locale('uz'),
    apiLang: 'uz',
    script: UzScript.none,
    nativeName: "O'zbekcha",
    shortLabel: 'UZ',
  ),

  /// Ўзбекча, кирилл ёзуви.
  uzCyrl(
    locale: Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    apiLang: 'uz',
    script: UzScript.cyrillic,
    nativeName: 'Ўзбекча',
    shortLabel: 'ЎЗ',
  ),

  /// Русский.
  ru(
    locale: Locale('ru'),
    apiLang: 'ru',
    script: UzScript.none,
    nativeName: 'Русский',
    shortLabel: 'RU',
  );

  const AppLocale({
    required this.locale,
    required this.apiLang,
    required this.script,
    required this.nativeName,
    required this.shortLabel,
  });

  /// Flutter `MaterialApp.locale` uchun.
  final Locale locale;

  /// Backendga yuboriladigan `?lang=` qiymati — FAQAT `uz` yoki `ru`.
  ///
  /// `uz-Cyrl` yuborilsa backend jimgina `uz` ga tushadi, lekin server
  /// keshining kalitini kerakmas ravishda ikkiga bo'lib yuboradi.
  final String apiLang;

  /// Server matnini qaysi yozuvga o'girish kerakligi.
  final UzScript script;

  /// Til tanlash ekranida ko'rsatiladigan nom (o'z tilida).
  final String nativeName;

  /// Kompakt ko'rsatkich (masalan AppBar dagi tugma).
  final String shortLabel;

  /// `intl` / `NumberFormat` / `DateFormat` uchun tag.
  ///
  /// `uz_Cyrl` HECH QACHON berilmaydi — `intl` da bunday locale yo'q.
  String get intlLocale => apiLang;

  /// Saqlangan kod bo'yicha tiklaydi, noma'lum bo'lsa [AppLocale.uz].
  static AppLocale fromCode(String? code) => switch (code) {
    'uz' => AppLocale.uz,
    'uz_Cyrl' || 'uz-Cyrl' => AppLocale.uzCyrl,
    'ru' => AppLocale.ru,
    _ => AppLocale.uz,
  };

  /// `shared_preferences` ga yoziladigan barqaror kod.
  String get code => switch (this) {
    AppLocale.uz => 'uz',
    AppLocale.uzCyrl => 'uz_Cyrl',
    AppLocale.ru => 'ru',
  };

  static List<Locale> get supportedLocales =>
      AppLocale.values.map((e) => e.locale).toList(growable: false);
}
