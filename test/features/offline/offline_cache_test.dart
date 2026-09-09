import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

/// Riverpod 3 xatoga uchragan provayderni backoff bilan avtomatik qayta
/// uradi — testda `.future` osilib qolmasligi uchun retry o'chiriladi.
Duration? _noRetry(int retryCount, Object error) => null;

const _address = UserAddress(
  id: 'a1',
  title: 'Uy',
  latitude: 41.0,
  longitude: 69.0,
  isDefault: true,
);

void main() {
  test(
    'connection recovery refreshes an open guest catalog without losing category',
    () async {
      final api = _MockCatalogApi();
      const page = CursorPage<ProductSummary>(items: [], nextUrl: null);
      when(
        () => api.fetchProducts(storeType: 'household'),
      ).thenAnswer((_) async => page);
      when(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: 'tools',
          query: '',
        ),
      ).thenAnswer((_) async => page);
      final container = ProviderContainer(
        retry: _noRetry,
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
      await container.read(provider.notifier).applyFilter(categoryId: 'tools');
      final connectivity = container.read(
        connectivityControllerProvider.notifier,
      );
      connectivity.reportHttpResponse(503);
      await container.pump();
      connectivity.reportSuccess();
      await container.pump();
      await container.read(provider.future);
      expect(container.read(provider).value?.categoryId, 'tools');
      verify(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: 'tools',
          query: '',
        ),
      ).called(2);
    },
  );

  test('katalog: kesh bo‘lmasa tarmoq xatosi yuqoriga chiqadi', () async {
    final api = _MockCatalogApi();
    when(
      () => api.fetchProducts(storeType: 'grocery'),
    ).thenThrow(const NetworkFailure('offline'));

    final container = ProviderContainer(
      retry: _noRetry,
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        catalogApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final provider = catalogControllerProvider(StoreType.grocery);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(provider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('sevimlilar: yangilash xatosi ro‘yxatni O‘CHIRMAYDI', () async {
    final api = _MockFavoritesApi();
    when(() => api.fetch()).thenAnswer((_) async => []);
    when(() => api.cachedFavorites()).thenAnswer((_) async => null);

    final container = ProviderContainer(
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        favoritesApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      favoritesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(favoritesControllerProvider.future);

    when(() => api.fetch()).thenThrow(const NetworkFailure('offline'));
    await container.read(favoritesControllerProvider.notifier).refresh();

    final state = container.read(favoritesControllerProvider);
    expect(state.hasError, isFalse, reason: 'ekran bo‘shab qolmasligi kerak');
    expect(state.value, isNotNull);
  });

  test('manzillar: oflaynda keshdagi ro‘yxat ishlatiladi', () async {
    final api = _MockCheckoutApi();
    when(() => api.fetchAddresses()).thenThrow(const NetworkFailure('offline'));
    when(() => api.cachedAddresses()).thenAnswer((_) async => [_address]);

    final container = ProviderContainer(
      retry: _noRetry,
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        checkoutApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      addressesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final addresses = await container.read(addressesControllerProvider.future);
    expect(addresses.single.id, 'a1');
  });

  test('manzillar: kesh ham yo‘q bo‘lsa xato ko‘rsatiladi', () async {
    final api = _MockCheckoutApi();
    when(() => api.fetchAddresses()).thenThrow(const NetworkFailure('offline'));
    when(() => api.cachedAddresses()).thenAnswer((_) async => null);

    final container = ProviderContainer(
      retry: _noRetry,
      overrides: [
        apiLangProvider.overrideWithValue('uz'),
        checkoutApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      addressesControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(addressesControllerProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('CursorPage keshdagi xom javobdan tiklanadi', () {
    final page = PageDecoder.cursor(const {
      'next': null,
      'results': [
        {
          'id': 'p1',
          'name': 'Sut',
          'description': '',
          'price': '12000.00',
          'unit': 'dona',
          'store_type': 'grocery',
          'variants': <Map<String, dynamic>>[],
        },
      ],
    }, ProductSummary.fromJson);
    expect(page.items.single.id, 'p1');
  });
}
