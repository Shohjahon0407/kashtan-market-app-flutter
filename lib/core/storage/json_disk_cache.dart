import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

const _kCachedAt = 'cachedAt';
const _kPayload = 'payload';

/// Oxirgi muvaffaqiyatli JSON javoblarning diskdagi keshi.
///
/// Maqsad: sekin/uzilgan internetda app bo'sh ekran o'rniga oxirgi ma'lumotni
/// DARHOL ko'rsatsin. Bu server keshi emas — faqat o'qish tezligi va oflayn
/// chidamlilik uchun; yozuvlar `maxAge` bilan cheklanadi.
///
/// Kalitga til va yozuv (lotin/kirill) KIRITILISHI SHART — javob matni
/// transformer tomonidan transliteratsiya qilingan holda keshlanadi.
class JsonDiskCache {
  JsonDiskCache({
    this.directoryName = 'json_cache',
    this.retention = const Duration(days: 7),
    this.directoryOverride,
  });

  final String directoryName;
  final Duration? retention;
  final Directory? directoryOverride;
  bool get isPersistentAvailable =>
      !kIsWeb &&
      (directoryOverride != null ||
          Platform.environment['FLUTTER_TEST'] != 'true');
  Future<Directory?>? _dirFuture;

  Future<Directory?> _dir() => _dirFuture ??= _open();

  Future<Directory?> _open() async {
    if (!isPersistentAvailable) return null;
    // Widget-testlarda path_provider kanali javob bermay osilib qoladi —
    // test muhitida kesh butunlay o'chiq.
    try {
      if (directoryOverride != null) {
        await directoryOverride!.create(recursive: true);
        return directoryOverride;
      }
      final base = await getApplicationSupportDirectory().timeout(
        const Duration(seconds: 5),
      );
      final dir = Directory('${base.path}/$directoryName');
      await dir.create(recursive: true);
      if (retention != null) unawaited(_cleanup(dir));
      return dir;
    } on Object {
      return null; // kesh ishlamasa app keshsiz davom etadi
    }
  }

  /// 7 kundan eski fayllarni sekin-asta tozalab boradi.
  Future<void> _cleanup(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(retention!);
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        if (entry.statSync().modified.isBefore(cutoff)) {
          await entry.delete();
        }
      }
    } on Object {
      // Tozalash best-effort.
    }
  }

  /// Butun disk keshini o'chiradi — hisob o'chirilganda chaqiriladi.
  Future<void> clear() async {
    final dir = await _dir();
    if (dir == null) return;
    try {
      await for (final entry in dir.list()) {
        if (entry is File) await entry.delete();
      }
    } on Object {
      // Best-effort: kesh tozalanmasa ham hisob o'chirilgan bo'ladi.
    }
  }

  File? _file(Directory? dir, String key) {
    if (dir == null) return null;
    final safe = key.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/$safe.json');
  }

  Future<void> write(String key, Map<String, dynamic> json) =>
      writeJson(key, json);

  /// Xom JSON javobni (obyekt YOKI massiv) konvert bilan saqlaydi.
  ///
  /// Konvert `{cachedAt, payload}` — yoshni bilish uchun kerak: UI "eski
  /// ma'lumotlar" belgisini shunga qarab ko'rsatadi. Fayl mtime'iga tayanib
  /// bo'lmaydi (nusxalash/backup uni o'zgartiradi).
  Future<void> writeJson(String key, Object json) async {
    final file = _file(await _dir(), key);
    if (file == null) return;
    try {
      final envelope = <String, dynamic>{
        _kCachedAt: DateTime.now().toUtc().toIso8601String(),
        _kPayload: json,
      };
      // Yarim yozilgan fayl o'qilmasin deb vaqtinchalik nomga yozib rename.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(envelope));
      await tmp.rename(file.path);
    } on Object {
      // Disk to'la/ruxsat yo'q — jim o'tamiz, kesh majburiy emas.
    }
  }

  Future<Map<String, dynamic>?> read(String key, {Duration? maxAge}) async {
    final entry = await readEntry(key, maxAge: maxAge);
    final payload = entry?.payload;
    return payload is Map<String, dynamic> ? payload : null;
  }

  /// Massiv javoblar uchun (sevimlilar, manzillar, filiallar).
  Future<List<dynamic>?> readList(String key, {Duration? maxAge}) async {
    final entry = await readEntry(key, maxAge: maxAge);
    final payload = entry?.payload;
    return payload is List ? payload : null;
  }

  /// Yosh bilan birga o'qiydi. Eski format (konvertsiz xom map) ham o'qiladi —
  /// oldingi versiyadan yangilangan qurilmalarda kesh yo'qolmasin.
  Future<CachedEntry?> readEntry(String key, {Duration? maxAge}) async {
    final file = _file(await _dir(), key);
    if (file == null) return null;
    try {
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      final modified = file.statSync().modified;

      Object? payload;
      DateTime cachedAt;
      if (decoded is Map<String, dynamic> && decoded.containsKey(_kPayload)) {
        payload = decoded[_kPayload];
        cachedAt =
            DateTime.tryParse('${decoded[_kCachedAt]}')?.toLocal() ?? modified;
      } else {
        // Eski format: butun fayl payload, yoshi mtime bo'yicha.
        payload = decoded;
        cachedAt = modified;
      }
      if (payload == null) return null;
      if (maxAge != null && DateTime.now().difference(cachedAt) > maxAge) {
        return null;
      }
      return CachedEntry(payload: payload, cachedAt: cachedAt);
    } on Object {
      return null; // buzilgan fayl = kesh yo'q
    }
  }

  Future<void> delete(String key) async {
    final file = _file(await _dir(), key);
    if (file == null) return;
    try {
      if (file.existsSync()) await file.delete();
    } on Object {
      // Best-effort.
    }
  }
}

