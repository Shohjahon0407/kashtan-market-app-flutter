import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/storage/prefs_store.dart';
import '../../../core/store_scope/store_type.dart';
import '../../cart/domain/cart_controller.dart';
import '../../orders/data/order_models.dart';
import '../../orders/domain/orders_controller.dart';
import '../../payments/data/payment_models.dart';
import '../../payments/domain/payment_availability.dart';
import '../data/checkout_models.dart';

class CheckoutSubmissionState {
  const CheckoutSubmissionState({this.isSubmitting = false, this.lastOrder});

  final bool isSubmitting;
  final OrderData? lastOrder;
}

/// Pending checkout is persisted before POST and scoped to the account/store.
/// An uncertain attempt retains its original payload/revision across restarts.
/// Only a definitive rejection or handoff to the resulting order clears it.
final checkoutIdempotencyStoreProvider = Provider<CheckoutIdempotencyStore>((
  ref,
) {
  return CheckoutIdempotencyStore(
    ref.watch(prefsStoreProvider),
    ref.watch(accountScopeProvider),
  );
});

class CheckoutIdempotencyStore {
  CheckoutIdempotencyStore([this.prefs, this.owner = 'test']);
  final PrefsStore? prefs;
  final String owner;
  String _diskKey(StoreType store) =>
      'checkout.pending.v1.$owner.${store.wire}';
  Map<String, dynamic>? pending(StoreType store) {
    final raw = prefs?.getString(_diskKey(store));
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>> prepare(
    StoreType store,
    Map<String, dynamic> payload,
  ) async {
    final existing = pending(store);
    if (existing != null) return existing;
    final entry = {
      'key': keyFor(store, jsonEncode(payload)),
      'payload': payload,
    };
    await prefs?.setString(_diskKey(store), jsonEncode(entry));
    return entry;
  }

  Future<void> acknowledge(StoreType store) async {
    await prefs?.remove(_diskKey(store));
    clear(store);
  }

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
  CheckoutSubmissionState build() {
    ref.watch(accountScopeProvider);
    final pending = ref
        .read(checkoutIdempotencyStoreProvider)
        .pending(storeType);
    if (pending != null) Future.microtask(_recover);
    return CheckoutSubmissionState(isSubmitting: pending != null);
  }

  Future<void> _recover() async {
    if (!ref.mounted) return;
    final owner = ref.read(accountScopeProvider);
    final entry = ref.read(checkoutIdempotencyStoreProvider).pending(storeType);
    if (entry == null) return;
    try {
      final order = await ref
          .read(ordersApiProvider)
          .byCheckoutKey(entry['key'] as String);
      if (ref.mounted && ref.read(accountScopeProvider) == owner) {
        state = CheckoutSubmissionState(lastOrder: order);
      }
    } on ApiFailure {
      if (ref.mounted && ref.read(accountScopeProvider) == owner) {
        state = const CheckoutSubmissionState();
      }
      // Keep the intent. Submit retries the original payload and revision.
    }
  }

  Future<OrderData?> retryPending() {
    final entry = ref.read(checkoutIdempotencyStoreProvider).pending(storeType);
    if (entry == null) return Future.value(null);
    final payload = Map<String, dynamic>.from(entry['payload'] as Map);
    return submit(
      fulfillmentType: payload['fulfillment'] == 'pickup'
          ? FulfillmentType.pickup
          : FulfillmentType.delivery,
      paymentMethod: PaymentMethod.cash,
      addressId: payload['address'] as String?,
      pickupBranchId: payload['branch'] as String?,
      note: payload['note'] as String,
      recipientName: payload['recipient_name'] as String?,
      recipientPhone: payload['recipient_phone'] as String?,
    );
  }

  Future<OrderData?> submit({
    required FulfillmentType fulfillmentType,
    required PaymentMethod paymentMethod,
    String? addressId,
    String? pickupBranchId,
    String note = '',
    String? recipientName,
    String? recipientPhone,
  }) async {
    if (state.isSubmitting) return null;
    final paymentWire = paymentMethod.wireFor(fulfillmentType);
    final keys = ref.read(checkoutIdempotencyStoreProvider);
    final api = ref.read(ordersApiProvider);
    final owner = ref.read(accountScopeProvider);
    state = const CheckoutSubmissionState(isSubmitting: true);
    try {
      final cart = ref.read(cartControllerProvider(storeType)).value?.cart;
      if (keys.pending(storeType) == null && cart?.isOrderable == false) {
        throw const ValidationFailure('', {
          'reason_code': ['product_unavailable'],
        });
      }
      final recovering = keys.pending(storeType) != null;
      if (paymentMethod == PaymentMethod.payme && !recovering) {
        final enabled = ref.read(paymeEnabledProvider);
        final capabilities = enabled
            ? await ref.read(paymentCapabilitiesProvider.future)
            : const <String, bool>{};
        if (!ref.mounted || ref.read(accountScopeProvider) != owner) {
          return null;
        }
        if (storeType != StoreType.household ||
            capabilities[storeType.wire] != true) {
          throw const ValidationFailure('Payme hozircha mavjud emas.', {
            'reason_code': ['payme_unavailable'],
          });
        }
      }
      final entry = await keys.prepare(storeType, {
        'fulfillment': fulfillmentType.wire,
        'payment': paymentWire,
        'address': addressId,
        'branch': pickupBranchId,
        'note': note,
        'revision': cart?.revision,
        'recipient_name': ?recipientName,
        'recipient_phone': ?recipientPhone,
      });
      if (!ref.mounted || ref.read(accountScopeProvider) != owner) return null;
      final key = entry['key'] as String;
      final payload = Map<String, dynamic>.from(entry['payload'] as Map);
      final recovered = recovering ? await api.byCheckoutKey(key) : null;
      if (!ref.mounted || ref.read(accountScopeProvider) != owner) return null;
      final order =
          recovered ??
          await api.create(
            storeType: storeType.wire,
            fulfillmentType: payload['fulfillment'] == 'pickup'
                ? FulfillmentType.pickup
                : FulfillmentType.delivery,
            paymentMethod: payload['payment'] as String,
            addressId: payload['address'] as String?,
            pickupBranchId: payload['branch'] as String?,
            note: payload['note'] as String,
            recipientName: payload['recipient_name'] as String?,
            recipientPhone: payload['recipient_phone'] as String?,
            idempotencyKey: key,
            expectedCartRevision: payload['revision'] as int?,
          );
      // Ekran yopilgan bo'lsa provider dispose bo'lgan: `ref`/`state` ga
      // tegib bo'lmaydi, buyurtma esa baribir mavjud.
      if (!ref.mounted) return order;
      if (ref.read(accountScopeProvider) != owner) return null;
      for (final query in orderQueriesAffectedBy(storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
      // Creating an order is the terminal result. Let the UI open tracking
      // before cart reconciliation empties the draft or waits on the network.
      state = CheckoutSubmissionState(isSubmitting: true, lastOrder: order);
      try {
        await ref.read(cartControllerProvider(storeType).notifier).refresh();
      } on Object {
        // A failed cleanup cannot turn an already-created order into a failed
        // submission and invite another POST. Cart keeps its own retry state.
      }
      if (!ref.mounted || ref.read(accountScopeProvider) != owner) return null;
      state = CheckoutSubmissionState(lastOrder: order);
      return order;
    } on ValidationFailure {
      // Definitive 400: shu payload qayta yuborilganda yangi checkout urinish
      // hisoblanadi. Network/timeout uchun esa ayni UUID saqlanadi.
      await keys.acknowledge(storeType);
      if (ref.mounted) state = const CheckoutSubmissionState();
      rethrow;
    } on Object {
      if (ref.mounted) state = const CheckoutSubmissionState();
      rethrow;
    }
  }
}

final pendingCheckoutProvider = FutureProvider.autoDispose<StoreType?>((
  ref,
) async {
  final keys = ref.watch(checkoutIdempotencyStoreProvider);
  for (final type in StoreType.values) {
    final entry = keys.pending(type);
    if (entry == null) continue;
    // Check at startup, without creating a new purchase in the background.
    try {
      await ref.read(ordersApiProvider).byCheckoutKey(entry['key'] as String);
    } on ApiFailure {
      /* The user can retry from checkout when online. */
    }
    return type;
  }
  return null;
});
