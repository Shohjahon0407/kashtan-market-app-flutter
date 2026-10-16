import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/category_banners.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements CatalogApi {}

class _Cache extends Mock implements JsonDiskCache {}

class _Banners extends Mock implements CategoryBannersApi {}

const empty = CursorPage<ProductSummary>(items: [], nextUrl: null);
ProductSummary product(String id) => ProductSummary.fromJson({
  'id': id,
  'name': id,
  'price': '5000',
  'store_type': 'household',
});
CursorPage<ProductSummary> page(String id, {String? next}) =>
    CursorPage(items: [product(id)], nextUrl: next);

void main() {
  ProviderContainer mount(_Api api) {
    final cache = _Cache();
    when(() => cache.read(any())).thenAnswer((_) async => null);
    when(
      () => api.fetchProducts(storeType: 'household', categoryId: 'tools'),
    ).thenAnswer((_) async => empty);
    final container = ProviderContainer(
      overrides: [
        catalogApiProvider.overrideWithValue(api),
        jsonDiskCacheProvider.overrideWithValue(cache),
        apiLangProvider.overrideWithValue('uz'),
        cacheKeySuffixProvider.overrideWithValue(() => ''),
        catalogControllerProvider(StoreType.household).overrideWith(
          () => CatalogController(
            StoreType.household,
            initialCategoryId: 'tools',
          ),
        ),
      ],
    );
    final sub = container.listen(
      catalogControllerProvider(StoreType.household),
      (_, _) {},
    );
    addTearDown(sub.close);
    addTearDown(container.dispose);
    return container;
  }

  test('category matches do not issue a store-wide search', () async {
    final api = _Api();
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: 'tools',
        query: 'drel',
      ),
    ).thenAnswer((_) async => page('drel'));
    final container = mount(api);
    final provider = catalogControllerProvider(StoreType.household);
    await container.read(provider.future);
    await container
        .read(provider.notifier)
        .applyFilter(categoryId: 'tools', query: 'drel');
    expect(container.read(provider).value!.searchFallback, isFalse);
    expect(container.read(provider).value!.categoryId, 'tools');
    verifyNever(() => api.fetchProducts(storeType: 'household', query: 'drel'));
  });
  test(
    'only empty success falls back; next URL and origin category are retained',
    () async {
      final api = _Api();
      when(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: 'tools',
          query: 'choynak',
        ),
      ).thenAnswer((_) async => empty);
      when(
        () => api.fetchProducts(storeType: 'household', query: 'choynak'),
      ).thenAnswer(
        (_) async => page('other-category', next: 'next-store-results'),
      );
      final container = mount(api);
      final provider = catalogControllerProvider(StoreType.household);
      await container.read(provider.future);
      await container
          .read(provider.notifier)
          .applyFilter(categoryId: 'tools', query: 'choynak');
      final value = container.read(provider).value!;
      expect(value.searchFallback, isTrue);
      expect(value.categoryId, 'tools');
      expect(value.nextUrl, 'next-store-results');
      await container.read(provider.notifier).applyFilter(categoryId: 'tools');
      expect(container.read(provider).value!.query, '');
      expect(container.read(provider).value!.searchFallback, isFalse);
    },
  );
  test('network errors do not trigger category fallback', () async {
    final api = _Api();
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: 'tools',
        query: 'drel',
      ),
    ).thenThrow(const NetworkFailure());
    final container = mount(api);
    final provider = catalogControllerProvider(StoreType.household);
    await container.read(provider.future);
    await container
        .read(provider.notifier)
        .applyFilter(categoryId: 'tools', query: 'drel');
    expect(container.read(provider).hasError, isTrue);
    verifyNever(() => api.fetchProducts(storeType: 'household', query: 'drel'));
  });
  test('late fallback cannot replace a newer category search', () async {
    final api = _Api();
    final pending = Completer<CursorPage<ProductSummary>>();
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: 'tools',
        query: 'old',
      ),
    ).thenAnswer((_) async => empty);
    when(
      () => api.fetchProducts(storeType: 'household', query: 'old'),
    ).thenAnswer((_) => pending.future);
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: 'tools',
        query: 'new',
      ),
    ).thenAnswer((_) async => page('new'));
    final container = mount(api);
    final provider = catalogControllerProvider(StoreType.household);
    await container.read(provider.future);
    final old = container
        .read(provider.notifier)
        .applyFilter(categoryId: 'tools', query: 'old');
    await Future<void>.delayed(Duration.zero);
    await container
        .read(provider.notifier)
        .applyFilter(categoryId: 'tools', query: 'new');
    pending.complete(page('old'));
    await old;
    expect(container.read(provider).value!.items.single.id, 'new');
    expect(container.read(provider).value!.searchFallback, isFalse);
  });
  test(
    'banner pagination is single flight, deduplicated and retryable',
    () async {
      final api = _Banners();
      final request = Completer<CategoryBannerPage>();
      CategoryProductBanner banner(String id) =>
          CategoryProductBanner.fromJson({
            'id': id,
            'product': {'id': 'p', 'price': '20'},
          });
      when(
        () => api.fetch('tools'),
      ).thenAnswer((_) async => CategoryBannerPage([banner('1')], 'next'));
      when(
        () => api.fetch('tools', nextUrl: 'next'),
      ).thenAnswer((_) => request.future);
      final container = ProviderContainer(
        overrides: [categoryBannersApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final provider = categoryBannersProvider('tools');
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      final first = container.read(provider.notifier).loadMore();
      await container.read(provider.notifier).loadMore();
      request.completeError(const NetworkFailure());
      await first;
      expect(container.read(provider).value!.loadMoreFailed, isTrue);
      expect(container.read(provider).value!.items.single.id, '1');
      when(() => api.fetch('tools', nextUrl: 'next')).thenAnswer(
        (_) async => CategoryBannerPage([banner('1'), banner('2')], null),
      );
      await container.read(provider.notifier).loadMore();
      expect(container.read(provider).value!.items.map((b) => b.id), [
        '1',
        '2',
      ]);
      expect(container.read(provider).value!.nextUrl, isNull);
    },
  );
}
