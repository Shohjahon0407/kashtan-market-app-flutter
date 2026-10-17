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

  /// Presentation-only total. Never invent a zero delivery fee while the
  /// address/estimate is unresolved, and never use floating-point money.
  static String? displayTotal({
    required String subtotal,
    required FulfillmentType fulfillment,
    DeliveryEstimate? estimate,
    bool estimating = false,
  }) {
    BigInt? minor(String raw) {
      final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(raw.trim());
      if (match == null) return null;
      return BigInt.parse(match[1]!) * BigInt.from(100) +
          BigInt.parse((match[2] ?? '').padRight(2, '0'));
    }

    final products = minor(subtotal);
    if (products == null) return null;
    var shipping = BigInt.zero;
    if (fulfillment == FulfillmentType.delivery) {
      if (estimating ||
          estimate?.available != true ||
          estimate?.deliveryPrice == null) {
        return null;
      }
      final parsed = minor(estimate!.deliveryPrice!);
      if (parsed == null) return null;
      shipping = parsed;
    }
    final total = products + shipping;
    return '${total ~/ BigInt.from(100)}.${(total % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  static bool canSubmit({
    required FulfillmentType fulfillmentType,
    required String? addressId,
    required DeliveryEstimate? estimate,
    required bool isEstimating,
    required String? pickupBranchId,
    required bool pickupAllowed,
    CartData? cart,
  }) => switch (fulfillmentType) {
    FulfillmentType.delivery =>
      (cart?.meetsDeliveryMinimumIncluding(
                !isEstimating && estimate?.available == true
                    ? estimate?.deliveryPrice
                    : null,
              ) ??
              true) &&
          addressId != null &&
          addressId.isNotEmpty &&
          estimate?.available == true &&
          estimate?.deliveryPrice != null &&
          displayTotal(
                subtotal: cart?.subtotal ?? '0',
                fulfillment: fulfillmentType,
                estimate: estimate,
                estimating: isEstimating,
              ) !=
              null &&
          !isEstimating,
    FulfillmentType.pickup =>
      pickupAllowed && pickupBranchId != null && pickupBranchId.isNotEmpty,
  };
}
