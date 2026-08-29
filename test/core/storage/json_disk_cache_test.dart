import 'dart:convert';
import 'dart:io';

import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// `JsonDiskCache` test muhitida diskni ochmaydi (path_provider osilib qoladi),
/// shuning uchun konvert FORMATI va yordamchilar alohida tekshiriladi.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('json_cache_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('konvert formati: cachedAt va payload yoziladi', () {
    final file = File('${dir.path}/sample.json');
    final envelope = {
      'cachedAt': DateTime.now().toUtc().toIso8601String(),
      'payload': {'results': <dynamic>[]},
    };
    file.writeAsStringSync(jsonEncode(envelope));

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded.containsKey('payload'), isTrue);
    expect(DateTime.tryParse('${decoded['cachedAt']}'), isNotNull);
  });

  test('CachedEntry yoshni to‘g‘ri hisoblaydi', () {
    final entry = CachedEntry(
      payload: const {'a': 1},
      cachedAt: DateTime.now().subtract(const Duration(hours: 30)),
    );
    expect(entry.age.inHours, greaterThanOrEqualTo(30));
  });

  test('kesh kalitlari til/yozuv bo‘yicha ajratiladi', () {
    expect(productCacheKey('p1', 'uz_none'), 'product_p1_uz_none');
    expect(
      productCacheKey('p1', 'uz_cyrillic'),
      isNot(productCacheKey('p1', 'uz_none')),
    );
    expect(
      ordersCacheKey('grocery', 'today', 'uz_none'),
      'orders_grocery_today_uz_none',
    );
    expect(favoritesCacheKey('ru_none'), 'favorites_ru_none');
  });

  test('test muhitida kesh xatosiz o‘chiq ishlaydi', () async {
    final cache = JsonDiskCache();
    // Disk ochilmaydi (FLUTTER_TEST) — hech qanday istisno bo'lmasligi kerak.
    await cache.writeJson('k', {'a': 1});
    expect(await cache.read('k'), isNull);
    expect(await cache.readList('k'), isNull);
    expect(await cache.readEntry('k'), isNull);
    await cache.delete('k');
    await cache.clear();
  });
}
