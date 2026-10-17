import 'dart:async';

import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/offline_cart_queue.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements CheckoutApi {}

class _Merge extends Mock implements GuestCartCoordinator {}

class _Queue extends Mock implements OfflineCartQueue {}

class _Account extends Notifier<String> {
  @override
  String build() => 'user_one';
  void change(String owner) => state = owner;
}

final _accountProvider = NotifierProvider<_Account, String>(_Account.new);

const _home = UserAddress(
  id: 'home',
  title: 'Uy',
  isDefault: true,
  latitude: 41,
  longitude: 69,
);
const _work = UserAddress(
  id: 'work',
  title: 'Ishxona',
  isDefault: false,
  latitude: 41.01,
  longitude: 69.01,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
);

CartData _cart({
  StoreType type = StoreType.household,
  List<String> stores = const ['physical-one'],
}) => CartData(
  id: 'cart-${type.wire}',
  storeTypeWire: type.wire,
  items: [
    for (var i = 0; i < stores.length; i++)
      CartItem(
        id: 'item-$i',
        product: ProductSummary.fromJson({
          'id': 'product-$i',
          'name': 'Product',
          'price': '8000',
          'store_type': type.wire,
          'store': {'id': stores[i], 'name': 'Store', 'store_type': type.wire},
        }),
        quantity: 1,
        selectedAddons: const [],
        note: '',
        subtotal: '8000',
      ),
  ],
  totalItems: stores.length,
  totalQuantity: stores.length,
  subtotal: '${8000 * stores.length}',
  minimumDeliveryOrderAmount: '20000',
);

class _Cart extends CartController {
  _Cart(super.storeType, this.log);
  final List<String> log;
  ApiFailure? refreshFailure;
  CartState? next;

  @override
  Future<CartState> build() async => CartState(cart: _cart(type: storeType));

  @override
  Future<void> refresh() async {
    log.add('cart-refresh');
    if (refreshFailure case final failure?) {
      state = AsyncData(
        state.requireValue.copyWith(mutationFailure: () => failure),
      );
    } else {
      state = AsyncData(next ?? CartState(cart: state.requireValue.cart));
    }
  }

  void publish(CartState cart) => state = AsyncData(cart);
  void loading() => state = const AsyncLoading();
}

class _Addresses extends AddressesController {
  _Addresses(this.log);
  final List<String> log;
  ApiFailure? readFailure;

  @override
  ApiFailure? get refreshFailure => readFailure;

  @override
  Future<List<UserAddress>> build() async => [_home, _work];

  @override
  Future<void> refresh() async {
    log.add('address-refresh');
    state = AsyncData(state.requireValue);
  }

  void publish(List<UserAddress> addresses) => state = AsyncData(addresses);
}

typedef _Fixture = ({
  ProviderContainer container,
  OrderDraftController draft,
  _Cart cart,
  _Addresses addresses,
  _Api api,
  _Merge merge,
  _Queue queue,
  List<String> log,
});

Future<_Fixture> _fixture() async {
  final log = <String>[];
  final api = _Api();
  final merge = _Merge();
  final queue = _Queue();
  when(() => queue.flush()).thenAnswer((_) async {});
  when(() => queue.isEmpty).thenReturn(true);
  when(() => merge.mergeIfNeeded()).thenAnswer((_) async => log.add('merge'));
  when(
    () => api.estimate(
      storeType: any(named: 'storeType'),
      latitude: any(named: 'latitude'),
      longitude: any(named: 'longitude'),
    ),
  ).thenAnswer((_) async {
    log.add('estimate');
    return _quote;
  });
  final container = ProviderContainer(
    overrides: [
      accountScopeProvider.overrideWith((ref) => ref.watch(_accountProvider)),
      checkoutApiProvider.overrideWithValue(api),
      guestCartCoordinatorProvider.overrideWithValue(merge),
      offlineCartQueueProvider.overrideWithValue(queue),
      for (final type in StoreType.values)
        cartControllerProvider(type).overrideWith(() => _Cart(type, log)),
      addressesControllerProvider.overrideWith(() => _Addresses(log)),
    ],
  );
  addTearDown(container.dispose);
  final draft = container.read(
    orderDraftProvider(StoreType.household).notifier,
  );
  await container.read(cartControllerProvider(StoreType.household).future);
  await container.read(addressesControllerProvider.future);
  return (
    container: container,
    draft: draft,
    cart:
        container.read(cartControllerProvider(StoreType.household).notifier)
            as _Cart,
    addresses:
        container.read(addressesControllerProvider.notifier) as _Addresses,
    api: api,
    merge: merge,
    queue: queue,
    log: log,
  );
}

OrderDraftState _state(_Fixture f) =>
    f.container.read(orderDraftProvider(StoreType.household));

