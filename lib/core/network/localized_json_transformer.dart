import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;

import '../localization/localized_keys.dart';
import '../localization/uzbek_transliterator.dart';

/// Server matnini kirillga o'giradigan YAGONA nuqta.
///
/// Nega transformer'da, model ichida emas: server matni ~55 DTO'da keladi.
/// `fromJson` yoki widget ichida transliteratsiya qilish 200+ chaqiruv nuqtasi
/// demak va biror joyni unutish kafolatlangan. Bu yerda dekodlangan JSON
/// daraxti **bir marta**, hech bir DTO uni ko'rmasdan oldin o'giriladi.
///
/// Katta javoblar (`/home/` ~15 KB, katalog sahifalari) uchun daraxt aylanishi
/// `compute()` bilan alohida izolatda bajariladi, shunda UI ipida jerk bo'lmaydi.
class LocalizedJsonTransformer extends BackgroundTransformer {
  /// [LocaleController] tomonidan til o'zgarganda yangilanadi.
  UzScript script = UzScript.none;

  /// Shu bayt hajmidan kattasi alohida izolatga uzatiladi.
  /// Kichik javoblar uchun izolat qo'zg'atish o'zi qimmatroq.
  static const int isolateThresholdBytes = 8 * 1024;

  @override
  Future<dynamic> transformResponse(
    RequestOptions options,
    ResponseBody responseBody,
  ) async {
    final decoded = await super.transformResponse(options, responseBody);
    if (script != UzScript.cyrillic) return decoded;
    if (decoded is! Map && decoded is! List) return decoded;

    final contentLength = responseBody.contentLength;
    if (contentLength > 0 && contentLength < isolateThresholdBytes) {
      return transliterateJsonTree(decoded);
    }
    return compute(transliterateJsonTree, decoded);
  }
}

/// Dekodlangan JSON daraxtini aylanib, allowlist'dagi matn maydonlarini
/// kirillga o'giradi.
///
/// Top-level funksiya — `compute()` ga uzatilishi uchun shart.
/// Kirish/chiqish faqat oddiy JSON turlari, shuning uchun izolat chegarasidan
/// muammosiz o'tadi.
Object? transliterateJsonTree(Object? node) {
  switch (node) {
    case final Map<String, dynamic> map:
      final result = <String, dynamic>{};
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is String) {
          result[entry.key] = kLocalizedKeys.contains(entry.key)
              ? UzbekTransliterator.toCyrillic(value)
              : value;
        } else {
          result[entry.key] = transliterateJsonTree(value);
        }
      }
      return result;

    case final Map<Object?, Object?> map:
      // Kalitlari String bo'lmagan map — kutilmagan, lekin buzmaymiz.
      return map;

    case final List<Object?> list:
      return list.map(transliterateJsonTree).toList();

    default:
      return node;
  }
}
