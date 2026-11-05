import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/store_scope/store_type.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../cart/domain/offline_cart_queue.dart';
import '../../payments/data/payment_models.dart';
import '../data/checkout_models.dart';
import 'addresses_controller.dart';
import 'checkout_rules.dart';
import 'delivery_address_selection.dart';

/// Machine-readable UI notices. Translations belong to the presentation layer.
abstract final class OrderDraftNotice {
  static const cartNotReady = 'cart_not_ready';
  static const cartEmpty = 'cart_empty';
  static const addressMissing = 'address_missing';
  static const addressChanged = 'address_changed';
  static const deliveryUnavailable = 'delivery_unavailable';
}

class OrderDraftState {
  const OrderDraftState({
    this.fulfillment = FulfillmentType.delivery,
    this.selection,
    this.pickupBranchId,
    this.note = '',
    this.paymentMethod = PaymentMethod.cash,
    this.preparing = false,
    this.estimating = false,
    this.quoteInvalidated = false,
    this.failure,
    this.notice,
    this.recipientName,
    this.recipientPhone,
  });

  final FulfillmentType fulfillment;

  /// Oluvchi (boshqa odamga buyurtma). `null` — profildagi ism/raqam.
  final String? recipientName;

  /// `+998XXXXXXXXX`; `null` — profildagi raqam.
  final String? recipientPhone;
  final DeliveryAddressSelection? selection;
  final String? pickupBranchId;
  final String note;
  final PaymentMethod paymentMethod;
  final bool preparing;
  final bool estimating;
  final bool quoteInvalidated;
  final ApiFailure? failure;
  final String? notice;

  String? get addressId => selection?.address.id;

  /// May be unavailable: use this only to explain a server coverage response.
  /// Totals and eligibility must use [quoteFor] instead.
  DeliveryEstimate? get estimate =>
      fulfillment == FulfillmentType.delivery ? selection?.estimate : null;

  DeliveryEstimate? quoteFor(CartData cart, List<UserAddress> addresses) {
    if (fulfillment != FulfillmentType.delivery ||
        estimating ||
        quoteInvalidated ||
        failure != null) {
      return null;
    }
    final chosen = selection;
    final current = addresses.where((a) => a.id == addressId).firstOrNull;
    if (chosen == null ||
        current == null ||
        !hasDeliveryCoordinates(current) ||
        !chosen.matches(current, cart) ||
        CheckoutRules.displayTotal(
              subtotal: cart.subtotal,
              fulfillment: fulfillment,
              estimate: chosen.estimate,
            ) ==
            null) {
      return null;
    }
    return chosen.estimate;
  }

  OrderDraftState copyWith({
    FulfillmentType? fulfillment,
    DeliveryAddressSelection? Function()? selection,
    String? Function()? pickupBranchId,
    String? note,
    PaymentMethod? paymentMethod,
    bool? preparing,
    bool? estimating,
    bool? quoteInvalidated,
    ApiFailure? Function()? failure,
    String? Function()? notice,
    String? Function()? recipientName,
    String? Function()? recipientPhone,
  }) => OrderDraftState(
    fulfillment: fulfillment ?? this.fulfillment,
    selection: selection == null ? this.selection : selection(),
    pickupBranchId: pickupBranchId == null
        ? this.pickupBranchId
        : pickupBranchId(),
    note: note ?? this.note,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    preparing: preparing ?? this.preparing,
    estimating: estimating ?? this.estimating,
    quoteInvalidated: quoteInvalidated ?? this.quoteInvalidated,
    failure: failure == null ? this.failure : failure(),
    notice: notice == null ? this.notice : notice(),
    recipientName: recipientName == null ? this.recipientName : recipientName(),
    recipientPhone: recipientPhone == null
        ? this.recipientPhone
        : recipientPhone(),
  );
}

/// Deliberately not autoDispose: going to a catalog/detail route must not lose
/// the order-local choice. Nothing here is persisted to disk or the account.
final orderDraftProvider =
    NotifierProvider.family<OrderDraftController, OrderDraftState, StoreType>(
      OrderDraftController.new,
    );

class OrderDraftController extends Notifier<OrderDraftState> {
  OrderDraftController(this.storeType);

  final StoreType storeType;
  int _epoch = 0;
  int _quoteRevision = 0;
  String? _requestedKey;
  String? _pickupStoreScope;
  bool _refreshScheduled = false;
  Future<bool>? _prepareInFlight;