/// Keshdan o'qilgan yozuv — qachon saqlangani bilan birga.
class CachedEntry {
  const CachedEntry({required this.payload, required this.cachedAt});

  final Object payload;
  final DateTime cachedAt;

  Duration get age => DateTime.now().difference(cachedAt);
}

final jsonDiskCacheProvider = Provider<JsonDiskCache>((ref) => JsonDiskCache());

/// Explicit offline downloads: app support storage, not a temporary cache.
/// No age-based cleanup. Other application caches keep their existing policy.
final restaurantOfflineCacheProvider = Provider<JsonDiskCache>(
  (ref) =>
      JsonDiskCache(directoryName: 'restaurant_offline_v1', retention: null),
);

String restaurantMenuKey(String scope) => 'menu_$scope';
String restaurantLandingKey(String scope) => 'landing_$scope';
String restaurantDetailKey(String id, String scope) => 'detail_${id}_$scope';
String restaurantReviewsKey(String id, String scope) => 'reviews_${id}_$scope';
String restaurantSyncKey(String scope) => 'sync_$scope';

// Kalitlar YOZUVCHI (API klasslari) va O'QUVCHI (controllerlar) tomonlarda
// aynan bir xil bo'lishi uchun bitta joyda:
String homeCacheKey(String suffix) => 'home_$suffix';
String landingCacheKey(String storeType, String suffix) =>
    'landing_${storeType}_$suffix';
String catalogCacheKey(String storeType, String suffix) =>
    // Ushbu kataloglar barcha cursor sahifalarining aggregate snapshotidir.
    // Eski build faqat birinchi sahifani yozgan; yangi versiya uni o'qib yarim
    // katalog ko'rsatmasligi uchun kalitlar alohida versiyalanadi.
    switch (storeType) {
      'meat' => 'catalog_meat_complete_v2_$suffix',
      'shashlik' => 'catalog_shashlik_complete_v2_$suffix',
      _ => 'catalog_${storeType}_$suffix',
    };
String catalogCategoryCacheKey(
  String storeType,
  String categoryId,
  String suffix,
) => 'catalog_${storeType}_category_${categoryId}_$suffix';
String productCacheKey(String productId, String suffix) =>
    'product_${productId}_$suffix';
String ordersCacheKey(String storeType, String period, String suffix) =>
    'orders_${storeType}_${period}_$suffix';
String favoritesCacheKey(String suffix) => 'favorites_$suffix';
String addressesCacheKey(String suffix) => 'addresses_$suffix';
String notificationsCacheKey(String suffix) => 'notifications_$suffix';
String videoFeedCacheKey(String suffix) => 'videos_$suffix';
