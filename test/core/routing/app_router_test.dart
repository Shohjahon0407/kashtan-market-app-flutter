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
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/presentation/screens/phone_screen.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/otp_code_field.dart';
import 'package:beshkashtan_customer/features/auth/presentation/widgets/phone_field.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/address_form_screen.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/delivery_address_screen.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/home/presentation/profile_screen.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_recommendations_api.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _MockVideoApi extends Mock implements VideoApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockCheckoutApi extends Mock implements CheckoutApi {}

class _MockNotificationsApi extends Mock implements NotificationsApi {}

class _MockOrdersApi extends Mock implements OrdersApi {}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: '',
  lastName: '',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: true, // router BUNI e'tiborga olmasligi kerak
  missingFields: ['full_name', 'location'],
);

const _homeWithStore = HomeData(
  banners: [],
  storeHub: [
    StoreHubItem(
      storeType: StoreType.household,
      storeTypeWire: 'household',
      label: 'Xozmak',
      subtitle: 'Uy uchun mahsulotlar',
      imageUrl: null,
      accentColor: null,
      sortOrder: 0,
    ),
  ],
);

const _routeAddress = UserAddress(
  id: 'saved',
  title: 'Uy',
  isDefault: true,
  latitude: 41.31,
  longitude: 69.24,
);
const _routeBranch = DeliveryCoverageBranch(
  id: 'branch',
  name: 'Store',
  latitude: 41.31,
  longitude: 69.24,
  radiusKm: 2,
);

class _RoutingAddresses extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => [_routeAddress];
  @override
  Future<void> refresh() async {}
  @override
  Future<UserAddress> save(UserAddress address) async {
    final saved = UserAddress(
      id: address.id.isEmpty ? 'created' : address.id,
      title: address.title,
      isDefault: address.isDefault,
      latitude: address.latitude,
      longitude: address.longitude,
    );
    state = AsyncData([...state.value!.where((a) => a.id != saved.id), saved]);
    return saved;
  }
}

