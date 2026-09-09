import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/store_scope/store_type.dart';
import '../../auth/domain/auth_controller.dart';
import '../../catalog/data/product_models.dart';
import '../data/favorite_models.dart';
import '../data/favorites_api.dart';

final favoritesApiProvider = Provider<FavoritesApi>(
  (ref) => FavoritesApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(privateJsonCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

class FavoritesState {
  const FavoritesState({
    required this.items,
    this.busyProductIds = const {},
    this.mutationFailure,
  });

  final List<FavoriteEntry> items;
  final Set<String> busyProductIds;
  final ApiFailure? mutationFailure;

  bool contains(String productId) =>
      items.any((entry) => entry.product.id == productId);

  List<FavoriteEntry> forStore(StoreType storeType) => items
      .where((entry) => entry.product.storeType == storeType)
      .toList(growable: false);

  FavoritesState copyWith({
    List<FavoriteEntry>? items,
    Set<String>? busyProductIds,
    ApiFailure? Function()? mutationFailure,
  }) => FavoritesState(
    items: items ?? this.items,
    busyProductIds: busyProductIds ?? this.busyProductIds,
    mutationFailure: mutationFailure != null
        ? mutationFailure()
        : this.mutationFailure,
  );
}

/// Backend favorites ro'yxati global. Bitta provider uni bir marta yuklaydi,
/// store ekranlari esa [FavoritesState.forStore] bilan client-side ajratadi.
final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, FavoritesState>(
      FavoritesController.new,
    );

class FavoritesController extends AsyncNotifier<FavoritesState> {
  int _generation = 0;
  @override
  Future<FavoritesState> build() async {
    _generation++;
    ref.watch(accountScopeProvider);
    ref.onDispose(() => _generation++);
    listenForConnectionRecovery(ref, () async {
      if (!state.isLoading &&
          ref.read(authControllerProvider).isAuthenticated &&
          state.value?.busyProductIds.isNotEmpty != true) {
        await refresh();
      }
    });
    ref.watch(apiLangProvider);
    if (!ref.watch(authControllerProvider).isAuthenticated) {
      return const FavoritesState(items: []);
    }
    final api = ref.watch(favoritesApiProvider);
    try {
      return FavoritesState(items: await api.fetch());
    } on ApiFailure {
      // Oflayn: oxirgi ro'yxat diskdan.
      final cached = await api.cachedFavorites();
      if (cached == null) rethrow;
      return FavoritesState(items: cached);
    }
  }

  /// Yangilash ro'yxatni BO'SHATMAYDI: xato bo'lsa eski ro'yxat ekranda
  /// qoladi (ilgari `AsyncLoading` qo'yilib, oflaynda ekran tozalanardi).
  Future<void> refresh() async {
    final generation = _generation;
    final previous = state.value;
    try {
      final items = await ref.read(favoritesApiProvider).fetch();
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(FavoritesState(items: items));
    } on Object catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      state = previous != null ? AsyncData(previous) : AsyncError(error, stack);
    }
  }

  Future<void> toggle(ProductSummary product) async {
    final generation = _generation;
    final current = state.value;
    if (current == null || current.busyProductIds.isNotEmpty) return;
    final wasFavorite = current.contains(product.id);
    final optimistic = wasFavorite
        ? current.items
              .where((entry) => entry.product.id != product.id)
              .toList(growable: false)
        : [
            FavoriteEntry(id: 'optimistic:${product.id}', product: product),
            ...current.items,
          ];
    state = AsyncData(
      current.copyWith(
        items: optimistic,
        busyProductIds: {...current.busyProductIds, product.id},
        mutationFailure: () => null,
      ),
    );
    try {
      final isFavorite = await ref
          .read(favoritesApiProvider)
          .toggle(product.id);
      if (!ref.mounted || generation != _generation) return;
      if (isFavorite != !wasFavorite) {
        await refresh();
        return;
      }
      final reconciled = await ref.read(favoritesApiProvider).fetch();
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(FavoritesState(items: reconciled));
    } on ApiFailure catch (failure) {
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(current.copyWith(mutationFailure: () => failure));
    }
  }
}
