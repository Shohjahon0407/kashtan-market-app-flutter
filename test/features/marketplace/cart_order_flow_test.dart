import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/auth_gate.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_colors.dart';
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
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
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
  _Addresses(this.addresses);
  final List<UserAddress> addresses;
  @override
  Future<List<UserAddress>> build() async => addresses;
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
    String? idempotencyKey,
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
  Completer<void>? pendingQuote;
  int branchCount = 1;
  DeliveryEstimate response = _quote;
  List<UserAddress> savedAddresses = [_address];
  @override
  Future<List<UserAddress>> fetchAddresses() async => savedAddresses;
  @override
  Future<DeliveryEstimate> estimate({
    required String storeType,
    required double latitude,
    required double longitude,
    String? branchId,
  }) async {
    log.add('quote');
    requests++;
    if (pendingQuote != null) await pendingQuote!.future;
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
  bool savedAddress = false,
  bool realCheckout = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await PrefsStore.load();
  final cart = _CartApi(type, unitPrice: unitPrice)..quantity = empty ? 0 : 1;
  final api = _Api(cart.log)
    ..branchCount = branchCount
    ..savedAddresses = confirmed || savedAddress ? [_address] : [];
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
      addressesControllerProvider.overrideWith(
        () => _Addresses(api.savedAddresses),
      ),
      favoritesControllerProvider.overrideWith(_Favorites.new),
      reportButtonEnabledProvider.overrideWith((ref, _) => false),
      cartRecommendationsProvider.overrideWith(
        (ref, _) async => recommendations
            ? [_product(type, id: 'recommendation', price: '7000', image: true)]
            : [],
      ),
      addressLocationAccessProvider.overrideWithValue(() async {
        cart.log.add('gps');
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
              path: '/other',
              builder: (_, _) =>
                  const Scaffold(body: Text('Other destination')),
            ),
            GoRoute(
              path: Routes.storeCart(type.wire),
              builder: (_, state) => CartScreen(
                storeType: type,
                initialFocus: state.uri.queryParameters['focus'],
              ),
              routes: [
                GoRoute(
                  path: 'checkout',
                  builder: (_, _) => realCheckout
                      ? CheckoutScreen(storeType: type)
                      : const Scaffold(body: Text('Compact checkout')),
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
    'pending preparation disables switch and never navigates from a covered cart',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.meat,
        confirmed: true,
        unitPrice: 50000,
        router: true,
      );
      h.api.pendingQuote = Completer<void>();
      await tester.tap(_primary);
      await tester.pump(const Duration(milliseconds: 100));
      final switcher = tester.widget<IconButton>(
        find.byKey(const ValueKey('store-switch-button')),
      );
      expect(switcher.onPressed, isNull);
      final router = GoRouter.of(tester.element(find.byType(CartScreen)));
      unawaited(router.push<void>('/other'));
      await tester.pump(const Duration(milliseconds: 300));
      h.api.pendingQuote!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Other destination'), findsOneWidget);
      expect(find.text('Compact checkout'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'shashlik guest chooses address only after login and cart merge',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.shashlik,
        guest: true,
        savedAddress: true,
        unitPrice: 50000,
        router: true,
      );
      expect(h.api.requests, 0);
      await tester.tap(find.byKey(const ValueKey('shashlik-cart-location')));
      await tester.pumpAndSettle();
      expect(h.cart.log, contains('login'));
      expect(h.cart.log, contains('merge'));
      expect(find.byType(DeliveryAddressScreen), findsOneWidget);
      final quoteIndex = h.cart.log.indexOf('quote');
      expect(
        h.cart.log.indexOf('login'),
        lessThan(h.cart.log.indexOf('merge')),
      );
      if (quoteIndex >= 0) {
        expect(h.cart.log.indexOf('merge'), lessThan(quoteIndex));
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
    },
  );
  testWidgets(
    'shashlik unknown delivery stays in cart and does not invent fee or minimum',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.shashlik,
        unitPrice: 40000,
        router: true,
      );
      expect(
        find.byKey(const ValueKey('shashlik-cart-location')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cart-order-summary')), findsNothing);
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      expect(
        find.descendant(of: _primary, matching: find.text('Manzil tanlash')),
        findsOneWidget,
      );
      expect(_button(tester).onPressed, isNotNull);
      expect(h.api.requests, 0);
      expect(h.cart.log, isNot(contains('gps')));
      expect(find.text('Compact checkout'), findsNothing);
    },
  );

  testWidgets(
    'shashlik confirmed minimum blocks then opens compact checkout when met',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.shashlik,
        confirmed: true,
        router: true,
        realCheckout: true,
      );
      expect(find.textContaining('yana 7 000'), findsWidgets);
      expect(_button(tester).onPressed, isNull);
      h.cart.quantity = 2;
      await h.container
          .read(cartControllerProvider(StoreType.shashlik).notifier)
          .refresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-checkout-content')),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<FulfillmentType>), findsNothing);
      expect(find.byKey(const ValueKey('checkout-payment-cash')), findsNothing);
      final draft = h.container.read(orderDraftProvider(StoreType.shashlik));
      expect(draft.addressId, 'home');
      await tester.tap(
        find.byKey(const ValueKey('shashlik-checkout-edit-address')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      expect(
        h.container.read(orderDraftProvider(StoreType.shashlik)).addressId,
        'home',
      );
      expect(_button(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'shashlik pickup is chosen in cart and bypasses delivery minimum',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.shashlik,
        router: true,
        realCheckout: true,
      );
      await tester.tap(find.byKey(const ValueKey('shashlik-cart-pickup')));
      await tester.pumpAndSettle();
      expect(
        h.container.read(orderDraftProvider(StoreType.shashlik)).pickupBranchId,
        'branch-0',
      );
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-checkout-content')),
        findsOneWidget,
      );
      expect(find.text('Filial 0'), findsOneWidget);
      expect(find.text('Uy'), findsNothing);
      expect(h.api.requests, 0);
    },
  );

  testWidgets(
    'meat unknown delivery stays in cart and does not invent fee or minimum',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.meat,
        unitPrice: 40000,
        router: true,
      );
      expect(find.byKey(const ValueKey('meat-cart-location')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-order-summary')), findsNothing);
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      expect(
        find.descendant(of: _primary, matching: find.text('Manzil tanlash')),
        findsOneWidget,
      );
      expect(_button(tester).onPressed, isNotNull);
      expect(h.api.requests, 0);
      expect(h.cart.log, isNot(contains('gps')));
      expect(find.text('Compact checkout'), findsNothing);
    },
  );

  testWidgets(
    'meat confirmed minimum blocks then opens compact checkout when met',
    (tester) async {
      final h = await _mount(
        tester,
        type: StoreType.meat,
        confirmed: true,
        router: true,
        realCheckout: true,
      );
      expect(find.textContaining('yana 7 000'), findsWidgets);
      expect(_button(tester).onPressed, isNull);
      h.cart.quantity = 2;
      await h.container
          .read(cartControllerProvider(StoreType.meat).notifier)
          .refresh();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('meat-checkout-content')),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<FulfillmentType>), findsNothing);
      expect(find.byKey(const ValueKey('checkout-payment-cash')), findsNothing);
      final draft = h.container.read(orderDraftProvider(StoreType.meat));
      expect(draft.addressId, 'home');
      await tester.tap(
        find.byKey(const ValueKey('meat-checkout-edit-address')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CartScreen), findsOneWidget);
      expect(
        h.container.read(orderDraftProvider(StoreType.meat)).addressId,
        'home',
      );
      expect(_button(tester).onPressed, isNotNull);
    },
  );

  testWidgets('meat pickup is chosen in cart and bypasses delivery minimum', (
    tester,
  ) async {
    final h = await _mount(
      tester,
      type: StoreType.meat,
      router: true,
      realCheckout: true,
    );
    await tester.tap(find.byKey(const ValueKey('meat-cart-pickup')));
    await tester.pumpAndSettle();
    expect(
      h.container.read(orderDraftProvider(StoreType.meat)).pickupBranchId,
      'branch-0',
    );
    expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
    expect(_button(tester).onPressed, isNotNull);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meat-checkout-content')), findsOneWidget);
    expect(find.text('Filial 0'), findsOneWidget);
    expect(find.text('Uy'), findsNothing);
    expect(h.api.requests, 0);
  });

  testWidgets(
    'shashlik configured cart line edits its total quantity without losing addons',
    (tester) async {
      final h = await _mount(tester, type: StoreType.shashlik, confirmed: true);
      h.cart.configured = true;
      h.cart.quantity = 10;
      await h.container
          .read(cartControllerProvider(StoreType.shashlik).notifier)
          .refresh();
      await tester.pumpAndSettle();
      final qty = find.text('10 kilogram');
      await _show(tester, qty);
      await tester.tap(qty);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shashlik-selector-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shashlik-selector-product-product')),
        findsNothing,
      );
      final input = find.byKey(const ValueKey('shashlik-quantity-input'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '20');
      await tester.pump();
      final save = find.byKey(const ValueKey('shashlik-selector-submit'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(h.cart.quantity, 20);
      final line = h.container
          .read(cartControllerProvider(StoreType.shashlik))
          .value!
          .cart
          .items
          .single;
      expect(line.variant!.id, 'large');
      expect(line.selectedAddons.single.id, 'extra-sauce');
      expect(line.note, 'Achchiq bo‘lmasin');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shashlik pending/offline quantity never enables continue', (
    tester,
  ) async {
    final h = await _mount(
      tester,
      type: StoreType.shashlik,
      confirmed: true,
      unitPrice: 50000,
    );
    h.cart.pending = Completer<void>();
    h.cart.offline = true;
    final plus = find.descendant(
      of: find.byType(CartQuantityStepper),
      matching: find.byIcon(Icons.add),
    );
    await _show(tester, plus);
    await tester.tap(plus);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_button(tester).onPressed, isNull);
    h.cart.pending!.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _primary, matching: find.text('Qayta urinish')),
      findsOneWidget,
    );
    expect(h.cart.quantity, 1);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(320, 700), Size(430, 850), Size(800, 360)]) {
      testWidgets('shashlik preparation fits $locale $size at 200%', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _mount(
          tester,
          type: StoreType.shashlik,
          confirmed: true,
          unitPrice: 50000,
          locale: locale,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_primary);
        await tester.pumpAndSettle();
        expect(_button(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(320, 700), Size(430, 850), Size(800, 360)]) {
      testWidgets('meat preparation fits $locale $size at 200%', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _mount(
          tester,
          type: StoreType.meat,
          confirmed: true,
          unitPrice: 50000,
          locale: locale,
          scale: 2,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_primary);
        await tester.pumpAndSettle();
        expect(_button(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'Rasmiylashtirish opens checkout across repeated trips; back keeps cart usable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final h = await _mount(
        tester,
        savedAddress: true,
        unitPrice: 50000,
        router: true,
        realCheckout: true,
      );
      for (var trip = 0; trip < 2; trip++) {
        expect(
          find.descendant(
            of: _primary,
            matching: find.text('Buyurtmani davom ettirish'),
          ),
          findsOneWidget,
        );
        await tester.tap(_primary);
        await tester.pumpAndSettle();
        expect(find.byType(CheckoutScreen), findsOneWidget);
        // Kuryer standart, saqlangan manzil tanlangan.
        expect(
          tester
              .widget<SegmentedButton<FulfillmentType>>(
                find.byKey(const ValueKey('checkout-fulfillment')),
              )
              .selected,
          {FulfillmentType.delivery},
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CartScreen), findsOneWidget);
        expect(_button(tester).onPressed, isNotNull);
        expect(
          h.container.read(orderDraftProvider(StoreType.household)).addressId,
          'home',
        );
      }
    },
  );

  testWidgets(
    'guest login restores saved delivery address and opens checkout in one tap',
    (tester) async {
      final h = await _mount(
        tester,
        guest: true,
        savedAddress: true,
        unitPrice: 50000,
        router: true,
      );
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(
        h.container.read(orderDraftProvider(StoreType.household)).addressId,
        'home',
      );
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      expect(h.cart.log, isNot(contains('gps')));
      expect(find.text('Compact checkout'), findsOneWidget);
    },
  );

  testWidgets(
    'saved address is quoted automatically and continues without address picker',
    (tester) async {
      final h = await _mount(
        tester,
        savedAddress: true,
        unitPrice: 50000,
        router: true,
      );
      expect(
        h.container.read(orderDraftProvider(StoreType.household)).addressId,
        'home',
      );
      expect(h.api.requests, 1);
      expect(h.cart.log, isNot(contains('gps')));
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text('Compact checkout'), findsOneWidget);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
    },
  );

  testWidgets(
    'cart shows items, summary and recommendations; no address or GPS on entry',
    (tester) async {
      final h = await _mount(tester, recommendations: true);
      expect(find.byType(DeliveryAddressScreen), findsNothing);
      expect(find.byKey(const ValueKey('cart-fulfillment')), findsNothing);
      expect(find.byKey(const ValueKey('cart-delivery-promise')), findsNothing);
      expect(
        find.byKey(const ValueKey('household-cart-location')),
        findsOneWidget,
      );
      expect(find.textContaining('Bugun'), findsNothing);
      expect(find.textContaining('40–60'), findsNothing);
      final stepper = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CartQuantityStepper).first,
              matching: find.byType(Container),
            )
            .first,
      );
      final stepperDecoration = stepper.decoration! as BoxDecoration;
      expect(stepperDecoration.color, Colors.white);
      expect(stepperDecoration.borderRadius, BorderRadius.circular(8));
      expect(find.byKey(const ValueKey('cart-order-summary')), findsNothing);
      expect(find.text('Buyurtmangiz'), findsNothing);
      expect(
        find.byKey(const ValueKey('cart-item-favorite-line')),
        findsOneWidget,
      );
      await _show(
        tester,
        find.byKey(const ValueKey('cart-recommendation-recommendation')),
      );
      expect(
        find.descendant(of: _primary, matching: find.text('Manzil tanlash')),
        findsOneWidget,
      );
      expect(_button(tester).onPressed, isNotNull);
      expect(h.api.requests, 0);
      expect(h.cart.log, isNot(contains('gps')));
    },
  );

  testWidgets('confirmed 8k+5k shows minimum hint linking to recommendations', (
    tester,
  ) async {
    await _mount(tester, confirmed: true);
    expect(find.textContaining('yana 7 000'), findsWidgets);
    // Minimum is enforced in cart; the explanatory row adds products.
    expect(_button(tester).onPressed, isNull);
    final add = find.byKey(const ValueKey('cart-minimum-progress'));
    await _show(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cart-browse-products')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'exact minimum hides hint and never creates an order automatically',
    (tester) async {
      final h = await _mount(
        tester,
        confirmed: true,
        unitPrice: 15000,
        router: true,
      );
      expect(find.text('Compact checkout'), findsNothing);
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.text('Compact checkout'), findsOneWidget);
      expect(
        h.cart.log.indexOf('merge'),
        lessThan(h.cart.log.indexOf('quote')),
      );
    },
  );

  testWidgets('40k products with unknown fee shows no minimum alert', (
    tester,
  ) async {
    await _mount(tester, unitPrice: 40000);
    expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('increasing and decreasing quantity toggles minimum hint', (
    tester,
  ) async {
    final h = await _mount(tester, confirmed: true);
    final minimum = find.byKey(const ValueKey('cart-minimum-progress'));
    expect(minimum, findsOneWidget);
    h.container
        .read(orderDraftProvider(StoreType.household).notifier)
        .setNotice('minimum_not_met');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cart-flow-notice')), findsNothing);
    final add = find.descendant(
      of: find.byType(CartQuantityStepper),
      matching: find.byIcon(Icons.add),
    );
    await _show(tester, add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(minimum, findsNothing);
    expect(
      _button(tester).style!.backgroundColor!.resolve({}),
      AppColors.primary,
    );
    final remove = find.descendant(
      of: find.byType(CartQuantityStepper),
      matching: find.byIcon(Icons.remove),
    );
    await _show(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(minimum, findsOneWidget);
    expect(find.textContaining('yana 7 000'), findsOneWidget);
  });

  testWidgets(
    'checkout pickup selects the only eligible branch without a quote',
    (tester) async {
      final h = await _mount(tester, router: true, realCheckout: true);
      await tester.tap(find.byKey(const ValueKey('household-cart-pickup')));
      await tester.pumpAndSettle();
      final draft = h.container.read(orderDraftProvider(StoreType.household));
      expect(draft.fulfillment, FulfillmentType.pickup);
      expect(draft.pickupBranchId, 'branch-0');
      expect(
        find.byKey(const ValueKey('checkout-delivery-minimum')),
        findsNothing,
      );
      expect(h.api.requests, 0);
      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen), findsOneWidget);
    },
  );

  testWidgets(
    'recommendation add updates same cart and reaches minimum in place',
    (tester) async {
      final h = await _mount(tester, confirmed: true, recommendations: true);
      final buy = find.byKey(const ValueKey('product-card-buy-recommendation'));
      await _show(tester, buy);
      await tester.tap(buy);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(h.cart.extra, isTrue);
      expect(find.byKey(const ValueKey('cart-minimum-progress')), findsNothing);
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

  testWidgets('offline optimistic quantity never permits checkout', (
    tester,
  ) async {
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
    expect(
      find.descendant(of: _primary, matching: find.text('Qayta urinish')),
      findsOneWidget,
    );
    expect(find.text('Buyurtmani davom ettirish'), findsNothing);
  });

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
        find.descendant(
          of: find.byKey(const ValueKey('cart-item-price-line')),
          matching: find.textContaining('16 000'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cart-item-price-line')))
            .data,
        contains('16 000'),
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
      expect(find.byKey(const ValueKey('cart-order-summary')), findsNothing);
    },
  );

  for (final type in StoreType.values) {
    testWidgets('store-scoped minimum flow works for $type', (tester) async {
      final h = await _mount(tester, type: type, confirmed: true);
      expect(find.textContaining('yana 7 000'), findsWidgets);
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
