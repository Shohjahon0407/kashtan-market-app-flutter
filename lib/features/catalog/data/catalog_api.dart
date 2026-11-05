import 'dart:async';

import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import 'product_models.dart';
import 'product_review_models.dart';
import 'restaurant_offline_repository.dart';

class CatalogApi {
  CatalogApi(
    this._client, {
    this.cache,
    this.cacheKeySuffix,
    this.sessionSeed,
    this.recoSession,
    this.offline,
  });

  final ApiClient _client;
  final RestaurantOfflineRepository? offline;
  final Map<String, Future<ProductDetail>> _detailFlights = {};

  /// Filtrsiz birinchi sahifa shu keshga yoziladi (oflayn fallback uchun).
  /// Testlarda mock API ishlatilgani uchun kesh umuman aralashmaydi.
  final JsonDiskCache? cache;
  final String Function()? cacheKeySuffix;

  /// Sessiyaviy random tartib urug'i: backend rasmlilarni birinchi qo'yib,
  /// har seed uchun boshqacha (lekin seed ichida barqaror) aralashtiradi.
  /// Qidiruvda va keyingi sahifalarda (`nextUrl` seed'ni o'zida saqlaydi)
  /// alohida yuborilmaydi.
  final int? sessionSeed;

  /// Shaxsiy tartib sessiyasi (`reco`): backend userning qiziqishiga qarab
  /// mos mahsulotlarni oldinga chiqaradi. Faqat oddiy ko'rishda, birinchi
  /// sahifada (keyingilarini `nextUrl` olib yuradi).
  final int? Function()? recoSession;

  Future<CursorPage<ProductSummary>> fetchProducts({
    required String storeType,
    String? categoryId,
    String query = '',
    String? nextUrl,
  }) async {
    final trimmed = query.trim();
    if (storeType == 'restaurant') {
      final saved = await offline?.products(
        categoryId: categoryId,
        query: trimmed,
      );
      if (saved != null) return saved;
    }
    Object? data = nextUrl != null
        ? await _client.getUrl(nextUrl)
        : await _client.get(
            trimmed.isEmpty ? Api.products : Api.productSearch,
            query: {
              'store_type': storeType,
              'page_size': 20,
              'category': ?categoryId,
              if (trimmed.isNotEmpty) 'q': trimmed,
              if (trimmed.isEmpty && sessionSeed != null) 'seed': sessionSeed,
              if (trimmed.isEmpty) 'reco': ?recoSession?.call(),
            },
          );
    final shouldCollectAllPages =
        nextUrl == null &&
        (storeType == 'meat' || storeType == 'shashlik') &&
        categoryId == null &&
        trimmed.isEmpty;
    if (shouldCollectAllPages) {
      data = await _collectCursorPages(data);
    }
    final isCacheableFirstPage = nextUrl == null && trimmed.isEmpty;
    if (isCacheableFirstPage && data is Map<String, dynamic>) {
      final suffix = cacheKeySuffix?.call();
      if (cache != null && suffix != null) {
        final key = categoryId == null
            ? catalogCacheKey(storeType, suffix)
            : catalogCategoryCacheKey(storeType, categoryId, suffix);
        unawaited(cache!.write(key, data));
      }
    }
    return PageDecoder.cursor(data, ProductSummary.fromJson);
  }

  /// Sanoqli mahsulotli maxsus kataloglar UI'da bir martada guruhlanadi, ammo
  /// backend rasmli/rasmsiz mahsulotlarni alohida cursor bosqichida qaytaradi.
  /// Disk keshi ham to'liq bo'lishi uchun cursorlar atomik yig'iladi: keyingi
  /// sahifa xato bersa yarim snapshot yozilmaydi.
  Future<Map<String, dynamic>> _collectCursorPages(Object? firstPage) async {
    if (firstPage is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed(
        'Aggregate katalog cursor javobi obyekt emas',
      );
    }

    final merged = <Map<String, dynamic>>[];
    final productIds = <String>{};
    final visitedUrls = <String>{};
    var page = firstPage;

    for (var pageIndex = 0; pageIndex < 20; pageIndex++) {
      final rawResults = page['results'];
      if (rawResults is! List) {
        throw const UnknownFailure.malformed(
          'Aggregate katalog cursor javobida results massivi yo\'q',
        );
      }
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final product = Map<String, dynamic>.from(raw);
        final id = '${product['id'] ?? ''}';
        if (id.isEmpty || productIds.add(id)) merged.add(product);
      }

      final next = page['next'];
      if (next == null || '$next'.isEmpty) {
        return <String, dynamic>{
          ...firstPage,
          'results': merged,
          'next': null,
          'next_phase': null,
          'previous': null,
        };
      }
      final nextUrl = '$next';
      if (!visitedUrls.add(nextUrl)) {
        throw const UnknownFailure.malformed(
          'Aggregate katalog cursor havolasi takrorlandi',
        );
      }
      final nextPage = await _client.getUrl(nextUrl);
      if (nextPage is! Map<String, dynamic>) {
        throw const UnknownFailure.malformed(
          'Aggregate katalogning keyingi sahifasi obyekt emas',
        );
      }
      page = nextPage;
    }

    throw const UnknownFailure.malformed(
      'Aggregate katalogda cursor sahifalari limiti oshdi',
    );
  }

  Future<ProductDetail> fetchDetail(String id) async {
    final pending = _detailFlights[id];
    if (pending != null) return pending;
    final future = _fetchDetail(id);
    unawaited(
      _detailFlights[id] = future,
    ); // also awaited below; concurrent readers reuse it
    try {
      return await future;
    } finally {
      unawaited(_detailFlights.remove(id));
    }
  }

  Future<ProductDetail> _fetchDetail(String id) async {
    final data = await _client.get(Api.product(id));
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('product detail javobi obyekt emas');
    }
    // Ko'rilgan mahsulot keshda qoladi — oflaynda ham ochiladi.
    final suffix = cacheKeySuffix?.call();
    if (cache != null && suffix != null) {
      unawaited(cache!.writeJson(productCacheKey(id, suffix), data));
    }
    final detail = ProductDetail.fromJson(data);
    if (detail.product.storeTypeWire == 'restaurant') {
      await offline?.saveDetail(id, data);
    }
    return detail;
  }

  /// Explicit refresh path for the background download, bypassing offline
  /// snapshots. Publish a complete cursor snapshot, never a partial first page.
  Future<CursorPage<ProductSummary>> downloadRestaurantMenu() async {
    final first = await _client.get(
      Api.products,
      query: {
        'store_type': 'restaurant',
        'page_size': 100,
        'seed': ?sessionSeed,
      },
    );
    final complete = await _collectCursorPages(first);
    final page = PageDecoder.cursor(complete, ProductSummary.fromJson);
    await offline?.saveMenu(complete);
    return page;
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
    final page = PageDecoder.offset(data, ProductReview.fromJson);
    if (data is Map<String, dynamic>) {
      await offline?.saveReviews(productId, data);
    }
    return page;
  }

  /// Offline download includes every review page, not only the first screen.
  /// A failed later page leaves the previous complete review snapshot intact.
  Future<OffsetPage<ProductReview>> downloadRestaurantReviews(
    String productId,
  ) async {
    final first = await _client.get(
      Api.productReviews(productId),
      query: {'page_size': 100},
    );
    final complete = await _collectCursorPages(first);
    final page = PageDecoder.offset(complete, ProductReview.fromJson);
    await offline?.saveReviews(productId, complete);
    return page;
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
    await offline?.invalidateProduct(productId);
    return ProductReview.fromJson(data);
  }
}
