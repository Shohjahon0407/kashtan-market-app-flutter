import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../catalog/data/restaurant_offline_repository.dart';
import 'store_models.dart';

class StoreApi {
  const StoreApi(this._client, {this.cache, this.cacheKeySuffix, this.offline});

  final ApiClient _client;
  final RestaurantOfflineRepository? offline;

  /// Oxirgi muvaffaqiyatli landing shu keshga yoziladi (provider o'qiydi).
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  Future<StoreLandingData> fetchLanding(String storeType) async {
    final raw = await _client.get(Api.storeLanding(storeType));
    if (raw is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('store landing javobi obyekt emas');
    }
    var data = raw;
    if (storeType == 'restaurant' && _usesLegacyCategoryPayload(data)) {
      try {
        data = await _withRestaurantPreviewFallback(data);
      } on Object {
        // Legacy compatibility is best-effort; keep the original images if
        // the shared catalogue request fails. Never invent product metadata.
      }
    }
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.write(landingCacheKey(storeType, suffix), data));
    }
    final landing = StoreLandingData.fromJson(data);
    if (storeType == 'restaurant') await offline?.saveLanding(data);
    return landing;
  }

  bool _usesLegacyCategoryPayload(Map<String, dynamic> landing) {
    final categories = landing['categories'];
    if (categories is! List) return false;
    return categories.whereType<Map<String, dynamic>>().any(
      (category) =>
          (category['product_count'] as num? ?? 0) > 0 &&
          category['preview_products'] is! List,
    );
  }

  Future<Map<String, dynamic>> _withRestaurantPreviewFallback(
    Map<String, dynamic> landing,
  ) async {
    final previews = <String, List<Map<String, dynamic>>>{};
    final categories = (landing['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
    for (final category in categories) {
      final id = '${category['id'] ?? ''}';
      if (id.isNotEmpty && category['preview_products'] is! List) {
        previews[id] = [];
      }
    }

    Object? page = await _client.get(
      Api.products,
      query: const {'store_type': 'restaurant', 'page_size': 100},
    );
    final visited = <String>{};
    for (var pageIndex = 0; pageIndex < 10; pageIndex++) {
      if (page is! Map<String, dynamic>) break;
      for (final rawProduct in (page['results'] as List? ?? const [])) {
        if (rawProduct is! Map<String, dynamic>) continue;
        final category = rawProduct['category'];
        if (category is! Map<String, dynamic>) continue;
        final categoryId = '${category['id'] ?? ''}';
        final products = previews[categoryId];
        final id = '${rawProduct['id'] ?? ''}'.trim();
        if (products == null ||
            products.length >= 6 ||
            id.isEmpty ||
            products.any((product) => product['id'] == id)) {
          continue;
        }
        final image = '${rawProduct['main_image'] ?? rawProduct['image'] ?? ''}'
            .trim();
        if (image.isNotEmpty) {
          products.add({
            'id': id,
            'name': rawProduct['name'],
            'image': image,
            'price': rawProduct['price'],
          });
        }
      }

      final next = '${page['next'] ?? ''}'.trim();
      if (next.isEmpty || !visited.add(next)) break;
      page = await _client.getUrl(next);
    }

    return <String, dynamic>{
      ...landing,
      'categories': [
        for (final category in categories)
          <String, dynamic>{
            ...category,
            if (previews.containsKey('${category['id'] ?? ''}')) ...{
              'preview_products': previews['${category['id'] ?? ''}'],
              if (previews['${category['id'] ?? ''}']!.isNotEmpty)
                'preview_images': [
                  for (final product in previews['${category['id'] ?? ''}']!)
                    product['image'],
                ],
            },
          },
      ],
    };
  }
}
