import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../store_scope/store_type.dart';
import 'routes.dart';

/// Store shell ichidagi to'rtta asosiy branch.
///
/// Branchlar orasida `push` ishlatilsa yangi sahifa joriy
/// branch navigatorining ustiga qo'yiladi. Natijada, masalan, Savat ochiq
/// turgan bo'lsa ham navbar Mahsulotlarni active ko'rsatishi mumkin. Shu
/// helper tablararo o'tishlarni har doim deklarativ `go` bilan bajaradi.
enum StoreTab { catalog, favorites, cart, orders }

String storeTabLocation(StoreType storeType, StoreTab tab) => switch (tab) {
  StoreTab.catalog => Routes.storeCatalog(storeType.wire),
  StoreTab.favorites => Routes.storeFavorites(storeType.wire),
  StoreTab.cart => Routes.storeCart(storeType.wire),
  StoreTab.orders => Routes.storeOrders(storeType.wire),
};

void goToStoreTab(BuildContext context, StoreType storeType, StoreTab tab) {
  context.go(storeTabLocation(storeType, tab));
}

/// Product ayni catalog branchida ochilsa oddiy back stack saqlanadi.
/// Boshqa store branchidan ochilsa avval catalog branchi active qilinadi.
/// Store shell tashqarisidan (Home, global search, Reels) kirilganda esa
/// caller ekranga qaytish uchun odatdagi push ishlatiladi.
void openStoreProduct(
  BuildContext context,
  StoreType storeType,
  String productId,
) {
  final currentPath = GoRouterState.of(context).uri.path;
  final storeRoot = Routes.storeRoot(storeType.wire);
  final catalogRoot = Routes.storeCatalog(storeType.wire);
  final target = Routes.productDetail(storeType.wire, productId);

  if (currentPath == catalogRoot || currentPath.startsWith('$catalogRoot/')) {
    context.push(target);
  } else if (currentPath == storeRoot ||
      currentPath.startsWith('$storeRoot/')) {
    context.go(target);
  } else {
    context.push(target);
  }
}