  @override
  OrderDraftState build() {
    final owner = ref.watch(accountScopeProvider);
    _epoch++;
    _quoteRevision++;
    _requestedKey = null;
    _pickupStoreScope = null;
    _refreshScheduled = false;
    _prepareInFlight = null;
    ref.listen(cartControllerProvider(storeType), (_, next) {
      if (next.isLoading || next.hasError) return;
      final cart = next.value;
      if (cart == null || !_stable(cart)) return;
      if (cart.cart.items.isEmpty) {
        clear();
        return;
      }
      if (state.pickupBranchId != null &&
          _pickupStoreScope != deliveryStoreScope(cart.cart)) {
        setPickupBranch(null);
      }
      if (state.fulfillment == FulfillmentType.pickup &&
          !CheckoutRules.pickupAllowed(cart.cart)) {
        setFulfillment(FulfillmentType.delivery);
      }
      _synchronizeSelection();
    });
    if (owner != 'guest') {
      ref.listen(addressesControllerProvider, (_, next) {
        if (!next.isLoading && !next.hasError) _synchronizeSelection();
      });
    }
    return const OrderDraftState();
  }

  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  static bool _stable(CartState cart) =>
      !cart.hasPendingMutation &&
      cart.unconfirmedKeys.isEmpty &&
      cart.mutationFailure == null;

  String _key(UserAddress address, CartData cart) =>
      '${address.id}|${address.latitude}|${address.longitude}|'
      '${deliveryStoreScope(cart)}';

  void _synchronizeSelection() {
    if (state.preparing || state.selection == null) return;
    final cartValue = ref.read(cartControllerProvider(storeType));
    final addressValue = ref.read(addressesControllerProvider);
    final cart = cartValue.value;
    final addresses = addressValue.value;
    if (cartValue.isLoading ||
        cartValue.hasError ||
        addressValue.isLoading ||
        addressValue.hasError ||
        cart == null ||
        addresses == null ||
        !_stable(cart)) {
      return;
    }
    final addressFailure = ref
        .read(addressesControllerProvider.notifier)
        .refreshFailure;
    if (addressFailure != null) {
      _quoteRevision++;
      state = state.copyWith(
        quoteInvalidated: true,
        estimating: false,
        failure: () => addressFailure,
      );
      return;
    }
    final address = addresses.where((a) => a.id == state.addressId).firstOrNull;
    if (address == null || !hasDeliveryCoordinates(address)) {
      _quoteRevision++;
      _requestedKey = null;
      state = state.copyWith(
        selection: () => null,
        estimating: false,
        failure: () => null,
        notice: () => OrderDraftNotice.addressChanged,
      );
      return;
    }
    if (state.fulfillment != FulfillmentType.delivery ||
        _key(address, cart.cart) == _requestedKey) {
      return;
    }
    _quoteRevision++;
    state = state.copyWith(estimating: true, failure: () => null);
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    final epoch = _epoch;
    scheduleMicrotask(() {
      if (!_current(epoch)) return;
      _refreshScheduled = false;
      unawaited(refreshQuote());
    });
  }

