import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'store_models.dart';

class StoreApi {
  const StoreApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Oxirgi muvaffaqiyatli landing shu keshga yoziladi (provider o'qiydi).
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<StoreLandingData> fetchLanding(String storeType) async {
    final data = await _client.get(Api.storeLanding(storeType));
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure('store landing javobi obyekt emas');
    }
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.write(landingCacheKey(storeType, suffix), data));
    }
    return StoreLandingData.fromJson(data);
  }
}