DeliveryAddressSelection _selection(
  _Fixture f, {
  UserAddress address = _home,
  DeliveryEstimate quote = _quote,
}) => DeliveryAddressSelection(
  address: address,
  estimate: quote,
  storeScope: deliveryStoreScope(
    f.container
        .read(cartControllerProvider(StoreType.household))
        .requireValue
        .cart,
  ),
);

Future<void> _tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'offline queue is flushed before guest merge and authoritative cart read',
    () async {
      final f = await _fixture();
      when(() => f.queue.isEmpty).thenReturn(false);
      when(() => f.queue.flush()).thenAnswer((_) async {
        f.log.add('queue-flush');
        when(() => f.queue.isEmpty).thenReturn(true);
      });
      expect(await f.draft.prepare(revalidateQuote: false), isTrue);
      expect(f.log, ['queue-flush', 'merge', 'cart-refresh']);
    },
  );

  test(
    'unflushed offline work blocks checkout even with optimistic minimum',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      when(() => f.queue.isEmpty).thenReturn(false);
      expect(await f.draft.prepare(), isFalse);
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(_state(f).notice, OrderDraftNotice.cartNotReady);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      expect(f.log, isEmpty);
      verifyNever(() => f.merge.mergeIfNeeded());
      when(() => f.queue.isEmpty).thenReturn(true);
      expect(await f.draft.prepare(), isTrue);
      expect(_state(f).failure, isNull);
    },
  );

  test(
    'queue flush failure is visible and cannot reach cart/quote reads',
    () async {
      final f = await _fixture();
      when(() => f.queue.flush()).thenThrow(const NetworkFailure());
      expect(await f.draft.prepare(), isFalse);
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(f.log, isEmpty);
      verifyNever(() => f.merge.mergeIfNeeded());
    },
  );

  test(
    'retained cached address cannot pass confirmation after refresh failure',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      f.addresses.readFailure = const NetworkFailure();
      expect(await f.draft.prepare(), isFalse);
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(_state(f).quoteInvalidated, isTrue);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      expect(f.log, ['merge', 'cart-refresh', 'address-refresh']);
      expect(await f.draft.prepare(revalidateQuote: false), isTrue);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      f.addresses.readFailure = null;
      expect(await f.draft.prepare(), isTrue);
      expect(_state(f).failure, isNull);
    },
  );

  test(
    'background address refresh failure invalidates and prevents auto-quote',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      f.addresses.readFailure = const NetworkFailure();
      f.addresses.publish([_home, _work]);
      await _tick();
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      await f.draft.refreshQuote();
      expect(f.log, isEmpty);
      expect(_state(f).estimating, isFalse);
    },
  );

  test(
    'creating draft and receiving cart/address data never auto-estimates',
    () async {
      final f = await _fixture();
      f.cart.publish(CartState(cart: _cart(stores: ['another-store'])));
      f.addresses.publish([_work, _home]);
      await _tick();
      expect(_state(f).selection, isNull);
      expect(_state(f).estimating, isFalse);
      expect(f.log, isEmpty);
    },
  );

  test(
    'unavailable quote does not prevent reopening address selector',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(
        _selection(
          f,
          quote: const DeliveryEstimate(
            available: false,
            detail: '',
            reasonCode: 'outside_delivery_radius',
          ),
        ),
      );
      expect(await f.draft.prepare(revalidateQuote: false), isTrue);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      expect(f.log, ['merge', 'cart-refresh', 'address-refresh']);
    },
  );

  test(
    'opening selector after quote failure never revives old successful fee',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      when(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenThrow(const NetworkFailure());
      await f.draft.refreshQuote();
      expect(_state(f).quoteInvalidated, isTrue);
      expect(await f.draft.prepare(revalidateQuote: false), isTrue);
      expect(_state(f).failure, isNull);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
    },
  );

  test(
    'single-store change clears pickup after pending mutations settle',
    () async {
      final f = await _fixture();
      f.draft.setFulfillment(FulfillmentType.pickup);
      f.draft.setPickupBranch('branch');
      final changed = _cart(stores: ['another-store']);
      f.cart.publish(CartState(cart: changed, busyKeys: {'quantity'}));
      expect(_state(f).pickupBranchId, 'branch');
      f.cart.publish(CartState(cart: changed));
      expect(_state(f).pickupBranchId, isNull);
      expect(_state(f).fulfillment, FulfillmentType.pickup);
    },
  );

  test('quote from prior account is discarded after logout', () async {
    final f = await _fixture();
    await f.draft.acceptAddress(_selection(f));
    final pending = Completer<DeliveryEstimate>();
    when(
      () => f.api.estimate(
        storeType: any(named: 'storeType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) => pending.future);
    final request = f.draft.refreshQuote();
    f.container.read(_accountProvider.notifier).change('guest');
    expect(_state(f).selection, isNull);
    pending.complete(_quote);
    await request;
    expect(_state(f).selection, isNull);
    expect(_state(f).estimating, isFalse);
  });

  test(
    'confirmed 8000 + 5000 requires 7000; draft is account-local only',
    () async {
      final f = await _fixture();
      expect(_state(f).selection, isNull);
      await f.draft.acceptAddress(_selection(f));
      final cart = f.container
          .read(cartControllerProvider(StoreType.household))
          .requireValue
          .cart;
      final quote = _state(f).quoteFor(cart, [_home, _work]);
      expect(quote?.deliveryPrice, '5000');
      expect(
        cart.deliveryMinimumRemaining(deliveryFee: quote!.deliveryPrice),
        '7000.00',
      );
      expect(
        f.container
            .read(addressesControllerProvider)
            .requireValue
            .first
            .isDefault,
        isTrue,
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

  test(
    'prepare merges first, refreshes cart then addresses, then re-estimates',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      expect(await f.draft.prepare(), isTrue);
      expect(f.log, ['merge', 'cart-refresh', 'address-refresh', 'estimate']);
      expect(_state(f).preparing, isFalse);
      expect(_state(f).estimating, isFalse);
    },
  );

  test(
    'prepare without a selected address never estimates or selects default',
    () async {
      final f = await _fixture();
      expect(await f.draft.prepare(revalidateQuote: false), isTrue);
      expect(_state(f).addressId, isNull);
      expect(f.log, ['merge', 'cart-refresh']);
    },
  );

  test('pending or unconfirmed cart blocks preparation before merge', () async {
    final f = await _fixture();
    for (final pending in [true, false]) {
      f.cart.publish(
        CartState(
          cart: _cart(),
          busyKeys: pending ? {'quantity'} : {},
          unconfirmedKeys: pending ? {} : {'unconfirmed'},
        ),
      );
      expect(await f.draft.prepare(), isFalse);
      expect(_state(f).notice, OrderDraftNotice.cartNotReady);
    }
    verifyNever(() => f.merge.mergeIfNeeded());
  });

  test(
    'swallowed cart refresh failure cannot reuse old quote; retry recovers',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      f.cart.refreshFailure = const NetworkFailure();
      expect(await f.draft.prepare(), isFalse);
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      f.cart.refreshFailure = null;
      expect(await f.draft.prepare(), isTrue);
      expect(_state(f).failure, isNull);
    },
  );

  test('merge failure is visible and no estimate or refresh follows', () async {
    final f = await _fixture();
    when(() => f.merge.mergeIfNeeded()).thenThrow(const NetworkFailure());
    expect(await f.draft.prepare(), isFalse);
    expect(_state(f).failure, isA<NetworkFailure>());
    expect(f.log, isEmpty);
  });

  test('late quote cannot replace a newer explicit address choice', () async {
    final f = await _fixture();
    await f.draft.acceptAddress(_selection(f));
    final pending = Completer<DeliveryEstimate>();
    when(
      () => f.api.estimate(
        storeType: any(named: 'storeType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
      ),
    ).thenAnswer((_) => pending.future);
    final old = f.draft.refreshQuote();
    await f.draft.acceptAddress(_selection(f, address: _work));
    pending.complete(
      const DeliveryEstimate(
        available: true,
        detail: '',
        deliveryPrice: '99000',
      ),
    );
    await old;
    expect(_state(f).addressId, 'work');
    expect(_state(f).estimate?.deliveryPrice, '5000');
  });

  test(
    'address coordinate change hides old fee and ignores late response',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      final requests = <Completer<DeliveryEstimate>>[];
      when(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer((_) {
        final request = Completer<DeliveryEstimate>();
        requests.add(request);
        return request.future;
      });
      final old = f.draft.refreshQuote();
      const moved = UserAddress(
        id: 'home',
        title: 'Uy',
        isDefault: true,
        latitude: 41.1,
        longitude: 69.1,
      );
      f.addresses.publish([moved, _work]);
      expect(_state(f).quoteFor(_cart(), [moved, _work]), isNull);
      await _tick();
      expect(requests, hasLength(2));
      requests.last.complete(
        const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '7000',
        ),
      );
      await _tick();
      requests.first.complete(
        const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '99000',
        ),
      );
      await old;
      expect(_state(f).selection?.address.latitude, 41.1);
      expect(_state(f).estimate?.deliveryPrice, '7000');
      expect(_state(f).estimating, isFalse);
    },
  );

  test('physical store change requotes only after stable mutation', () async {
    final f = await _fixture();
    await f.draft.acceptAddress(_selection(f));
    final changed = _cart(stores: ['physical-two']);
    f.cart.publish(CartState(cart: changed, busyKeys: {'quantity'}));
    await _tick();
    expect(f.log, isEmpty);
    expect(_state(f).quoteFor(changed, [_home]), isNull);
    f.cart.publish(CartState(cart: changed));
    await _tick();
    expect(f.log, ['estimate']);
    expect(_state(f).selection?.storeScope, 'physical-two');
  });

  test(
    'deleting selected address clears selection; editing labels does not requote',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      f.addresses.publish(const [
        UserAddress(
          id: 'home',
          title: 'Renamed',
          isDefault: true,
          latitude: 41,
          longitude: 69,
        ),
      ]);
      await _tick();
      expect(f.log, isEmpty);
      expect(_state(f).addressId, 'home');
      f.addresses.publish([_work]);
      await _tick();
      expect(_state(f).addressId, isNull);
      expect(_state(f).notice, OrderDraftNotice.addressChanged);
    },
  );

  test(
    'pickup keeps address draft but never exposes its delivery fee',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      f.draft.setFulfillment(FulfillmentType.pickup);
      f.draft.setPickupBranch('branch');
      expect(_state(f).addressId, 'home');
      expect(_state(f).estimate, isNull);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      expect(await f.draft.prepare(), isTrue);
      expect(_state(f).pickupBranchId, 'branch');
    },
  );

  test(
    'mixed physical stores force delivery and clear pickup branch',
    () async {
      final f = await _fixture();
      f.draft.setFulfillment(FulfillmentType.pickup);
      f.draft.setPickupBranch('branch');
      f.cart.publish(CartState(cart: _cart(stores: ['one', 'two'])));
      await _tick();
      expect(_state(f).fulfillment, FulfillmentType.delivery);
      expect(_state(f).pickupBranchId, isNull);
    },
  );

  test(
    'unavailable/missing/malformed price never becomes a usable quote',
    () async {
      final f = await _fixture();
      for (final quote in [
        const DeliveryEstimate(
          available: false,
          detail: '',
          deliveryPrice: '5000',
        ),
        const DeliveryEstimate(available: true, detail: ''),
        const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: 'bad',
        ),
      ]) {
        await f.draft.acceptAddress(_selection(f, quote: quote));
        expect(_state(f).quoteFor(_cart(), [_home]), isNull);
        expect(_state(f).notice, OrderDraftNotice.deliveryUnavailable);
      }
    },
  );

  test(
    'quote network failure leaves retry available without using old total',
    () async {
      final f = await _fixture();
      await f.draft.acceptAddress(_selection(f));
      when(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenThrow(const NetworkFailure());
      await f.draft.refreshQuote();
      expect(_state(f).failure, isA<NetworkFailure>());
      expect(_state(f).estimating, isFalse);
      expect(_state(f).quoteFor(_cart(), [_home]), isNull);
      when(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer((_) async => _quote);
      await f.draft.refreshQuote();
      expect(_state(f).quoteFor(_cart(), [_home])?.deliveryPrice, '5000');
    },
  );

  test(
    'loading and optimistic empty do not reset; confirmed empty does',
    () async {
      final f = await _fixture();
      f.draft.setNote('Keep this');
      f.cart.loading();
      expect(_state(f).note, 'Keep this');
      f.cart.publish(
        CartState(cart: CartData.empty('household'), busyKeys: {'clear'}),
      );
      expect(_state(f).note, 'Keep this');
      f.cart.publish(CartState(cart: CartData.empty('household')));
      expect(_state(f).note, isEmpty);
      expect(await f.draft.prepare(), isFalse);
    },
  );

  test(
    'account and stores isolate draft, reset clears late requests',
    () async {
      final f = await _fixture();
      f.draft.setNote('Household note');
      f.draft.setPaymentMethod(PaymentMethod.payme);
      final other = f.container.read(
        orderDraftProvider(StoreType.meat).notifier,
      );
      other.setNote('Meat note');
      expect(_state(f).note, 'Household note');
      expect(
        f.container.read(orderDraftProvider(StoreType.meat)).note,
        'Meat note',
      );
      await f.draft.acceptAddress(_selection(f));
      final pending = Completer<DeliveryEstimate>();
      when(
        () => f.api.estimate(
          storeType: any(named: 'storeType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer((_) => pending.future);
      final request = f.draft.refreshQuote();
      f.draft.clear();
      pending.complete(_quote);
      await request;
      expect(_state(f).selection, isNull);
      expect(_state(f).paymentMethod, PaymentMethod.cash);
      f.draft.setNote('Before logout');
      f.container.read(_accountProvider.notifier).change('guest');
      expect(_state(f).note, isEmpty);
      expect(
        f.container.read(orderDraftProvider(StoreType.meat)).note,
        isEmpty,
      );
    },
  );
}
