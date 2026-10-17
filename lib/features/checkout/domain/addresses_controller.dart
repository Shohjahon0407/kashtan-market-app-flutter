import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/account_scope.dart';
import '../../auth/domain/auth_controller.dart';
import '../data/checkout_api.dart';
import '../data/checkout_models.dart';

final checkoutApiProvider = Provider<CheckoutApi>(
  (ref) => CheckoutApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(privateJsonCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

final deliveryCoverageProvider = FutureProvider.autoDispose
    .family<List<DeliveryCoverageBranch>, String>((ref, storeType) {
      ref.watch(accountScopeProvider);
      ref.watch(apiLangProvider);
      return ref.watch(checkoutApiProvider).fetchCoverage(storeType);
    });

/// Shared address limit: independent from the currently selected store/cart.
final addressCoverageProvider =
    FutureProvider.autoDispose<List<DeliveryCoverageBranch>>((ref) {
      ref.watch(accountScopeProvider);
      ref.watch(apiLangProvider);
      return ref
          .watch(checkoutApiProvider)
          .fetchAddressCoverage()
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw const NetworkFailure(),
          );
    }, retry: (_, _) => null);

final addressesControllerProvider =
    AsyncNotifierProvider<AddressesController, List<UserAddress>>(
      AddressesController.new,
    );

class AddressesController extends AsyncNotifier<List<UserAddress>> {
  int _generation = 0;
  ApiFailure? _refreshFailure;

  /// The list remains useful offline, but checkout must know whether the last
  /// explicit server refresh actually succeeded before trusting its coordinates.
  ApiFailure? get refreshFailure => _refreshFailure;
  @override
  Future<List<UserAddress>> build() async {
    _generation++;
    _refreshFailure = null;
    ref.watch(accountScopeProvider);
    ref.onDispose(() => _generation++);
    listenForConnectionRecovery(ref, () async {
      if (!state.isLoading &&
          ref.read(authControllerProvider).isAuthenticated) {
        await refresh();
      }
    });
    ref.watch(apiLangProvider);
    final api = ref.watch(checkoutApiProvider);
    try {
      return await api.fetchAddresses();
    } on ApiFailure catch (failure) {
      _refreshFailure = failure;
      final cached = await api.cachedAddresses();
      if (cached == null) rethrow;
      return cached;
    }
  }

  /// Yangilash ro'yxatni BO'SHATMAYDI — xato bo'lsa eskisi ekranda qoladi.
  Future<void> refresh() async {
    final generation = _generation;
    final previous = state.value;
    try {
      final addresses = await ref.read(checkoutApiProvider).fetchAddresses();
      if (!ref.mounted || generation != _generation) return;
      _refreshFailure = null;
      state = AsyncData(addresses);
    } on Object catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      _refreshFailure = error is ApiFailure ? error : const UnknownFailure();
      state = previous != null ? AsyncData(previous) : AsyncError(error, stack);
    }
  }

  Future<UserAddress> save(UserAddress address) async {
    final generation = _generation;
    final saved = address.id.isEmpty
        ? await ref.read(checkoutApiProvider).createAddress(address)
        : await ref.read(checkoutApiProvider).updateAddress(address);
    if (!ref.mounted || generation != _generation) return saved;
    // The write already succeeded. Keep its result available if the following
    // read fails offline, so the selector can reveal the saved draft card.
    final previous = state.value ?? const <UserAddress>[];
    state = AsyncData([
      for (final current in previous) current.id == saved.id ? saved : current,
      if (!previous.any((current) => current.id == saved.id)) saved,
    ]);
    await refresh();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(checkoutApiProvider).deleteAddress(id);
    await refresh();
  }

  Future<void> setDefault(String id) async {
    await ref.read(checkoutApiProvider).setDefaultAddress(id);
    await refresh();
  }
}

final storeBranchesProvider = FutureProvider.autoDispose
    .family<List<StoreBranch>, String>((ref, storeId) {
      ref.watch(apiLangProvider);
      return ref.watch(checkoutApiProvider).fetchBranches(storeId);
    });
