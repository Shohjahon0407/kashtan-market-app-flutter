import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/auth_gate.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_recommendations_provider.dart';
import 'package:beshkashtan_customer/features/cart/presentation/cart_screen.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/product_report_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/delivery_address_screen.dart';
import 'package:beshkashtan_customer/features/favorites/domain/favorites_controller.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _address = UserAddress(
  id: 'home',
  title: 'Uy',
  isDefault: true,
  latitude: 41.31,
  longitude: 69.24,
  street: 'Yangi ko‘cha',
);
const _coverage = DeliveryCoverageBranch(
  id: 'branch',
  name: 'Filial',
  latitude: 41.31,
  longitude: 69.24,
  radiusKm: 2,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
  branch: _coverage,
);

ProductSummary _product(
  StoreType type, {
  String id = 'product',
  String price = '8000',
  bool image = false,
}) => ProductSummary.fromJson({
  'id': id,
  'name': 'Kundalik foydalanish uchun foydali mahsulot',
  'price': price,
  'store_type': type.wire,
  'is_purchasable': true,
  'variants': <Object>[],
  'main_image': image ? 'https://example.test/product.jpg' : null,
  'unit': type == StoreType.shashlik ? 'kg' : 'piece',
  'store': {'id': 'store', 'name': 'Do‘kon', 'store_type': type.wire},
});

class _Auth extends AuthController {
  _Auth({this.guest = false});
  final bool guest;
  @override
  AuthState build() => guest ? const AuthState.unauthenticated() : _signedIn;
  void signIn() => state = _signedIn;
  static const _signedIn = AuthState.authenticated(
    AuthUser(
      id: 'user',
      phoneNumber: '+998900000000',
      firstName: 'Ali',
      lastName: '',
      role: UserRole.customer,
      isPhoneVerified: true,
      requiresOnboarding: false,
      missingFields: [],
    ),
  );
}

class _SignInPrompt extends AuthPromptCoordinator {
  _SignInPrompt(super.ref, this.signIn);
  final VoidCallback signIn;
  @override
  Future<bool> require(BuildContext context, WidgetRef ref) async {
    signIn();
    return true;
  }
}

class _Home extends HomeController {
  @override
  Future<HomeData> build() async => const HomeData(banners: [], storeHub: []);
}

class _Favorites extends FavoritesController {
  @override
  Future<FavoritesState> build() async => const FavoritesState(items: []);
}

class _Addresses extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => [_address];
  @override
  Future<void> refresh() async {}
}

class _CartApi extends Fake implements CartApi {
  _CartApi(this.type, {this.unitPrice = 8000});
  final StoreType type;
  final int unitPrice;
  int quantity = 1;
  bool extra = false, fail = false, offline = false, configured = false;
  Completer<void>? pending;
  final log = <String>[];
  @override
  Future<CartData> fetch(String storeType) async {
    log.add('cart');
    if (quantity == 0 && !extra) return CartData.empty(storeType);
    return CartData(
      id: 'cart',
      storeTypeWire: storeType,
      minimumDeliveryOrderAmount: '20000',
      subtotal: '${quantity * unitPrice + (extra ? 7000 : 0)}',
      totalItems: extra ? 2 : 1,
      totalQuantity: quantity + (extra ? 1 : 0),
      items: [
        if (quantity > 0)
          CartItem(
            id: 'line',
            product: _product(type, price: '$unitPrice'),
            quantity: quantity,
            variant: configured
                ? ProductVariant.fromJson({
                    'id': 'large',
                    'name': 'Katta porsiya',
                    'price': '$unitPrice',
                  })
                : null,
            selectedAddons: configured
                ? const [
                    SelectedAddon(
                      id: 'extra-sauce',
                      name: 'Qo‘shimcha sous',
                      price: '1000',
                    ),
                  ]
                : const [],
            note: configured ? 'Achchiq bo‘lmasin' : '',
            subtotal: '${quantity * unitPrice}',
          ),
        if (extra)
          CartItem(
            id: 'extra',
            product: _product(
              type,
              id: 'recommendation',
              price: '7000',
              image: true,
            ),
            quantity: 1,
            selectedAddons: const [],
            note: '',
            subtotal: '7000',
          ),
      ],
    );
  }