  /// Merge and reconcile before opening the address selector or checkout.
  /// A successful synchronization does not imply that the minimum is met.
  Future<bool> prepare({
    bool revalidateQuote = true,
    bool useSavedAddress = false,
  }) {
    final active = _prepareInFlight;
    if (active != null) return active;
    final future = _prepare(
      revalidateQuote: revalidateQuote,
      useSavedAddress: useSavedAddress,
    );
    _prepareInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_prepareInFlight, future)) _prepareInFlight = null;
      }),
    );
    return future;
  }

  Future<bool> _prepare({
    required bool revalidateQuote,
    required bool useSavedAddress,
  }) async {
    final epoch = _epoch;
    state = state.copyWith(
      preparing: true,
      failure: () => null,
      notice: () => null,
    );
    try {
      final before = ref.read(cartControllerProvider(storeType)).value;
      if (before != null &&
          (before.hasPendingMutation || before.unconfirmedKeys.isNotEmpty)) {
        state = state.copyWith(
          failure: () => before.mutationFailure,
          notice: () => OrderDraftNotice.cartNotReady,
        );
        return false;
      }
      final queue = ref.read(offlineCartQueueProvider);
      await queue.flush();
      if (!_current(epoch)) return false;
      if (!queue.isEmpty) {
        state = state.copyWith(
          failure: () => const NetworkFailure(),
          notice: () => OrderDraftNotice.cartNotReady,
        );
        return false;
      }
      await ref.read(guestCartCoordinatorProvider).mergeIfNeeded();
      if (!_current(epoch)) return false;
      await ref.read(cartControllerProvider(storeType).future);
      if (!_current(epoch)) return false;
      await ref.read(cartControllerProvider(storeType).notifier).refresh();
      if (!_current(epoch)) return false;
      final cartValue = ref.read(cartControllerProvider(storeType));
      final cart = cartValue.value;
      if (cartValue.isLoading || cartValue.hasError || cart == null) {
        state = state.copyWith(
          failure: () => _asFailure(cartValue.error),
          notice: () => OrderDraftNotice.cartNotReady,
        );
        return false;
      }
      if (!_stable(cart)) {
        state = state.copyWith(
          failure: () => cart.mutationFailure,
          notice: () => OrderDraftNotice.cartNotReady,
        );
        return false;
      }
      if (cart.cart.items.isEmpty) {
        clear();
        return false;
      }
      if (state.fulfillment == FulfillmentType.pickup) {
        if (CheckoutRules.pickupAllowed(cart.cart)) return true;
        setFulfillment(FulfillmentType.delivery);
      }
      if (state.selection == null && !useSavedAddress) return true;
      await ref.read(addressesControllerProvider.future);
      if (!_current(epoch)) return false;
      final addressController = ref.read(addressesControllerProvider.notifier);
      await addressController.refresh();
      if (!_current(epoch)) return false;
      // Cached addresses remain useful in the selector. They are not proof
      // that the server still has these coordinates when confirming an order.
      final addressFailure = addressController.refreshFailure;
      if (addressFailure != null) {
        state = state.copyWith(
          quoteInvalidated: true,
          failure: () => addressFailure,
        );
        return !revalidateQuote;
      }
      if (state.selection == null && useSavedAddress) {
        final addresses =
            ref.read(addressesControllerProvider).value ??
            const <UserAddress>[];
        final usable = addresses.where(hasDeliveryCoordinates);
        final saved =
            usable.where((address) => address.isDefault).firstOrNull ??
            usable.firstOrNull;
        if (saved == null) return true;
        // This is only a pending server quote, never a zero-price assumption.
        state = state.copyWith(
          selection: () => DeliveryAddressSelection(
            address: saved,
            estimate: const DeliveryEstimate(available: false, detail: ''),
            storeScope: deliveryStoreScope(cart.cart),
          ),
          quoteInvalidated: true,
        );
      }
      // Opening the selector must not require the previous quote to be valid:
      // choosing a different address is how unavailable delivery is resolved.
      if (!revalidateQuote) return true;
      await refreshQuote();
      if (!_current(epoch)) return false;
      final addresses = ref.read(addressesControllerProvider).value ?? const [];
      final latestCart = ref.read(cartControllerProvider(storeType)).value;
      return latestCart != null &&
          _stable(latestCart) &&
          state.quoteFor(latestCart.cart, addresses) != null;
    } on Object catch (error) {
      if (_current(epoch)) {
        state = state.copyWith(failure: () => _asFailure(error));
      }
      return false;
    } finally {
      if (_current(epoch)) state = state.copyWith(preparing: false);
    }
  }

  Future<void> acceptAddress(DeliveryAddressSelection selection) async {
    final epoch = _epoch;
    final revision = ++_quoteRevision;
    try {
      final cart = await ref.read(cartControllerProvider(storeType).future);
      final addresses = await ref.read(addressesControllerProvider.future);
      if (!_current(epoch) || revision != _quoteRevision) return;
      final current = addresses
          .where((a) => a.id == selection.address.id)
          .firstOrNull;
      if (current == null || !hasDeliveryCoordinates(current)) {
        state = state.copyWith(
          selection: () => null,
          failure: () => null,
          notice: () => OrderDraftNotice.addressMissing,
        );
        return;
      }
      state = state.copyWith(
        selection: () => selection,
        fulfillment: FulfillmentType.delivery,
        estimating: false,
        quoteInvalidated: false,
        failure: () => null,
        notice: () => null,
      );
      if (selection.matches(current, cart.cart) && _stable(cart)) {
        _requestedKey = _key(current, cart.cart);
        if (state.quoteFor(cart.cart, addresses) == null) {
          state = state.copyWith(
            notice: () => OrderDraftNotice.deliveryUnavailable,
          );
        }
        return;
      }
      await refreshQuote();
    } on Object catch (error) {
      if (_current(epoch) && revision == _quoteRevision) {
        state = state.copyWith(failure: () => _asFailure(error));
      }
    }
  }

  Future<void> refreshQuote() async {
    final epoch = _epoch;
    final revision = ++_quoteRevision;
    final cartValue = ref.read(cartControllerProvider(storeType));
    final addressValue = ref.read(addressesControllerProvider);
    final cart = cartValue.value;
    final address = addressValue.value
        ?.where((a) => a.id == state.addressId)
        .firstOrNull;
    if (state.fulfillment != FulfillmentType.delivery) {
      state = state.copyWith(estimating: false);
      return;
    }
    // Keep the server response for error explanations without ever reviving an
    // old fee merely because a different operation clears the failure field.
    state = state.copyWith(quoteInvalidated: true);
    if (cartValue.isLoading ||
        cartValue.hasError ||
        cart == null ||
        !_stable(cart)) {
      state = state.copyWith(
        estimating: false,
        failure: () => cart?.mutationFailure,
        notice: () => OrderDraftNotice.cartNotReady,
      );
      return;
    }
    if (addressValue.isLoading || addressValue.hasError) {
      state = state.copyWith(
        estimating: false,
        failure: () => _asFailure(addressValue.error),
      );
      return;
    }
    final addressFailure = ref
        .read(addressesControllerProvider.notifier)
        .refreshFailure;
    if (addressFailure != null) {
      state = state.copyWith(estimating: false, failure: () => addressFailure);
      return;
    }
    if (address == null || !hasDeliveryCoordinates(address)) {
      state = state.copyWith(
        estimating: false,
        selection: () => null,
        failure: () => null,
        notice: () => OrderDraftNotice.addressMissing,
      );
      return;
    }
    final key = _key(address, cart.cart);
    _requestedKey = key;
    state = state.copyWith(
      estimating: true,
      failure: () => null,
      notice: () => null,
    );
    try {
      final quote = await ref
          .read(checkoutApiProvider)
          .estimate(
            storeType: storeType.wire,
            latitude: address.latitude!,
            longitude: address.longitude!,
          );
      if (!_quoteIsCurrent(epoch, revision, key)) return;
      state = state.copyWith(
        selection: () => DeliveryAddressSelection(
          address: address,
          estimate: quote,
          storeScope: deliveryStoreScope(cart.cart),
        ),
        estimating: false,
        quoteInvalidated: false,
        failure: () => null,
        notice: () =>
            CheckoutRules.displayTotal(
                  subtotal: cart.cart.subtotal,
                  fulfillment: FulfillmentType.delivery,
                  estimate: quote,
                ) ==
                null
            ? OrderDraftNotice.deliveryUnavailable
            : null,
      );
    } on Object catch (error) {
      if (!_quoteIsCurrent(epoch, revision, key)) return;
      state = state.copyWith(
        estimating: false,
        failure: () => _asFailure(error),
      );
    }
  }

  bool _quoteIsCurrent(int epoch, int revision, String key) {
    if (!_current(epoch) || revision != _quoteRevision) return false;
    final cart = ref.read(cartControllerProvider(storeType)).value;
    final address = ref
        .read(addressesControllerProvider)
        .value
        ?.where((a) => a.id == state.addressId)
        .firstOrNull;
    return state.fulfillment == FulfillmentType.delivery &&
        cart != null &&
        address != null &&
        _key(address, cart.cart) == key;
  }

  void setFulfillment(FulfillmentType fulfillment) {
    final cart = ref.read(cartControllerProvider(storeType)).value?.cart;
    if (fulfillment == FulfillmentType.pickup &&
        cart != null &&
        !CheckoutRules.pickupAllowed(cart)) {
      fulfillment = FulfillmentType.delivery;
    }
    if (fulfillment == state.fulfillment) return;
    _quoteRevision++;
    _requestedKey = null;
    _pickupStoreScope = null;
    state = state.copyWith(
      fulfillment: fulfillment,
      pickupBranchId: () => null,
      estimating: false,
      failure: () => null,
      notice: () => null,
    );
    if (fulfillment == FulfillmentType.delivery) _synchronizeSelection();
  }

  void setPickupBranch(String? id) {
    final cart = ref.read(cartControllerProvider(storeType)).value?.cart;
    _pickupStoreScope = id != null && cart != null
        ? deliveryStoreScope(cart)
        : null;
    state = state.copyWith(
      pickupBranchId: () => id,
      failure: () => null,
      notice: () => null,
    );
  }

  void setNote(String note) => state = state.copyWith(note: note);

  /// Bo'sh qiymat — profildagi ma'lumotga qaytadi.
  void setRecipient({String? name, String? phone}) => state = state.copyWith(
    recipientName: () =>
        name == null || name.trim().isEmpty ? null : name.trim(),
    recipientPhone: () => phone == null || phone.isEmpty ? null : phone,
  );

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void setNotice(String? notice) =>
      state = state.copyWith(notice: () => notice);

  void clear() {
    _epoch++;
    _quoteRevision++;
    _requestedKey = null;
    _pickupStoreScope = null;
    _refreshScheduled = false;
    _prepareInFlight = null;
    state = const OrderDraftState();
  }

  static ApiFailure _asFailure(Object? error) =>
      error is ApiFailure ? error : const UnknownFailure();
}
