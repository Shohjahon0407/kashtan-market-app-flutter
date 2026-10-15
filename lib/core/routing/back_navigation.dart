import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

Uri _visibleUri(RouteMatchList snapshot) {
  if (snapshot.isEmpty) return snapshot.uri;
  final last = snapshot.last;
  return last is ImperativeRouteMatch ? last.matches.uri : snapshot.uri;
}

/// Session-only history for declarative tab changes. Snapshots also retain
/// the caller's nested stack when a store tab replaces an imperative push.
class AppBackCoordinator {
  AppBackCoordinator(this.router);

  static final _instances = Expando<AppBackCoordinator>();
  static AppBackCoordinator of(GoRouter router) =>
      _instances[router] ??= AppBackCoordinator(router);

  final GoRouter router;
  final List<RouteMatchList> _history = [];
  bool _busy = false;
  bool _restoring = false;

  /// Only active navigators, innermost first. A branch's first page can
  /// consume maybePop through PopScope without actually popping anything;
  /// it must not prevent the enclosing store shell from returning Home.
  Iterable<NavigatorState> get activeNavigators {
    final states = <NavigatorState>[];
    final root = router.routerDelegate.navigatorKey.currentState;
    if (root != null) states.add(root);
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return states.reversed;
    RouteMatchBase match = configuration.matches.last;
    while (match is ShellRouteMatch) {
      final navigator = match.navigatorKey.currentState;
      if (navigator == null) break;
      final enclosing = ModalRoute.of(navigator.context);
      // A dialog above the shell is handled by the enclosing navigator first.
      if (enclosing != null && !enclosing.isCurrent) break;
      states.add(navigator);
      match = match.matches.last;
    }
    return states.reversed;
  }

  bool hasInnerStack(NavigatorState? enclosing) => activeNavigators
      .takeWhile((navigator) => navigator != enclosing)
      .any((navigator) => navigator.canPop());

  String get location =>
      _visibleUri(router.routerDelegate.currentConfiguration).toString();

  void remember() {
    final snapshot = router.routerDelegate.currentConfiguration;
    if (snapshot.isEmpty || snapshot.isError) return;
    final path = _visibleUri(snapshot).path;
    if (path == Routes.splash || Routes.authEntry.contains(path)) return;
    if (_history.isEmpty ||
        _visibleUri(_history.last) != _visibleUri(snapshot)) {
      _history.add(snapshot);
    }
  }

  void go(String target) {
    if (target == location) return;

    final destination = Uri.parse(target);
    // Selecting a tab that is already in the return path closes the tab
    // excursion. Recording the departing tab here would create a loop:
    // Home -> catalog -> cart -> catalog -> back -> cart.
    // Restore the snapshot (not just its URL) to retain the original caller
    // below an imperatively pushed store shell.
    final current = _snapshotAt(
      router.routerDelegate.currentConfiguration,
      destination,
    );
    if (current != null) {
      router.restore(current);
      return;
    }
    for (var index = _history.length - 1; index >= 0; index--) {
      final previous = _snapshotAt(_history[index], destination);
      if (previous == null) continue;
      _history.removeRange(index, _history.length);
      router.restore(previous);
      return;
    }
    remember();
    router.go(target);
  }

  /// Also recognize a tab root below a pushed detail/category page. Returning
  /// through the navbar still resets that tab to its root, without remembering
  /// the discarded detail page or losing the store's caller.
  RouteMatchList? _snapshotAt(RouteMatchList snapshot, Uri destination) {
    var candidate = snapshot;
    while (candidate.isNotEmpty && !candidate.isError) {
      if (_visibleUri(candidate) == destination) return candidate;
      candidate = candidate.remove(candidate.last);
    }
    return null;
  }

  void clear() => _history.clear();

  void discardCheckout() {
    _history.removeWhere(
      (snapshot) => _visibleUri(snapshot).path.contains('/cart/checkout'),
    );
  }

  /// Native pop is tried first so dialogs, sheets and nested pages keep their
  /// normal result/PopScope semantics. Only an unhandled pop uses tab history.
  Future<bool> back() async {
    if (_busy) return true;
    _busy = true;
    try {
      for (final navigator in activeNavigators) {
        if (!navigator.canPop()) continue;
        // Preserve intentional modal/form vetoes. Only non-poppable branch
        // roots are skipped, never a dialog or a real detail route.
        if (await navigator.maybePop()) return true;
      }
      return fallback();
    } finally {
      // Keep duplicate back events in the same frame from racing a restore.
      WidgetsBinding.instance.addPostFrameCallback((_) => _busy = false);
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  bool fallback() {
    if (_restoring) return true;
    final current = _visibleUri(router.routerDelegate.currentConfiguration);
    if (current.path == Routes.home) {
      clear();
      return false;
    }
    _restoring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoring = false);
    WidgetsBinding.instance.ensureVisualUpdate();
    while (_history.isNotEmpty) {
      final previous = _history.removeLast();
      if (_visibleUri(previous) == current) continue;
      router.restore(previous);
      return true;
    }
    router.go(Routes.home);
    return true;
  }
}

void appBack(BuildContext context) {
  unawaited(AppBackCoordinator.of(GoRouter.of(context)).back());
}

class AppBackButtonDispatcher extends RootBackButtonDispatcher {
  AppBackButtonDispatcher(this.coordinator);
  final AppBackCoordinator coordinator;

  @override
  Future<bool> didPopRoute() => coordinator.back();
}

/// Register the fallback with the enclosing Navigator too, allowing Android
/// predictive back to see that a non-Home root must not exit the application.
class BackNavigationGuard extends StatefulWidget {
  const BackNavigationGuard({required this.child, super.key});
  final Widget child;

  @override
  State<BackNavigationGuard> createState() => _BackNavigationGuardState();
}

class _BackNavigationGuardState extends State<BackNavigationGuard> {
  final _stackRevision = ValueNotifier<int>(0);
  bool _scheduled = false;

  @override
  void dispose() {
    _stackRevision.dispose();
    super.dispose();
  }

  bool _stackChanged(NavigationNotification notification) {
    // Router notifications precede the nested Navigator's page update. Read
    // its actual stack again after that update, rather than keeping a stale
    // canPop veto after category -> cart -> catalog tab-root restoration.
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _stackRevision.value++;
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return NotificationListener<NavigationNotification>(
      onNotification: _stackChanged,
      child: AnimatedBuilder(
        animation: Listenable.merge([router.routerDelegate, _stackRevision]),
        builder: (context, _) {
          final coordinator = AppBackCoordinator.of(router);
          final enclosing = Navigator.maybeOf(context);
          final route = ModalRoute.of(context);
          final innerStack = coordinator.hasInnerStack(enclosing);
          return PopScope(
            // Android predictive back talks to the enclosing navigator directly.
            // Intercept it when a nested branch must pop instead of the shell.
            canPop:
                route?.isCurrent == false ||
                (!innerStack &&
                    ((enclosing?.canPop() ?? false) ||
                        Uri.parse(coordinator.location).path == Routes.home)),
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                // Calling back() here would retry this guard recursively. When
                // the enclosing route has a stack, this veto is specifically
                // redirecting predictive back to a deeper navigator.
                if (innerStack) {
                  unawaited(coordinator.back());
                } else {
                  coordinator.fallback();
                }
              }
            },
            child: widget.child,
          );
        },
      ),
    );
  }
}
