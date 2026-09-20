import 'package:beshkashtan_customer/app.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/app_router.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/domain/home_tab_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/home/presentation/stores_screen.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/orders_screen.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:beshkashtan_customer/features/videos/presentation/reels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockNotificationsApi extends Mock implements NotificationsApi {}

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

const _home = HomeData(
  banners: [],
  storeHub: [
    StoreHubItem(
      storeType: StoreType.meat,
      storeTypeWire: 'meat',
      label: "Go'sht",
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 0,
    ),
  ],
);

/// Home shell: Asosiy | Videolar | Do'konlar | Buyurtmalar.
void main() {
  late ProviderContainer container;
  late _MockOrdersApi ordersApi;
  var disposed = false;

  Future<void> pumpApp(
    WidgetTester tester, {
    bool authenticated = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final authApi = _MockAuthApi();
    final homeApi = _MockHomeApi();
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final notificationsApi = _MockNotificationsApi();
    ordersApi = _MockOrdersApi();
    when(() => authApi.me()).thenAnswer((_) async => _user);
    when(() => homeApi.fetch()).thenAnswer((_) async => _home);
    when(() => videoApi.fetchFeed(seed: any(named: 'seed'))).thenAnswer(
      (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
    );
    when(() => videoApi.fetchFeed()).thenAnswer(
      (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
    );
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    when(() => notificationsApi.unreadCount()).thenAnswer((_) async => 0);
    when(
      () => ordersApi.fetch(
        storeType: any(named: 'storeType'),
        period: any(named: 'period'),
      ),
    ).thenAnswer(
      (invocation) async => OffsetPage(
        items: invocation.namedArguments[#period] == 'today'
            ? [_order('o-1', 'pending'), _order('o-2', 'delivered')]
            : const <OrderData>[],
        nextUrl: null,
        count: 2,
      ),
    );
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          authenticated
              ? InMemoryTokenStore(access: 'a', refresh: 'r')
              : InMemoryTokenStore(),
        ),
        authApiProvider.overrideWithValue(authApi),
        homeApiProvider.overrideWithValue(homeApi),
        videoApiProvider.overrideWithValue(videoApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        notificationsApiProvider.overrideWithValue(notificationsApi),
        ordersApiProvider.overrideWithValue(ordersApi),
        orderRealtimeProvider.overrideWith(_NoopRealtimeController.new),
      ],
    );
    disposed = false;
    addTearDown(() {
      if (!disposed) container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
    if (authenticated) {
      await container.read(authControllerProvider.notifier).restoreSession();
    }
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    disposed = true;
    container.dispose();
  }

  testWidgets(
    'mehmon: 4 tab, Videolar/Do\'konlar ochiq, Buyurtmalar login so\'raydi',
    (tester) async {
      await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Asosiy'), findsOneWidget);
      expect(find.text('Videolar'), findsOneWidget);
      expect(find.text("Do'konlar"), findsWidgets);
      expect(find.text('Buyurtmalar'), findsOneWidget);
      // Mehmon — buyurtma so'ralmaydi.
      verifyNever(
        () => ordersApi.fetch(
          storeType: any(named: 'storeType'),
          period: any(named: 'period'),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('home-nav-videos')));
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(container.read(homeTabProvider), HomeTab.videos);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-nav-stores')));
      await tester.pumpAndSettle();
      expect(find.byType(StoresScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('home-store-meat')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-missing-product-card')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home-nav-orders')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
      expect(find.byType(OrdersScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('auth-prompt-close')));
      await tester.pumpAndSettle();

      // Android "orqa" — Do'konlar tabidan Asosiy'ga.
      expect(find.byType(StoresScreen), findsOneWidget);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(homeTabProvider), HomeTab.home);
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .path,
        Routes.home,
      );
    },
  );

  testWidgets('kirgan: Buyurtmalar tabi barcha do\'konlar, badge faol soni', (
    tester,
  ) async {
    await pumpApp(tester, authenticated: true);
    // o-1 pending faol, o-2 delivered emas → 1.
    expect(find.byKey(const ValueKey('home-nav-orders-badge-1')), findsWidgets);
    verify(() => ordersApi.fetch(storeType: null, period: 'today')).called(1);

    await tester.tap(find.byKey(const ValueKey('home-nav-orders')));
    // pumpAndSettle EMAS — buyurtma holati badge'i doimiy animatsiyali.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(
      tester.widget<OrdersScreen>(find.byType(OrdersScreen)).storeType,
      isNull,
    );
    expect(find.byKey(const ValueKey('order-store-label-o-1')), findsOneWidget);
    expect(find.text("GO'SHT"), findsWidgets);
    await unmount(tester);
  });
}

OrderData _order(String id, String status) => OrderData.fromJson({
  'id': id,
  'order_number': 'BK-1',
  'store_type': 'meat',
  'fulfillment_type': 'delivery',
  'status': status,
  'user_status': status,
  'subtotal': '12000',
  'delivery_fee': '5000',
  'total': '17000',
  'items': <Object>[],
  'created_at': '2026-09-19T10:00:00Z',
});