  @override
  Future<bool> mergeGuestCart() async {
    log.add('merge');
    return false;
  }

  @override
  Future<void> updateQuantity(String itemId, int value) async {
    if (pending != null) await pending!.future;
    if (offline) throw const NetworkFailure();
    if (fail) throw const ServerFailure('failed', 500);
    quantity = value;
  }

  @override
  Future<void> deleteItem(String itemId) async {
    quantity = 0;
  }

  @override
  Future<void> addItem({
    required String storeType,
    required CartConfiguration configuration,
    required int quantity,
  }) async {
    extra = true;
  }

  @override
  Future<void> clear(String storeType) async {
    quantity = 0;
    extra = false;
  }
}

class _Api extends Fake implements CheckoutApi {
  _Api(this.log);
  final List<String> log;
  int requests = 0;
  int branchCount = 1;
  DeliveryEstimate response = _quote;
  @override
  Future<List<UserAddress>> fetchAddresses() async => [_address];
  @override
  Future<DeliveryEstimate> estimate({
    required String storeType,
    required double latitude,
    required double longitude,
    String? branchId,
  }) async {
    log.add('quote');
    requests++;
    return response;
  }

  @override
  Future<List<DeliveryCoverageBranch>> fetchCoverage(String storeType) async =>
      [_coverage];
  @override
  Future<List<StoreBranch>> fetchBranches(String storeId) async =>
      List.generate(
        branchCount,
        (i) => StoreBranch.fromJson({
          'id': 'branch-$i',
          'name': 'Filial $i',
          'address': 'Haqiqiy manzil',
          'is_active': true,
          'is_pickup_available': true,
          'store': {'id': storeId, 'name': 'Do‘kon', 'store_type': 'household'},
        }),
      );
}

class _Harness {
  _Harness(this.container, this.cart, this.api);
  final ProviderContainer container;
  final _CartApi cart;
  final _Api api;
}

Future<_Harness> _mount(
  WidgetTester tester, {
  StoreType type = StoreType.household,
  bool confirmed = false,
  bool empty = false,
  bool recommendations = false,
  int unitPrice = 8000,
  int branchCount = 1,
  double scale = 1,
  Locale locale = const Locale('uz'),
  bool router = false,
  bool guest = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final cart = _CartApi(type, unitPrice: unitPrice)..quantity = empty ? 0 : 1;
  final api = _Api(cart.log)..branchCount = branchCount;
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      apiLangProvider.overrideWithValue('uz'),
      authControllerProvider.overrideWith(() => _Auth(guest: guest)),
      if (guest)
        authPromptCoordinatorProvider.overrideWith(
          (ref) => _SignInPrompt(ref, () {
            cart.log.add('login');
            (ref.read(authControllerProvider.notifier) as _Auth).signIn();
          }),
        ),
      homeControllerProvider.overrideWith(_Home.new),
      cartApiProvider.overrideWithValue(cart),
      checkoutApiProvider.overrideWithValue(api),
      addressesControllerProvider.overrideWith(_Addresses.new),
      favoritesControllerProvider.overrideWith(_Favorites.new),
      reportButtonEnabledProvider.overrideWith((ref, _) => false),
      cartRecommendationsProvider.overrideWith(
        (ref, _) async => recommendations
            ? [_product(type, id: 'recommendation', price: '7000', image: true)]
            : [],
      ),
      addressLocationAccessProvider.overrideWithValue(() async {
        throw const DeviceLocationException(DeviceLocationFailure.denied);
      }),
    ],
  );
  addTearDown(container.dispose);
  final provider = cartControllerProvider(type);
  final subscription = container.listen(provider, (_, _) {});
  addTearDown(subscription.close);
  await container.read(provider.future);
  await container.read(addressesControllerProvider.future);
  if (confirmed) {
    await container
        .read(orderDraftProvider(type).notifier)
        .acceptAddress(
          const DeliveryAddressSelection(
            address: _address,
            estimate: _quote,
            storeScope: 'store',
          ),
        );
  }
  final appRouter = router
      ? GoRouter(
          initialLocation: Routes.storeCart(type.wire),
          routes: [
            GoRoute(
              path: Routes.storeCart(type.wire),
              builder: (_, _) => CartScreen(storeType: type),
              routes: [
                GoRoute(
                  path: 'checkout',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Compact checkout')),
                ),
                GoRoute(
                  path: 'address/select',
                  builder: (_, state) => DeliveryAddressScreen(
                    storeType: type,
                    arguments: state.extra as DeliveryAddressArguments?,
                    selectionRoute: Routes.cartDeliveryAddressSelect(type.wire),
                  ),
                ),
              ],
            ),
          ],
        )
      : null;
  if (appRouter != null) addTearDown(appRouter.dispose);
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: appRouter == null
          ? MaterialApp(
              theme: AppTheme.light(),
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: builder,
              home: Scaffold(
                body: CartScreen(storeType: type),
                bottomNavigationBar: const SizedBox(height: 80),
              ),
            )
          : MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: appRouter,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: builder,
            ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, cart, api);
}

