import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../data/home_api.dart';
import '../data/home_models.dart';

final homeApiProvider = Provider<HomeApi>(
  (ref) => HomeApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

/// Bosh ekran ma'lumoti.
///
/// Til o'zgarganda avtomatik qayta yuklanadi (`watch(apiLangProvider)` —
/// provider qayta quriladi va yangi `lang` bilan so'raydi).
///
/// Tezlik: HomeApi har muvaffaqiyatli javobni diskka yozadi — app ochilganda
/// avval o'sha kesh DARHOL ko'rsatiladi, yangisi fonda kelib almashtiradi
/// (stale-while-revalidate). Internet ishlamasa kesh ko'rsatilib turaveradi.
final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeData>(
  HomeController.new,
);

class HomeController extends AsyncNotifier<HomeData> {
  var _buildRevision = 0;

  @override
  Future<HomeData> build() async {
    listenForConnectionRecovery(ref, () async {
      if (!state.isLoading) await refresh();
    });
    ref.watch(apiLangProvider);
    ref.watch(uzScriptProvider);
    final revision = ++_buildRevision;

    final cachedRaw = await ref
        .read(jsonDiskCacheProvider)
        .read(
          homeCacheKey(ref.read(cacheKeySuffixProvider)()),
          maxAge: const Duration(days: 3),
        );
    if (cachedRaw != null) {
      HomeData? cached;
      try {
        cached = HomeData.fromJson(cachedRaw);
      } on Object {
        cached = null; // eski format — keshni e'tiborsiz qoldiramiz
      }
      if (cached != null) {
        unawaited(_revalidate(revision));
        return cached;
      }
    }
    return ref.read(homeApiProvider).fetch();
  }

  /// Kesh ko'rsatilgandan keyin fonda yangilash. Xato bo'lsa jim qolamiz —
  /// ekranda kesh bor.
  Future<void> _revalidate(int revision) async {
    try {
      final fresh = await ref.read(homeApiProvider).fetch();
      if (revision == _buildRevision) state = AsyncData(fresh);
    } on Object {
      // Oflayn — keshdagi ko'rinish qoladi.
    }
  }

  /// Pull-to-refresh: eski ma'lumot ekranda qoladi (RefreshIndicator o'z
  /// spinnerini ko'rsatadi), xato bo'lsa ham eski ro'yxat yo'qolmaydi.
  Future<void> refresh() async {
    final previous = state.value;
    try {
      state = AsyncData(await ref.read(homeApiProvider).fetch());
    } on Object catch (error, stack) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stack);
      }
    }
  }
}
