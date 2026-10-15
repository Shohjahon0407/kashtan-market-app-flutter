import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_product_images.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements CatalogApi {}

class _Cache extends Mock implements JsonDiskCache {}

ProductSummary product(
  String id, {
  bool image = true,
  String name = 'Product',
  String store = 'grocery',
}) => ProductSummary.fromJson({
  'id': id,
  'name': name,
  'price': '100',
  'store_type': store,
  'main_image': image ? 'https://example.test/$id.jpg' : null,
});

void main() {
  ProviderContainer mount(_Api api, {Map<String, dynamic>? cachedData}) {
    final cache = _Cache();
    when(() => cache.read(any())).thenAnswer((_) async => cachedData);
    final container = ProviderContainer(
      overrides: [
        catalogApiProvider.overrideWithValue(api),
        apiLangProvider.overrideWithValue('uz'),
        cacheKeySuffixProvider.overrideWithValue(() => ''),
        jsonDiskCacheProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      catalogControllerProvider(StoreType.grocery),
      (_, _) {},
    );
    addTearDown(sub.close);
    return container;
  }

  test(
    'old mixed/cache lists partition stably; no image-only URL is required',
    () {
      final state = CatalogState(
        items: [product('n', image: false), product('a'), product('b')],
      );
      expect(state.visibleItems.map((p) => p.id), ['a', 'b']);
      expect(state.canRevealImageless, isTrue);
      expect(
        state.copyWith(imagelessRevealed: true).visibleItems.map((p) => p.id),
        ['a', 'b', 'n'],
      );
      expect(const CatalogState(items: []).canRevealImageless, isFalse);
      expect(
        CatalogState(items: [product('n', image: false)]).visibleItems,
        isEmpty,
      );
      expect(
        CatalogState(items: [product('n', image: false)]).canRevealImageless,
        isTrue,
      );
    },
  );

  test('only actual product-specific meat fallback counts as image', () {
    for (final name in [
      'Qo‘y go‘shti',
      'Mol go‘shti',
      'Ot go‘shi',
      'Qazi',
      'Mol jigar',
      'Qo‘y jigar',
    ]) {
      expect(
        catalogProductHasImage(
          product('1', image: false, name: name, store: 'meat'),
        ),
        isTrue,
      );
    }
    expect(
      catalogProductHasImage(
        product('1', image: false, name: 'Unknown', store: 'meat'),
      ),
      isFalse,
    );
    expect(catalogProductHasImage(product('1', image: false)), isFalse);
  });

  test(
    'cursor phase fields are optional and decoded without inspecting URLs',
    () {
      final page = PageDecoder.cursor<ProductSummary>({
        'results': <Object?>[],
        'next': 'opaque',
        'page_phase': 'image',
        'next_phase': 'no_image',
      }, ProductSummary.fromJson);
      expect(page.pagePhase, 'image');
      expect(page.nextPhase, 'no_image');
      expect(
        PageDecoder.cursor<ProductSummary>({
          'results': <Object?>[],
          'next': null,
        }, ProductSummary.fromJson).nextPhase,
        isNull,
      );
    },
  );

  test(
    'auto loads all image pages, stops before imageless, reveal submits once and deduplicates',
    () async {
      final api = _Api();
      when(() => api.fetchProducts(storeType: 'grocery')).thenAnswer(
        (_) async => CursorPage(
          items: [product('a')],
          nextUrl: 'images-2',
          pagePhase: 'image',
          nextPhase: 'image',
        ),
      );
      when(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'images-2'),
      ).thenAnswer(
        (_) async => CursorPage(
          items: [product('b')],
          nextUrl: 'hidden',
          pagePhase: 'image',
          nextPhase: 'no_image',
        ),
      );
      final pending = Completer<CursorPage<ProductSummary>>();
      when(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
      ).thenAnswer((_) => pending.future);
      final container = mount(api);
      final provider = catalogControllerProvider(StoreType.grocery);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      await controller.loadMore();
      await controller.loadMore();
      verifyNever(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
      );
      expect(container.read(provider).value!.visibleItems.map((p) => p.id), [
        'a',
        'b',
      ]);
      final first = controller.revealImageless();
      await controller.revealImageless();
      pending.complete(
        CursorPage(
          items: [product('b'), product('n', image: false)],
          nextUrl: null,
          pagePhase: 'no_image',
        ),
      );
      await first;
      verify(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
      ).called(1);
      expect(container.read(provider).value!.visibleItems.map((p) => p.id), [
        'a',
        'b',
        'n',
      ]);
      // Memory snapshots retain products, but not the user's disclosure intent.
      final cached = container
          .read(catalogMemoryCacheProvider)
          .read('grocery|||');
      expect(cached?.imagelessRevealed, isFalse);
    },
  );

  test(
    'failed reveal retains image rows and can retry the same cursor',
    () async {
      final api = _Api();
      when(() => api.fetchProducts(storeType: 'grocery')).thenAnswer(
        (_) async => CursorPage(
          items: [product('a')],
          nextUrl: 'hidden',
          pagePhase: 'image',
          nextPhase: 'no_image',
        ),
      );
      when(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
      ).thenThrow(const NetworkFailure());
      final container = mount(api);
      final provider = catalogControllerProvider(StoreType.grocery);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      await controller.revealImageless();
      expect(container.read(provider).value!.visibleItems.single.id, 'a');
      expect(
        container.read(provider).value!.loadMoreFailure,
        isA<NetworkFailure>(),
      );
      when(
        () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
      ).thenAnswer(
        (_) async =>
            CursorPage(items: [product('n', image: false)], nextUrl: null),
      );
      await controller.loadMore();
      expect(container.read(provider).value!.visibleItems.map((p) => p.id), [
        'a',
        'n',
      ]);
    },
  );

  test(
    'search never hides imageless; clearing and refresh reset disclosure',
    () async {
      final api = _Api();
      final mixed = CursorPage(
        items: [product('a'), product('n', image: false)],
        nextUrl: null,
      );
      when(
        () => api.fetchProducts(storeType: 'grocery'),
      ).thenAnswer((_) async => mixed);
      when(
        () => api.fetchProducts(
          storeType: 'grocery',
          categoryId: null,
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => mixed);
      final container = mount(api);
      final provider = catalogControllerProvider(StoreType.grocery);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      await controller.revealImageless();
      expect(container.read(provider).value!.visibleItems, hasLength(2));
      await controller.refresh();
      expect(container.read(provider).value!.visibleItems, hasLength(1));
      await controller.applyFilter(query: 'Product');
      expect(container.read(provider).value!.visibleItems, hasLength(2));
      await controller.applyFilter(query: '');
      expect(container.read(provider).value!.visibleItems, hasLength(1));
    },
  );

  test('late imageless response cannot replace a new category', () async {
    final api = _Api();
    when(() => api.fetchProducts(storeType: 'grocery')).thenAnswer(
      (_) async => CursorPage(
        items: [product('a')],
        nextUrl: 'hidden',
        pagePhase: 'image',
        nextPhase: 'no_image',
      ),
    );
    final pending = Completer<CursorPage<ProductSummary>>();
    when(
      () => api.fetchProducts(storeType: 'grocery', nextUrl: 'hidden'),
    ).thenAnswer((_) => pending.future);
    when(
      () =>
          api.fetchProducts(storeType: 'grocery', categoryId: 'new', query: ''),
    ).thenAnswer(
      (_) async => CursorPage(items: [product('new')], nextUrl: null),
    );
    final container = mount(api);
    final provider = catalogControllerProvider(StoreType.grocery);
    await container.read(provider.future);
    final controller = container.read(provider.notifier);
    final reveal = controller.revealImageless();
    await controller.applyFilter(categoryId: 'new');
    pending.complete(
      CursorPage(items: [product('old', image: false)], nextUrl: null),
    );
    await reveal;
    expect(container.read(provider).value!.visibleItems.single.id, 'new');
    expect(container.read(provider).value!.imagelessRevealed, isFalse);
  });

  test(
    'late first-page cache revalidation cannot close a disclosed list',
    () async {
      final api = _Api();
      final pending = Completer<CursorPage<ProductSummary>>();
      when(
        () => api.fetchProducts(storeType: 'grocery'),
      ).thenAnswer((_) => pending.future);
      final container = mount(
        api,
        cachedData: {
          'next': null,
          'results': [
            {
              'id': 'a',
              'main_image': 'https://example.test/a.jpg',
              'store_type': 'grocery',
            },
            {'id': 'n', 'store_type': 'grocery'},
          ],
        },
      );
      final provider = catalogControllerProvider(StoreType.grocery);
      await container.read(provider.future);
      await container.read(provider.notifier).revealImageless();
      pending.complete(CursorPage(items: [product('a')], nextUrl: null));
      await container.pump();
      expect(container.read(provider).value!.visibleItems.map((p) => p.id), [
        'a',
        'n',
      ]);
    },
  );

  test(
    'offline cache hides imageless and never persists disclosure on a fresh provider',
    () async {
      final api = _Api();
      final cache = _Cache();
      when(
        () => api.fetchProducts(storeType: 'grocery'),
      ).thenThrow(const NetworkFailure());
      when(() => cache.read(any())).thenAnswer(
        (_) async => {
          'next': 'unavailable-offline',
          'next_phase': 'no_image',
          'imageless_revealed': true,
          'results': [
            {
              'id': 'a',
              'main_image': 'https://example.test/a.jpg',
              'store_type': 'grocery',
            },
            {'id': 'n', 'main_image': null, 'store_type': 'grocery'},
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          catalogApiProvider.overrideWithValue(api),
          jsonDiskCacheProvider.overrideWithValue(cache),
          cacheKeySuffixProvider.overrideWithValue(() => 'test'),
          apiLangProvider.overrideWithValue('uz'),
        ],
      );
      addTearDown(container.dispose);
      final provider = catalogControllerProvider(StoreType.grocery);
      var sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      await container.pump();
      expect(container.read(provider).value!.visibleItems.single.id, 'a');
      expect(container.read(provider).value!.hasMore, isFalse);
      await container.read(provider.notifier).revealImageless();
      expect(container.read(provider).value!.visibleItems, hasLength(2));
      sub.close();
      await container.pump();
      sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      await container.pump();
      expect(container.read(provider).value!.visibleItems.single.id, 'a');
    },
  );
}
