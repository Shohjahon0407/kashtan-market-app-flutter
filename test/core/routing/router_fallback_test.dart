import 'package:beshkashtan_customer/app.dart';
import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/routing/app_router.dart';
import 'package:beshkashtan_customer/core/routing/route_not_found_screen.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/home/presentation/home_screen.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:beshkashtan_customer/features/notifications/domain/notifications_controller.dart';
import 'package:beshkashtan_customer/features/store/presentation/unsupported_store_screen.dart';
import 'package:beshkashtan_customer/features/videos/data/video_api.dart';
import 'package:beshkashtan_customer/features/videos/data/video_models.dart';
import 'package:beshkashtan_customer/features/videos/domain/video_feed_controller.dart';
import 'package:flutter/material.dart';
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

/// Mehmon (login qilmagan) uchun ham noma'lum do'kon turi va mos kelmagan
/// yo'l go_router'ning qizil xato ekraniga emas, ilova ekranlariga tushadi.
void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final homeApi = _MockHomeApi();
    final videoApi = _MockVideoApi();
    final cartApi = _MockCartApi();
    final checkoutApi = _MockCheckoutApi();
    final notificationsApi = _MockNotificationsApi();
    when(
      () => homeApi.fetch(),
    ).thenAnswer((_) async => const HomeData(banners: [], storeHub: []));
    when(() => videoApi.fetchFeed()).thenAnswer(
      (_) async => const CursorPage<StoreVideo>(items: [], nextUrl: null),
    );
    when(() => cartApi.fetch(any())).thenAnswer(
      (invocation) async =>
          CartData.empty(invocation.positionalArguments.first as String),
    );
    when(() => checkoutApi.fetchAddresses()).thenAnswer((_) async => []);
    when(() => notificationsApi.unreadCount()).thenAnswer((_) async => 0);
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authApiProvider.overrideWithValue(_MockAuthApi()),
        homeApiProvider.overrideWithValue(homeApi),
        videoApiProvider.overrideWithValue(videoApi),
        cartApiProvider.overrideWithValue(cartApi),
        checkoutApiProvider.overrideWithValue(checkoutApi),
        notificationsApiProvider.overrideWithValue(notificationsApi),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeshKashtanApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }

  testWidgets('mehmon: noma\'lum do\'kon turi → UnsupportedStoreScreen', (
    tester,
  ) async {
    await pumpApp(tester);
    container.read(appRouterProvider).go('/store/pharmacy/catalog');
    await tester.pumpAndSettle();
    expect(find.byType(UnsupportedStoreScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mos kelmagan yo\'l → RouteNotFoundScreen, bosh sahifaga qaytadi',
    (tester) async {
      await pumpApp(tester);
      container.read(appRouterProvider).go('/bu-yol-yoq');
      await tester.pumpAndSettle();
      expect(find.byType(RouteNotFoundScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('route-not-found-home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
