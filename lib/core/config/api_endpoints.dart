/// User API endpointlarining YAGONA reyestri.
///
/// Qoida: hech bir servis/repository o'z ichida yo'l stringini yozmaydi.
/// Eski appda yo'llar 20 dan ortiq faylga tarqalib ketgan edi.
///
/// Barcha yo'llar `AppConfig.apiBaseUrl` ga nisbatan va **oxirida `/`** bilan
/// (DRF `DefaultRouter` shunday talab qiladi).
library;

abstract final class Api {
  static const String androidAppRelease = '/app-release/android/';
  // ── Auth ───────────────────────────────────────────────────────────────────
  static const String sendOtp = '/auth/send-otp/';
  static const String verifyOtp = '/auth/verify-otp/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';

  // Hisobni o'chirish: avval SMS kod so'raladi, keyin kod bilan tasdiqlanadi.
  static const String deleteAccountRequestOtp =
      '/auth/delete-account/request-otp/';
  static const String deleteAccount = '/auth/delete-account/';

  /// Auth shakli: `{id, phone_number, first_name, last_name, role, ...}`.
  /// `me` (profil shakli) bilan ADASHTIRMASLIK kerak.
  static const String authMe = '/auth/me/';

  /// Refresh/otp endpointlariga Bearer qo'shilmaydi va 401 da refresh
  /// urinilmaydi — aks holda rekursiya bo'ladi.
  static const Set<String> authExempt = {
    sendOtp,
    verifyOtp,
    tokenRefresh,
    androidAppRelease,
  };

  // ── Profil ─────────────────────────────────────────────────────────────────
  /// Profil shakli: `language`, `requires_onboarding`, `missing_fields`,
  /// `default_address` bilan. `authMe` dan boshqacha!
  static const String me = '/me/';
  static const String profile = '/profile/';
  static const String completeOnboarding = '/profile/complete-onboarding/';

  /// Mijoz push tokeni. Backendda HALI YO'Q (R1 riski) —
  /// endpoint paydo bo'lgach `NoopPushTokenRepository` almashtiriladi.
  static const String devices = '/profile/devices/';

  // ── Bosh ekran ─────────────────────────────────────────────────────────────
  static const String home = '/home/';
  static const String homeNews = '/home/news/';

  // ── Do'konlar ──────────────────────────────────────────────────────────────
  static const String stores = '/stores/';
  static String storeLanding(String storeType) => '/stores/$storeType/landing/';
  static String storeBranches(String storeId) => '/stores/$storeId/branches/';

  // ── Katalog ────────────────────────────────────────────────────────────────
  static const String categories = '/catalog/categories/';
  static const String products = '/catalog/products/';
  static const String productSearch = '/catalog/products/search/';
  static const String productsFeatured = '/catalog/products/featured/';
  static const String productsPopular = '/catalog/products/popular/';
  static const String productsDiscounted = '/catalog/products/discounted/';
  static String product(String id) => '/catalog/products/$id/';
  static String productReport(String id) => '/catalog/products/$id/report/';

  // ── Shaxsiy tavsiyalar ─────────────────────────────────────────────────────
  static const String recoEvents = '/recommendations/events/';
  static const String recoForYou = '/recommendations/for-you/';
  static String recoSimilar(String productId) =>
      '/recommendations/similar/$productId/';

  // ── Sharhlar ───────────────────────────────────────────────────────────────
  static String productReviews(String productId) =>
      '/products/$productId/reviews/';
  static String review(String id) => '/reviews/$id/';

  // ── UGC xavfsizligi va huquqiy rozilik ───────────────────────────────────
  static const String ugcPolicy = '/legal/ugc-policy/';
  static const String ugcPolicyAccept = '/legal/ugc-policy/accept/';
  static const String ugcReports = '/ugc/reports/';
  static const String ugcBlockedUsers = '/ugc/blocked-users/';
  static String ugcUserBlock(String userId) => '/ugc/users/$userId/block/';

  // ── Savat ──────────────────────────────────────────────────────────────────
  static const String cart = '/cart/';
  static const String cartItems = '/cart/items/';
  static String cartItem(String itemId) => '/cart/items/$itemId/';
  static const String cartClear = '/cart/clear/';
  static const String guestCartSession = '/cart/guest-session/';
  static const String mergeGuestCart = '/cart/merge-guest/';
  static String cartBundleAdd(String bundleId) =>
      '/cart/bundles/$bundleId/add/';

  // ── Buyurtmalar ────────────────────────────────────────────────────────────
  static const String orders = '/orders/';
  static String order(String id) => '/orders/$id/';
  static String orderTracking(String id) => '/orders/$id/tracking/';
  static String orderCancel(String id) => '/orders/$id/cancel/';

  // ── Yetkazib berish ────────────────────────────────────────────────────────
  static const String deliveryEstimate = '/delivery/estimate/';
  static const String deliveryCoverage = '/delivery/coverage/';

  // ── To'lovlar ──────────────────────────────────────────────────────────────
  static const String paymePaymentCreate = '/payments/payme/create/';

  // ── Manzillar ──────────────────────────────────────────────────────────────
  static const String addresses = '/addresses/';
  static String address(String id) => '/addresses/$id/';
  static String addressSetDefault(String id) => '/addresses/$id/set-default/';

  // ── Sevimlilar ─────────────────────────────────────────────────────────────
  static const String favorites = '/favorites/';
  static String favorite(String productId) => '/favorites/$productId/';
  static String favoriteToggle(String productId) =>
      '/favorites/$productId/toggle/';

  // ── Bildirishnomalar ───────────────────────────────────────────────────────
  static const String notifications = '/notifications/';
  static String notificationRead(String id) => '/notifications/$id/read/';
  static const String notificationsReadAll = '/notifications/read-all/';
  static const String notificationsUnreadCount = '/notifications/unread-count/';
  static const String notificationDevices = '/notification-devices/';
  static String notificationDevice(String id) => '/notification-devices/$id/';

  // ── Aksiyalar / bannerlar ──────────────────────────────────────────────────
  static const String promotions = '/promotions/';
  static const String promotionBanners = '/promotions/banners/';
  static const String storeTopBanners = '/store-top-banners/';

  // ── Yordam ─────────────────────────────────────────────────────────────────
  static const String supportTickets = '/support/tickets/';
  static String supportTicket(String id) => '/support/tickets/$id/';

  // ── Home Reels ────────────────────────────────────────────────────────────
  static const String videos = '/videos/';
  static String videoLike(String id) => '/videos/$id/like/';
  static String videoProducts(String id) => '/videos/$id/products/';
  static String videoComments(String id) => '/videos/$id/comments/';
  static String videoComment(String videoId, String commentId) =>
      '/videos/$videoId/comments/$commentId/';
}
