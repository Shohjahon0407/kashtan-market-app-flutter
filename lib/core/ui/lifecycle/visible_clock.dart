import 'dart:async';

import 'package:flutter/material.dart';

import '../../routing/routes.dart';

/// 1 Hz `setState` soati FAQAT ekran ko'rinib turganda ishlaydi: ilova
/// fonda (paused/hidden) yoki ustiga boshqa route push qilinganda to'xtaydi,
/// qaytganda yana yuradi. Aks holda yopiq ekran ostida xarita har soniya
/// qayta chizilib, batareya ketardi.
///
/// Foydalanish: `with WidgetsBindingObserver, RouteAware, VisibleClock` va
/// [onVisibleTick] ni override qilish.
mixin VisibleClock<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver, RouteAware {
  Timer? _visibleClock;
  bool _routeCovered = false;
  bool _appPaused = false;
  ModalRoute<Object?>? _subscribedRoute;

  Duration get visibleClockPeriod => const Duration(seconds: 1);

  /// Har tikda chaqiriladi (widget mounted bo'lganda).
  void onVisibleTick();

  @visibleForTesting
  bool get isVisibleClockRunning => _visibleClock != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (identical(route, _subscribedRoute)) return;
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _visibleClock?.cancel();
    _visibleClock = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused = state != AppLifecycleState.resumed;
    _syncClock();
  }

  @override
  void didPushNext() {
    _routeCovered = true;
    _syncClock();
  }

  @override
  void didPopNext() {
    _routeCovered = false;
    _syncClock();
  }

  void _syncClock() {
    if (_appPaused || _routeCovered) {
      _visibleClock?.cancel();
      _visibleClock = null;
    } else if (_visibleClock == null) {
      _startClock();
    }
  }

  void _startClock() {
    _visibleClock = Timer.periodic(visibleClockPeriod, (_) {
      if (mounted) onVisibleTick();
    });
  }
}
