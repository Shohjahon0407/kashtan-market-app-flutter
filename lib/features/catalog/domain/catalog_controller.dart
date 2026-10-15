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
import '../../recommendations/domain/interaction_tracker.dart';
import '../../recommendations/domain/recommendations_controller.dart';
import '../data/catalog_api.dart';
import '../data/catalog_product_images.dart';
import '../data/product_models.dart';
import '../data/product_review_models.dart';

final catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
    sessionSeed: ref.watch(catalogSessionSeedProvider),
    recoSession: () => ref.read(catalogRecoSessionProvider),
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
    this.pagePhase,
    this.nextPhase,
    this.imagelessRevealed = false,
  });

  final List<ProductSummary> items;
  final String? nextUrl;
  final String? categoryId;
  final String query;
  final bool isLoadingMore;
  final ApiFailure? loadMoreFailure;
  final String? pagePhase;
  final String? nextPhase;
  final bool imagelessRevealed;

  bool get hasMore => nextUrl != null && nextUrl!.isNotEmpty;

  bool get canAutoLoadMore =>
      hasMore &&
      (query.isNotEmpty ||
          imagelessRevealed ||
          (nextPhase != 'no_image' &&
              pagePhase != 'no_image' &&
              (nextPhase != null ||
                  !items.any((p) => !catalogProductHasImage(p)))));

  bool get hasHiddenImageless =>
      query.isEmpty &&
      !imagelessRevealed &&
      (nextPhase == 'no_image' || items.any((p) => !catalogProductHasImage(p)));

  bool get canRevealImageless =>
      hasHiddenImageless && !canAutoLoadMore && !isLoadingMore;

  List<ProductSummary> get visibleItems {
    if (query.isNotEmpty) return items;
    return [
      ...items.where(catalogProductHasImage),
      if (imagelessRevealed) ...items.where((p) => !catalogProductHasImage(p)),
    ];
  }

  CatalogState copyWith({
    List<ProductSummary>? items,
    String? Function()? nextUrl,
    String? Function()? categoryId,
    String? query,
    bool? isLoadingMore,
    ApiFailure? Function()? loadMoreFailure,
    String? Function()? pagePhase,
    String? Function()? nextPhase,
    bool? imagelessRevealed,
  }) => CatalogState(
    items: items ?? this.items,
    nextUrl: nextUrl != null ? nextUrl() : this.nextUrl,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    query: query ?? this.query,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure != null
        ? loadMoreFailure()
        : this.loadMoreFailure,
    pagePhase: pagePhase != null ? pagePhase() : this.pagePhase,
    nextPhase: nextPhase != null ? nextPhase() : this.nextPhase,
    imagelessRevealed: imagelessRevealed ?? this.imagelessRevealed,
  );
}

/// Route'lar alohida [ProviderScope] ishlatsa ham bir sessiyada ko'rilgan
/// katalogni qayta ochganda API javobini kutmaslik uchun yengil xotira keshi.
/// Disk keshi oflayn/cold-start uchun, bu esa back-navigation va Web'dagi
/// takroriy kirishlarni birinchi frame'danoq silliq qiladi.
class CatalogMemoryCache {
  final Map<String, CatalogState> _values = {};

  CatalogState? read(String key) => _values[key];

  void write(String key, CatalogState value) => _values[key] = value;
}

final catalogMemoryCacheProvider = Provider<CatalogMemoryCache>(
  (ref) => CatalogMemoryCache(),
);

final catalogControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CatalogController, CatalogState, StoreType>(
      (storeType) => CatalogController(storeType),
    );

class CatalogController extends AsyncNotifier<CatalogState> {
  CatalogController(this.storeType, {this.initialCategoryId});

  final StoreType storeType;
  final String? initialCategoryId;
  var _requestRevision = 0;
  var _buildRevision = 0;

