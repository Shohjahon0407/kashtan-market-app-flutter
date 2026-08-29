import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'favorite_models.dart';

class FavoritesApi {
  const FavoritesApi(this._client, {this.cache, this.cacheKeySuffix});

  final ApiClient _client;

  /// Oxirgi muvaffaqiyatli ro'yxat — oflaynda shu ko'rsatiladi.
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<List<FavoriteEntry>> fetch() async {
    final data = await _client.get(Api.favorites);
    final suffix = cacheKeySuffix?.call();
    final payload = data;
    if (cache != null && suffix != null && payload != null) {
      unawaited(cache!.writeJson(favoritesCacheKey(suffix), payload as Object));
    }
    return PageDecoder.bare(data, FavoriteEntry.fromJson).items;
  }

  /// Keshdagi ro'yxat (oflayn uchun). Kesh yo'q/buzuq bo'lsa `null`.
  Future<List<FavoriteEntry>?> cachedFavorites() async {
    try {
      final suffix = cacheKeySuffix?.call();
      if (cache == null || suffix == null) return null;
      final raw = await cache!.readEntry(favoritesCacheKey(suffix));
      if (raw == null) return null;
      return PageDecoder.bare(raw.payload, FavoriteEntry.fromJson).items;
    } on Object {
      return null; // kesh hech qachon asosiy oqimni buzmaydi
    }
  }

  Future<bool> toggle(String productId) async {
    final data = await _client.post(Api.favoriteToggle(productId));
    if (data is Map<String, dynamic> && data['is_favorite'] is bool) {
      return data['is_favorite'] as bool;
    }
    return false;
  }
}