void main() {
  late _MockAuthApi api;
  late ProviderContainer container;
  var containerDisposed = false;

  /// Kirgan foydalanuvchida Home shell badge uchun `OrdersController`
  /// (yarim tungi refresh Timer'i) tirik — testdan oldin daraxt bilan birga
  /// container ham yopiladi, aks holda `!timersPending` xatosi.
  Future<void> unmountApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    if (!containerDisposed) {
      containerDisposed = true;
      container.dispose();
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    String? access,
    String? refresh,
    HomeData homeData = const HomeData(banners: [], storeHub: []),
    bool deliveryCart = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _MockAuthApi();
    final homeApi = _MockHomeApi();
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final notificationsApi = _MockNotificationsApi();
    final ordersApi = _MockOrdersApi();
    when(() => homeApi.fetch()).thenAnswer((_) async => homeData);
    when(
      () => ordersApi.fetch(
        storeType: any(named: 'storeType'),
        period: any(named: 'period'),
      ),
    ).thenAnswer(
      (_) async => const OffsetPage(items: [], nextUrl: null, count: 0),
    );
    when(() => videoApi.fetchFeed()).thenAnswer(
      (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
    );
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    if (deliveryCart) {
      when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
      when(() => cartApi.fetch('household')).thenAnswer(
        (_) async => CartData.fromJson({
          'id': 'cart',
          'store_type': 'household',
          'subtotal': '8000',
          'minimum_delivery_order_amount': '20000',
          'total_items': 1,
          'total_quantity': 1,
          'items': [
            {
              'id': 'line',
              'quantity': 1,
              'subtotal': '8000',
              'product': {
                'id': 'product',
                'name': 'Buyum',
                'price': '8000',
                'store_type': 'household',
                'store': {
                  'id': 'store',
                  'name': 'Xozmak',
                  'store_type': 'household',
                },
              },
            },
          ],
        }),
      );
      when(
        () => checkoutApi.fetchCoverage('household'),
      ).thenAnswer((_) async => [_routeBranch]);
      when(
        () => checkoutApi.fetchBranches('store'),
      ).thenAnswer((_) async => []);
      when(
        () => checkoutApi.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer(
        (_) async => const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '5000',
          branch: _routeBranch,
        ),
      );
    }
    when(() => notificationsApi.unreadCount()).thenAnswer((_) async => 0);
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: access, refresh: refresh),
        ),
        authApiProvider.overrideWithValue(api),
        homeApiProvider.overrideWithValue(homeApi),
        recommendationsApiProvider.overrideWithValue(FakeRecommendationsApi()),
        videoApiProvider.overrideWithValue(videoApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        if (deliveryCart) ...[
          addressesControllerProvider.overrideWith(_RoutingAddresses.new),
          addressCoverageProvider.overrideWith((_) async => [_routeBranch]),
          addressLocationAccessProvider.overrideWithValue(() async {
            throw const DeviceLocationException(DeviceLocationFailure.denied);
          }),
          addressLocationResolverProvider.overrideWithValue(() async {
            throw const DeviceLocationException(DeviceLocationFailure.denied);
          }),
        ],
        notificationsApiProvider.overrideWithValue(notificationsApi),
        ordersApiProvider.overrideWithValue(ordersApi),
      ],
    );
    containerDisposed = false;
    addTearDown(() {
      if (!containerDisposed) {
        containerDisposed = true;
        container.dispose();
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
  }

  AuthController auth() => container.read(authControllerProvider.notifier);

  testWidgets('kirilmagan guest → Home ekrani', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneScreen), findsNothing);
  });

  testWidgets('guest request kartasi mavjud login modalni ochadi', (
    tester,
  ) async {
    await pumpApp(tester, homeData: _homeWithStore);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-missing-product-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(PhoneField), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('protected amal blur modal ochadi va fon bosilganda yopilmaydi', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(PhoneField), findsOneWidget);

    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth-prompt-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('telefon va OTP shu modalda, login ortidan amal davom etadi', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    when(
      () => api.sendOtp(any()),
    ).thenAnswer((_) async => const SendOtpResult(smsAppHash: false));
    when(
      () => api.verifyOtp(
        normalizedPhone: any(named: 'normalizedPhone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer(
      (_) async => const VerifyOtpResult(
        access: 'a',
        refresh: 'r',
        user: _user,
        isNewUser: false,
      ),
    );

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PhoneField),
        matching: find.byType(TextField),
      ),
      '90 123 45 67',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('auth-prompt-continue')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('auth-prompt-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.byType(PhoneField), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(OtpCodeField),
        matching: find.byType(TextField),
      ),
      '482913',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auth-prompt-modal')), findsNothing);
    expect(
      find.byType(ProfileScreen),
      findsOneWidget,
      reason:
          'current route: ${container.read(appRouterProvider).routerDelegate.currentConfiguration.uri}',
    );
    verify(() => api.sendOtp('+998901234567')).called(1);
    verify(
      () => api.verifyOtp(normalizedPhone: '+998901234567', code: '482913'),
    ).called(1);
    await unmountApp(tester);
  });

  testWidgets(
    'to‘g‘ridan-to‘g‘ri OTP holatiga o‘tib bo‘lmaydi (telefon yo‘q)',
    (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(Routes.authOtp);
      await tester.pumpAndSettle();
      // phone == null bo'lgani uchun /auth/otp so'ralsa ham /auth/phone
      expect(find.byType(PhoneScreen), findsOneWidget);
      expect(find.byType(OtpCodeField), findsNothing);
    },
  );

  testWidgets(
    'kod yuborilgach OTP ekrani, verify’dan keyin redirect Home’ga olib chiqadi'
    ' (requiresOnboarding=true bo‘lsa ham)',
    (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(Routes.authPhone);
      await tester.pumpAndSettle();

      when(
        () => api.sendOtp(any()),
      ).thenAnswer((_) async => const SendOtpResult(smsAppHash: false));
      when(
        () => api.verifyOtp(
          normalizedPhone: any(named: 'normalizedPhone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer(
        (_) async => const VerifyOtpResult(
          access: 'a',
          refresh: 'r',
          user: _user,
          isNewUser: true,
        ),
      );

      await auth().sendCode('901234567');
      container.read(appRouterProvider).go(Routes.authOtp);
      await tester.pumpAndSettle();

      // Controller navigatsiya qilmaydi; auth prompt UI muvaffaqiyatni yopadi.
      // Bu controller-level testda faqat sessiya holatini tekshiramiz.
      await auth().verifyCode('482913');
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      container.read(appRouterProvider).go(Routes.home);
      await tester.pumpAndSettle();

      // Onboarding YO'Q — to'g'ri Home
      expect(find.byType(HomeScreen), findsOneWidget);
      await unmountApp(tester);
    },
  );

  testWidgets('token bor, me() OK → restoreSession Home’ga olib boradi', (
    tester,
  ) async {
    await pumpApp(tester, access: 'a', refresh: 'r');
    when(() => api.me()).thenAnswer((_) async => _user);

    await auth().restoreSession();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('logout → guest Home ekraniga qaytadi', (tester) async {
    await pumpApp(tester, access: 'a', refresh: 'r');
    when(() => api.me()).thenAnswer((_) async => _user);
    when(() => api.logout(any())).thenAnswer((_) async {});

    await auth().restoreSession();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await auth().logout();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PhoneScreen), findsNothing);
  });

  testWidgets(
    'cart selector confirms explicitly, keeps nested add edit routes and back',
    (tester) async {
      await pumpApp(tester, access: 'a', refresh: 'r', deliveryCart: true);
      when(() => api.me()).thenAnswer((_) async => _user);
      await auth().restoreSession();
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      router.go(Routes.storeCart('household'));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      expect(find.textContaining('yana 7\u00a0000'), findsWidgets);

      // Minimum blocks checkout, but address selection remains available.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cart-primary-action')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('household-cart-location')));
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryAddressScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('store-nav-cart')), findsOneWidget);
      expect(
        AppBackCoordinator.of(router).location,
        Routes.cartDeliveryAddressSelect('household'),
      );
      await tester.tap(find.byKey(const ValueKey('delivery-address-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      verify(
        () => container
            .read(checkoutApiProvider)
            .estimate(
              storeType: 'household',
              latitude: 41.31,
              longitude: 69.24,
            ),
      ).called(greaterThanOrEqualTo(1));

      await tester.tap(find.byKey(const ValueKey('household-cart-location')));
      await tester.pumpAndSettle();
      final add = find.byKey(const ValueKey('checkout-add-new-location'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        AppBackCoordinator.of(router).location,
        Routes.cartDeliveryAddressNew('household'),
      );
      expect(find.text('Manzilni saqlash'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryAddressScreen), findsOneWidget);
      final edit = find.byKey(const ValueKey('delivery-address-edit-saved'));
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        AppBackCoordinator.of(router).location,
        Routes.cartDeliveryAddressEdit('household', 'saved'),
      );
      router.pop(); // Browser history and Android pop keep the draft selection.
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delivery-address-back')));
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      // The compact minimum row is in the cart footer, never a second card.
      expect(
        find.byKey(const ValueKey('cart-minimum-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout-delivery-minimum')),
        findsNothing,
      );
      expect(
        container.read(addressesControllerProvider).value!.single.isDefault,
        isTrue,
      );

      expect(find.byType(CartScreen), findsOneWidget);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      await unmountApp(tester);
    },
  );

  testWidgets(
    'cart and old checkout address URLs preserve navbar and stable back',
    (tester) async {
      await pumpApp(tester, access: 'a', refresh: 'r', deliveryCart: true);
      when(() => api.me()).thenAnswer((_) async => _user);
      await auth().restoreSession();
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      for (final url in [
        Routes.checkoutAddressNew('household'),
        Routes.checkoutAddressEdit('household', 'saved'),
        Routes.deliveryAddressSelect('household'),
        Routes.cartDeliveryAddressNew('household'),
        Routes.cartDeliveryAddressEdit('household', 'saved'),
        Routes.cartDeliveryAddressSelect('household'),
      ]) {
        router.go(Routes.home);
        await tester.pumpAndSettle();
        router.go(url);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('store-nav-cart')), findsOneWidget);
        final selecting =
            url == Routes.deliveryAddressSelect('household') ||
            url == Routes.cartDeliveryAddressSelect('household');
        if (selecting) {
          expect(find.byType(DeliveryAddressScreen), findsOneWidget);
        } else {
          expect(find.byType(AddressFormScreen), findsOneWidget);
          expect(
            find.text('Manzilni saqlash'),
            url.contains('/cart/address/select/')
                ? findsOneWidget
                : findsNothing,
          );
        }
        router.pop();
        await tester.pumpAndSettle();
        if (url.contains('/cart/address/select/')) {
          expect(find.byType(DeliveryAddressScreen), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(seconds: 1));
        // Legacy checkout URLs remain valid, but this below-minimum fixture
        // returns to the cart after the covering address route is closed.
        expect(find.byType(CartScreen), findsOneWidget);
        expect(find.byType(DeliveryAddressScreen), findsNothing);
      }
      await unmountApp(tester);
    },
  );

  testWidgets('guest cart selector direct link requests authentication', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    router.go(Routes.cartDeliveryAddressSelect('household'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(find.byType(DeliveryAddressScreen), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['returnTo'],
      Routes.cartDeliveryAddressSelect('household'),
    );
  });
}
