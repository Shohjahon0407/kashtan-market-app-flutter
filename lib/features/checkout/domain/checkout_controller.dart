import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../../cart/domain/cart_controller.dart';
import '../../orders/data/order_models.dart';
import '../../orders/domain/orders_controller.dart';
import '../../payments/data/payment_models.dart';
import '../data/checkout_models.dart';

class CheckoutSubmissionState {
  const CheckoutSubmissionState({this.isSubmitting = false, this.lastOrder});

  final bool isSubmitting;
  final OrderData? lastOrder;
}

final checkoutControllerProvider = NotifierProvider.autoDispose
    .family<CheckoutController, CheckoutSubmissionState, StoreType>(
      (storeType) => CheckoutController(storeType),
    );

class CheckoutController extends Notifier<CheckoutSubmissionState> {
  CheckoutController(this.storeType);

  final StoreType storeType;
  String? _submissionKey;
  String? _submissionSignature;

  @override
  CheckoutSubmissionState build() => const CheckoutSubmissionState();

  Future<OrderData?> submit({
    required FulfillmentType fulfillmentType,
    required PaymentMethod paymentMethod,
    String? addressId,
    String? pickupBranchId,
    String note = '',
  }) async {
    if (state.isSubmitting) return null;
    final paymentWire = paymentMethod.wireFor(fulfillmentType);
    final signature = [
      storeType.wire,
      fulfillmentType.wire,
      paymentWire,
      addressId ?? '',
      pickupBranchId ?? '',
      note.trim(),
    ].join('|');
    if (_submissionSignature != signature) {
      _submissionSignature = signature;
      _submissionKey = _newIdempotencyKey();
    }
    state = const CheckoutSubmissionState(isSubmitting: true);
    try {
      final order = await ref
          .read(ordersApiProvider)
          .create(
            storeType: storeType.wire,
            fulfillmentType: fulfillmentType,
            paymentMethod: paymentWire,
            addressId: addressId,
            pickupBranchId: pickupBranchId,
            note: note,
            idempotencyKey: _submissionKey,
          );
      await ref.read(cartControllerProvider(storeType).notifier).refresh();
      for (final query in orderQueriesForStore(storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
      state = CheckoutSubmissionState(lastOrder: order);
      _submissionKey = null;
      _submissionSignature = null;
      return order;
    } on ValidationFailure {
      // Definitive 400: shu payload qayta yuborilganda yangi checkout urinish
      // hisoblanadi. Network/timeout uchun esa ayni UUID saqlanadi.
      _submissionKey = null;
      _submissionSignature = null;
      state = const CheckoutSubmissionState();
      rethrow;
    } on Object {
      state = const CheckoutSubmissionState();
      rethrow;
    }
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // RFC 4122 version 4 + variant bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
