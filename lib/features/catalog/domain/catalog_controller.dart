import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/paginated.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/store_scope/store_type.dart';
import '../../auth/domain/auth_controller.dart';
import '../data/catalog_api.dart';
import '../data/product_models.dart';
import '../data/product_review_models.dart';

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
    sessionSeed: ref.watch(catalogSessionSeedProvider),
  ),
);

/// Sessiyaviy random urug'i: app har ochilganda bitta qiymat tanlanadi va
/// sessiya davomida o'zgarmaydi (sahifalash barqaror qoladi). 1..24 oralig'i
/// ataylab tor — server anonim keshi shu variantlar orasida bo'lishib,
/// samaradorligini yo'qotmaydi.
final catalogSessionSeedProvider = Provider<int>(
  (ref) => Random().nextInt(24) + 1,
);

class CatalogState {
  const CatalogState({
    required this.items,
    this.nextUrl,
    this.categoryId,
    this.query = '',
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<ProductSummary> items;
  final String? nextUrl;
  final String? categoryId;
  final String query;
  final bool isLoadingMore;
  final ApiFailure? loadMoreFailure;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  CatalogState copyWith({
    List<ProductSummary>? items,
    String? Function()? nextUrl,
    String? Function()? categoryId,
    String? query,
    bool? isLoadingMore,
    ApiFailure? Function()? loadMoreFailure,
  }) => CatalogState(
    items: items ?? this.items,
    nextUrl: nextUrl != null ? nextUrl() : this.nextUrl,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    query: query ?? this.query,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure != null
        ? loadMoreFailure()
        : this.loadMoreFailure,
  );
}

final catalogControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CatalogController, CatalogState, StoreType>(
      (storeType) => CatalogController(storeType),
    );

class CatalogController extends AsyncNotifier<CatalogState> {
  CatalogController(this.storeType);

  final StoreType storeType;
  var _requestRevision = 0;
  var _buildRevision = 0;

  @override
  Future<CatalogState> build() async {
    // Dispose'dan keyin kechikkan javob eski instance'ga yozmasin:
    // `state` ga tegish UnmountedRefException beradi.
    ref.onDispose(() {
      _requestRevision++;
      _buildRevision++;
    });
    listenForConnectionRecovery(ref, () async {
      // A successful in-flight filter request already reconciles the screen.
      // Starting another refresh here would lose its pending category/query.
      if (!state.isLoading) await refresh();
    });
    ref.listen<String>(apiLangProvider, (previous, next) {
      if (previous != null && previous != next && state.value != null) {
        unawaited(refresh());
      }
    });
    // `ref.watch` faqat build'ning sinxron qismida ishlaydi (await'dan keyin
    // chaqirish rebuild siklini keltirib chiqaradi) — shuning uchun API
    // await'lardan OLDIN olinadi.
    final api = ref.watch(catalogApiProvider);

    // AVVAL kesh (agar bor bo'lsa) — ekran darhol to'ladi, so'ng fonda
    // yangilanadi. Ilgari kesh faqat XATODAN keyin ishlatilardi, ya'ni sekin
    // tarmoqda foydalanuvchi taymaut tugashini kutib o'tirardi.
    final cached = await _cachedState();
    if (cached != null) {
      unawaited(_revalidate(++_buildRevision));
      return cached;
    }

    try {
      final page = await api.fetchProducts(storeType: storeType.wire);
      return CatalogState(items: page.items, nextUrl: page.nextUrl);
    } on ApiFailure {
      final fallback = await _cachedState();
      if (fallback == null) rethrow;
      return fallback;
    }
  }

  /// Keshdan o'qish HECH QACHON asosiy oqimni buzmasligi kerak — kesh
  /// mavjud bo'lmasa ham (test muhiti, disk yo'q) ilova ishlayveradi.
  Future<CatalogState?> _cachedState() async {
    try {
      final cacheKey = catalogCacheKey(
        storeType.wire,
        ref.read(cacheKeySuffixProvider)(),
      );
      final cached = await ref.read(jsonDiskCacheProvider).read(cacheKey);
      if (cached == null) return null;
      final page = PageDecoder.cursor(cached, ProductSummary.fromJson);
      if (page.items.isEmpty) return null;
      // nextUrl server URL — oflaynda baribir ishlamaydi, shuning uchun yo'q.
      return CatalogState(items: page.items);
    } on Object {
      return null;
    }
  }

  /// Keshdan ko'rsatilgandan keyin fonda yangilash. Xato bo'lsa jim —
  /// ekranda kesh qoladi.
  Future<void> _revalidate(int revision) async {
    try {
      final page = await ref
          .read(catalogApiProvider)
          .fetchProducts(storeType: storeType.wire);
      if (revision != _buildRevision) return;
      state = AsyncData(CatalogState(items: page.items, nextUrl: page.nextUrl));
    } on Object {
      // Oflayn — keshdagi ko'rinish qoladi.
    }
  }

  Future<void> applyFilter({String? categoryId, String query = ''}) async {
    // Invalidate the plain-catalog cache revalidation too, not only other
    // filter requests. Its late response must not replace this selection.
    _buildRevision++;
    final normalizedQuery = query.trim();
    // Store qidiruvi har doim butun store bo'yicha ishlaydi. Aks holda avval
    // tanlangan, UI'da ko'rinmay qolgan kategoriya natijalarni nolga tushiradi.
    final normalizedCategoryId = normalizedQuery.isEmpty ? categoryId : null;
    final revision = ++_requestRevision;
    final previous = state.value;
    // Filtr o'zgarganda spinner (yangi kontent kutilmoqda). Ayni filtrni
    // yangilashda (pull-to-refresh, reconnect) esa eski ro'yxat ekranda
    // qoladi — xato bo'lsa ham 40 ta mahsulot yo'qolib ketmaydi.
    final filterChanged =
        previous == null ||
        previous.categoryId != normalizedCategoryId ||
        previous.query != normalizedQuery;
    if (filterChanged) state = const AsyncLoading();
    try {
      final page = await ref
          .read(catalogApiProvider)
          .fetchProducts(
            storeType: storeType.wire,
            categoryId: normalizedCategoryId,
            query: normalizedQuery,
          );
      if (!ref.mounted || revision != _requestRevision) return;
      state = AsyncData(
        CatalogState(
          items: page.items,
          nextUrl: page.nextUrl,
          categoryId: normalizedCategoryId,
          query: normalizedQuery,
        ),
      );
    } on Object catch (error, stack) {
      if (!ref.mounted || revision != _requestRevision) return;
      if (previous != null && (!filterChanged || error is CancelledFailure)) {
        state = AsyncData(previous.copyWith(isLoadingMore: false));
        return;
      }
      state = AsyncError(error, stack);
    }
  }

  Future<void> refresh() async {
    final current = state.value;
    await applyFilter(
      categoryId: current?.categoryId,
      query: current?.query ?? '',
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    final revision = _requestRevision;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(catalogApiProvider)
          .fetchProducts(storeType: storeType.wire, nextUrl: current.nextUrl);
      if (!ref.mounted || revision != _requestRevision) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...page.items],
          nextUrl: () => page.nextUrl,
          isLoadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      if (!ref.mounted || revision != _requestRevision) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailure: () => failure),
      );
    }
  }
}

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, String>((ref, id) async {
      ref.watch(connectivityRecoveryProvider);
      ref.watch(apiLangProvider);
      ref.watch(authControllerProvider.select((auth) => auth.isAuthenticated));
      final api = ref.watch(catalogApiProvider);
      try {
        return await api.fetchDetail(id);
      } on ApiFailure {
        // Oflayn: mahsulot avval ochilgan bo'lsa keshdan ko'rsatiladi.
        ProductDetail? cached;
        try {
          final raw = await ref
              .read(jsonDiskCacheProvider)
              .read(productCacheKey(id, ref.read(cacheKeySuffixProvider)()));
          if (raw != null) cached = ProductDetail.fromJson(raw);
        } on Object {
          cached = null; // kesh ishlamasa asl xato qaytadi
        }
        if (cached == null) rethrow;
        return cached;
      }
    });

final productReviewsProvider = FutureProvider.autoDispose
    .family<List<ProductReview>, String>((ref, productId) async {
      ref.watch(apiLangProvider);
      final page = await ref.watch(catalogApiProvider).fetchReviews(productId);
      return page.items;
    });
