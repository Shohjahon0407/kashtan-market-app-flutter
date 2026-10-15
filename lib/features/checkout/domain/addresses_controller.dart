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

final addressesControllerProvider =
    AsyncNotifierProvider<AddressesController, List<UserAddress>>(
      AddressesController.new,
    );

class AddressesController extends AsyncNotifier<List<UserAddress>> {
  int _generation = 0;
  @override
  Future<List<UserAddress>> build() async {
    _generation++;
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
    } on ApiFailure {
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
      state = AsyncData(addresses);
    } on Object catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = previous != null ? AsyncData(previous) : AsyncError(error, stack);
    }
  }

  Future<UserAddress> save(UserAddress address) async {
    final saved = address.id.isEmpty
        ? await ref.read(checkoutApiProvider).createAddress(address)
        : await ref.read(checkoutApiProvider).updateAddress(address);
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
