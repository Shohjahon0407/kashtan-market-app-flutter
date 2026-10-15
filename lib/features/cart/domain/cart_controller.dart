import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/account_scope.dart';
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

/// Savat mutatsiyalarining kalitlari.
///
/// UI aynan SHU kalit bo'yicha "bandmi" deb so'raydi — shuning uchun kalit
/// qurish mantigi bitta joyda turadi (ilgari `'item:$id'` satri uch xil
/// ekranda takrorlanardi).
abstract final class CartMutationKeys {
  /// Savatdagi mavjud satr (miqdor o'zgartirish, o'chirish).
  static String item(String itemId) => 'item:$itemId';

  /// Yangi mahsulot qo'shish — konfiguratsiya o'ziga xosligi bilan.
  static String add(CartConfiguration configuration) => configuration.identity;

  static String bundle(String bundleId) => 'bundle:$bundleId';

  static String quantity(String configurationIdentity) =>
      'quantity:$configurationIdentity';

  static const String clear = 'clear';
}

const _localCartItemPrefix = 'local-cart-item:';
const _quantityDebounce = Duration(milliseconds: 180);

class _QuantityIntent {
  _QuantityIntent({
    required this.configuration,
    required this.template,
    required this.confirmedItem,
    required this.desiredQuantity,
    this.addAlreadyCommitted = false,
    this.discardOfflineAdd = false,
  });

  final CartConfiguration configuration;
  CartItem template;
  CartItem? confirmedItem;
  int desiredQuantity;
  int revision = 0;
  bool running = false;
  bool addAlreadyCommitted;
  bool discardOfflineAdd;
  Timer? timer;
  final List<Completer<bool>> waiters = [];

  String get key => CartMutationKeys.quantity(configuration.identity);
}

class CartState {
  const CartState({
    required this.cart,
    this.busyKeys = const {},
    this.unconfirmedKeys = const {},
    this.mutationFailure,
  });

  final CartData cart;

  /// Ayni paytda bajarilayotgan (yoki navbatda turgan) mutatsiya kalitlari.
  ///
  /// UI ularni [isBusy] orqali KALIT BO'YICHA so'raydi: bitta mahsulot
  /// o'zgarganda checkout/clear kabi yakuniy amallar yozuv tugaguncha
  /// bloklanadi. Mahsulot stepperlari esa optimistic ishlashda davom etadi.
  final Set<String> busyKeys;

  /// Serverga YOZILGAN, lekin keyingi GET xato bergani uchun `cart` ichida
  /// hali tasdiqlanmagan konfiguratsiyalar. Lokal optimistic satr ko'rinib
  /// turadi; keyingi refresh uni server ID bilan almashtiradi.
  final Set<String> unconfirmedKeys;
  final ApiFailure? mutationFailure;

  bool isBusy(String key) => busyKeys.contains(key);

  /// Savat bo'yicha biror amal ketyaptimi (tozalash/checkout kabi butun
  /// savatga tegadigan tugmalar uchun).
  bool get hasPendingMutation => busyKeys.isNotEmpty;

