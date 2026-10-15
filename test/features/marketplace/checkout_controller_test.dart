import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/domain/payment_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCartApi extends Mock implements CartApi {}

class _MockOrdersApi extends Mock implements OrdersApi {}

final _product = ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Sovun',
  'description': '',
  'price': '12000.00',
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'store': {'id': 'store-1', 'name': 'Xozmak', 'store_type': 'household'},
  'variants': <Map<String, dynamic>>[],
});

CartData cart(bool empty) => CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: empty
      ? const []
      : [
          CartItem(
            id: 'item-1',
            product: _product,
            quantity: 1,
            selectedAddons: const [],
            note: '',
            subtotal: '12000.00',
          ),
        ],
  totalItems: empty ? 0 : 1,
  totalQuantity: empty ? 0 : 1,
  subtotal: empty ? '0.00' : '12000.00',
);

final _order = OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'household',
  'fulfillment_type': 'delivery',
  'status': 'pending',
  'status_label': 'Ko‘rib chiqilmoqda',
  'payment_method': 'cash_to_courier',
  'payment_status': 'pending',
  'subtotal': '12000.00',
  'delivery_fee': '5000.00',
  'total': '17000.00',
  'items': <Map<String, dynamic>>[],
  'created_at': '2026-07-31T10:00:00Z',
});

void main() {
  _paymentMethodTests();
  test(
    'double-submit bloklanadi va success’dan keyin aynan store cart refetch',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final cartApi = _MockCartApi();
      final ordersApi = _MockOrdersApi();
      var fetchCount = 0;
      when(() => cartApi.fetch('household')).thenAnswer((_) async {
        fetchCount++;
        return cart(fetchCount > 1);
      });
      final create = Completer<OrderData>();
      when(
        () => ordersApi.create(
          storeType: 'household',
          fulfillmentType: FulfillmentType.delivery,
          paymentMethod: any(named: 'paymentMethod'),
          addressId: 'address-1',
          pickupBranchId: null,
          note: 'tezroq',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) => create.future);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(cartApi),
          ordersApiProvider.overrideWithValue(ordersApi),
        ],
      );
      addTearDown(container.dispose);
      final cartProvider = cartControllerProvider(StoreType.household);
      final cartSubscription = container.listen(cartProvider, (_, _) {});
      addTearDown(cartSubscription.close);
      await container.read(cartProvider.future);
      final checkoutProvider = checkoutControllerProvider(StoreType.household);
      final checkoutSubscription = container.listen(
        checkoutProvider,
        (_, _) {},
      );
      addTearDown(checkoutSubscription.close);
      final controller = container.read(checkoutProvider.notifier);

      final first = controller.submit(
        fulfillmentType: FulfillmentType.delivery,
        paymentMethod: PaymentMethod.payme,
        addressId: 'address-1',
        note: 'tezroq',
      );
      final duplicate = await controller.submit(
        fulfillmentType: FulfillmentType.delivery,
        paymentMethod: PaymentMethod.payme,
        addressId: 'address-1',
        note: 'tezroq',
      );
      expect(duplicate, isNull);
      expect(container.read(checkoutProvider).isSubmitting, isTrue);

      create.complete(_order);
      expect(await first, same(_order));
      expect(container.read(checkoutProvider).isSubmitting, isFalse);
      expect(container.read(cartProvider).value?.cart.items, isEmpty);
      expect(fetchCount, 2);
      final captured = verify(
        () => ordersApi.create(
          storeType: 'household',
          fulfillmentType: FulfillmentType.delivery,
          paymentMethod: any(named: 'paymentMethod'),
          addressId: 'address-1',
          pickupBranchId: null,
          note: 'tezroq',
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      )..called(1);
      final key = captured.captured.single as String;
      expect(
        key,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    },
  );
}

// ─── To'lov usuli va idempotency ─────────────────────────────────────────────

void _paymentMethodTests() {
  for (final enabled in [false, true]) {
    test(
      'payment submission and idempotency with Payme enabled=$enabled',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await PrefsStore.load();
        final cartApi = _MockCartApi();
        final ordersApi = _MockOrdersApi();
        when(
          () => cartApi.fetch('household'),
        ).thenAnswer((_) async => cart(false));
        when(
          () => ordersApi.create(
            storeType: 'household',
            fulfillmentType: FulfillmentType.delivery,
            paymentMethod: any(named: 'paymentMethod'),
            addressId: 'address-1',
            pickupBranchId: null,
            note: '',
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer((_) async => _order);

        final container = ProviderContainer(
          overrides: [
            if (enabled) paymeEnabledProvider.overrideWithValue(true),
            prefsStoreProvider.overrideWithValue(prefs),
            cartApiProvider.overrideWithValue(cartApi),
            ordersApiProvider.overrideWithValue(ordersApi),
          ],
        );
        addTearDown(container.dispose);
        final checkoutProvider = checkoutControllerProvider(
          StoreType.household,
        );
        final subscription = container.listen(checkoutProvider, (_, _) {});
        addTearDown(subscription.close);
        final controller = container.read(checkoutProvider.notifier);

        await controller.submit(
          fulfillmentType: FulfillmentType.delivery,
          paymentMethod: PaymentMethod.payme,
          addressId: 'address-1',
        );
        await controller.submit(
          fulfillmentType: FulfillmentType.delivery,
          paymentMethod: PaymentMethod.cash,
          addressId: 'address-1',
        );

        final captured = verify(
          () => ordersApi.create(
            storeType: 'household',
            fulfillmentType: FulfillmentType.delivery,
            paymentMethod: captureAny(named: 'paymentMethod'),
            addressId: 'address-1',
            pickupBranchId: null,
            note: '',
            idempotencyKey: captureAny(named: 'idempotencyKey'),
          ),
        ).captured;

        // captured = [payme, key1, cash_to_courier, key2]
        expect(captured[0], enabled ? 'payme' : 'cash_to_courier');
        expect(captured[2], 'cash_to_courier');
        expect(
          captured[1],
          isNot(captured[3]),
          reason: "usul o'zgardi — kalit ham yangilanishi kerak",
        );
      },
    );
  }
}
