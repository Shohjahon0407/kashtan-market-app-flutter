import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_endpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/json_read.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../recommendations/domain/interaction_tracker.dart';
import '../data/catalog_product_images.dart';
import 'product_models.dart';

class CategoryProductBanner {
  const CategoryProductBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.cta,
    required this.imageUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.product,
  });
  factory CategoryProductBanner.fromJson(Map<String, dynamic> json) =>
      CategoryProductBanner(
        id: JsonRead.string(json['id']),
        title: JsonRead.string(json['title']),
        subtitle: JsonRead.string(json['subtitle']),
        badge: JsonRead.string(json['badge']),
        cta: JsonRead.string(json['cta']),
        imageUrl: AppConfig.resolveMediaUrl(
          JsonRead.nullableString(json['image']),
        ),
        backgroundColor: JsonRead.string(json['background_color']),
        textColor: JsonRead.string(json['text_color']),
        product: ProductSummary.fromJson(JsonRead.map(json['product']) ?? {}),
      );
  final String id, title, subtitle, badge, cta, backgroundColor, textColor;
  final String? imageUrl;
  final ProductSummary product;
}

class CategoryBannerPage {
  factory CategoryBannerPage.fromJson(Map<String, dynamic> json) =>
      CategoryBannerPage(
        JsonRead.list(json['results'], CategoryProductBanner.fromJson),
        JsonRead.nullableString(json['next']),
      );
  const CategoryBannerPage(this.items, this.nextUrl);
  final List<CategoryProductBanner> items;
  final String? nextUrl;
}

class CategoryBannersApi {
  const CategoryBannersApi(this.client, {this.cache, this.cacheSuffix = ''});
  final ApiClient client;
  final JsonDiskCache? cache;
  final String cacheSuffix;
  Future<CategoryBannerPage> fetch(String category, {String? nextUrl}) async {
    final key = 'category-banners-$category-$cacheSuffix';
    try {
      final raw = nextUrl == null
          ? await client.get(Api.categoryBanners(category))
          : await client.getUrl(nextUrl);
      final json = JsonRead.map(raw) ?? <String, dynamic>{};
      if (nextUrl == null && cache != null) unawaited(cache!.write(key, json));
      return CategoryBannerPage.fromJson(json);
    } on Object catch (error) {
      if (nextUrl == null &&
          (error is NetworkFailure || error is ServerFailure)) {
        final cached = await cache?.read(key, maxAge: const Duration(days: 1));
        if (cached != null) return CategoryBannerPage.fromJson(cached);
      }
      rethrow;
    }
  }
}

final categoryBannersApiProvider = Provider(
  (ref) => CategoryBannersApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheSuffix:
        '${ref.watch(accountScopeProvider)}-${ref.watch(localeControllerProvider).locale}',
  ),
);

class CategoryBannersState {
  const CategoryBannersState({
    this.items = const [],
    this.nextUrl,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });
  final List<CategoryProductBanner> items;
  final String? nextUrl;
  final bool loadingMore, loadMoreFailed;
}

final categoryBannersProvider = AsyncNotifierProvider.autoDispose
    .family<CategoryBannersController, CategoryBannersState, String>(
      CategoryBannersController.new,
    );

class CategoryBannersController extends AsyncNotifier<CategoryBannersState> {
  CategoryBannersController(this.category);
  final String category;
  int _generation = 0;
  @override
  Future<CategoryBannersState> build() async {
    _generation++;
    final page = await ref.watch(categoryBannersApiProvider).fetch(category);
    return CategoryBannersState(items: page.items, nextUrl: page.nextUrl);
  }

  Future<void> loadMore() async {
    final generation = _generation;
    final current = state.value;
    if (current == null || current.nextUrl == null || current.loadingMore) {
      return;
    }
    state = AsyncData(
      CategoryBannersState(
        items: current.items,
        nextUrl: current.nextUrl,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(categoryBannersApiProvider)
          .fetch(category, nextUrl: current.nextUrl);
      if (!ref.mounted || generation != _generation) return;
      final ids = current.items.map((b) => b.id).toSet();
      state = AsyncData(
        CategoryBannersState(
          items: [...current.items, ...page.items.where((b) => ids.add(b.id))],
          nextUrl: page.nextUrl == current.nextUrl ? null : page.nextUrl,
        ),
      );
    } on Object {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          CategoryBannersState(
            items: current.items,
            nextUrl: current.nextUrl,
            loadMoreFailed: true,
          ),
        );
      }
    }
  }
}

final categoryRecommendationsProvider = FutureProvider.autoDispose
    .family<List<ProductSummary>, String>((ref, category) async {
      ref.watch(apiLangProvider);
      ref.watch(accountScopeProvider);
      final page = await ref
          .watch(recommendationsApiProvider)
          .forYou(
            storeType: 'household',
            categoryId: category,
            imagesOnly: true,
            limit: 12,
          );
      // Older backend versions may ignore additive query parameters.
      return page.items
          .where(
            (p) =>
                p.storeTypeWire == 'household' &&
                p.category?.id == category &&
                catalogProductHasImage(p),
          )
          .toList();
    });
