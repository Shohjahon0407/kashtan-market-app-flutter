import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/store_scope/store_type.dart';
import '../../auth/domain/auth_controller.dart';
import '../../catalog/data/product_models.dart';
import '../data/cart_api.dart';
import '../data/cart_models.dart';
import 'offline_cart_queue.dart';

final cartApiProvider = Provider<CartApi>(
  (ref) => CartApi(
    ref.watch(apiClientProvider),
    ref.watch(guestCartTokenStoreProvider),
    () => ref.read(authControllerProvider).isAuthenticated,
  ),
);

class CartState {
  const CartState({
    required this.cart,
    this.busyKeys = const {},
    this.mutationFailure,
  });

  final CartData cart;
  final Set<String> busyKeys;
  final ApiFailure? mutationFailure;

  bool isBusy(String key) => busyKeys.contains(key);

  CartState copyWith({
    CartData? cart,
    Set<String>? busyKeys,
    ApiFailure? Function()? mutationFailure,
  }) => CartState(
    cart: cart ?? this.cart,
    busyKeys: busyKeys ?? this.busyKeys,
    mutationFailure: mutationFailure != null
        ? mutationFailure()
        : this.mutationFailure,
  );
}

final cartControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CartController, CartState, StoreType>(
      (storeType) => CartController(storeType),
    );

class CartController extends AsyncNotifier<CartState> {
  CartController(this.storeType);

  final StoreType storeType;

