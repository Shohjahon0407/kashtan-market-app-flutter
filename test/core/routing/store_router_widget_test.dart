import 'dart:async';

import 'package:beshkashtan_customer/app.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/app_router.dart';
import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/app_update/presentation/update_navigation_gate.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/catalog_screen.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorite_models.dart';
import 'package:beshkashtan_customer/features/favorites/data/favorites_api.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/favorites/presentation/favorites_screen.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/orders_screen.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/features/store/data/store_api.dart';
import 'package:beshkashtan_customer/features/store/data/store_models.dart';
import 'package:beshkashtan_customer/features/store/domain/store_landing_controller.dart';
import 'package:beshkashtan_customer/features/store/presentation/unsupported_store_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_recommendations_api.dart';
import '../../helpers/reveal_imageless.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _MockStoreApi extends Mock implements StoreApi {}

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockFavoritesApi extends Mock implements FavoritesApi {}

class _MockOrdersApi extends Mock implements OrdersApi {}

class _NoopRealtimeController extends OrderRealtimeController {
  @override
  OrderRealtimeState build() =>
      const OrderRealtimeState(status: OrderSocketStatus.disconnected);
}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: 'Ali',
  lastName: 'Valiyev',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: false,
  missingFields: [],
);

StoreLandingData landing(StoreType type) => StoreLandingData(
  header: StoreHeader(
    storeTypeWire: type.wire,
    label: type.wire,
    subtitle: '',
    isEnabled: true,
    showHeader: false,
  ),
  categories: const [],
  stores: const [],
  banners: const [],
  sections: const [],
);

