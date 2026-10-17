import 'package:flutter/foundation.dart'
    show ChangeNotifier, ValueKey, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_update/presentation/update_navigation_gate.dart';
import '../../features/auth/domain/auth_controller.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/catalog/domain/catalog_controller.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/shashlik_family_screen.dart';
import '../../features/checkout/domain/delivery_address_selection.dart';
import '../../features/checkout/presentation/address_form_screen.dart';
import '../../features/checkout/presentation/addresses_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/checkout/presentation/delivery_address_screen.dart';
import '../../features/dev/presentation/api_playground_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/home/presentation/profile_screen.dart';
import '../../features/home/presentation/stores_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/order_map_screen.dart';
import '../../features/orders/presentation/order_summary_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/store/presentation/store_shell.dart';
import '../../features/store/presentation/unsupported_store_screen.dart';
import '../../features/support/presentation/support_center_screen.dart';
import '../../features/ugc/presentation/blocked_users_screen.dart';
import '../../features/videos/presentation/reels_screen.dart';
import '../store_scope/current_store_type_provider.dart';
import '../store_scope/store_type.dart';
import 'back_navigation.dart';
import 'route_not_found_screen.dart';
import 'routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: ref.read(appRootNavigatorKeyProvider),
    initialLocation: Routes.splash,
    observers: [
      appRouteObserver,
      ref.read(updateNavigationGateProvider).observer(),
    ],
    refreshListenable: refresh,
    // Hech qaysi route mos kelmasa (eski havola, noma'lum yo'l) go_router'ning
    // qizil xato ekrani emas, bosh sahifaga qaytaruvchi oddiy ekran.
    errorBuilder: (context, state) => BackNavigationGuard(
      child: RouteNotFoundScreen(location: state.uri.toString()),
    ),
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
      _homeShellRoute(ref.read(updateNavigationGateProvider)),
      GoRoute(
        path: Routes.search,
        builder: (context, state) =>
            const BackNavigationGuard(child: SearchScreen()),
      ),
      GoRoute(
        path: Routes.cart,
        builder: (context, state) =>
            const BackNavigationGuard(child: MainCartScreen()),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) =>
            const BackNavigationGuard(child: ProfileScreen()),
        routes: [
          GoRoute(
            path: 'blocked-users',
            builder: (context, state) => const BlockedUsersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) =>
            const BackNavigationGuard(child: NotificationsScreen()),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (context, state) =>
            const BackNavigationGuard(child: AddressesScreen()),
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
        builder: (context, state) => BackNavigationGuard(
          child: SupportCenterScreen(
            initialKind: state.uri.queryParameters['kind'],
            initialStoreType: state.uri.queryParameters['storeType'],
          ),
        ),
      ),
      GoRoute(
        path: Routes.missingProductRequest,
        builder: (context, state) => BackNavigationGuard(
          child: MissingProductRequestScreen(
            initialStoreType: state.uri.queryParameters['storeType'],
          ),
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
        builder: (context, state) => BackNavigationGuard(
          child: UnsupportedStoreScreen(
            storeTypeWire: state.uri.queryParameters['storeType'],
          ),
        ),
      ),
      for (final storeType in StoreType.values)
        _storeShellRoute(storeType, ref.read(updateNavigationGateProvider)),
      if (kDebugMode)
        GoRoute(
          path: Routes.dev,
          builder: (context, state) => const ApiPlaygroundScreen(),
        ),
    ],
  );
  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    if (previous?.isAuthenticated == true && !next.isAuthenticated) {
      AppBackCoordinator.of(router).clear();
      router.go(Routes.home);
    }
  });
  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<bool> _authPromptPage(GoRouterState state) =>
    CustomTransitionPage<bool>(
      key: state.pageKey,
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      child: BackNavigationGuard(
        child: PhoneScreen(
          returnTo: state.uri.queryParameters['returnTo'],
          isModalPrompt: state.uri.queryParameters['modal'] == '1',
        ),
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

/// Bosh sahifa qobig'i: Asosiy | Videolar | Do'konlar | Buyurtmalar.
/// Branch tartibi [HomeTab] bilan bir xil. Do'kon shell'lari bu yerga
/// KIRMAYDI — ular alohida sibling route (o'z navbar'i bilan).
StatefulShellRoute _homeShellRoute(UpdateNavigationGate gate) =>
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          observers: [gate.observer()],
          routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [gate.observer()],
          routes: [
            GoRoute(
              path: Routes.videos,
              builder: (context, state) => const ReelsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [gate.observer()],
          routes: [
            GoRoute(
              path: Routes.stores,
              builder: (context, state) => const StoresScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          observers: [gate.observer()],
          routes: [
            GoRoute(
              path: Routes.allOrders,
              builder: (context, state) => const OrdersScreen(),
            ),
          ],
        ),
      ],
    );

StatefulShellRoute _storeShellRoute(
  StoreType storeType,
  UpdateNavigationGate gate,
) => StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => ProviderScope(
    key: ValueKey('store-scope-${storeType.wire}'),
    overrides: [currentStoreTypeProvider.overrideWithValue(storeType)],
    child: StoreShell(storeType: storeType, navigationShell: navigationShell),
  ),
  branches: [
    StatefulShellBranch(
      observers: [gate.observer()],
      routes: [
        GoRoute(
          path: Routes.storeCatalog(storeType.wire),
          builder: (context, state) {
            final initialCategoryId = state.uri.queryParameters['category'];
            return ProviderScope(
              overrides: [
                catalogControllerProvider(storeType).overrideWith(
                  () => CatalogController(
                    storeType,
                    initialCategoryId: initialCategoryId,
                  ),
                ),
              ],
              child: CatalogScreen(
                key: ValueKey(
                  'catalog-${storeType.wire}-${initialCategoryId ?? ''}',
                ),
                storeType: storeType,
                initialCategoryId: initialCategoryId,
              ),
            );
          },
          routes: [
            GoRoute(
              path: 'search',
              builder: (context, state) => ProviderScope(
                overrides: [
                  catalogControllerProvider(
                    storeType,
                  ).overrideWith(() => CatalogController(storeType)),
                ],
                child: CatalogScreen(
                  key: ValueKey('catalog-${storeType.wire}-search'),
                  storeType: storeType,
                  searchOnly: true,
                ),
              ),
            ),
            GoRoute(
              path: 'category/:categoryId',
              builder: (context, state) {
                final categoryId = state.pathParameters['categoryId'] ?? '';
                return ProviderScope(
                  overrides: [
                    catalogControllerProvider(storeType).overrideWith(
                      () => CatalogController(
                        storeType,
                        initialCategoryId: categoryId,
                      ),
                    ),
                  ],
                  child: CatalogScreen(
                    key: ValueKey(
                      'catalog-${storeType.wire}-category-$categoryId',
                    ),
                    storeType: storeType,
                    initialCategoryId: categoryId,
                    initialQuery: state.uri.queryParameters['q'] ?? '',
                  ),
                );
              },
            ),
            if (storeType == StoreType.shashlik)
              GoRoute(
                path: 'family/:familyKey',
                builder: (context, state) => ShashlikFamilyScreen(
                  familyKey: state.pathParameters['familyKey'] ?? '',
                ),
              ),
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
      observers: [gate.observer()],
      routes: [
        GoRoute(
          path: Routes.storeFavorites(storeType.wire),
          builder: (context, state) => FavoritesScreen(storeType: storeType),
        ),
      ],
    ),
    StatefulShellBranch(
      observers: [gate.observer()],
      routes: [
        GoRoute(
          path: Routes.storeCart(storeType.wire),
          builder: (context, state) => CartScreen(
            storeType: storeType,
            initialFocus: state.uri.queryParameters['focus'],
          ),
          routes: [
            GoRoute(
              path: 'address/select',
              builder: (context, state) => DeliveryAddressScreen(
                storeType: storeType,
                selectionRoute: Routes.cartDeliveryAddressSelect(
                  storeType.wire,
                ),
                arguments: state.extra is DeliveryAddressArguments
                    ? state.extra as DeliveryAddressArguments
                    : null,
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => AddressFormScreen(
                    storeType: storeType,
                    saveForSelection: true,
                  ),
                ),
                GoRoute(
                  path: ':addressId/edit',
                  builder: (context, state) => AddressFormScreen(
                    storeType: storeType,
                    addressId: state.pathParameters['addressId'],
                    saveForSelection: true,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'checkout',
              builder: (context, state) => CheckoutScreen(storeType: storeType),
              routes: [
                GoRoute(
                  path: 'address/select',
                  builder: (context, state) => DeliveryAddressScreen(
                    storeType: storeType,
                    arguments: state.extra is DeliveryAddressArguments
                        ? state.extra as DeliveryAddressArguments
                        : null,
                  ),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => AddressFormScreen(
                        storeType: storeType,
                        saveForSelection: true,
                      ),
                    ),
                    GoRoute(
                      path: ':addressId/edit',
                      builder: (context, state) => AddressFormScreen(
                        storeType: storeType,
                        addressId: state.pathParameters['addressId'],
                        saveForSelection: true,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'address/new',
                  builder: (context, state) =>
                      AddressFormScreen(storeType: storeType),
                ),
                GoRoute(
                  path: 'address/:addressId/edit',
                  builder: (context, state) => AddressFormScreen(
                    storeType: storeType,
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
      observers: [gate.observer()],
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
              routes: [
                GoRoute(
                  path: 'map',
                  builder: (context, state) => OrderMapScreen(
                    storeType: storeType,
                    orderId: state.pathParameters['orderId'] ?? '',
                  ),
                ),
                GoRoute(
                  path: 'details',
                  builder: (context, state) => OrderSummaryScreen(
                    storeType: storeType,
                    orderId: state.pathParameters['orderId'] ?? '',
                  ),
                ),
              ],
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
      path == Routes.allOrders ||
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
            (segments[3] == 'checkout' || segments[3] == 'address'));
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
