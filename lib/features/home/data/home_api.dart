import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'home_models.dart';

class HomeApi {
  const HomeApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Oxirgi muvaffaqiyatli javob shu keshga yoziladi — app keyingi ochilishda
  /// avval keshni ko'rsatadi (controller o'qiydi).
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  /// Bosh ekran ma'lumoti. `lang` interceptor avtomatik qo'shadi.
  Future<HomeData> fetch() async {
    final data = await _client.get(Api.home);
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure('home javobi obyekt emas');
    }
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.write(homeCacheKey(suffix), data));
    }
    return HomeData.fromJson(data);
  }
}