  @override
  FutureOr<CatalogState> build() {
    // Dispose'dan keyin kechikkan javob eski instance'ga yozmasin:
    // `state` ga tegish UnmountedRefException beradi.
    ref.onDispose(() {
      _requestRevision++;
      _buildRevision++;
    });
    listenForConnectionRecovery(ref, () async {
      // A successful in-flight filter request already reconciles the screen.
      // Starting another refresh here would lose its pending category/query.
      if (!state.isLoading) await refresh(resetDisclosure: false);
    });
    ref.listen<String>(apiLangProvider, (previous, next) {
      if (previous != null && previous != next && state.value != null) {
        unawaited(refresh(resetDisclosure: false));
      }
    });
    // `ref.watch` faqat build'ning sinxron qismida ishlaydi (await'dan keyin
    // chaqirish rebuild siklini keltirib chiqaradi) — shuning uchun API
    // await'lardan OLDIN olinadi.
    final api = ref.watch(catalogApiProvider);

    final memoryKey = _memoryKey(categoryId: initialCategoryId);
    final memory = ref.read(catalogMemoryCacheProvider).read(memoryKey);
    if (memory != null) {
      unawaited(_revalidate(++_buildRevision, categoryId: initialCategoryId));
      return memory.copyWith(imagelessRevealed: false);
    }

    return _loadInitial(api, categoryId: initialCategoryId);
  }

  Future<CatalogState> _loadInitial(
    CatalogApi api, {
    String? categoryId,
  }) async {
    // AVVAL kesh (agar bor bo'lsa) — ekran darhol to'ladi, so'ng fonda
    // yangilanadi. Ilgari kesh faqat XATODAN keyin ishlatilardi, ya'ni sekin
    // tarmoqda foydalanuvchi taymaut tugashini kutib o'tirardi.
    final cached = await _cachedState(categoryId: categoryId);
    if (cached != null) {
      _remember(cached);
      unawaited(_revalidate(++_buildRevision, categoryId: categoryId));
      return cached;
    }

    try {
      final page = categoryId == null
          ? await api.fetchProducts(storeType: storeType.wire)
          : await api.fetchProducts(
              storeType: storeType.wire,
              categoryId: categoryId,
            );
      final result = CatalogState(
        items: page.items,
        nextUrl: page.nextUrl,
        pagePhase: page.pagePhase,
        nextPhase: page.nextPhase,
        categoryId: categoryId,
      );
      _remember(result);
      return result;
    } on ApiFailure {
      final fallback = await _cachedState(categoryId: categoryId);
      if (fallback == null) rethrow;
      _remember(fallback);
      return fallback;
    }
  }

  /// Keshdan o'qish HECH QACHON asosiy oqimni buzmasligi kerak — kesh
  /// mavjud bo'lmasa ham (test muhiti, disk yo'q) ilova ishlayveradi.
  Future<CatalogState?> _cachedState({String? categoryId}) async {
    try {
      final suffix = ref.read(cacheKeySuffixProvider)();
      final cacheKey = categoryId == null
          ? catalogCacheKey(storeType.wire, suffix)
          : catalogCategoryCacheKey(storeType.wire, categoryId, suffix);
      final cached = await ref.read(jsonDiskCacheProvider).read(cacheKey);
      if (cached == null) return null;
      final page = PageDecoder.cursor(cached, ProductSummary.fromJson);
      if (page.items.isEmpty) return null;
      // nextUrl server URL — oflaynda baribir ishlamaydi, shuning uchun yo'q.
      return CatalogState(items: page.items, categoryId: categoryId);
    } on Object {
      return null;
    }
  }

  /// Keshdan ko'rsatilgandan keyin fonda yangilash. Xato bo'lsa jim —
  /// ekranda kesh qoladi.
  Future<void> _revalidate(int revision, {String? categoryId}) async {
    try {
      final api = ref.read(catalogApiProvider);
      final page = categoryId == null
          ? await api.fetchProducts(storeType: storeType.wire)
          : await api.fetchProducts(
              storeType: storeType.wire,
              categoryId: categoryId,
            );
      if (revision != _buildRevision) return;
      final result = CatalogState(
        items: page.items,
        nextUrl: page.nextUrl,
        pagePhase: page.pagePhase,
        nextPhase: page.nextPhase,
        imagelessRevealed: state.value?.imagelessRevealed ?? false,
        categoryId: categoryId,
      );
      _remember(result);
      state = AsyncData(result);
    } on Object {
      // Oflayn — keshdagi ko'rinish qoladi.
    }
  }

