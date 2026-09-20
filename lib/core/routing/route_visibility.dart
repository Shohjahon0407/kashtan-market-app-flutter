import 'package:flutter/widgets.dart';

/// Ekran ustiga boshqa sahifa chiqqanini bilish — ichki (`StatefulShellRoute`
/// branch) navigator'lar uchun.
///
/// `GoRouter.observers` faqat ROOT navigator'ga ulanadi. Shell ichidagi ekran
/// `ModalRoute.of(context)` bilan o'z branch route'iga obuna bo'lsa, root'ga
/// push qilingan sahifa (mahsulot, profil, savat...) haqida `didPushNext`
/// hech qachon kelmaydi — video ostida o'ynayveradi. Shuning uchun tashqi
/// (root) route'ga ham obuna bo'linadi va "joriy"lik butun zanjir bo'ylab
/// tekshiriladi.
List<ModalRoute<Object?>> enclosingRoutesOf(BuildContext context) {
  final routes = <ModalRoute<Object?>>[];
  var current = context;
  while (true) {
    final route = ModalRoute.of(current);
    if (route == null) break;
    routes.add(route);
    // `Navigator.maybeOf` navigator'ning O'Z context'ida o'zini qaytaradi
    // (cheksiz sikl) — shuning uchun ota elementlardan qidiriladi.
    final navigator = current.findAncestorStateOfType<NavigatorState>();
    if (navigator == null) break;
    // Navigator'ning o'z context'idan yuqoriga — uni o'rab turgan route.
    current = navigator.context;
  }
  return routes;
}

/// Ichkaridan tashqarigacha barcha route'lar joriy bo'lsa `true`.
bool isRouteStackCurrent(BuildContext context) =>
    enclosingRoutesOf(context).every((route) => route.isCurrent);

/// [subscriber]ni zanjirdagi har bir route'ga obuna qiladi.
void subscribeToEnclosingRoutes(
  RouteObserver<ModalRoute<Object?>> observer,
  RouteAware subscriber,
  BuildContext context,
) {
  for (final route in enclosingRoutesOf(context)) {
    observer.subscribe(subscriber, route);
  }
}
