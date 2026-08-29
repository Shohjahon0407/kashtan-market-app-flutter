import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_providers.dart';
import 'json_disk_cache.dart';

/// Xom server javoblarini keshlash uchun yagona kirish nuqtasi.
///
/// Nega xom javob darajasida: DTO'larda `toJson` yo'q (faqat `fromJson`), ya'ni
/// dekodlangan modelni diskka qaytarib bo'lmaydi. Shuning uchun kesh
/// dekodlashdan OLDIN, javobning o'zi ustida ishlaydi.
class ResponseCache {
  const ResponseCache(this._cache, this._suffix);

  final JsonDiskCache _cache;
  final String Function() _suffix;

  /// Kalitni joriy til/yozuv bilan to'ldiradi — kirill va lotin javoblari
  /// aralashib ketmasligi uchun.
  String key(String Function(String suffix) builder) => builder(_suffix());

  /// Javobni fon rejimida keshga yozadi (chaqiruvchini kutdirmaydi).
  void put(String cacheKey, Object json) =>
      unawaited(_cache.writeJson(cacheKey, json));

  Future<Map<String, dynamic>?> readMap(String cacheKey, {Duration? maxAge}) =>
      _cache.read(cacheKey, maxAge: maxAge);

  Future<List<dynamic>?> readList(String cacheKey, {Duration? maxAge}) =>
      _cache.readList(cacheKey, maxAge: maxAge);

  Future<CachedEntry?> readEntry(String cacheKey, {Duration? maxAge}) =>
      _cache.readEntry(cacheKey, maxAge: maxAge);

  /// Keshdagi javobni dekodlab qaytaradi; kesh yo'q/buzuq bo'lsa `null`.
  ///
  /// Dekodlash xatosi ham `null` beradi — eski formatdagi kesh yangi model
  /// bilan mos kelmasa ilova yiqilmasligi kerak.
  Future<T?> decodeMap<T>(
    String cacheKey,
    T Function(Map<String, dynamic> json) decode, {
    Duration? maxAge,
  }) async {
    final raw = await readMap(cacheKey, maxAge: maxAge);
    if (raw == null) return null;
    try {
      return decode(raw);
    } on Object {
      return null;
    }
  }

  Future<T?> decodeList<T>(
    String cacheKey,
    T Function(List<dynamic> json) decode, {
    Duration? maxAge,
  }) async {
    final raw = await readList(cacheKey, maxAge: maxAge);
    if (raw == null) return null;
    try {
      return decode(raw);
    } on Object {
      return null;
    }
  }
}

final responseCacheProvider = Provider<ResponseCache>(
  (ref) => ResponseCache(
    ref.watch(jsonDiskCacheProvider),
    ref.watch(cacheKeySuffixProvider),
  ),
);
