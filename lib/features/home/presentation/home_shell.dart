import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../orders/domain/orders_controller.dart';
import '../domain/home_tab_controller.dart';

/// Bosh sahifa qobig'i: Asosiy | Videolar | Do'konlar | Buyurtmalar.
///
/// `StoreShell` naqshi: `NavigationBar`, himoyalangan tab (Buyurtmalar)
/// bosilganda avval `requireAuthentication`. Tab holati (scroll joyi, reels
/// sahifasi) `indexedStack` tufayli saqlanadi.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int? _publishedIndex;

  void _publishTab(int index) {
    if (_publishedIndex == index) return;
    _publishedIndex = index;
    ref.read(homeTabProvider.notifier).set(HomeTab.values[index]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = widget.navigationShell;
    final index = shell.currentIndex;
    // Deep link / tizim "orqa" tugmasi orqali ham branch almashishi mumkin —
    // build paytida provider o'zgartirib bo'lmaydi, kadrdan keyin.
    if (_publishedIndex != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publishTab(shell.currentIndex);
      });
    }
    final activeOrders = ref.watch(activeOrdersCountProvider);
    return PopScope(
      // Boshqa tabda "orqa" — Asosiy'ga; Asosiy'da — odatdagidek chiqish.
      canPop: index == HomeTab.home.index,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _switchTo(HomeTab.home.index);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (target) async {
            if (target == HomeTab.orders.index &&
                !await requireAuthentication(context, ref)) {
              return;
            }
            if (!context.mounted) return;
            _switchTo(target);
          },
          destinations: [
            NavigationDestination(
              key: const ValueKey('home-nav-home'),
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(
              key: const ValueKey('home-nav-videos'),
              icon: const Icon(Icons.play_circle_outline),
              selectedIcon: const Icon(Icons.play_circle),
              label: l10n.navVideos,
            ),
            NavigationDestination(
              key: const ValueKey('home-nav-stores'),
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: l10n.homeStoresTitle,
            ),
            NavigationDestination(
              key: const ValueKey('home-nav-orders'),
              icon: _OrdersIcon(count: activeOrders, selected: false),
              selectedIcon: _OrdersIcon(count: activeOrders, selected: true),
              label: l10n.navOrders,
            ),
          ],
        ),
      ),
    );
  }

  void _switchTo(int target) {
    // Provider darhol yangilanadi — Asosiy'dagi video tab almashishi bilanoq
    // to'xtaydi (branch o'zi bir kadr kechikishi mumkin).
    _publishTab(target);
    widget.navigationShell.goBranch(
      target,
      // Faol tabni qayta bosish — branch boshiga (StoreShell'dagi kabi).
      initialLocation: target == widget.navigationShell.currentIndex,
    );
  }
}

class _OrdersIcon extends StatelessWidget {
  const _OrdersIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) => Badge(
    key: ValueKey('home-nav-orders-badge-$count'),
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    child: Icon(selected ? Icons.receipt_long : Icons.receipt_long_outlined),
  );
}
