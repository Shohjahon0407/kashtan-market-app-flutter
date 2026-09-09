import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'product_models.dart';
import 'product_review_models.dart';

class CatalogApi {
  const CatalogApi(
    this._client, {
    this.cache,
    this.cacheKeySuffix,
    this.sessionSeed,
  });

  final ApiClient _client;

  /// Filtrsiz birinchi sahifa shu keshga yoziladi (oflayn fallback uchun).
  /// Testlarda mock API ishlatilgani uchun kesh umuman aralashmaydi.
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  /// Sessiyaviy random tartib urug'i: backend rasmlilarni birinchi qo'yib,
  /// har seed uchun boshqacha (lekin seed ichida barqaror) aralashtiradi.
  /// Qidiruvda va keyingi sahifalarda (`nextUrl` seed'ni o'zida saqlaydi)
  /// alohida yuborilmaydi.
  final int? sessionSeed;

  Future<CursorPage<ProductSummary>> fetchProducts({
    required String storeType,
    String? categoryId,
    String query = '',
    String? nextUrl,
  }) async {
    final trimmed = query.trim();
    final data = nextUrl != null
        ? await _client.getUrl(nextUrl)
        : await _client.get(
            trimmed.isEmpty ? Api.products : Api.productSearch,
            query: {
              'store_type': storeType,
              'page_size': 20,
              'category': ?categoryId,
              if (trimmed.isNotEmpty) 'q': trimmed,
              if (trimmed.isEmpty && sessionSeed != null) 'seed': sessionSeed,
            },
          );
    final isPlainFirstPage =
        nextUrl == null && categoryId == null && trimmed.isEmpty;
    if (isPlainFirstPage && data is Map<String, dynamic>) {
      final suffix = cacheKeySuffix?.call();
      if (cache != null && suffix != null) {
        unawaited(cache!.write(catalogCacheKey(storeType, suffix), data));
      }
    }
    return PageDecoder.cursor(data, ProductSummary.fromJson);
  }

  Future<ProductDetail> fetchDetail(String id) async {
    final data = await _client.get(Api.product(id));
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('product detail javobi obyekt emas');
    }
    // Ko'rilgan mahsulot keshda qoladi — oflaynda ham ochiladi.
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.writeJson(productCacheKey(id, suffix), data));
    }
    return ProductDetail.fromJson(data);
  }

  /// Mahsulotni "rasmi/kategoriyasi noto'g'ri" deb adminga xabar qiladi.
  /// Backend idempotent: takror yuborish ham muvaffaqiyat qaytaradi.
  Future<void> reportProduct(String id) async {
    await _client.post(Api.productReport(id));
  }

  Future<OffsetPage<ProductReview>> fetchReviews(String productId) async {
    final data = await _client.get(
      Api.productReviews(productId),
      query: {'page_size': 20},
    );
    return PageDecoder.offset(data, ProductReview.fromJson);
  }

  Future<ProductReview> createReview({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final data = await _client.post(
      Api.productReviews(productId),
      body: {'rating': rating, 'comment': comment.trim()},
    );
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('product review javobi obyekt emas');
    }
    return ProductReview.fromJson(data);
  }
}
