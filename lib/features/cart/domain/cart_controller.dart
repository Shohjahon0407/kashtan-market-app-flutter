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

  static const String clear = 'clear';
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
  /// qo'shilayotganda faqat o'sha karta spinner ko'rsatadi, qolganlari
  /// oddiy holatda qoladi.
  final Set<String> busyKeys;

  /// Serverga YOZILGAN, lekin keyingi GET xato bergani uchun `cart` ichida
  /// hali ko'rinmayotgan konfiguratsiyalar. UI ular uchun "Sotib olish"
  /// tugmasini QAYTA ko'rsatmaydi — aks holda foydalanuvchi ikkinchi marta
  /// bosib, serverda 2 dona bo'lib qolardi.
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
    return _mutate(
      CartMutationKeys.add(configuration),
      (current) => _addProduct(configuration, current, quantity),
    );
  }

  Future<bool> _addProduct(
    CartConfiguration configuration,
    CartState current,
    int quantity,
  ) async {
    final generation = _generation;
    CartItem? duplicate;
    for (final item in current.cart.items) {
      if (item.configurationIdentity == configuration.identity) {
        duplicate = item;
        break;
      }
    }

    final previous = current;
    if (duplicate != null) {
      final optimistic = duplicate.copyWith(
        quantity: duplicate.quantity + quantity,
      );
      state = AsyncData(
        current.copyWith(cart: current.cart.replaceItem(optimistic)),
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
      if (!ref.mounted || generation != _generation) return false;
      final reconciled = await _reconcile();
      if (!ref.mounted || generation != _generation) return true;
      if (!reconciled && duplicate == null) {
        // Yozuv serverga yetdi, lekin GET xato berdi: yangi satr server
        // id'siz ko'rsatilmaydi. Konfiguratsiya "tasdiqlanmagan" deb
        // belgilanadi — tugma qayta "Sotib olish" bo'lmaydi.
        final held = state.value;
        if (held != null) {
          state = AsyncData(
            held.copyWith(
              unconfirmedKeys: {
                ...held.unconfirmedKeys,
                configuration.identity,
              },
            ),
          );
        }
        _scheduleUnconfirmedRetry();
      }
      // Mahsulot savatda — solishtirish xatosi buni bekor qilmaydi.
      return true;
    } on NetworkFailure {
      if (!ref.mounted || generation != _generation) return false;
      // OFLAYN: amal navbatga tushadi va internet qaytganda yuboriladi.
      // Optimistik ko'rinish saqlanadi — foydalanuvchi uchun savat ishlayveradi.
      if (duplicate != null) {
        await ref
            .read(offlineCartQueueProvider)
            .enqueueSetQuantity(duplicate.id, duplicate.quantity + quantity);
        final held = state.value ?? previous;
        state = AsyncData(held.copyWith(mutationFailure: () => null));
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
      state = AsyncData(previous.copyWith(mutationFailure: () => null));
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    } on Object {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          previous.copyWith(mutationFailure: () => const UnknownFailure()),
        );
      }
      return false;
    }
  }

  Future<void> increment(CartItem item) =>
      _setQuantity(item, item.quantity + 1);

  Future<void> decrement(CartItem item) =>
      item.quantity <= 1 ? remove(item) : _setQuantity(item, item.quantity - 1);

  Future<void> remove(CartItem item) => _mutate(
    CartMutationKeys.item(item.id),
    (current) => _remove(item, current),
  );

  Future<bool> _remove(CartItem item, CartState current) async {
    final generation = _generation;
    final previous = current;
    state = AsyncData(current.copyWith(cart: current.cart.removeItem(item.id)));
    try {
      await ref.read(cartApiProvider).deleteItem(item.id);
      if (!ref.mounted || generation != _generation) return false;
      await _reconcile();
      return true;
    } on NetworkFailure {
      if (!ref.mounted || generation != _generation) return false;
      // Oflayn: element ekrandan olib tashlangan holicha qoladi.
      await ref.read(offlineCartQueueProvider).enqueueRemove(item.id);
      final held = state.value ?? previous;
      state = AsyncData(held.copyWith(mutationFailure: () => null));
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    }
  }

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

  Future<void> _setQuantity(CartItem item, int quantity) => _mutate(
    CartMutationKeys.item(item.id),
    (current) => _applyQuantity(item, quantity, current),
  );

  Future<bool> _applyQuantity(
    CartItem item,
    int quantity,
    CartState current,
  ) async {
    final generation = _generation;
    final previous = current;
    state = AsyncData(
      current.copyWith(
        cart: current.cart.replaceItem(item.copyWith(quantity: quantity)),
      ),
    );
    try {
      await ref.read(cartApiProvider).updateQuantity(item.id, quantity);
      if (!ref.mounted || generation != _generation) return false;
      await _reconcile();
      return true;
    } on NetworkFailure {
      if (!ref.mounted || generation != _generation) return false;
      // Oflayn: yangi miqdor ekranda qoladi, amal navbatga tushadi.
      await ref
          .read(offlineCartQueueProvider)
          .enqueueSetQuantity(item.id, quantity);
      final held = state.value ?? previous;
      state = AsyncData(held.copyWith(mutationFailure: () => null));
      return true;
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return false;
      state = AsyncData(previous.copyWith(mutationFailure: () => failure));
      return false;
    }
  }

  Future<bool> _reconcile() async {
    final generation = _generation;
    try {
      final cart = await ref.read(cartApiProvider).fetch(storeType.wire);
      if (!ref.mounted || generation != _generation) return false;
      // Navbatda turgan mutatsiyalarning kalitlari SAQLANADI — aks holda
      // ular hali bajarilmagan bo'lsa ham spinnerlari yo'qolib ketardi.
      state = AsyncData(CartState(cart: cart, busyKeys: {..._pending}));
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
