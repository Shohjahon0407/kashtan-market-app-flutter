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
    final raw = await _client.get(Api.storeLanding(storeType));
    if (raw is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('store landing javobi obyekt emas');
    }
    var data = raw;
    if (storeType == 'restaurant' && _usesLegacyCategoryPayload(data)) {
      try {
        data = await _withRestaurantPreviewFallback(data);
      } on Object {
        // Preview rasmlar yordamchi vizual. Eski backendda mahsulot so'rovi
        // ishlamasa ham landing lokal category rasmlari bilan ochilaversin.
      }
    }
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.write(landingCacheKey(storeType, suffix), data));
    }
    return StoreLandingData.fromJson(data);
  }

  bool _usesLegacyCategoryPayload(Map<String, dynamic> landing) {
    final categories = landing['categories'];
    if (categories is! List) return false;
    return categories.whereType<Map<String, dynamic>>().any(
      (category) =>
          (category['product_count'] as num? ?? 0) > 0 &&
          !category.containsKey('preview_images'),
    );
  }

  Future<Map<String, dynamic>> _withRestaurantPreviewFallback(
    Map<String, dynamic> landing,
  ) async {
    final previews = <String, List<String>>{};
    final categories = (landing['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
    for (final category in categories) {
      final id = '${category['id'] ?? ''}';
      if (id.isNotEmpty) previews[id] = <String>[];
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
        final images = previews[categoryId];
        if (images == null || images.length >= 6) continue;
        final image = '${rawProduct['main_image'] ?? rawProduct['image'] ?? ''}'
            .trim();
        if (image.isNotEmpty && !images.contains(image)) images.add(image);
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
            'preview_images': previews['${category['id'] ?? ''}'] ?? const [],
          },
      ],
    };
  }
}
