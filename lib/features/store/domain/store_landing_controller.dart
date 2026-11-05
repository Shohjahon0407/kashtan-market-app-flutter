import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/connectivity_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/store_scope/store_type.dart';
import '../../catalog/data/restaurant_offline_repository.dart';
import '../../catalog/domain/restaurant_offline_sync.dart';
import '../data/store_api.dart';
import '../data/store_models.dart';

final storeApiProvider = Provider<StoreApi>(
  (ref) => StoreApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
    offline: ref.watch(restaurantOfflineRepositoryProvider),
  ),
);

/// Do'kon landing ma'lumoti — stale-while-revalidate:
/// avval diskdagi oxirgi muvaffaqiyatli javob DARHOL chiqadi, keyin tarmoqdan
/// yangisi kelib almashtiradi (StoreApi uni keshga o'zi yozadi). Tarmoq
/// ishlamasa kesh ko'rsatilib qoladi; kesh ham bo'lmasa xato tashlanadi
/// (ekran retry ko'rsatadi).
final storeLandingProvider = StreamProvider.family<StoreLandingData, StoreType>(
  (ref, storeType) async* {
    ref.watch(apiLangProvider);
    ref.watch(uzScriptProvider);
    if (storeType == StoreType.restaurant) {
      ref.watch(connectivityRecoveryProvider);
    }
    final api = ref.watch(storeApiProvider);
    if (storeType == StoreType.restaurant &&
        ref.read(restaurantOfflineRepositoryProvider).enabled) {
      // Background download is independent of the visible landing request.
      unawaited(
        Future<void>.microtask(() {
          if (ref.mounted) {
            return ref.read(restaurantOfflineSyncProvider.notifier).sync();
          }
        }),
      );
    }

    StoreLandingData? cached;
    if (storeType == StoreType.restaurant) {
      final saved = await ref
          .read(restaurantOfflineRepositoryProvider)
          .landing();
      if (saved != null) {
        try {
          cached = StoreLandingData.fromJson(saved);
          yield cached;
        } on Object {
          cached = null;
        }
      }
    }
    final cachedRaw = await ref
        .read(jsonDiskCacheProvider)
        .read(
          landingCacheKey(storeType.wire, ref.read(cacheKeySuffixProvider)()),
          maxAge: const Duration(days: 3),
        );
    if (cached == null && cachedRaw != null) {
      try {
        cached = StoreLandingData.fromJson(cachedRaw);
        yield cached;
      } on Object {
        cached = null; // eski format — e'tiborsiz
      }
    }

    try {
      yield await api.fetchLanding(storeType.wire);
      if (ref.mounted &&
          storeType == StoreType.restaurant &&
          ref.read(restaurantOfflineRepositoryProvider).enabled) {
        unawaited(ref.read(restaurantOfflineSyncProvider.notifier).sync());
      }
    } on Object {
      if (cached == null) rethrow;
      // Kesh ko'rsatilgan — tarmoq xatosini yutamiz.
    }
  },
);