void main() {
  testWidgets('barcha store va 4 tab route’i real routerda ochiladi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final authApi = _MockAuthApi();
    final homeApi = _MockHomeApi();
    final storeApi = _MockStoreApi();
    final catalogApi = _MockCatalogApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final favoritesApi = _MockFavoritesApi();
    final ordersApi = _MockOrdersApi();
    when(() => authApi.me()).thenAnswer((_) async => _user);
    when(
      () => homeApi.fetch(),
    ).thenAnswer((_) async => const HomeData(banners: [], storeHub: []));
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
    for (final type in StoreType.values) {
      when(
        () => storeApi.fetchLanding(type.wire),
      ).thenAnswer((_) async => landing(type));
      when(() => catalogApi.fetchProducts(storeType: type.wire)).thenAnswer(
        (_) async => const CursorPage<ProductSummary>(items: [], nextUrl: null),
      );
      when(
        () => catalogApi.fetchProducts(
          storeType: type.wire,
          categoryId: 'test-category',
        ),
      ).thenAnswer(
        (_) async => const CursorPage<ProductSummary>(items: [], nextUrl: null),
      );
      when(
        () => cartApi.fetch(type.wire),
      ).thenAnswer((_) async => CartData.empty(type.wire));
      when(
        () => ordersApi.fetch(
          storeType: type.wire,
          period: any(named: 'period'),
        ),
      ).thenAnswer(
        (_) async => const OffsetPage(items: [], nextUrl: null, count: 0),
      );
    }

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'access', refresh: 'refresh'),
        ),
        authApiProvider.overrideWithValue(authApi),
        homeApiProvider.overrideWithValue(homeApi),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
        storeApiProvider.overrideWithValue(storeApi),
        catalogApiProvider.overrideWithValue(catalogApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        addressLocationAccessProvider.overrideWithValue(() async {
          throw const DeviceLocationException(DeviceLocationFailure.denied);
        }),
        favoritesApiProvider.overrideWithValue(favoritesApi),
        ordersApiProvider.overrideWithValue(ordersApi),
        orderRealtimeProvider.overrideWith(_NoopRealtimeController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    for (final type in StoreType.values) {
      router.go(Routes.home);
      AppBackCoordinator.of(router).clear();
      await tester.pumpAndSettle();
      unawaited(router.push<void>(Routes.storeCatalog(type.wire)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('store-nav-favorites')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('store-nav-orders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('store-nav-cart')));
      await tester.pumpAndSettle();
      for (final expected in [
        Routes.storeOrders(type.wire),
        Routes.storeFavorites(type.wire),
        Routes.storeCatalog(type.wire),
      ]) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(AppBackCoordinator.of(router).location, expected);
      }
      await tester.tap(find.byKey(const ValueKey('catalog-cart-button')));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CatalogScreen), findsOneWidget);
      expect(
        AppBackCoordinator.of(router).location,
        Routes.storeCatalog(type.wire),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await AppBackCoordinator.of(router).back(), isFalse);
      await tester.pumpAndSettle();

      // Returning to Products from Cart must unwind that tab excursion,
      // rather than make the catalog's back arrow open Cart again.
      for (final systemBack in [false, true]) {
        unawaited(router.push<void>(Routes.storeCatalog(type.wire)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('catalog-cart-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('store-nav-catalog')));
        await tester.pumpAndSettle();
        if (systemBack) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byIcon(Icons.arrow_back));
        }
        await tester.pumpAndSettle();
        expect(AppBackCoordinator.of(router).location, Routes.home);
        expect(find.byType(HomeScreen), findsOneWidget);
      }

      unawaited(router.push<void>(Routes.storeCatalog(type.wire)));
      await tester.pumpAndSettle();
      unawaited(
        router.push<void>(
          Routes.storeCategoryProducts(type.wire, 'test-category'),
        ),
      );
      await tester.pumpAndSettle();
      // Predictive/native back reaches the enclosing root Navigator rather
      // than the Router dispatcher. It must pop the category, not the store.
      await container
          .read(appRootNavigatorKeyProvider)
          .currentState!
          .maybePop();
      await tester.pumpAndSettle();
      expect(
        AppBackCoordinator.of(router).location,
        Routes.storeCatalog(type.wire),
      );
      unawaited(
        router.push<void>(
          Routes.storeCategoryProducts(type.wire, 'test-category'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-cart-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('store-nav-catalog')));
      await tester.pumpAndSettle();
      expect(
        AppBackCoordinator.of(router).location,
        Routes.storeCatalog(type.wire),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(AppBackCoordinator.of(router).location, Routes.home);
    }

    // Opening detail/back must preserve disclosure in the existing catalog.
    final imageless = ProductSummary.fromJson({
      'id': 'no-photo',
      'name': 'Rasmsiz mahsulot',
      'price': '1000',
      'store_type': 'grocery',
    });
    when(
      () => catalogApi.fetchProducts(storeType: 'grocery'),
    ).thenAnswer((_) async => CursorPage(items: [imageless], nextUrl: null));
    when(() => catalogApi.fetchDetail('no-photo')).thenAnswer(
      (_) async => ProductDetail(
        product: imageless,
        images: const [],
        addonGroups: const [],
        relatedProducts: const [],
      ),
    );
    unawaited(router.push<void>(Routes.storeCatalog('grocery')));
    await tester.pumpAndSettle();
    await revealImagelessProducts(tester);
    await tester.ensureVisible(find.text('Rasmsiz mahsulot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rasmsiz mahsulot'));
    await tester.pumpAndSettle();
    expect(
      AppBackCoordinator.of(router).location,
      Routes.productDetail('grocery', 'no-photo'),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Rasmsiz mahsulot'), findsOneWidget);
    expect(find.byKey(const ValueKey('imageless-reveal-button')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    router.go(Routes.cart);
    await tester.pumpAndSettle();
    expect(find.byType(MainCartScreen), findsOneWidget);

    for (final type in StoreType.values) {
      router.go(Routes.storeCatalog(type.wire));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CatalogScreen>(find.byType(CatalogScreen)).storeType,
        type,
      );
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      router.go(Routes.storeFavorites(type.wire));
      await tester.pumpAndSettle();
      expect(find.byType(FavoritesScreen), findsOneWidget);

      router.go(Routes.storeCart(type.wire));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);

      router.go(Routes.storeOrders(type.wire));
      await tester.pumpAndSettle();
      expect(find.byType(OrdersScreen), findsOneWidget);
    }

    router.go(Routes.storeCatalog(StoreType.household.wire));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    router.go('/store/future-store/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(UnsupportedStoreScreen), findsOneWidget);
  });

  testWidgets('catalog savati va navbar branch rootlarini aralashtirmaydi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final authApi = _MockAuthApi();
    final homeApi = _MockHomeApi();
    final storeApi = _MockStoreApi();
    final catalogApi = _MockCatalogApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final favoritesApi = _MockFavoritesApi();
    final ordersApi = _MockOrdersApi();
    when(() => authApi.me()).thenAnswer((_) async => _user);
    when(
      () => homeApi.fetch(),
    ).thenAnswer((_) async => const HomeData(banners: [], storeHub: []));
    when(() => favoritesApi.fetch()).thenAnswer((_) async => <FavoriteEntry>[]);
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
    for (final type in StoreType.values) {
      when(
        () => storeApi.fetchLanding(type.wire),
      ).thenAnswer((_) async => landing(type));
      when(() => catalogApi.fetchProducts(storeType: type.wire)).thenAnswer(
        (_) async => const CursorPage<ProductSummary>(items: [], nextUrl: null),
      );
      when(
        () => cartApi.fetch(type.wire),
      ).thenAnswer((_) async => CartData.empty(type.wire));
      when(
        () => ordersApi.fetch(
          storeType: type.wire,
          period: any(named: 'period'),
        ),
      ).thenAnswer(
        (_) async => const OffsetPage(items: [], nextUrl: null, count: 0),
      );
    }

    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'access', refresh: 'refresh'),
        ),
        authApiProvider.overrideWithValue(authApi),
        homeApiProvider.overrideWithValue(homeApi),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
        storeApiProvider.overrideWithValue(storeApi),
        catalogApiProvider.overrideWithValue(catalogApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        addressLocationAccessProvider.overrideWithValue(() async {
          throw const DeviceLocationException(DeviceLocationFailure.denied);
        }),
        favoritesApiProvider.overrideWithValue(favoritesApi),
        ordersApiProvider.overrideWithValue(ordersApi),
        orderRealtimeProvider.overrideWith(_NoopRealtimeController.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
    await container.read(authControllerProvider.notifier).restoreSession();
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    router.go(Routes.storeCatalog(StoreType.household.wire));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.byKey(const ValueKey('catalog-cart-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.byType(CatalogScreen), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.byKey(const ValueKey('store-nav-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(find.byType(CartScreen), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    router.go(Routes.checkout(StoreType.household.wire));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );

    await tester.tap(find.byKey(const ValueKey('store-nav-catalog')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });
}
