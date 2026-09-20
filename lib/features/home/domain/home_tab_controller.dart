import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/routes.dart';

/// Home shell'ning joriy tabi.
///
/// `StatefulShellRoute` branch almashganda ichki ekranlarga `RouteAware`
/// xabari (`didPushNext`) BORMAYDI — Asosiy'dagi reel Videolar tabiga
/// o'tilganda ham o'ynayverardi. Video ekranlar shu provider'dan "men
/// ko'rinyapmanmi"ni biladi. Standart — [HomeTab.home] (shell'siz mount
/// qilingan HomeScreen, masalan testlarda, doim ko'rinadigan hisoblanadi).
final homeTabProvider = NotifierProvider<HomeTabController, HomeTab>(
  HomeTabController.new,
);

class HomeTabController extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.home;

  void set(HomeTab tab) => state = tab;
}
