import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/storage/account_scope.dart';
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

/// Buyurtma yaratish idempotency kalitlari — checkout controller'idan TASHQARIDA.
///
/// Controller autoDispose: timeout'dan keyin foydalanuvchi savatga qaytib,
/// checkout'ga qayta kirsa yangi instance qurilardi va kalit yo'qolardi —
/// server javobi yo'qolgan (lekin buyurtma yaratilgan) holatda qayta
/// yuborish IKKINCHI buyurtma ochardi. Kalit shu yerda, do'kon bo'yicha,
/// muvaffaqiyat yoki qat'iy 400 gacha saqlanadi; akkaunt almashsa tozalanadi.
final checkoutIdempotencyStoreProvider = Provider<CheckoutIdempotencyStore>((
  ref,
) {
  ref.watch(accountScopeProvider);
  return CheckoutIdempotencyStore();
});

class CheckoutIdempotencyStore {
  final _entries = <StoreType, ({String signature, String key})>{};

  /// Ayni imzo uchun mavjud kalitni qaytaradi, aks holda yangisini yaratadi.
  String keyFor(StoreType storeType, String signature) {
    final existing = _entries[storeType];
    if (existing != null && existing.signature == signature) {
      return existing.key;
    }
    final key = _newIdempotencyKey();
    _entries[storeType] = (signature: signature, key: key);
    return key;
  }

  void clear(StoreType storeType) => _entries.remove(storeType);

  static String _newIdempotencyKey() {
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

final checkoutControllerProvider = NotifierProvider.autoDispose
    .family<CheckoutController, CheckoutSubmissionState, StoreType>(
      (storeType) => CheckoutController(storeType),
    );

class CheckoutController extends Notifier<CheckoutSubmissionState> {
  CheckoutController(this.storeType);

  final StoreType storeType;

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
    // Izoh imzoga KIRMAYDI: bitta belgi o'zgarsa yangi kalit — ayni
    // buyurtma niyati uchun takroriy buyurtma bo'lardi.
    final signature = [
      storeType.wire,
      fulfillmentType.wire,
      paymentWire,
      addressId ?? '',
      pickupBranchId ?? '',
    ].join('|');
    final keys = ref.read(checkoutIdempotencyStoreProvider);
    final idempotencyKey = keys.keyFor(storeType, signature);
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
            idempotencyKey: idempotencyKey,
          );
      // Buyurtma yaratildi — kalit ishini tugatdi (store keepAlive, shuning
      // uchun ekran yopilgan bo'lsa ham tozalanadi).
      keys.clear(storeType);
      // Ekran yopilgan bo'lsa provider dispose bo'lgan: `ref`/`state` ga
      // tegib bo'lmaydi, buyurtma esa baribir mavjud.
      if (!ref.mounted) return order;
      await ref.read(cartControllerProvider(storeType).notifier).refresh();
      if (!ref.mounted) return order;
      for (final query in orderQueriesAffectedBy(storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
      state = CheckoutSubmissionState(lastOrder: order);
      return order;
    } on ValidationFailure {
      // Definitive 400: shu payload qayta yuborilganda yangi checkout urinish
      // hisoblanadi. Network/timeout uchun esa ayni UUID saqlanadi.
      keys.clear(storeType);
      if (ref.mounted) state = const CheckoutSubmissionState();
      rethrow;
    } on Object {
      if (ref.mounted) state = const CheckoutSubmissionState();
      rethrow;
    }
  }
}