Finder get _primary => find.byKey(const ValueKey('cart-primary-action'));
FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(_primary);
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'cart entry does not open address or request location; unknown fee is not zero',
    (tester) async {
      final h = await _mount(tester);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      expect(
        find.text('Yetkazish narxi manzil tanlangach hisoblanadi'),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Yetkazish manzilini tanlash'),
        ),
        findsOneWidget,
      );
      expect(h.api.requests, 0);
      expect(h.cart.log, isNot(contains('merge')));
    },
  );

  testWidgets('confirmed 8k+5k shows 7k remaining and active add action', (
    tester,
  ) async {
    await _mount(tester, confirmed: true);
    expect(find.textContaining('yana 7\u00a0000'), findsWidgets);
    expect(
      find.descendant(of: _primary, matching: find.text('Mahsulot qo‘shish')),
      findsOneWidget,
    );
    expect(_button(tester).onPressed, isNotNull);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(
      find.text('Minimumni to‘ldirish uchun').hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cart-browse-products')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'exact minimum enables next step but never creates an order automatically',
    (tester) async {
      final h = await _mount(
        tester,
        confirmed: true,
        unitPrice: 15000,
        router: true,
      );
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Buyurtmani davom ettirish'),
        ),
        findsOneWidget,
      );
      expect(find.text('Compact checkout'), findsNothing);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text('Compact checkout'), findsOneWidget);
      expect(
        h.cart.log.indexOf('merge'),
        lessThan(h.cart.log.indexOf('quote')),
      );
    },
  );

  testWidgets(
    'address action merges server cart before opening selector; back remains unconfirmed',
    (tester) async {
      final h = await _mount(tester, router: true);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.byType(DeliveryAddressScreen), findsOneWidget);
      expect(
        h.cart.log.indexOf('merge'),
        lessThan(h.cart.log.indexOf('quote')),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        h.container.read(orderDraftProvider(StoreType.household)).selection,
        isNull,
      );
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Yetkazish manzilini tanlash'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pickup ignores delivery minimum and selects only eligible single branch',
    (tester) async {
      final h = await _mount(tester);
      await tester.tap(find.text('Olib ketish'));
      await tester.pumpAndSettle();
      expect(
        h.container
            .read(orderDraftProvider(StoreType.household))
            .pickupBranchId,
        'branch-0',
      );
      expect(
        find.byKey(const ValueKey('checkout-delivery-minimum')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Buyurtmani davom ettirish'),
        ),
        findsOneWidget,
      );
      expect(h.api.requests, 0);
    },
  );

  testWidgets(
    'guest pickup survives login and merge without selecting delivery address',
    (tester) async {
      final h = await _mount(tester, guest: true, router: true);
      await tester.tap(find.text('Olib ketish'));
      await tester.pumpAndSettle();
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text('Compact checkout'), findsOneWidget);
      final draft = h.container.read(orderDraftProvider(StoreType.household));
      expect(draft.fulfillment, FulfillmentType.pickup);
      expect(draft.pickupBranchId, 'branch-0');
      expect(draft.addressId, isNull);
      expect(
        h.cart.log.indexOf('login'),
        lessThan(h.cart.log.indexOf('merge')),
      );
      expect(h.api.requests, 0);
    },
  );

  testWidgets(
    'multiple pickup branches require explicit selection via footer',
    (tester) async {
      final h = await _mount(tester, branchCount: 2);
      await tester.tap(find.text('Olib ketish'));
      await tester.pumpAndSettle();
      expect(
        h.container
            .read(orderDraftProvider(StoreType.household))
            .pickupBranchId,
        isNull,
      );
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cart-pickup-option-branch-1')),
      );
      await tester.pumpAndSettle();
      expect(
        h.container
            .read(orderDraftProvider(StoreType.household))
            .pickupBranchId,
        'branch-1',
      );
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Buyurtmani davom ettirish'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'recommendation add updates same cart and reaches minimum in place',
    (tester) async {
      final h = await _mount(tester, confirmed: true, recommendations: true);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      final buy = find.byKey(const ValueKey('product-card-buy-recommendation'));
      await _show(tester, buy);
      await tester.tap(buy);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(h.cart.extra, isTrue);
      expect(
        find.descendant(
          of: _primary,
          matching: find.text('Buyurtmani davom ettirish'),
        ),
        findsOneWidget,
      );
      expect(
        h.container.read(orderDraftProvider(StoreType.household)).addressId,
        'home',
      );
    },
  );

  testWidgets(
    'pending quantity and failed write block next step then rollback progress',
    (tester) async {
      final h = await _mount(tester, confirmed: true);
      h.cart.pending = Completer<void>();
      h.cart.fail = true;
      final add = find.descendant(
        of: find.byType(CartQuantityStepper),
        matching: find.byIcon(Icons.add),
      );
      await _show(tester, add);
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_button(tester).onPressed, isNull);
      h.cart.pending!.complete();
      await tester.pumpAndSettle();
      expect(h.cart.quantity, 1);
      expect(
        find.descendant(of: _primary, matching: find.text('Qayta urinish')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'offline optimistic quantity never confirms minimum or permits checkout',
    (tester) async {
      final h = await _mount(tester, confirmed: true);
      h.cart.offline = true;
      final add = find.descendant(
        of: find.byType(CartQuantityStepper),
        matching: find.byIcon(Icons.add),
      );
      await _show(tester, add);
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(h.cart.quantity, 1);
      expect(find.text('Minimal buyurtma summasiga yetdingiz'), findsNothing);
      expect(
        find.descendant(of: _primary, matching: find.text('Qayta urinish')),
        findsOneWidget,
      );
      expect(find.text('Buyurtmani davom ettirish'), findsNothing);
    },
  );

  testWidgets(
    'shashlik row retains units, configuration and actual line total at 2x',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final h = await _mount(tester, type: StoreType.shashlik, scale: 2);
      h.cart.configured = true;
      h.cart.quantity = 2;
      await h.container
          .read(cartControllerProvider(StoreType.shashlik).notifier)
          .refresh();
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('cart-item-line'));
      await _show(tester, row);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Katta porsiya'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Qo‘shimcha sous'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 kilogram'), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.textContaining('16\u00a0000')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty cart hides order panel and keeps large empty illustration',
    (tester) async {
      await _mount(tester, empty: true);
      expect(_primary, findsNothing);
      expect(find.byKey(const ValueKey('empty-cart-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-fulfillment')), findsNothing);
    },
  );

  for (final type in StoreType.values) {
    testWidgets('store-scoped minimum flow works for $type', (tester) async {
      final h = await _mount(tester, type: type, confirmed: true);
      expect(find.textContaining('yana 7\u00a0000'), findsWidgets);
      expect(h.container.read(orderDraftProvider(type)).addressId, 'home');
      if (type == StoreType.shashlik) {
        expect(find.text('1 kilogram'), findsOneWidget);
      }
    });
  }

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in [
      const Size(320, 640),
      const Size(430, 850),
      const Size(800, 360),
    ]) {
      for (final confirmed in [false, true]) {
        testWidgets('cart fits $locale $size 2x navbar confirmed=$confirmed', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          await _mount(tester, locale: locale, scale: 2, confirmed: confirmed);
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(_primary);
          expect(rect.bottom, lessThanOrEqualTo(size.height - 80));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.left, greaterThanOrEqualTo(0));
        });
      }
    }
  }
}
