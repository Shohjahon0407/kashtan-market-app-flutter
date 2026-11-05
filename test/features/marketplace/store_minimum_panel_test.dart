import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_recommendations_provider.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/shashlik_cart_bar.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _address = UserAddress(
  id: 'address',
  title: 'Uy',
  isDefault: true,
  latitude: 41.31,
  longitude: 69.24,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
);

CartData _cart(StoreType type, {String subtotal = '8000'}) => CartData(
  id: 'cart-${type.wire}',
  storeTypeWire: type.wire,
  subtotal: subtotal,
  minimumDeliveryOrderAmount: '20000',
  totalItems: 1,
  totalQuantity: 1,
  items: [
    CartItem(
      id: 'line',
      quantity: 1,
      note: '',
      selectedAddons: const [],
      subtotal: subtotal,
      product: ProductSummary.fromJson({
        'id': 'product',
        'name': 'Mahsulot',
        'price': subtotal,
        'store_type': type.wire,
        'is_purchasable': true,
        'store': {'id': 'store-${type.wire}', 'store_type': type.wire},
      }),
    ),
  ],
);

class _Cart extends CartController {
  _Cart(super.storeType, this.initial);
  final CartData initial;
  @override
  Future<CartState> build() async => CartState(cart: initial);
  void replace(CartState next) => state = AsyncData(next);
  @override
  Future<void> refresh() async {}
}

class _Draft extends OrderDraftController {
  _Draft(super.storeType, this.initial);
  final OrderDraftState initial;
  int preparations = 0;
  @override
  OrderDraftState build() => initial;
  void replace(OrderDraftState next) => state = next;
  @override
  Future<bool> prepare({
    bool revalidateQuote = true,
    bool useSavedAddress = false,
  }) async {
    preparations++;
    return true;
  }
}

class _Addresses extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [_address];
}

