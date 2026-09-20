import 'package:flutter/material.dart';

/// Home video kabi route lifecycle'iga bog'liq resurslar uchun yagona observer.
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// Route yo'llari — bitta joyda, string takrorlanmaydi.
abstract final class Routes {
  static const String splash = '/splash';
  static const String authPhone = '/auth/phone';
  static const String authOtp = '/auth/otp';
  static const String home = '/';

  /// Home shell tablari (Asosiy = [home]) — qarang [HomeTab].
  static const String videos = '/videos';
  static const String stores = '/stores';
  static const String allOrders = '/orders';
  static const String search = '/search';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String blockedUsers = '/profile/blocked-users';
  static const String requests = '/requests';
  static const String missingProductRequest = '/requests/missing-product';
  static const String notifications = '/notifications';
  static const String addresses = '/addresses';
  static const String addressNew = '/addresses/new';

  static String addressEdit(String addressId) => '$addresses/$addressId/edit';

  static String requestsFor({String? kind, String? storeType}) {
    if (kind == 'missing_product') {
      return missingProductRequestFor(storeType: storeType);
    }
    final query = {
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (storeType != null && storeType.isNotEmpty) 'storeType': storeType,
    };
    return query.isEmpty
        ? requests
        : Uri(path: requests, queryParameters: query).toString();
  }

  static String missingProductRequestFor({String? storeType}) =>
      storeType == null || storeType.isEmpty
      ? missingProductRequest
      : Uri(
          path: missingProductRequest,
          queryParameters: {'storeType': storeType},
        ).toString();

  /// Do'kon ekrani: `/store/grocery` kabi. To'liq yo'l uchun
  /// `'$storeBase/$storeTypeWire'`.
  static const String storeBase = '/store';
  static const String storePattern = '/store/:storeType';

  static const String unsupportedStore = '/store-unsupported';

  static String unsupportedStoreFor(String storeType) => Uri(
    path: unsupportedStore,
    queryParameters: {'storeType': storeType},
  ).toString();

  static String storeRoot(String storeType) => '$storeBase/$storeType';
  static String storeCatalog(String storeType, {String? categoryId}) {
    final path = '${storeRoot(storeType)}/catalog';
    return categoryId == null || categoryId.isEmpty
        ? path
        : Uri(path: path, queryParameters: {'category': categoryId}).toString();
  }

  static String storeCatalogSearch(String storeType) =>
      '${storeCatalog(storeType)}/search';

  static String storeCategoryProducts(String storeType, String categoryId) =>
      '${storeCatalog(storeType)}/category/${Uri.encodeComponent(categoryId)}';

  static String storeFavorites(String storeType) =>
      '${storeRoot(storeType)}/favorites';
  static String storeCart(String storeType) => '${storeRoot(storeType)}/cart';
  static String storeOrders(String storeType) =>
      '${storeRoot(storeType)}/orders';
  static String productDetail(String storeType, String productId) =>
      '${storeCatalog(storeType)}/product/$productId';
  static String checkout(String storeType) =>
      '${storeCart(storeType)}/checkout';
  static String checkoutAddressNew(String storeType) =>
      '${checkout(storeType)}/address/new';
  static String checkoutAddressEdit(String storeType, String addressId) =>
      '${checkout(storeType)}/address/$addressId/edit';

  /// [autoPay] — buyurtma yaratilgach Payme to'loviga avtomatik urinish
  /// bayrog'i (checkout'da Payme tanlanganda).
  static String orderDetail(
    String storeType,
    String orderId, {
    bool autoPay = false,
  }) => '${storeOrders(storeType)}/$orderId${autoPay ? '?autopay=1' : ''}';

  /// Dev playground — faqat debug build'da router'ga qo'shiladi.
  /// Diagnostika uchun KIRILMAGAN holatda ham ochiq (faqat debug).
  static const String dev = '/dev';

  /// Kirilmagan foydalanuvchi turishi MUMKIN bo'lgan yo'llar.
  static const Set<String> authEntry = {authPhone, authOtp};

  static String authPhoneFor({String? returnTo, bool modal = false}) =>
      _authPath(authPhone, returnTo, modal: modal);

  static String authOtpFor({String? returnTo, bool modal = false}) =>
      _authPath(authOtp, returnTo, modal: modal);

  static String _authPath(String path, String? returnTo, {bool modal = false}) {
    final query = {
      if (returnTo != null && returnTo.isNotEmpty) 'returnTo': returnTo,
      if (modal) 'modal': '1',
    };
    return query.isEmpty
        ? path
        : Uri(path: path, queryParameters: query).toString();
  }
}

/// Bosh sahifa pastki navbar tablari. Tartib `StatefulShellRoute`
/// branch'lari tartibi bilan bir xil (index = branch).
enum HomeTab { home, videos, stores, orders }

String homeTabLocation(HomeTab tab) => switch (tab) {
  HomeTab.home => Routes.home,
  HomeTab.videos => Routes.videos,
  HomeTab.stores => Routes.stores,
  HomeTab.orders => Routes.allOrders,
};
