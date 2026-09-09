import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueKey, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/checkout/presentation/address_form_screen.dart';
import '../../features/checkout/presentation/addresses_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/dev/presentation/api_playground_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/store/presentation/store_shell.dart';
import '../../features/store/presentation/unsupported_store_screen.dart';
import '../../features/support/presentation/support_center_screen.dart';
import '../../features/ugc/presentation/blocked_users_screen.dart';
import '../store_scope/current_store_type_provider.dart';
import '../store_scope/store_type.dart';
import 'route_not_found_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    observers: [appRouteObserver],
    refreshListenable: refresh,
    // Hech qaysi route mos kelmasa (eski havola, noma'lum yo'l) go_router'ning
    // qizil xato ekrani emas, bosh sahifaga qaytaruvchi oddiy ekran.
    errorBuilder: (context, state) =>
        RouteNotFoundScreen(location: state.uri.toString()),
    debugLogDiagnostics: kDebugMode,

    // QOIDA: auth'dan keyingi navigatsiya FAQAT shu redirect orqali
    // (deklarativ). Ekranlar hech qachon verify muvaffaqiyatida o'zi
    // `context.go` qilmaydi — eski appda ikkalasi birga qilinib,
    // "keyReservation" crash'iga olib kelgan edi.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.uri.path;

      // Sessiya tekshirilayotganda splash'da turamiz.
      if (auth.isCheckingSession) {
        return path == Routes.splash ? null : Routes.splash;
      }

      // Noma'lum do'kon turi (backend yangi tur qo'shgan, ilova eski) —
      // MEHMON uchun ham. Reels/hub'dan xom wire bilan `/store/<wire>/catalog`
      // ochiladi; shell route'lari faqat enum qiymatlari uchun bor.
      if (path.startsWith('${Routes.storeBase}/')) {
        final segments = state.uri.pathSegments;
        final wire = segments.length > 1 ? segments[1] : '';
        if (StoreType.fromWire(wire) == null) {
          return Routes.unsupportedStoreFor(wire);
        }
      }

      if (auth.isAuthenticated) {
        // Kirgan foydalanuvchi splash/auth ekranlarida turmaydi.
        if (path == Routes.splash) return Routes.home;
        // Auth prompt muvaffaqiyatni o'zi yakunlaydi. Router bu yerda
        // parallel redirect qilsa push-result va back stack poygasi yuz beradi.
        return null;
      }

      // Guest public marketplace'ga kira oladi. OTP faqat himoyalangan amal
      // bosilganda ochiladi va returnTo orqali aynan o'sha joyga qaytadi.
      if (path == Routes.authOtp) {
        return auth.phone == null
            ? Routes.authPhoneFor(
                returnTo: state.uri.queryParameters['returnTo'],
              )
            : null;
      }
      if (path == Routes.authPhone) return null;
      if (path == Routes.splash) return Routes.home;
      // Debug'da /dev kirilmasdan ham ochiq — login muammolarini SMS
      // sarflamasdan diagnostika qilish uchun (GET /home/ ni sinash mumkin).
      if (kDebugMode && path == Routes.dev) return null;
      if (_requiresAuthentication(path)) {
        return Routes.authPhoneFor(returnTo: state.uri.toString());
      }
      return null;
    },

    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.authPhone,
        pageBuilder: (context, state) => _authPromptPage(state),
      ),
      GoRoute(
        path: Routes.authOtp,
        pageBuilder: (context, state) => _authPromptPage(state),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) => const MainCartScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'blocked-users',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (context, state) => const AddressesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AddressFormScreen(),
          ),
          GoRoute(
            path: ':addressId/edit',
            builder: (context, state) =>
                AddressFormScreen(addressId: state.pathParameters['addressId']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.requests,
        redirect: (context, state) =>
            state.uri.queryParameters['kind'] == 'missing_product'
            ? Routes.missingProductRequestFor(
                storeType: state.uri.queryParameters['storeType'],
              )
            : null,
        builder: (context, state) => SupportCenterScreen(
          initialKind: state.uri.queryParameters['kind'],
          initialStoreType: state.uri.queryParameters['storeType'],
        ),
      ),
      GoRoute(
        path: Routes.missingProductRequest,
        builder: (context, state) => MissingProductRequestScreen(
          initialStoreType: state.uri.queryParameters['storeType'],
        ),
      ),
      GoRoute(
        path: Routes.storePattern,
        redirect: (context, state) {
          final wire = state.pathParameters['storeType'] ?? '';
          return StoreType.fromWire(wire) == null
              ? Routes.unsupportedStoreFor(wire)
              : Routes.storeCatalog(wire);
        },
      ),
      GoRoute(
        path: Routes.unsupportedStore,
        builder: (context, state) => UnsupportedStoreScreen(
          storeTypeWire: state.uri.queryParameters['storeType'],
        ),
      ),
      for (final storeType in StoreType.values) _storeShellRoute(storeType),
      if (kDebugMode)
        GoRoute(
          path: Routes.dev,
          builder: (context, state) => const ApiPlaygroundScreen(),
        ),
    ],
  );
});

