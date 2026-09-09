import 'dart:async';

import 'package:beshkashtan_customer/core/localization/app_locale.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCache extends Mock implements JsonDiskCache {}

ProductSummary _product(String id) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'description': '',
  'price': '10000.00',
  'unit_display': 'dona',
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

void main() {
  test('late cache revalidation cannot replace a selected category', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _MockCatalogApi();
    final cache = _MockCache();
    final oldPage = Completer<CursorPage<ProductSummary>>();
    when(() => cache.read(any())).thenAnswer(
      (_) async => {
        'next': null,
        'results': [
          {
            'id': 'cached',
            'name': 'Cached',
            'price': '100',
            'store_type': 'household',
          },
        ],
      },
    );
    when(
      () => api.fetchProducts(storeType: 'household'),
    ).thenAnswer((_) => oldPage.future);
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: 'tools',
        query: '',
      ),
    ).thenAnswer(
      (_) async => CursorPage(items: [_product('filtered')], nextUrl: null),
    );
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        catalogApiProvider.overrideWithValue(api),
        jsonDiskCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    final provider = catalogControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    await container.read(provider.notifier).applyFilter(categoryId: 'tools');
    oldPage.complete(CursorPage(items: [_product('old')], nextUrl: null));
    await container.pump();
    expect(container.read(provider).value!.categoryId, 'tools');
    expect(container.read(provider).value!.items.single.id, 'filtered');
  });

  test(
    'qidiruv kategoriyani olib tashlaydi va locale bilan refetch qiladi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _MockCatalogApi();
      const emptyPage = CursorPage<ProductSummary>(items: [], nextUrl: null);
      when(
        () => api.fetchProducts(storeType: 'household'),
      ).thenAnswer((_) async => emptyPage);
      when(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: 'sovun',
        ),
      ).thenAnswer((_) async => emptyPage);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          catalogApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final provider = catalogControllerProvider(StoreType.household);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      await container
          .read(provider.notifier)
          .applyFilter(categoryId: 'category-1', query: 'sovun');

      await container.read(localeControllerProvider.notifier).set(AppLocale.ru);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final value = container.read(provider).value!;
      expect(value.categoryId, isNull);
      expect(value.query, 'sovun');
      verify(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: null,
          query: 'sovun',
        ),
      ).called(2);
    },
  );

  test('sekin eski qidiruv yangi natijani bosib ketmaydi', () async {
    final api = _MockCatalogApi();
    final oldRequest = Completer<CursorPage<ProductSummary>>();
    when(
      () => api.fetchProducts(storeType: 'household'),
    ).thenAnswer((_) async => const CursorPage(items: [], nextUrl: null));
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'eski',
      ),
    ).thenAnswer((_) => oldRequest.future);
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'yangi',
      ),
    ).thenAnswer(
      (_) async => CursorPage(items: [_product('yangi')], nextUrl: null),
    );
    final container = ProviderContainer(
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        catalogApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final provider = catalogControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final first = container.read(provider.notifier).applyFilter(query: 'eski');
    await Future<void>.delayed(Duration.zero);
    await container.read(provider.notifier).applyFilter(query: 'yangi');
    oldRequest.complete(CursorPage(items: [_product('eski')], nextUrl: null));
    await first;

    final value = container.read(provider).value!;
    expect(value.query, 'yangi');
    expect(value.items.single.id, 'yangi');
  });

  test('pagination joriy qidiruv holatini saqlaydi', () async {
    final api = _MockCatalogApi();
    const nextUrl =
        'https://api.beshkashtan.uz/api/user/catalog/products/search/'
        '?cursor=next&store_type=household&q=temir';
    when(
      () => api.fetchProducts(storeType: 'household'),
    ).thenAnswer((_) async => const CursorPage(items: [], nextUrl: null));
    when(
      () => api.fetchProducts(
        storeType: 'household',
        categoryId: null,
        query: 'temir',
      ),
    ).thenAnswer(
      (_) async => CursorPage(items: [_product('1')], nextUrl: nextUrl),
    );
    when(
      () => api.fetchProducts(storeType: 'household', nextUrl: nextUrl),
    ).thenAnswer(
      (_) async => CursorPage(items: [_product('2')], nextUrl: null),
    );
    final container = ProviderContainer(
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        catalogApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final provider = catalogControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    await container.read(provider.notifier).applyFilter(query: 'temir');
    await container.read(provider.notifier).loadMore();

    final value = container.read(provider).value!;
    expect(value.query, 'temir');
    expect(value.items.map((item) => item.id), ['1', '2']);
    expect(value.hasMore, isFalse);
  });
}
