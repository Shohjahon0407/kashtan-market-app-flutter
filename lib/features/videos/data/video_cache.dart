import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ko'rilgan videolarning fayl keshi.
///
/// Oldindan HECH NARSA yuklanmaydi (egasining qarori) — faqat foydalanuvchi
/// ko'rgan video diskda qoladi va keyingi safar (shu jumladan oflaynda)
/// fayldan o'ynatiladi. Orqaga scroll qilganda ham qayta yuklanmaydi.
class VideoCache {
  static final _manager = CacheManager(
    Config(
      'bk_video_cache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 40, // ~40 ta reel — telefonni to'ldirmaydi
    ),
  );

  /// Keshda bo'lsa fayl, bo'lmasa null (yuklab O'TIRMAYDI).
  Future<File?> cachedFile(String url) async {
    if (kIsWeb) return null;
    try {
      final info = await _manager.getFileFromCache(url);
      return info?.file;
    } on Object {
      return null;
    }
  }

  /// Ayni paytda yuklanayotgan URL'lar — bir video ikki marta yuklanmasin.
  final _inFlight = <String>{};

  /// Ko'rilayotgan videoni fonda keshga tushiradi (stream'ga xalal bermaydi).
  void storeInBackground(String url) {
    if (kIsWeb || !_inFlight.add(url)) return;
    try {
      // downloadFile o'zi keshga yozadi; xatosi bizni qiziqtirmaydi.
      _manager
          .downloadFile(url)
          .whenComplete(() => _inFlight.remove(url))
          .ignore();
    } on Object {
      _inFlight.remove(url);
    }
  }
}

final videoCacheProvider = Provider<VideoCache>((ref) => VideoCache());