  Future<void> applyFilter({
    String? categoryId,
    String query = '',
    bool preserveDisclosure = false,
  }) async {
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
    CatalogState? fallback;
    if (filterChanged) {
      fallback = ref
          .read(catalogMemoryCacheProvider)
          .read(
            _memoryKey(
              categoryId: normalizedCategoryId,
              query: normalizedQuery,
            ),
          );
      if (fallback == null &&
          normalizedCategoryId != null &&
          normalizedQuery.isEmpty) {
        fallback = await _cachedState(categoryId: normalizedCategoryId);
      }
      if (!ref.mounted || revision != _requestRevision) return;
      state = fallback == null
          ? const AsyncLoading()
          : AsyncData(fallback.copyWith(imagelessRevealed: false));
    } else if (!preserveDisclosure && previous.imagelessRevealed) {
      state = AsyncData(previous.copyWith(imagelessRevealed: false));
    }
    try {
      final page = await ref
          .read(catalogApiProvider)
          .fetchProducts(
            storeType: storeType.wire,
            categoryId: normalizedCategoryId,
            query: normalizedQuery,
          );
      if (!ref.mounted || revision != _requestRevision) return;
      final result = CatalogState(
        items: page.items,
        nextUrl: page.nextUrl,
        pagePhase: page.pagePhase,
        nextPhase: page.nextPhase,
        imagelessRevealed:
            preserveDisclosure && !filterChanged && previous.imagelessRevealed,
        categoryId: normalizedCategoryId,
        query: normalizedQuery,
      );
      _remember(result);
      state = AsyncData(result);
      if (normalizedQuery.isNotEmpty) {
        ref
            .read(interactionTrackerProvider)
            .recordSearch(normalizedQuery, storeType: storeType);
      }
    } on Object catch (error, stack) {
      if (!ref.mounted || revision != _requestRevision) return;
      if (fallback != null) {
        state = AsyncData(fallback);
        return;
      }
      if (previous != null && (!filterChanged || error is CancelledFailure)) {
        state = AsyncData(
          previous.copyWith(
            isLoadingMore: false,
            imagelessRevealed:
                preserveDisclosure &&
                !filterChanged &&
                previous.imagelessRevealed,
          ),
        );
        return;
      }
      state = AsyncError(error, stack);
    }
  }

  Future<void> refresh({bool resetDisclosure = true}) async {
    final current = state.value;
    // Yangi sessiya — keyingi tartib so'nggi ko'rishlarni hisobga oladi.
    ref.read(catalogRecoSessionProvider.notifier).renew();
    await applyFilter(
      categoryId: current?.categoryId,
      query: current?.query ?? '',
      preserveDisclosure: !resetDisclosure,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canAutoLoadMore || current.isLoadingMore) {
      return;
    }
    // An initial cache revalidation must not truncate an expanded/paged list.
    _buildRevision++;
    final revision = _requestRevision;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: () => null),
    );
    try {
      final page = await ref
          .read(catalogApiProvider)
          .fetchProducts(storeType: storeType.wire, nextUrl: current.nextUrl);
      if (!ref.mounted || revision != _requestRevision) return;
      final result = current.copyWith(
        items: {
          for (final product in [...current.items, ...page.items])
            product.id: product,
        }.values.toList(),
        nextUrl: () => page.nextUrl,
        pagePhase: () => page.pagePhase,
        nextPhase: () => page.nextPhase,
        isLoadingMore: false,
      );
      _remember(result);
      state = AsyncData(result);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || revision != _requestRevision) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailure: () => failure),
      );
    }
  }

  Future<void> revealImageless() async {
    final current = state.value;
    if (current == null || !current.canRevealImageless) return;
    _buildRevision++;
    state = AsyncData(current.copyWith(imagelessRevealed: true));
    await loadMore();
  }

  void hideImageless() {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(imagelessRevealed: false));
    }
  }

  String _memoryKey({String? categoryId, String query = ''}) {
    // Ayrim unit-testlarda prefs/locale providerlari ataylab ulanmagan.
    // Xotira keshi optimizatsiya xolos, shuning uchun suffix olinmasa ham
    // katalogning asosiy ishlashini buzmasligi kerak.
    var suffix = '';
    try {
      suffix = ref.read(cacheKeySuffixProvider)();
    } on Object {
      // Test yoki minimal embed muhiti — store/filter kalitining o'zi yetadi.
    }
    return '${storeType.wire}|$suffix|${categoryId ?? ''}|${query.trim()}';
  }

  void _remember(CatalogState value) {
    if (!ref.mounted) return;
    ref
        .read(catalogMemoryCacheProvider)
        .write(
          _memoryKey(categoryId: value.categoryId, query: value.query),
          value.copyWith(
            isLoadingMore: false,
            loadMoreFailure: () => null,
            imagelessRevealed: false,
          ),
        );
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