  CartState copyWith({
    CartData? cart,
    Set<String>? busyKeys,
    Set<String>? unconfirmedKeys,
    ApiFailure? Function()? mutationFailure,
  }) => CartState(
    cart: cart ?? this.cart,
    busyKeys: busyKeys ?? this.busyKeys,
    unconfirmedKeys: unconfirmedKeys ?? this.unconfirmedKeys,
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
  int _generation = 0;
  Timer? _unconfirmedRetry;
  int _unconfirmedAttempt = 0;

  /// Band kalitlarning YAGONA manbasi; har bir state yozuvi shundan ko'chiriladi.
  final Set<String> _pending = {};
  final Map<String, _QuantityIntent> _quantityIntents = {};

  /// Mutatsiyalar KETMA-KET bajariladi (ikkita parallel yozuv `_reconcile`
  /// natijalarini bir-birining ustiga tashlab yuborardi), ammo endi ular
  /// TASHLAB YUBORILMAYDI: ikkinchi karta bosilsa navbatda kutadi.
  Future<void> _queueTail = Future<void>.value();

  @override
  Future<CartState> build() async {
    _generation++;
    ref.watch(accountScopeProvider);
    ref.onDispose(() {
      _generation++;
      _unconfirmedRetry?.cancel();
      for (final intent in _quantityIntents.values) {
        intent.timer?.cancel();
        for (final waiter in intent.waiters) {
          if (!waiter.isCompleted) waiter.complete(false);
        }
      }
      _quantityIntents.clear();
      _pending.clear();
    });
    listenForConnectionRecovery(ref, () async {
      if (state.isLoading || state.value?.hasPendingMutation == true) return;
      await refresh();
    });
    ref.watch(apiLangProvider);
    ref.watch(authControllerProvider.select((auth) => auth.isAuthenticated));
    final cart = await ref.watch(cartApiProvider).fetch(storeType.wire);
    return CartState(cart: cart);
  }

  /// Mutatsiyani navbatga qo'yadi va `key` ni band deb belgilaydi.
  ///
  /// Kalit DARHOL band bo'ladi — foydalanuvchi bosgan karta bir zumda spinner
  /// ko'rsatadi, garchi so'rov oldingi mutatsiya tugashini kutsa ham. Ayni
  /// kalit bo'yicha takroriy bosish e'tiborsiz qoldiriladi (ikki marta
  /// qo'shilib ketmasin), boshqa kalitlar esa navbatda kutadi.
  Future<bool> _mutate(
    String key,
    Future<bool> Function(CartState current) action,
  ) {
    final current = state.value;
    if (current == null || _pending.contains(key)) return Future.value(false);
    final generation = _generation;
    _pending.add(key);
    state = AsyncData(
      current.copyWith(busyKeys: {..._pending}, mutationFailure: () => null),
    );

    final result = _queueTail.then((_) async {
      if (!ref.mounted || generation != _generation) return false;
      final latest = state.value;
      if (latest == null) return false;
      try {
        return await action(latest);
      } finally {
        _pending.remove(key);
        if (ref.mounted && generation == _generation) {
          final held = state.value;
          if (held != null) {
            state = AsyncData(held.copyWith(busyKeys: {..._pending}));
          }
        }
      }
    });
    // Xato zanjirni uzmasin — keyingi mutatsiyalar baribir bajarilishi kerak.
    _queueTail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> refresh() async {
    final generation = _generation;
    final previous = state.value;
    if (previous?.hasPendingMutation == true) return;
    if (previous == null) {
      ref.invalidateSelf();
      return;
    }
    try {
      final cart = await ref.read(cartApiProvider).fetch(storeType.wire);
      if (!ref.mounted || generation != _generation) return;
      _unconfirmedAttempt = 0;
      state = AsyncData(CartState(cart: cart));
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      if (previous.unconfirmedKeys.isNotEmpty) _scheduleUnconfirmedRetry();
    }
  }

  /// Serverga yetgan, lekin ko'rinishda tasdiqlanmagan qo'shish — savat
  /// o'sib boruvchi interval bilan qayta o'qiladi (5, 10, 20, 30 s).
  void _scheduleUnconfirmedRetry() {
    final generation = _generation;
    final seconds = switch (_unconfirmedAttempt++) {
      0 => 5,
      1 => 10,
      2 => 20,
      _ => 30,
    };
    _unconfirmedRetry?.cancel();
    _unconfirmedRetry = Timer(Duration(seconds: seconds), () {
      if (!ref.mounted || generation != _generation) return;
      unawaited(refresh());
    });
  }

  Future<bool> addProduct(
    ProductSummary product, {
    ProductVariant? variant,
    List<SelectedAddon> addons = const [],
    String note = '',
    int quantity = 1,
  }) {
    // inReview — admin tekshiruvidagi mahsulot (server ham checkoutda rad etadi).
    if (!product.isPurchasable || product.inReview || quantity < 1) {
      return Future.value(false);
    }
    final configuration = CartConfiguration(
      productId: product.id,
      variantId: variant?.id,
      addons: addons,
      note: note,
    );
    return _changeQuantity(
      product: product,
      variant: variant,
      addons: addons,
      note: note,
      configuration: configuration,
      delta: quantity,
    );
  }

  Future<void> increment(CartItem item) => _changeExisting(item, 1);

  Future<void> decrement(CartItem item) => _changeExisting(item, -1);

  Future<void> remove(CartItem item) => _setExistingQuantity(item, 0);

  Future<void> clear() => _mutate(CartMutationKeys.clear, _clear);

  Future<bool> _clear(CartState current) async {
    final generation = _generation;
    final previous = current;
    state = AsyncData(
      CartState(cart: CartData.empty(storeType.wire), busyKeys: {..._pending}),
    );
    try {
      await ref.read(cartApiProvider).clear(storeType.wire);
      if (!ref.mounted || generation != _generation) return false;
      await _reconcile();
      return true;
    } on NetworkFailure {
      if (!ref.mounted || generation != _generation) return false;
      // Oflayn: boshqa amallar kabi navbatga tushadi, savat bo'sh qoladi.
      await ref.read(offlineCartQueueProvider).enqueueClear(storeType.wire);
      final held = state.value ?? previous;
      state = AsyncData(held.copyWith(mutationFailure: () => null));
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    }
  }

  Future<void> addBundle(String bundleId) => _mutate(
    CartMutationKeys.bundle(bundleId),
    (current) => _addBundle(bundleId, current),
  );

  Future<bool> _addBundle(String bundleId, CartState current) async {
    final generation = _generation;
    final previous = current;
    try {
      final cart = await ref.read(cartApiProvider).addBundle(bundleId);
      if (!ref.mounted || generation != _generation) return false;
      if (cart.storeTypeWire == storeType.wire) {
        state = AsyncData(CartState(cart: cart, busyKeys: {..._pending}));
      } else {
        await _reconcile();
      }
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    }
  }

  Future<void> _changeExisting(CartItem item, int delta) async {
    await _changeQuantity(
      product: item.product,
      variant: item.variant,
      addons: item.selectedAddons,
      note: item.note,
      configuration: CartConfiguration(
        productId: item.product.id,
        variantId: item.variant?.id,
        addons: item.selectedAddons,
        note: item.note,
      ),
      delta: delta,
    );
  }

  Future<void> _setExistingQuantity(CartItem item, int quantity) async {
    final current = state.value;
    if (current == null) return;
    final latest = _findByIdentity(
      current.cart.items,
      item.configurationIdentity,
    );
    final currentQuantity =
        _quantityIntents[item.configurationIdentity]?.desiredQuantity ??
        latest?.quantity ??
        item.quantity;
    await _changeQuantity(
      product: item.product,
      variant: item.variant,
      addons: item.selectedAddons,
      note: item.note,
      configuration: CartConfiguration(
        productId: item.product.id,
        variantId: item.variant?.id,
        addons: item.selectedAddons,
        note: item.note,
      ),
      delta: quantity - currentQuantity,
    );
  }

  Future<bool> _changeQuantity({
    required ProductSummary product,
    required ProductVariant? variant,
    required List<SelectedAddon> addons,
    required String note,
    required CartConfiguration configuration,
    required int delta,
  }) {
    final current = state.value;
    if (current == null || delta == 0) return Future.value(delta == 0);
    final identity = configuration.identity;
    final visible = _findByIdentity(current.cart.items, identity);
    var intent = _quantityIntents[identity];
    if (intent == null) {
      final isLocal = visible?.id.startsWith(_localCartItemPrefix) ?? false;
      final localId =
          visible?.id ??
          '$_localCartItemPrefix${DateTime.now().microsecondsSinceEpoch}';
      final template =
          visible ??
          CartItem(
            id: localId,
            product: product,
            variant: variant,
            quantity: 0,
            selectedAddons: List.unmodifiable(addons),
            note: note,
            subtotal: '0.00',
          );
      intent = _QuantityIntent(
        configuration: configuration,
        template: template,
        confirmedItem: isLocal ? null : visible,
        desiredQuantity: visible?.quantity ?? 0,
        addAlreadyCommitted:
            isLocal && current.unconfirmedKeys.contains(identity),
        discardOfflineAdd:
            isLocal && !current.unconfirmedKeys.contains(identity),
      );
      _quantityIntents[identity] = intent;
    }

    intent.desiredQuantity = (intent.desiredQuantity + delta).clamp(0, 999999);
    intent.revision++;
    final waiter = Completer<bool>();
    intent.waiters.add(waiter);
    _pending.add(intent.key);

    final optimisticCart = _applyIntent(current.cart, intent);
    state = AsyncData(
      current.copyWith(
        cart: optimisticCart,
        busyKeys: {..._pending},
        mutationFailure: () => null,
      ),
    );
    _scheduleQuantityIntent(intent);
    return waiter.future;
  }

  void _scheduleQuantityIntent(_QuantityIntent intent) {
    intent.timer?.cancel();
    if (intent.running) return;
    intent.timer = Timer(_quantityDebounce, () {
      intent.timer = null;
      if (!ref.mounted ||
          _quantityIntents[intent.configuration.identity] != intent) {
        return;
      }
      intent.running = true;
      final work = _queueTail.then((_) => _flushQuantityIntent(intent));
      _queueTail = work.then((_) {}, onError: (Object _) {});
    });
  }

  Future<void> _flushQuantityIntent(_QuantityIntent intent) async {
    final generation = _generation;
    try {
      while (ref.mounted &&
          generation == _generation &&
          _quantityIntents[intent.configuration.identity] == intent) {
        final revision = intent.revision;
        final target = intent.desiredQuantity;

        if (intent.confirmedItem == null && intent.addAlreadyCommitted) {
          final serverCart = await ref
              .read(cartApiProvider)
              .fetch(storeType.wire);
          final serverLine = _findByIdentity(
            serverCart.items,
            intent.configuration.identity,
          );
          if (serverLine == null) {
            throw const UnknownFailure();
          }
          intent.confirmedItem = serverLine;
          intent.template = serverLine;
          intent.addAlreadyCommitted = false;
          _publishServerCart(serverCart);
          continue;
        }

        if (intent.confirmedItem == null) {
          if (target <= 0) {
            _settleQuantityIntent(intent, success: true);
            return;
          }
          if (intent.discardOfflineAdd) {
            await ref
                .read(offlineCartQueueProvider)
                .discardAdd(
                  storeType: storeType.wire,
                  configuration: intent.configuration,
                );
            intent.discardOfflineAdd = false;
          }
          await ref
              .read(cartApiProvider)
              .addItem(
                storeType: storeType.wire,
                configuration: intent.configuration,
                quantity: target,
              );
          intent.addAlreadyCommitted = true;

          CartData serverCart;
          try {
            serverCart = await ref.read(cartApiProvider).fetch(storeType.wire);
          } on Object catch (error) {
            if (!ref.mounted || generation != _generation) return;
            final held = state.value;
            if (held != null) {
              state = AsyncData(
                held.copyWith(
                  unconfirmedKeys: {
                    ...held.unconfirmedKeys,
                    intent.configuration.identity,
                  },
                  mutationFailure: () =>
                      error is ApiFailure ? error : const UnknownFailure(),
                ),
              );
            }
            _scheduleUnconfirmedRetry();
            _settleQuantityIntent(intent, success: true, preserveFailure: true);
            return;
          }
          final serverLine = _findByIdentity(
            serverCart.items,
            intent.configuration.identity,
          );
          if (serverLine == null) throw const UnknownFailure();
          intent.confirmedItem = serverLine;
          intent.template = serverLine;
          intent.addAlreadyCommitted = false;
          _publishServerCart(serverCart);
          if (revision != intent.revision || target != intent.desiredQuantity) {
            continue;
          }
        } else {
          final confirmed = intent.confirmedItem!;
          if (target <= 0) {
            await ref.read(cartApiProvider).deleteItem(confirmed.id);
            intent.confirmedItem = null;
          } else {
            await ref
                .read(cartApiProvider)
                .updateQuantity(confirmed.id, target);
            intent.confirmedItem = _itemWithQuantity(confirmed, target);
            intent.template = intent.confirmedItem!;
          }
          if (revision != intent.revision || target != intent.desiredQuantity) {
            continue;
          }
        }

        final serverCart = await ref
            .read(cartApiProvider)
            .fetch(storeType.wire);
        if (!ref.mounted || generation != _generation) return;
        _publishServerCart(serverCart);
        if (revision != intent.revision || target != intent.desiredQuantity) {
          continue;
        }
        _settleQuantityIntent(intent, success: true);
        return;
      }
    } on NetworkFailure {
      if (!ref.mounted || generation != _generation) return;
      await _queueOfflineIntent(intent);
      _settleQuantityIntent(intent, success: true);
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      _rollbackIntent(intent, failure);
    } on Object {
      if (!ref.mounted || generation != _generation) return;
      _rollbackIntent(intent, const UnknownFailure());
    }
  }

  Future<void> _queueOfflineIntent(_QuantityIntent intent) async {
    final target = intent.desiredQuantity;
    final confirmed = intent.confirmedItem;
    if (confirmed == null || confirmed.id.startsWith(_localCartItemPrefix)) {
      await ref
          .read(offlineCartQueueProvider)
          .enqueueAdd(
            storeType: storeType.wire,
            configuration: intent.configuration,
            quantity: target,
          );
      return;
    }
    if (target <= 0) {
      await ref.read(offlineCartQueueProvider).enqueueRemove(confirmed.id);
    } else {
      await ref
          .read(offlineCartQueueProvider)
          .enqueueSetQuantity(confirmed.id, target);
    }
  }

  void _publishServerCart(CartData serverCart) {
    final held = state.value;
    if (held == null) return;
    var visible = serverCart;
    for (final pendingIntent in _quantityIntents.values) {
      final serverLine = _findByIdentity(
        serverCart.items,
        pendingIntent.configuration.identity,
      );
      if (serverLine != null && pendingIntent.confirmedItem == null) {
        pendingIntent.confirmedItem = serverLine;
        pendingIntent.template = serverLine;
        pendingIntent.addAlreadyCommitted = false;
      }
      visible = _applyIntent(visible, pendingIntent);
    }
    state = AsyncData(
      held.copyWith(
        cart: visible,
        busyKeys: {..._pending},
        unconfirmedKeys: {
          for (final key in held.unconfirmedKeys)
            if (_findByIdentity(serverCart.items, key) == null) key,
        },
        mutationFailure: () => null,
      ),
    );
  }

  CartData _applyIntent(CartData cart, _QuantityIntent intent) {
    final existing = _findByIdentity(cart.items, intent.configuration.identity);
    if (intent.desiredQuantity <= 0) {
      return existing == null ? cart : cart.removeItem(existing.id);
    }
    final source = existing ?? intent.template;
    final optimistic = _itemWithQuantity(source, intent.desiredQuantity);
    return existing == null
        ? cart.upsertItem(optimistic)
        : cart.replaceItem(optimistic);
  }

  CartItem _itemWithQuantity(CartItem item, int quantity) {
    final oldQuantity = item.quantity;
    final oldSubtotal = double.tryParse(item.subtotal);
    final basePrice =
        double.tryParse(item.variant?.price ?? item.product.price) ?? 0;
    final addonsPrice = item.selectedAddons.fold<double>(
      0,
      (total, addon) => total + (double.tryParse(addon.price) ?? 0),
    );
    final unitPrice = oldQuantity > 0 && oldSubtotal != null && oldSubtotal > 0
        ? oldSubtotal / oldQuantity
        : basePrice + addonsPrice;
    return item.copyWith(
      quantity: quantity,
      subtotal: (unitPrice * quantity).toStringAsFixed(2),
    );
  }

  CartItem? _findByIdentity(List<CartItem> items, String identity) {
    for (final item in items) {
      if (item.configurationIdentity == identity) return item;
    }
    return null;
  }

  void _rollbackIntent(_QuantityIntent intent, ApiFailure failure) {
    final held = state.value;
    if (held == null) return;
    var cart = held.cart;
    final visible = _findByIdentity(cart.items, intent.configuration.identity);
    if (visible != null) cart = cart.removeItem(visible.id);
    final confirmed = intent.confirmedItem;
    if (confirmed != null) cart = cart.upsertItem(confirmed);
    state = AsyncData(
      held.copyWith(cart: cart, mutationFailure: () => failure),
    );
    _settleQuantityIntent(intent, success: false, preserveFailure: true);
  }

  void _settleQuantityIntent(
    _QuantityIntent intent, {
    required bool success,
    bool preserveFailure = false,
  }) {
    final identity = intent.configuration.identity;
    if (_quantityIntents[identity] != intent) return;
    intent.timer?.cancel();
    _quantityIntents.remove(identity);
    _pending.remove(intent.key);
    final held = state.value;
    if (held != null) {
      state = AsyncData(
        preserveFailure
            ? held.copyWith(busyKeys: {..._pending})
            : held.copyWith(
                busyKeys: {..._pending},
                mutationFailure: () => null,
              ),
      );
    }
    for (final waiter in intent.waiters) {
      if (!waiter.isCompleted) waiter.complete(success);
    }
  }

  Future<bool> _reconcile() async {
    final generation = _generation;
    try {
      final cart = await ref.read(cartApiProvider).fetch(storeType.wire);
      if (!ref.mounted || generation != _generation) return false;
      // Navbatda turgan mutatsiyalarning kalitlari SAQLANADI — aks holda
      // ular hali bajarilmagan bo'lsa ham spinnerlari yo'qolib ketardi.
      _publishServerCart(cart);
      return true;
    } on Object catch (error) {
      // The write already succeeded. A failed READ must not enqueue/replay it.
      if (!ref.mounted || generation != _generation) return false;
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          current.copyWith(
            busyKeys: {..._pending},
            mutationFailure: () =>
                error is ApiFailure ? error : const UnknownFailure(),
          ),
        );
      }
      return false;
    }
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
