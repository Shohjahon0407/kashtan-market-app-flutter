import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../splash/presentation/startup_intro.dart';
import '../domain/app_update_service.dart';
import 'app_update_dialog.dart';
import 'update_navigation_gate.dart';

bool isSafeUpdateLocation(String path) =>
    path == Routes.home ||
    path == Routes.stores ||
    RegExp(r'^/store/[^/]+/catalog$').hasMatch(path);

/// Never blocks startup. Waits for intro, foreground and a non-form route.
class AppUpdateBootstrap extends ConsumerStatefulWidget {
  const AppUpdateBootstrap({
    required this.isAppReady,
    required this.child,
    super.key,
  });
  final bool isAppReady;
  final Widget child;
  @override
  ConsumerState<AppUpdateBootstrap> createState() => _AppUpdateBootstrapState();
}

class _AppUpdateBootstrapState extends ConsumerState<AppUpdateBootstrap>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  late final UpdateNavigationGate _gate;
  AndroidAppRelease? _pending;
  bool _introFinished = false;
  bool _handled = false;
  Timer? _settleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = ref.read(appRouterProvider);
    _gate = ref.read(updateNavigationGateProvider);
    _router.routerDelegate.addListener(_schedule);
    _gate.addListener(_schedule);
    unawaited(_check());
  }

  Future<void> _check() async {
    final release = await ref.read(appUpdateServiceProvider).check();
    if (!mounted) return;
    _pending = release;
    _schedule();
  }

  void _schedule() {
    if (!mounted || _handled || _pending == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryShow());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _tryShow() {
    if (!mounted ||
        _handled ||
        _pending == null ||
        !_introFinished ||
        !widget.isAppReady ||
        _gate.hasPopup) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final location = Uri.parse(AppBackCoordinator.of(_router).location);
    if (!isSafeUpdateLocation(location.path)) return;
    if (_gate.transitioning) {
      _settleTimer ??= Timer(const Duration(milliseconds: 350), () {
        _settleTimer = null;
        _schedule();
      });
      return;
    }
    final navigator = ref.read(appRootNavigatorKeyProvider).currentState;
    final dialogContext = navigator?.overlay?.context;
    if (dialogContext == null) return;
    // A late response must not interrupt typing in a catalog search field.
    if (MediaQuery.viewInsetsOf(dialogContext).bottom > 0) return;
    _handled = true;
    unawaited(
      showDialog<void>(
        context: dialogContext,
        useRootNavigator: true,
        builder: (_) => AppUpdateDialog(release: _pending!),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant AppUpdateBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void didChangeMetrics() => _schedule();

  @override
  void dispose() {
    _settleTimer?.cancel();
    _gate.removeListener(_schedule);
    _router.routerDelegate.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StartupIntro(
    isAppReady: widget.isAppReady,
    onFinished: () {
      _introFinished = true;
      _schedule();
    },
    child: widget.child,
  );
}
