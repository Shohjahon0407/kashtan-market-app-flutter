import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final updateNavigationGateProvider = Provider<UpdateNavigationGate>((ref) {
  final gate = UpdateNavigationGate();
  ref.onDispose(gate.dispose);
  return gate;
});
final appRootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

/// Distinct observers per navigator track sheets/dialogs in nested branches too.
class UpdateNavigationGate extends ChangeNotifier {
  final Set<Route<dynamic>> _popups = {};
  final Set<Route<dynamic>> _routes = {};
  bool _disposed = false;
  bool _notificationPending = false;
  bool get hasPopup => _popups.isNotEmpty;
  bool get transitioning => _routes.any((route) {
    if (route is! TransitionRoute) return false;
    // Auth prompts are page routes, not PopupRoutes. Their exit transition
    // remains visible even after the router has restored the previous URL.
    if (!route.isCurrent &&
        route.animation?.status != AnimationStatus.reverse) {
      return false;
    }
    if (route is ModalRoute &&
        route.subtreeContext != null &&
        !TickerMode.getValuesNotifier(route.subtreeContext!).value.enabled) {
      return false;
    }
    return route.animation?.status == AnimationStatus.forward ||
        route.animation?.status == AnimationStatus.reverse;
  });
  NavigatorObserver observer() => _UpdateObserver(this);

  void _add(Route<dynamic> route) {
    _routes.add(route);
    if (route is PopupRoute) _popups.add(route);
    // Also release routes when an entire shell/branch navigator is disposed.
    // Those routes need not produce individual didPop/didRemove events.
    if (route is TransitionRoute) {
      unawaited(route.completed.then((_) => _remove(route)));
    }
    _changed();
  }

  void _remove(Route<dynamic> route) {
    final removed = _routes.remove(route);
    _popups.remove(route);
    if (removed) _changed();
  }

  void _changed() {
    if (_disposed || _notificationPending) return;
    _notificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _routes.clear();
    _popups.clear();
    super.dispose();
  }
}

class _UpdateObserver extends NavigatorObserver {
  _UpdateObserver(this.gate);
  final UpdateNavigationGate gate;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      gate._add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Keep closing popups gated until their reverse animation finishes.
    if (route is! TransitionRoute) {
      gate._remove(route);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      gate._remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) gate._remove(oldRoute);
    if (newRoute != null) gate._add(newRoute);
  }
}
