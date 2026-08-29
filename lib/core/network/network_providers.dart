import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_locale.dart';
import '../localization/locale_controller.dart';
import '../localization/uzbek_transliterator.dart';
import '../storage/secure_token_store.dart';
import 'api_client.dart';
import 'connectivity_controller.dart';

/// Tokenlar ombori — Keychain / EncryptedSharedPreferences.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final guestCartTokenStoreProvider = Provider<GuestCartTokenStore>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  return tokenStore is GuestCartTokenStore
      ? tokenStore as GuestCartTokenStore
      : InMemoryTokenStore();
});

/// Refresh uchun mustaqil klient (AuthInterceptor'ga qaytib tushmaydi).
final tokenRefreshClientProvider = Provider<TokenRefreshClient>(
  (ref) => TokenRefreshClient(),
);

/// Sessiya tugaganda (refresh ham o'lganda) chaqiriladi.
///
/// Default'da faqat tokenlarni tozalaydi. `app.dart` buni
/// `AuthController.expireSession()` ga override qiladi — bu yerda
/// to'g'ridan-to'g'ri import qilinsa aylanma bog'liqlik chiqadi
/// (auth → apiClient → onSessionExpired → auth).
final onSessionExpiredProvider = Provider<Future<void> Function()>(
  (ref) =>
      () async => ref.read(tokenStoreProvider).clear(),
);

/// User API klienti.
///
/// `keepAlive` emas, lekin `ApiClient` root'da yaratilgani va hech kim uni
/// dispose qilmagani uchun bir nusxada qoladi.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient.create(
    tokenStore: ref.watch(tokenStoreProvider),
    apiLang: () => ref.read(localeControllerProvider).apiLang,
    script: () => ref.read(localeControllerProvider).script,
    refresh: (refreshToken) =>
        ref.read(tokenRefreshClientProvider).refresh(refreshToken),
    // Ulanish holati: offline bo'lsa so'rov yuborilmaydi, natijalar esa
    // holatni yangilab boradi.
    isOffline: () => ref.read(connectivityControllerProvider).isOffline,
    onNetworkSuccess: () =>
        ref.read(connectivityControllerProvider.notifier).reportSuccess(),
    onNetworkFailure: () => ref
        .read(connectivityControllerProvider.notifier)
        .reportNetworkFailure(),
    onSessionExpired: () => ref.read(onSessionExpiredProvider)(),
  );

  // Til o'zgarganda transliteratsiya rejimini yangilaymiz. Bu yagona nuqta —
  // shundan keyin butun daraxt to'g'ri yozuvda keladi.
  ref.listen<AppLocale>(localeControllerProvider, (previous, next) {
    client.transformer.script = next.script;
  });
  client.transformer.script = ref.read(localeControllerProvider).script;

  return client;
});

/// Chiquvchi matn uchun joriy yozuv (interceptorlar o'qiydi).
final uzScriptProvider = Provider<UzScript>(
  (ref) => ref.watch(localeControllerProvider).script,
);

/// Disk keshi kalitlari uchun til+yozuv qo'shimchasi.
///
/// Javob matni transformer tomonidan joriy yozuvga transliteratsiya qilingan
/// holda keshlanadi — kalitga ikkisi ham kirmasa, til almashtirilganda eski
/// yozuvdagi kesh ko'rsatilib qoladi.
final cacheKeySuffixProvider = Provider<String Function()>(
  (ref) => () {
    final locale = ref.read(localeControllerProvider);
    return '${locale.apiLang}_${locale.script.name}';
  },
);
