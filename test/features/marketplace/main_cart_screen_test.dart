import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCartApi extends Mock implements CartApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState.authenticated(
    AuthUser(
      id: 'user-1',
      phoneNumber: '+998901234567',
      firstName: 'Test',
      lastName: 'User',
      role: UserRole.customer,
      isPhoneVerified: true,
      requiresOnboarding: false,
      missingFields: [],
    ),
  );
}

final _restaurantProduct = ProductSummary.fromJson({
  'id': 'osh-1',
  'name': 'Toshkent oshi',
  'price': '38000.00',
  'main_image': null,
  'is_purchasable': true,
  'store_type': 'restaurant',
  'variants': <Map<String, dynamic>>[],
});

CartData _restaurantCart(int quantity) => CartData(
  id: 'restaurant-cart',
  storeTypeWire: 'restaurant',
  items: [
    CartItem(
      id: 'osh-line',
      product: _restaurantProduct,
      quantity: quantity,
      selectedAddons: const [],
      note: '',
      subtotal: '${38000 * quantity}.00',
    ),
  ],
  totalItems: 1,
  totalQuantity: quantity,
  subtotal: '${38000 * quantity}.00',
);

const _home = HomeData(
  banners: [],
  storeHub: [
    StoreHubItem(
      storeType: StoreType.restaurant,
      storeTypeWire: 'restaurant',
      label: 'Ofiyat milliy taomlari',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 0,
    ),
    StoreHubItem(
      storeType: StoreType.household,
      storeTypeWire: 'household',
      label: '1005 xil mahsulot',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 1,
    ),
    StoreHubItem(
      storeType: StoreType.grocery,
      storeTypeWire: 'grocery',
      label: 'Misqol market',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 2,
    ),
    StoreHubItem(
      storeType: StoreType.shashlik,
      storeTypeWire: 'shashlik',
      label: 'Shashlik marenovka',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 3,
    ),
  ],
);

void main() {
  testWidgets(
    'global savat 4 store, stepper va store-specific checkoutni ko‘rsatadi',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final cartApi = _MockCartApi();
      final homeApi = _MockHomeApi();
      var quantity = 2;
      when(() => homeApi.fetch()).thenAnswer((_) async => _home);
      for (final type in StoreType.values) {
        when(() => cartApi.fetch(type.wire)).thenAnswer(
          (_) async => type == StoreType.restaurant
              ? _restaurantCart(quantity)
              : CartData.empty(type.wire),
        );
      }
      when(() => cartApi.updateQuantity('osh-line', any())).thenAnswer((
        call,
      ) async {
        quantity = call.positionalArguments[1] as int;
      });

      final router = GoRouter(
        initialLocation: Routes.cart,
        routes: [
          GoRoute(path: Routes.cart, builder: (_, _) => const MainCartScreen()),
          GoRoute(
            path: '/store/:storeType/cart/checkout',
            builder: (_, state) =>
                Text('checkout-${state.pathParameters['storeType']}'),
          ),
          GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith(
              _AuthenticatedAuthController.new,
            ),
            cartApiProvider.overrideWithValue(cartApi),
            homeApiProvider.overrideWithValue(homeApi),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('uz'),
            supportedLocales: const [Locale('uz')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final type in StoreType.values) {
        expect(
          find.byKey(ValueKey('main-cart-section-${type.wire}')),
          findsOneWidget,
        );
      }
      expect(find.text('Toshkent oshi'), findsOneWidget);
      expect(find.text("38\u00a0000 so'm"), findsOneWidget);
      // Bitta savatda mahsulot bor — qolgan barcha turlar bo'sh.
      expect(
        find.textContaining('savat bo\'sh'),
        findsNWidgets(StoreType.values.length - 1),
      );

      final stepper = find.byType(CartQuantityStepper);
      await tester.tap(
        find.descendant(of: stepper, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: stepper, matching: find.text('3')),
        findsOneWidget,
      );
      verify(() => cartApi.updateQuantity('osh-line', 3)).called(1);

      await tester.tap(find.byKey(const ValueKey('cart-checkout-restaurant')));
      await tester.pumpAndSettle();
      expect(find.text('checkout-restaurant'), findsOneWidget);
    },
  );
}
