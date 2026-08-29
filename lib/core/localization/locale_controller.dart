import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_store.dart';
import 'app_locale.dart';

/// `PrefsStore` `runApp` dan oldin yuklanadi va shu yerda override qilinadi.
final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw StateError('prefsStoreProvider override qilinmagan'),
);

/// Tanlangan til. YAGONA yozuvchi — [LocaleController].
final localeControllerProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);

class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final prefs = ref.read(prefsStoreProvider);
    return AppLocale.fromCode(prefs.localeCode);
  }

  Future<void> set(AppLocale locale) async {
    if (locale == state) return;
    state = locale;
    await ref.read(prefsStoreProvider).setLocaleCode(locale.code);
  }
}

/// Serverga yuboriladigan `lang` — faqat `uz` yoki `ru`.
final apiLangProvider = Provider<String>(
  (ref) => ref.watch(localeControllerProvider).apiLang,
);

/// Material/Cupertino lokalizatsiyasida `uz_Cyrl` yo'q.
///
/// Flutter `uz` uchun tarjimalarga ega, lekin `Locale(uz, Cyrl)` ni
/// qo'llab-quvvatlanmagan deb hisoblaydi va ilova ishga tushmaydi.
/// Bu delegate uni jimgina `uz` ga tushiradi.
class ScriptFallbackDelegate<T> extends LocalizationsDelegate<T> {
  const ScriptFallbackDelegate(this._inner, this._fallback);

  final LocalizationsDelegate<T> _inner;
  final Locale _fallback;

  /// Bazadagi `Type get type => T` ga TAYANMAYMIZ.
  ///
  /// `const [...]` ro'yxati `List<LocalizationsDelegate<dynamic>>` konteksida
  /// bo'lsa, Dart `T` ni `dynamic` deb chiqaradi va delegate `dynamic` kaliti
  /// ostida ro'yxatdan o'tadi. Natijada `MaterialLocalizations` umuman
  /// topilmaydi ("No MaterialLocalizations found") — chunki
  /// `DefaultMaterialLocalizations` faqat `en` ni qo'llab-quvvatlaydi va
  /// o'rnini bosa olmaydi. O'ralgan delegate'ning turini olish bu xatoni
  /// tur chiqarilishidan qat'i nazar yo'q qiladi.
  @override
  Type get type => _inner.type;

  @override
  bool isSupported(Locale locale) =>
      _inner.isSupported(locale) || _inner.isSupported(_resolve(locale));

  @override
  Future<T> load(Locale locale) => _inner.load(_resolve(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;

  Locale _resolve(Locale locale) =>
      locale.scriptCode == 'Cyrl' && locale.languageCode == 'uz'
      ? _fallback
      : locale;
}
