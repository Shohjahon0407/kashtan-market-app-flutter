import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_rules.dart';
import 'package:flutter_test/flutter_test.dart';

ProductSummary product(String id, String storeId) => ProductSummary.fromJson({
  'id': id,
  'name': id,
  'price': '1000.00',
  'is_purchasable': true,
  'store_type': 'household',
  'store': {'id': storeId, 'name': storeId, 'store_type': 'household'},
  'variants': <Map<String, dynamic>>[],
});

CartData cart(List<ProductSummary> products) => CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: [
    for (var i = 0; i < products.length; i++)
      CartItem(
        id: 'item-$i',
        product: products[i],
        quantity: 1,
        selectedAddons: const [],
        note: '',
        subtotal: '1000.00',
      ),
  ],
  totalItems: products.length,
  totalQuantity: products.length,
  subtotal: '${products.length * 1000}.00',
);

void main() {
  test('display total uses exact money and only a resolved delivery fee', () {
    expect(
      CheckoutRules.displayTotal(
        subtotal: '180000',
        fulfillment: FulfillmentType.delivery,
        estimate: const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '5000',
        ),
      ),
      '185000.00',
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '0.10',
        fulfillment: FulfillmentType.delivery,
        estimate: const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '0.20',
        ),
      ),
      '0.30',
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '180000.01',
        fulfillment: FulfillmentType.pickup,
      ),
      '180000.01',
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '180000',
        fulfillment: FulfillmentType.delivery,
      ),
      isNull,
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '180000',
        fulfillment: FulfillmentType.delivery,
        estimate: const DeliveryEstimate(
          available: false,
          detail: '',
          deliveryPrice: '5000',
        ),
      ),
      isNull,
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '180000',
        fulfillment: FulfillmentType.delivery,
        estimating: true,
        estimate: const DeliveryEstimate(
          available: true,
          detail: '',
          deliveryPrice: '5000',
        ),
      ),
      isNull,
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: 'bad',
        fulfillment: FulfillmentType.pickup,
      ),
      isNull,
    );
    expect(
      CheckoutRules.displayTotal(
        subtotal: '-100',
        fulfillment: FulfillmentType.pickup,
      ),
      isNull,
    );
  });
  const available = DeliveryEstimate(
    available: true,
    detail: '',
    deliveryPrice: '5000',
  );
  const unavailable = DeliveryEstimate(available: false, detail: 'uzoq');

  test('delivery address va available estimate bo‘lmasa submit bloklanadi', () {
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.delivery,
        addressId: null,
        estimate: available,
        isEstimating: false,
        pickupBranchId: null,
        pickupAllowed: true,
      ),
      isFalse,
    );
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.delivery,
        addressId: 'address-1',
        estimate: unavailable,
        isEstimating: false,
        pickupBranchId: null,
        pickupAllowed: true,
      ),
      isFalse,
    );
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.delivery,
        addressId: 'address-1',
        estimate: available,
        isEstimating: false,
        pickupBranchId: null,
        pickupAllowed: true,
      ),
      isTrue,
    );
  });

  test('pickup faqat bitta physical store va tanlangan filial bilan', () {
    final singleStore = cart([
      product('p-1', 'store-1'),
      product('p-2', 'store-1'),
    ]);
    final mixedStore = cart([
      product('p-1', 'store-1'),
      product('p-2', 'store-2'),
    ]);
    expect(CheckoutRules.pickupAllowed(singleStore), isTrue);
    expect(CheckoutRules.pickupAllowed(mixedStore), isFalse);
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.pickup,
        addressId: null,
        estimate: null,
        isEstimating: false,
        pickupBranchId: null,
        pickupAllowed: true,
      ),
      isFalse,
    );
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.pickup,
        addressId: null,
        estimate: null,
        isEstimating: false,
        pickupBranchId: 'branch-1',
        pickupAllowed: true,
      ),
      isTrue,
    );
    expect(
      CheckoutRules.canSubmit(
        fulfillmentType: FulfillmentType.pickup,
        addressId: null,
        estimate: null,
        isEstimating: false,
        pickupBranchId: 'branch-1',
        pickupAllowed: false,
      ),
      isFalse,
    );
  });
}