  @override
  Future<CartState> build() async {
    ref.watch(apiLangProvider);
    ref.watch(authControllerProvider.select((auth) => auth.isAuthenticated));
    final cart = await ref.watch(cartApiProvider).fetch(storeType.wire);
    return CartState(cart: cart);
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) {
      ref.invalidateSelf();
      return;
    }
    try {
      final cart = await ref.read(cartApiProvider).fetch(storeType.wire);
      state = AsyncData(CartState(cart: cart));
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
    }
  }

  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) async {
    // inReview — admin tekshiruvidagi mahsulot (server ham checkoutda rad etadi).
    if (!product.isPurchasable || product.inReview || quantity < 1) {
      return false;
    }
    final configuration = CartConfiguration(
      productId: product.id,
      variantId: variant?.id,
      addons: addons,
      note: note,
    );
    final current = state.value;
    if (current == null || current.isBusy(configuration.identity)) return false;

    CartItem? duplicate;
    for (final item in current.cart.items) {
      if (item.configurationIdentity == configuration.identity) {
        duplicate = item;
        break;
      }
    }

    final previous = current;
    final busy = {...current.busyKeys, configuration.identity};
    if (duplicate != null) {
      final optimistic = duplicate.copyWith(
        quantity: duplicate.quantity + quantity,
      );
      state = AsyncData(
        current.copyWith(
          cart: current.cart.replaceItem(optimistic),
          busyKeys: busy,
          mutationFailure: () => null,
        ),
      );
    } else {
      state = AsyncData(
        current.copyWith(busyKeys: busy, mutationFailure: () => null),
      );
    }

    try {
      if (duplicate != null) {
        await ref
            .read(cartApiProvider)
            .updateQuantity(duplicate.id, duplicate.quantity + quantity);
      } else {
        await ref
            .read(cartApiProvider)
            .addItem(
              storeType: storeType.wire,
              configuration: configuration,
              quantity: quantity,
            );
      }
      await _reconcile();
      return true;
    } on NetworkFailure {
      // OFLAYN: amal navbatga tushadi va internet qaytganda yuboriladi.
      // Optimistik ko'rinish saqlanadi — foydalanuvchi uchun savat ishlayveradi.
      if (duplicate != null) {
        await ref
            .read(offlineCartQueueProvider)
            .enqueueSetQuantity(duplicate.id, duplicate.quantity + quantity);
        final held = state.value ?? previous;
        state = AsyncData(
          held.copyWith(
            busyKeys: held.busyKeys.difference({configuration.identity}),
            mutationFailure: () => null,
          ),
        );
        return true;
      }
      // Yangi element serverda hali yo'q — ko'rinishda ko'rsata olmaymiz
      // (server id kerak), lekin navbatda saqlanadi va ulanishda qo'shiladi.
      await ref
          .read(offlineCartQueueProvider)
          .enqueueAdd(
            storeType: storeType.wire,
            configuration: configuration,
            quantity: quantity,
          );
      state = AsyncData(
        previous.copyWith(
          busyKeys: previous.busyKeys.difference({configuration.identity}),
          mutationFailure: () => null,
        ),
      );
      return true;
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    }
  }

  Future<void> increment(CartItem item) =>
      _setQuantity(item, item.quantity + 1);

  Future<void> decrement(CartItem item) =>
      item.quantity <= 1 ? remove(item) : _setQuantity(item, item.quantity - 1);

  Future<void> remove(CartItem item) async {
    final current = state.value;
    final key = 'item:${item.id}';
    if (current == null || current.isBusy(key)) return;
    final previous = current;
    state = AsyncData(
      current.copyWith(
        cart: current.cart.removeItem(item.id),
        busyKeys: {...current.busyKeys, key},
        mutationFailure: () => null,
      ),
    );
    try {
      await ref.read(cartApiProvider).deleteItem(item.id);
      await _reconcile();
    } on NetworkFailure {
      // Oflayn: element ekrandan olib tashlangan holicha qoladi.
      await ref.read(offlineCartQueueProvider).enqueueRemove(item.id);
      final held = state.value ?? previous;
      state = AsyncData(
        held.copyWith(
          busyKeys: held.busyKeys.difference({key}),
          mutationFailure: () => null,
        ),
      );
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
    }
  }

  Future<void> clear() async {
    final current = state.value;
    const key = 'clear';
    if (current == null || current.isBusy(key)) return;
    final previous = current;
    state = AsyncData(
      CartState(
        cart: CartData.empty(storeType.wire),
        busyKeys: {...current.busyKeys, key},
      ),
    );
    try {
      await ref.read(cartApiProvider).clear(storeType.wire);
      await _reconcile();
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
    }
  }

  Future<void> addBundle(String bundleId) async {
    final current = state.value;
    final key = 'bundle:$bundleId';
    if (current == null || current.isBusy(key)) return;
    final previous = current;
    state = AsyncData(
      current.copyWith(
        busyKeys: {...current.busyKeys, key},
        mutationFailure: () => null,
      ),
    );
    try {
      final cart = await ref.read(cartApiProvider).addBundle(bundleId);
      if (cart.storeTypeWire == storeType.wire) {
        state = AsyncData(CartState(cart: cart));
      } else {
        await _reconcile();
      }
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
    }
  }

  Future<void> _setQuantity(CartItem item, int quantity) async {
    final current = state.value;
    final key = 'item:${item.id}';
    if (current == null || current.isBusy(key)) return;
    final previous = current;
    state = AsyncData(
      current.copyWith(
        cart: current.cart.replaceItem(item.copyWith(quantity: quantity)),
        busyKeys: {...current.busyKeys, key},
        mutationFailure: () => null,
      ),
    );
    try {
      await ref.read(cartApiProvider).updateQuantity(item.id, quantity);
      await _reconcile();
    } on NetworkFailure {
      // Oflayn: yangi miqdor ekranda qoladi, amal navbatga tushadi.
      await ref
          .read(offlineCartQueueProvider)
          .enqueueSetQuantity(item.id, quantity);
      final held = state.value ?? previous;
      state = AsyncData(
        held.copyWith(
          busyKeys: held.busyKeys.difference({key}),
          mutationFailure: () => null,
        ),
      );
    } on ApiFailure catch (failure) {
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
    }
  }

  Future<void> _reconcile() async {
    final cart = await ref.read(cartApiProvider).fetch(storeType.wire);
    state = AsyncData(CartState(cart: cart));
  }
}

final guestCartCoordinatorProvider = Provider<GuestCartCoordinator>(
  GuestCartCoordinator.new,
);

class GuestCartCoordinator {
  GuestCartCoordinator(this.ref);

  final Ref ref;
  Future<void>? _mergeInFlight;

  Future<void> mergeIfNeeded() {
    final active = _mergeInFlight;
    if (active != null) return active;
    final future = _merge();
    _mergeInFlight = future;
    return future.whenComplete(() => _mergeInFlight = null);
  }

  Future<void> _merge() async {
    final merged = await ref.read(cartApiProvider).mergeGuestCart();
    if (!merged) return;
    for (final storeType in StoreType.values) {
      ref.invalidate(cartControllerProvider(storeType));
    }
  }
}