class _Auth extends AuthController {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _Home extends HomeController {
  @override
  Future<HomeData> build() async => const HomeData(banners: [], storeHub: []);
}

OrderDraftState _draft(StoreType type) => OrderDraftState(
  selection: DeliveryAddressSelection(
    address: _address,
    estimate: _quote,
    storeScope: 'store-${type.wire}',
  ),
);

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  StoreType type = StoreType.household,
  bool cartScreen = false,
  OrderDraftState? draft,
  String subtotal = '8000',
  double scale = 1,
  Locale locale = const Locale('uz'),
}) async {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      homeControllerProvider.overrideWith(_Home.new),
      cartControllerProvider.overrideWith2(
        (t) => _Cart(t, _cart(t, subtotal: subtotal)),
      ),
      orderDraftProvider.overrideWith2((t) => _Draft(t, draft ?? _draft(t))),
      addressesControllerProvider.overrideWith(_Addresses.new),
      storeBranchesProvider.overrideWith(
        (ref, id) async => [
          StoreBranch.fromJson({
            'id': 'pickup',
            'name': 'Filial',
            'address': 'Toshkent',
            'is_active': true,
            'is_pickup_available': true,
            'store': {'id': id},
          }),
        ],
      ),
      cartRecommendationsProvider.overrideWith((ref, _) async => []),
      // The catalogue footer must never start an estimate or prepare a draft.
      checkoutApiProvider.overrideWith(
        (_) => throw StateError('Unexpected API request'),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/preview',
    routes: [
      GoRoute(
        path: '/preview',
        builder: (context, _) => Scaffold(
          body: cartScreen
              ? CartScreen(storeType: type)
              : const Text('Catalogue'),
          bottomNavigationBar: cartScreen
              ? const SizedBox(height: 80, key: ValueKey('navbar'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShashlikCartBar(
                      storeType: type,
                      quantity: 1,
                      subtotal: subtotal,
                      onTap: () => context.push(Routes.storeCart(type.wire)),
                    ),
                    const SizedBox(height: 80, key: ValueKey('navbar')),
                  ],
                ),
        ),
      ),
      GoRoute(
        path: Routes.storeCart(type.wire),
        builder: (_, _) => const Scaffold(body: Text('Store cart')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

final _minimum = find.byKey(const ValueKey('cart-minimum-progress'));
final _primary = find.byKey(const ValueKey('cart-primary-action'));

void main() {
  for (final type in StoreType.values) {
    testWidgets('$type pickup bypasses delivery minimum', (tester) async {
      await _mount(
        tester,
        type: type,
        cartScreen: true,
        draft: const OrderDraftState(
          fulfillment: FulfillmentType.pickup,
          pickupBranchId: 'pickup',
        ),
      );
      expect(_minimum, findsNothing);
      expect(tester.widget<FilledButton>(_primary).onPressed, isNotNull);
    });
    testWidgets(
      '$type catalogue stays actionable below minimum without estimating',
      (tester) async {
        final container = await _mount(tester, type: type);
        expect(_minimum, findsOneWidget);
        expect(find.textContaining('7\u00a0000'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .65,
        );
        expect(
          (container.read(orderDraftProvider(type).notifier) as _Draft)
              .preparations,
          0,
        );
        await tester.tap(_minimum);
        await tester.pumpAndSettle();
        expect(find.text('Store cart'), findsOneWidget);
      },
    );

    testWidgets(
      '$type cart blocks below minimum; minimum row precedes action',
      (tester) async {
        final container = await _mount(tester, type: type, cartScreen: true);
        expect(_minimum, findsOneWidget);
        expect(tester.widget<FilledButton>(_primary).onPressed, isNull);
        expect(
          tester.getBottomRight(_minimum).dy,
          lessThan(tester.getTopLeft(_primary).dy),
        );
        expect(
          tester.getBottomRight(_primary).dy,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(const ValueKey('navbar'))).dy,
          ),
        );
        await tester.tap(_minimum);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cart-browse-products')).hitTestable(),
          findsOneWidget,
        );
        final controller =
            container.read(cartControllerProvider(type).notifier) as _Cart;
        controller.replace(CartState(cart: _cart(type, subtotal: '15000')));
        await tester.pumpAndSettle();
        expect(_minimum, findsNothing);
        expect(tester.widget<FilledButton>(_primary).onPressed, isNotNull);
        controller.replace(CartState(cart: _cart(type)));
        await tester.pumpAndSettle();
        expect(_minimum, findsOneWidget);
        expect(tester.widget<FilledButton>(_primary).onPressed, isNull);
      },
    );
  }

  testWidgets(
    'pending mutation, rollback and unconfirmed/offline rows never use stale totals',
    (tester) async {
      final c = await _mount(tester);
      final controller =
          c.read(cartControllerProvider(StoreType.household).notifier) as _Cart;
      final cart = _cart(StoreType.household);
      for (final state in [
        CartState(cart: cart, busyKeys: {'line'}),
        CartState(cart: cart, unconfirmedKeys: {'line'}),
        CartState(cart: cart, mutationFailure: const NetworkFailure()),
      ]) {
        controller.replace(state);
        await tester.pumpAndSettle();
        expect(_minimum, findsNothing);
      }
      controller.replace(CartState(cart: cart));
      await tester.pumpAndSettle();
      expect(_minimum, findsOneWidget);
      controller.replace(CartState(cart: CartData.empty('household')));
      await tester.pumpAndSettle();
      expect(_minimum, findsNothing);
    },
  );

  testWidgets(
    'unknown, invalidated, moved-address and wrong-store quotes stay hidden',
    (tester) async {
      final c = await _mount(tester);
      final controller =
          c.read(orderDraftProvider(StoreType.household).notifier) as _Draft;
      for (final state in [
        const OrderDraftState(),
        _draft(StoreType.household).copyWith(quoteInvalidated: true),
        _draft(StoreType.household).copyWith(estimating: true),
        _draft(StoreType.household).copyWith(
          selection: () => const DeliveryAddressSelection(
            address: _address,
            estimate: DeliveryEstimate(available: false, detail: ''),
            storeScope: 'store-household',
          ),
        ),
        _draft(
          StoreType.household,
        ).copyWith(fulfillment: FulfillmentType.pickup),
        _draft(StoreType.restaurant),
        const OrderDraftState(
          selection: DeliveryAddressSelection(
            address: UserAddress(
              id: 'address',
              title: 'Moved',
              isDefault: true,
              latitude: 42,
              longitude: 69,
            ),
            estimate: _quote,
            storeScope: 'store-household',
          ),
        ),
      ]) {
        controller.replace(state);
        await tester.pumpAndSettle();
        expect(_minimum, findsNothing);
        expect(
          find.byKey(const ValueKey('shashlik-go-to-cart')).hitTestable(),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('only the current store total affects its panel', (tester) async {
    final c = await _mount(tester);
    await c.read(cartControllerProvider(StoreType.restaurant).future);
    final other =
        c.read(cartControllerProvider(StoreType.restaurant).notifier) as _Cart;
    other.replace(
      CartState(cart: _cart(StoreType.restaurant, subtotal: '999999')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7\u00a0000'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 700),
    const Size(430, 850),
    const Size(800, 360),
  ]) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('catalogue and cart panel fit $size $locale at 200%', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await _mount(tester, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('shashlik-go-to-cart')).hitTestable(),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await _mount(tester, locale: locale, scale: 2, cartScreen: true);
        expect(tester.takeException(), isNull);
        expect(_primary.hitTestable(), findsOneWidget);
      });
    }
  }
}
