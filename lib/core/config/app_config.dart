/// Build-time konfiguratsiya.
///
/// Hech qanday `.env` fayl yo'q — hamma narsa `--dart-define` orqali keladi,
/// shunda qiymatlar kompilyatsiya paytida qadaladi va release build'da
/// o'zgartirib bo'lmaydi.
///
/// ```
/// flutter run --dart-define=BACKEND_ORIGIN=http://10.0.2.2:8000
/// ```
library;

/// Ilova qaysi muhitga qarshi ishlayapti.
enum AppFlavor {
  dev,
  staging,
  prod;

  static AppFlavor fromName(String value) => switch (value.toLowerCase()) {
    'dev' || 'development' => AppFlavor.dev,
    'staging' || 'stage' => AppFlavor.staging,
    _ => AppFlavor.prod,
  };

  bool get isProd => this == AppFlavor.prod;
}

abstract final class AppConfig {
  // ── Build-time qiymatlar ───────────────────────────────────────────────────

  static const String _defaultBackendOrigin = 'https://api.beshkashtan.uz';

  static const String _originOverride = String.fromEnvironment(
    'BACKEND_ORIGIN',
  );

  static const String _flavorName = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'prod',
  );

  /// `true` bo'lsa tarmoq so'rovlari curl ko'rinishida logga chiqadi.
  /// Debug build'da default yoqiq, release'da hech qachon yoqilmaydi.
  static const bool verboseNetworkLog = bool.fromEnvironment(
    'VERBOSE_NETWORK_LOG',
    defaultValue: true,
  );

  /// Mapbox public token faqat build-time'da beriladi. Debugda token bo'lmasa
  /// OSM fallback ishlaydi; production packaging esa Gradle/release gate'da
  /// tokensiz qat'iy to'xtatiladi.
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  // ── Hosila qiymatlar ───────────────────────────────────────────────────────

  static AppFlavor get flavor => AppFlavor.fromName(_flavorName);

  /// Sxema + host, oxirida `/` yo'q. Masalan `https://api.beshkashtan.uz`.
  static String get backendOrigin {
    final raw = _originOverride.trim().isEmpty
        ? _defaultBackendOrigin
        : _originOverride.trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// User API ildizi. Admin API bu ilovada umuman ishlatilmaydi.
  static String get apiBaseUrl => '$backendOrigin$_userApiPath';
  static const String _userApiPath = '/api/user';

  /// Buyurtma holati uchun WebSocket manzili.
  ///
  /// `https` → `wss`, `http` → `ws` ga aylantiriladi.
  static Uri get orderSocketUri {
    final origin = Uri.parse(backendOrigin);
    return origin.replace(
      scheme: origin.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/user/orders/',
    );
  }

  // ── Media ──────────────────────────────────────────────────────────────────

  /// Backend rasm URL'larini absolut qaytaradi, lekin himoya sifatida
  /// nisbiy `/media/...` yo'llari ham qo'llab-quvvatlanadi.
  static String? resolveMediaUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return value.startsWith('/')
        ? '$backendOrigin$value'
        : '$backendOrigin/$value';
  }

  /// Play Store talabi: maxfiylik siyosati ilova ichidan ochilishi kerak.
  static const String privacyPolicyUrl = 'https://api.beshkashtan.uz/privacy/';
  static const String termsUrl = 'https://api.beshkashtan.uz/terms/';
  static const String communityGuidelinesUrl =
      'https://api.beshkashtan.uz/community-guidelines/';

  // ── Tarmoq taymautlari ─────────────────────────────────────────────────────

  // Qisqa taymautlar ataylab: sekin tarmoqda foydalanuvchi 30-60 soniya
  // spinnerga qarab o'tirmasin. Offline ekani ma'lum bo'lsa so'rov umuman
  // yuborilmaydi (ConnectivityInterceptor).
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 15);
  // Fayl yuklash (murojaat rasmi/ovozi) uzunroq bo'lishi mumkin.
  static const Duration sendTimeout = Duration(seconds: 30);

  // ── Deep link ──────────────────────────────────────────────────────────────

  static const String deepLinkScheme = 'marketplace';
  static const String universalLinkHost = 'beshkashtan.uz';

  // ── Xarita (OpenStreetMap) ─────────────────────────────────────────────────

  /// Nominatim ishlatish shartlari identifikatsiyalovchi User-Agent talab qiladi.
  /// R2 riski: relizdan oldin o'z geocoder'imizga o'tish kerak.
  static const String mapUserAgent =
      'BeshKashtanCustomer/1.0 (support@beshkashtan.uz)';

  /// Faqat debug/local ishlash uchun fallback. Play release gate production
  /// buildni Mapbox public tokenisiz o'tkazmaydi.
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static bool get usesMapboxTiles => mapboxAccessToken.trim().isNotEmpty;

  static String get mapTileUrl => !usesMapboxTiles
      ? osmTileUrl
      : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/'
            '256/{z}/{x}/{y}@2x?access_token=$mapboxAccessToken';

  static String get addressTileUrl => mapTileUrl;
  static String get trackingTileUrl => mapTileUrl;

  /// Toshkent viloyati, Parkent — filiallar shu atrofda.
  static const double defaultLatitude = 41.308119;
  static const double defaultLongitude = 69.564014;
}
