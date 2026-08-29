import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/store_scope/store_type.dart';
import '../data/store_api.dart';
import '../data/store_models.dart';

final storeApiProvider = Provider<StoreApi>(
  (ref) => StoreApi(
    ref.watch(apiClientProvider),
    cache: ref.watch(jsonDiskCacheProvider),
    cacheKeySuffix: ref.watch(cacheKeySuffixProvider),
  ),
);

/// Do'kon landing ma'lumoti — stale-while-revalidate:
/// avval diskdagi oxirgi muvaffaqiyatli javob DARHOL chiqadi, keyin tarmoqdan
/// yangisi kelib almashtiradi (StoreApi uni keshga o'zi yozadi). Tarmoq
/// ishlamasa kesh ko'rsatilib qoladi; kesh ham bo'lmasa xato tashlanadi
/// (ekran retry ko'rsatadi).
final storeLandingProvider = StreamProvider.autoDispose
    .family<StoreLandingData, StoreType>((ref, storeType) async* {
      ref.watch(apiLangProvider);
      ref.watch(uzScriptProvider);
      final api = ref.watch(storeApiProvider);

      StoreLandingData? cached;
      final cachedRaw = await ref
          .read(jsonDiskCacheProvider)
          .read(
            landingCacheKey(storeType.wire, ref.read(cacheKeySuffixProvider)()),
            maxAge: const Duration(days: 3),
          );
      if (cachedRaw != null) {
        try {
          cached = StoreLandingData.fromJson(cachedRaw);
          yield cached;
        } on Object {
          cached = null; // eski format — e'tiborsiz
        }
      }

      try {
        yield await api.fetchLanding(storeType.wire);
      } on Object {
        if (cached == null) rethrow;
        // Kesh ko'rsatilgan — tarmoq xatosini yutamiz.
      }
    });
