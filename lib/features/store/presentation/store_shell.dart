import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../cart/domain/cart_controller.dart';
import '../../orders/domain/order_realtime_controller.dart';

class StoreShell extends ConsumerWidget {
  const StoreShell({
    required this.storeType,
    required this.navigationShell,
    super.key,
  });

  final StoreType storeType;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(
      authControllerProvider.select((auth) => auth.isAuthenticated),
    )) {
      // Faqat tirik ushlab turish — har WS pong'da shell + NavigationBar
      // qayta qurilmasin.
      ref.listen(orderRealtimeProvider, (_, _) {});
    }
    final l10n = AppLocalizations.of(context);
    final cartQuantity =
        ref
            .watch(cartControllerProvider(storeType))
            .value
            ?.cart
            .totalQuantity ??
        0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) async {
          final protected = index == 1 || index == 3;
          if (protected && !await requireAuthentication(context, ref)) {
            return;
          }
          if (!context.mounted) return;
          goToStoreTab(context, storeType, StoreTab.values[index]);
        },
        destinations: [
          NavigationDestination(
            key: const ValueKey('store-nav-catalog'),
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: l10n.navProducts,
          ),
          NavigationDestination(
            key: const ValueKey('store-nav-favorites'),
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: l10n.navFavorites,
          ),
          NavigationDestination(
            key: const ValueKey('store-nav-cart'),
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text(cartQuantity > 99 ? '99+' : '$cartQuantity'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text(cartQuantity > 99 ? '99+' : '$cartQuantity'),
              child: const Icon(Icons.shopping_bag),
            ),
            label: l10n.navCart,
          ),
          NavigationDestination(
            key: const ValueKey('store-nav-orders'),
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n.navOrders,
          ),
        ],
      ),
    );
  }
}
