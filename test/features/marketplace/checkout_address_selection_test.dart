import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/connectivity_controller.dart';
import 'package:beshkashtan_customer/core/routing/routes.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/offline_cart_queue.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/device_location.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_live_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/order_detail_screen.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

const _type = StoreType.household;
const _address = UserAddress(
  id: 'home',
  title: 'Uy',
  isDefault: true,
  latitude: 41.3,
  longitude: 69.2,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
);

class _CartApi extends Mock implements CartApi {}

class _Api extends Mock implements CheckoutApi {}

class _Queue extends Mock implements OfflineCartQueue {}

class _Submission extends CheckoutController {
  _Submission(super.type, this.onSubmit);
  final Future<OrderData?> Function() onSubmit;
  int calls = 0;
  void publish(CheckoutSubmissionState value) => state = value;
  @override
  Future<OrderData?> submit({
    required FulfillmentType fulfillmentType,
    required PaymentMethod paymentMethod,
    String? addressId,
    String? pickupBranchId,
    String note = '',
  }) async {
    calls++;
    return onSubmit();
  }
}

class _Cart extends CartController {
  _Cart(super.type, this.initial, {this.afterRefresh, this.refreshFailure});
  final CartData initial;
  final CartData? afterRefresh;
  final ApiFailure? refreshFailure;
  @override
  Future<CartState> build() async => CartState(cart: initial);
  @override
  Future<void> refresh() async {
    if (refreshFailure != null) throw refreshFailure!;
    if (afterRefresh != null) state = AsyncData(CartState(cart: afterRefresh!));
  }

  void empty() =>
      state = AsyncData(CartState(cart: CartData.empty(storeType.wire)));
}

class _Tracking extends OrderTrackingController {
  _Tracking(super.id, this.order);
  final OrderData order;
  @override
  Future<OrderTrackingData> build() async => OrderTrackingData.fromJson({
    'status': order.status,
    'user_status': order.userStatus,
    'store_type': order.storeTypeWire,
    'fulfillment_type': order.fulfillmentType,
  });
}

class _Addresses extends AddressesController {
  _Addresses(this.items);
  final List<UserAddress> items;
  @override
  Future<List<UserAddress>> build() async => items;
  @override
  Future<void> refresh() async {}
}

CartData _cart({
  String amount = '17000',
  String store = 'store',
  String minimum = '20000',
  bool empty = false,
}) => CartData(
  id: 'cart',
  storeTypeWire: _type.wire,
  subtotal: amount,
  minimumDeliveryOrderAmount: minimum,
  totalItems: empty ? 0 : 1,
  totalQuantity: empty ? 0 : 1,
  items: empty
      ? const []
      : [
          CartItem(
            id: 'item',
            quantity: 1,
            subtotal: amount,
            selectedAddons: const [],
            note: '',
            product: ProductSummary.fromJson({
              'id': 'product',
              'name': 'Mahsulot',
              'price': amount,
              'unit': 'dona',
              'store': {
                'id': store,
                'name': 'Xozmak',
                'store_type': _type.wire,
              },
            }),
          ),
        ],
);

