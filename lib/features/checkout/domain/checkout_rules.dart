import '../../cart/data/cart_models.dart';
import '../data/checkout_models.dart';

abstract final class CheckoutRules {
  static Set<String> physicalStoreIds(CartData cart) => cart.items
      .map((item) => item.product.store?.id)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet();

  static bool pickupAllowed(CartData cart) =>
      physicalStoreIds(cart).length == 1;

  static bool canSubmit({
    required FulfillmentType fulfillmentType,
    required String? addressId,
    required DeliveryEstimate? estimate,
    required bool isEstimating,
    required String? pickupBranchId,
    required bool pickupAllowed,
  }) => switch (fulfillmentType) {
    FulfillmentType.delivery =>
      addressId != null &&
          addressId.isNotEmpty &&
          estimate?.available == true &&
          !isEstimating,
    FulfillmentType.pickup =>
      pickupAllowed && pickupBranchId != null && pickupBranchId.isNotEmpty,
  };
}
