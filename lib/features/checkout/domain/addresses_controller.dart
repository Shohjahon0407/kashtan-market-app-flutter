import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../data/checkout_api.dart';
import '../data/checkout_models.dart';

final checkoutApiProvider = Provider<CheckoutApi>(
  (ref) => CheckoutApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

final addressesControllerProvider =
    AsyncNotifierProvider<AddressesController, List<UserAddress>>(
      AddressesController.new,
    );

class AddressesController extends AsyncNotifier<List<UserAddress>> {
  @override
  Future<List<UserAddress>> build() async {
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
    final previous = state.value;
    try {
      state = AsyncData(await ref.read(checkoutApiProvider).fetchAddresses());
    } on Object catch (error, stack) {
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