CustomTransitionPage<bool> _authPromptPage(GoRouterState state) =>
    CustomTransitionPage<bool>(
      key: state.pageKey,
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      child: PhoneScreen(
        returnTo: state.uri.queryParameters['returnTo'],
        isModalPrompt: state.uri.queryParameters['modal'] == '1',
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.97, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );

StatefulShellRoute _storeShellRoute(
  StoreType storeType,
) => StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => ProviderScope(
    key: ValueKey('store-scope-${storeType.wire}'),
    overrides: [currentStoreTypeProvider.overrideWithValue(storeType)],
    child: StoreShell(storeType: storeType, navigationShell: navigationShell),
  ),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.storeCatalog(storeType.wire),
          builder: (context, state) => CatalogScreen(
            key: ValueKey(
              'catalog-${storeType.wire}-${state.uri.queryParameters['category'] ?? ''}',
            ),
            storeType: storeType,
            initialCategoryId: state.uri.queryParameters['category'],
          ),
          routes: [
            GoRoute(
              path: 'product/:productId',
              builder: (context, state) => ProductDetailScreen(
                storeType: storeType,
                productId: state.pathParameters['productId'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.storeFavorites(storeType.wire),
          builder: (context, state) => FavoritesScreen(storeType: storeType),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.storeCart(storeType.wire),
          builder: (context, state) => CartScreen(storeType: storeType),
          routes: [
            GoRoute(
              path: 'checkout',
              builder: (context, state) => CheckoutScreen(storeType: storeType),
              routes: [
                GoRoute(
                  path: 'address/new',
                  builder: (context, state) => const AddressFormScreen(),
                ),
                GoRoute(
                  path: 'address/:addressId/edit',
                  builder: (context, state) => AddressFormScreen(
                    addressId: state.pathParameters['addressId'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.storeOrders(storeType.wire),
          builder: (context, state) => OrdersScreen(storeType: storeType),
          routes: [
            GoRoute(
              path: ':orderId',
              builder: (context, state) => OrderDetailScreen(
                storeType: storeType,
                orderId: state.pathParameters['orderId'] ?? '',
                autoPay: state.uri.queryParameters['autopay'] == '1',
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

bool _requiresAuthentication(String path) {
  if (path == Routes.profile ||
      path.startsWith('${Routes.profile}/') ||
      path == Routes.notifications ||
      path == Routes.addresses ||
      path.startsWith('${Routes.addresses}/') ||
      path == Routes.requests ||
      path.startsWith('${Routes.requests}/')) {
    return true;
  }
  final segments = Uri.parse(path).pathSegments;
  if (segments.length >= 3 && segments.first == 'store') {
    final section = segments[2];
    return section == 'favorites' ||
        section == 'orders' ||
        (section == 'cart' &&
            segments.length >= 4 &&
            segments[3] == 'checkout');
  }
  return false;
}

/// Router'ni FAQAT navigatsiyaga ta'sir qiluvchi auth o'tishlarida uyg'otadi.
///
/// Auth holati boy (sendingCode/codeSent/verifying/failure...), lekin
/// navigatsiya uchun faqat 3 ta savol muhim: sessiya tekshirilyaptimi,
/// kirilganmi va OTP ekranida turish uchun telefon bormi. OTP raqami
/// terilayotganda redirect qayta ishlamaydi.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    _signature = _signatureOf(ref.read(authControllerProvider));
    _sub = ref.listen<AuthState>(authControllerProvider, (_, next) {
      final nextSignature = _signatureOf(next);
      if (nextSignature != _signature) {
        _signature = nextSignature;
        notifyListeners();
      }
    });
  }

  late final ProviderSubscription<AuthState> _sub;
  late (bool, bool, bool) _signature;

  static (bool, bool, bool) _signatureOf(AuthState state) =>
      (state.isCheckingSession, state.isAuthenticated, state.phone != null);

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