class _Fixture {
  _Fixture(this.container, this.router, this.api);
  final ProviderContainer container;
  final GoRouter router;
  final _Api api;
  OrderDraftController get draft =>
      container.read(orderDraftProvider(_type).notifier);
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  CartData? cart,
  CartData? afterRefresh,
  DeliveryEstimate quote = _quote,
  Future<DeliveryEstimate> Function()? estimate,
  ApiFailure? refreshFailure,
  bool confirmed = true,
  bool pickup = false,
  List<StoreBranch> branches = const [],
  List<UserAddress> addresses = const [_address],
  String? initialLocation,
  bool settle = true,
  _Submission? submission,
  OrderData? placedOrder,
}) async {
  final fixture = cart ?? _cart();
  final api = _Api();
  final cartApi = _CartApi();
  final queue = _Queue();
  when(() => queue.flush()).thenAnswer((_) async {});
  when(() => queue.isEmpty).thenReturn(true);
  when(() => cartApi.mergeGuestCart()).thenAnswer((_) async => false);
  when(
    () => api.estimate(
      storeType: any(named: 'storeType'),
      latitude: any(named: 'latitude'),
      longitude: any(named: 'longitude'),
    ),
  ).thenAnswer((_) => estimate?.call() ?? Future.value(quote));
  when(() => api.fetchBranches(any())).thenAnswer((_) async => branches);
  final container = ProviderContainer(
    overrides: [
      isOfflineProvider.overrideWithValue(false),
      offlineCartQueueProvider.overrideWithValue(queue),
      if (submission != null)
        checkoutControllerProvider(_type).overrideWith(() => submission),
      if (placedOrder != null) ...[
        orderDetailProvider(
          placedOrder.id,
        ).overrideWith((ref) async => placedOrder),
        orderTrackingControllerProvider(
          placedOrder.id,
        ).overrideWith(() => _Tracking(placedOrder.id, placedOrder)),
      ],
      accountScopeProvider.overrideWithValue('user_review'),
      apiLangProvider.overrideWithValue('uz'),
      cartApiProvider.overrideWithValue(cartApi),
      checkoutApiProvider.overrideWithValue(api),
      cartControllerProvider.overrideWith2(
        (type) => _Cart(
          type,
          fixture,
          afterRefresh: afterRefresh,
          refreshFailure: refreshFailure,
        ),
      ),
      addressesControllerProvider.overrideWith(() => _Addresses(addresses)),
      addressLocationAccessProvider.overrideWithValue(() async {
        throw StateError('Final review must not request GPS permission');
      }),
    ],
  );
  final draft = container.read(orderDraftProvider(_type).notifier);
  await container.read(cartControllerProvider(_type).future);
  await container.read(addressesControllerProvider.future);
  if (confirmed) {
    await draft.acceptAddress(
      DeliveryAddressSelection(
        address: _address,
        estimate: _quote,
        storeScope: deliveryStoreScope(fixture),
      ),
    );
  }
  if (pickup) draft.setFulfillment(FulfillmentType.pickup);
  final router = GoRouter(
    initialLocation: initialLocation ?? Routes.checkout(_type.wire),
    routes: [
      GoRoute(
        path: '${Routes.storeOrders(_type.wire)}/:orderId',
        builder: (_, state) => OrderDetailScreen(
          storeType: _type,
          orderId: state.pathParameters['orderId']!,
        ),
      ),
      GoRoute(
        path: Routes.storeCart(_type.wire),
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text(
                'CART:${state.uri.queryParameters['focus'] ?? ''}',
                key: const ValueKey('cart-root'),
              ),
              TextButton(
                onPressed: () => context.push(Routes.checkout(_type.wire)),
                child: const Text('Open review'),
              ),
            ],
          ),
        ),
        routes: [
          GoRoute(
            path: 'checkout',
            builder: (context, state) => const CheckoutScreen(storeType: _type),
            routes: [
              GoRoute(
                path: 'address/select',
                builder: (context, state) =>
                    const Scaffold(body: Text('LEGACY ADDRESS')),
              ),
              GoRoute(
                path: 'address/new',
                builder: (context, state) =>
                    const Scaffold(body: Text('LEGACY NEW')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
  return _Fixture(container, router, api);
}

void main() {
  testWidgets(
    'successful order shows tracking stages despite cart/draft clearing before navigation',
    (tester) async {
      final order = OrderData.fromJson({
        'id': 'new-order',
        'order_number': 'TEST',
        'store_type': 'household',
        'fulfillment_type': 'delivery',
        'status': 'preparing',
        'user_status': 'preparing',
        'payment_method': 'cash_to_courier',
        'payment_status': 'pending',
        'subtotal': '17000',
        'delivery_fee': '5000',
        'total': '22000',
        'items': <Map<String, dynamic>>[],
      });
      final response = Completer<OrderData?>();
      late _Fixture f;
      late _Submission submission;
      submission = _Submission(_type, () async {
        submission.publish(const CheckoutSubmissionState(isSubmitting: true));
        (f.container.read(cartControllerProvider(_type).notifier) as _Cart)
            .empty();
        submission.publish(CheckoutSubmissionState(lastOrder: order));
        return response.future;
      });
      f = await _mount(tester, submission: submission, placedOrder: order);
      await tester.tap(find.byKey(const ValueKey('checkout-submit')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(submission.calls, 1);
      expect(f.container.read(orderDraftProvider(_type)).preparing, isFalse);
      expect(f.container.read(orderDraftProvider(_type)).estimating, isFalse);
      expect(f.container.read(orderDraftProvider(_type)).failure, isNull);
      expect(
        f.container.read(cartControllerProvider(_type)).requireValue.cart.items,
        isEmpty,
      );
      expect(
        f.container.read(checkoutControllerProvider(_type)).lastOrder?.id,
        order.id,
      );
      expect(
        find.byType(OrderDetailScreen),
        findsOneWidget,
        reason:
            'Published successful order must take priority over empty cart, without waiting for cleanup continuation',
      );
      response.complete(order);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(
        f.router.routeInformationProvider.value.uri.path,
        Routes.orderDetail(_type.wire, order.id),
      );
      expect(find.byKey(const ValueKey('order-stage-title')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order-stage-current-accepted')),
        findsOneWidget,
      );
      f.container.read(orderLiveProvider(order.id).notifier).applyLifecycle({
        'status': 'out_for_delivery',
        'user_status': 'out_for_delivery',
      }, language: 'uz');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('order-stage-current-onWay')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cart-root')), findsNothing);
      expect(submission.calls, 1);
      expect(f.container.read(orderDraftProvider(_type)).selection, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('submit revalidates fee and stops when radius changed', (
    tester,
  ) async {
    final submission = _Submission(_type, () async => null);
    var quote = _quote;
    await _mount(tester, submission: submission, estimate: () async => quote);
    quote = const DeliveryEstimate(
      available: false,
      detail: '',
      reasonCode: 'outside_delivery_radius',
    );
    await tester.tap(find.byKey(const ValueKey('checkout-submit')));
    await tester.pumpAndSettle();
    expect(find.text('CART:location'), findsOneWidget);
    expect(submission.calls, 0);
  });

  testWidgets('two taps during submit preflight create only one intent', (
    tester,
  ) async {
    final submission = _Submission(_type, () async => null);
    final f = await _mount(tester, submission: submission);
    final pending = Completer<DeliveryEstimate>();
    when(
      () => f.api.estimate(
        storeType: any(named: 'storeType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) => pending.future);
    final button = find.byKey(const ValueKey('checkout-submit'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(submission.calls, 0);
    pending.complete(_quote);
    await tester.pumpAndSettle();
    expect(submission.calls, 1);
  });

  testWidgets('order network failure retains review draft for retry', (
    tester,
  ) async {
    final submission = _Submission(
      _type,
      () async => throw const NetworkFailure(),
    );
    final f = await _mount(tester, submission: submission);
    f.draft.setNote('Saqlansin');
    await tester.tap(find.byKey(const ValueKey('checkout-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(f.container.read(orderDraftProvider(_type)).addressId, 'home');
    expect(f.container.read(orderDraftProvider(_type)).note, 'Saqlansin');
    expect(submission.calls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'unprepared direct link returns to cart instead of prompting GPS/address',
    (tester) async {
      final f = await _mount(tester, confirmed: false);
      expect(find.text('CART:location'), findsOneWidget);
      expect(f.container.read(orderDraftProvider(_type)).selection, isNull);
      verifyNever(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
      expect(
        find.byKey(const ValueKey('delivery-address-confirm')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry revalidates a confirmed quote before enabling order', (
    tester,
  ) async {
    final pending = Completer<DeliveryEstimate>();
    final f = await _mount(
      tester,
      estimate: () => pending.future,
      settle: false,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('checkout-submit-total')), findsNothing);
    pending.complete(_quote);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
          .onPressed,
      isNotNull,
    );
    verify(
      () => f.api.estimate(
        storeType: _type.wire,
        latitude: _address.latitude!,
        longitude: _address.longitude!,
      ),
    ).called(1);
    expect(find.byKey(const ValueKey('cart-root')), findsNothing);
  });

  for (final amount in ['8000', '15000', '17000', '20000']) {
    testWidgets('fresh quote minimum routes correctly at $amount', (
      tester,
    ) async {
      final f = await _mount(tester, cart: _cart(amount: amount));
      if (amount == '8000') {
        expect(find.text('CART:products'), findsOneWidget);
        expect(
          f.container.read(orderDraftProvider(_type)).notice,
          'minimum_not_met',
        );
        expect(
          f.container
              .read(cartControllerProvider(_type))
              .value!
              .cart
              .deliveryMinimumRemaining(deliveryFee: '5000'),
          '7000.00',
        );
      } else {
        expect(find.byType(CheckoutScreen), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('checkout-submit')),
              )
              .onPressed,
          isNotNull,
        );
      }
    });
  }

  testWidgets('minimum increased on refresh returns to products with notice', (
    tester,
  ) async {
    final f = await _mount(tester, afterRefresh: _cart(minimum: '30000'));
    expect(find.text('CART:products'), findsOneWidget);
    expect(
      f.container.read(orderDraftProvider(_type)).notice,
      'minimum_not_met',
    );
  });

  for (final invalidQuote in [
    const DeliveryEstimate(
      available: false,
      detail: 'Outside radius',
      reasonCode: 'outside_delivery_radius',
    ),
    const DeliveryEstimate(available: true, detail: '', deliveryPrice: null),
    const DeliveryEstimate(available: true, detail: '', deliveryPrice: 'bad'),
  ]) {
    testWidgets('unavailable or invalid delivery price returns to address', (
      tester,
    ) async {
      final f = await _mount(tester, quote: invalidQuote);
      expect(find.text('CART:location'), findsOneWidget);
      expect(
        f.container.read(orderDraftProvider(_type)).quoteFor(
          f.container.read(cartControllerProvider(_type)).value!.cart,
          const [_address],
        ),
        isNull,
      );
      expect(find.byKey(const ValueKey('checkout-submit-total')), findsNothing);
    });
  }

  testWidgets('deleted/coordinate-less selected address cannot enter review', (
    tester,
  ) async {
    final f = await _mount(
      tester,
      addresses: const [UserAddress(id: 'home', title: '', isDefault: true)],
    );
    expect(find.text('CART:location'), findsOneWidget);
    expect(f.container.read(orderDraftProvider(_type)).selection, isNull);
  });

  testWidgets(
    'changed physical store re-estimates instead of adopting stale quote',
    (tester) async {
      final f = await _mount(
        tester,
        afterRefresh: _cart(store: 'another-store'),
        quote: const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '9000',
        ),
      );
      final state = f.container.read(orderDraftProvider(_type));
      expect(state.selection!.storeScope, 'another-store');
      expect(state.estimate!.deliveryPrice, '9000');
      expect(find.byType(CheckoutScreen), findsOneWidget);
    },
  );

  testWidgets(
    'estimate network error stays in review, retry keeps selected address',
    (tester) async {
      var fail = true;
      final f = await _mount(
        tester,
        estimate: () async {
          if (fail) throw const NetworkFailure();
          return _quote;
        },
      );
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-retry')), findsOneWidget);
      expect(f.container.read(orderDraftProvider(_type)).addressId, 'home');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNull,
      );
      fail = false;
      await tester.tap(find.byKey(const ValueKey('checkout-retry')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'cart refresh network error stays retryable instead of redirecting',
    (tester) async {
      await _mount(tester, refreshFailure: const NetworkFailure());
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('cart-root')), findsNothing);
    },
  );

  testWidgets(
    'edit location returns cart focus, preserves note and default address',
    (tester) async {
      final f = await _mount(tester);
      f.draft.setNote('Eshik kodi 124');
      await tester.tap(find.byKey(const ValueKey('checkout-edit-location')));
      await tester.pumpAndSettle();
      expect(find.text('CART:location'), findsOneWidget);
      expect(
        f.container.read(orderDraftProvider(_type)).note,
        'Eshik kodi 124',
      );
      expect(
        f.container.read(addressesControllerProvider).value!.single.isDefault,
        isTrue,
      );
    },
  );

  testWidgets('edit products returns products focus without losing draft', (
    tester,
  ) async {
    final f = await _mount(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkout-edit-cart')),
    );
    await tester.tap(find.byKey(const ValueKey('checkout-edit-cart')));
    await tester.pumpAndSettle();
    expect(find.text('CART:products'), findsOneWidget);
    expect(f.container.read(orderDraftProvider(_type)).addressId, 'home');
  });

  testWidgets('legacy address URL is not covered by checkout redirect', (
    tester,
  ) async {
    final f = await _mount(
      tester,
      confirmed: false,
      initialLocation: Routes.deliveryAddressSelect(_type.wire),
    );
    expect(find.text('LEGACY ADDRESS'), findsOneWidget);
    expect(
      f.router.routeInformationProvider.value.uri.path,
      Routes.deliveryAddressSelect(_type.wire),
    );
    f.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('CART:location'), findsOneWidget);
  });

  testWidgets(
    'single pickup branch skips minimum and does not estimate delivery',
    (tester) async {
      final f = await _mount(
        tester,
        cart: _cart(amount: '8000'),
        confirmed: false,
        pickup: true,
        branches: [
          StoreBranch.fromJson({
            'id': 'branch',
            'name': 'Pickup filial',
            'address': 'Real address',
            'is_active': true,
            'is_pickup_available': true,
            'store': {'id': 'store', 'store_type': 'household'},
          }),
        ],
      );
      expect(find.text('Pickup filial'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNotNull,
      );
      verifyNever(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      );
    },
  );

  testWidgets(
    'multiple pickup branches without selection return to fulfillment',
    (tester) async {
      await _mount(
        tester,
        confirmed: false,
        pickup: true,
        branches: [
          for (final id in ['a', 'b'])
            StoreBranch.fromJson({
              'id': id,
              'name': id,
              'address': 'Real address',
              'is_active': true,
              'is_pickup_available': true,
              'store': {'id': 'store', 'store_type': 'household'},
            }),
        ],
      );
      expect(find.text('CART:fulfillment'), findsOneWidget);
    },
  );
}
