import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../auth/domain/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../orders/domain/orders_controller.dart';
import '../data/notification_models.dart';
import '../domain/customer_push_service.dart';
import '../domain/notifications_controller.dart';

/// Root lifecycle bridge for FCM registration, foreground banners and taps.
///
/// Place this below `MaterialApp` (for example in `MaterialApp.builder`) so it
/// can use the app's ScaffoldMessenger and GoRouter. It has no visible UI.
class CustomerNotificationBootstrap extends ConsumerStatefulWidget {
  const CustomerNotificationBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerNotificationBootstrap> createState() =>
      _CustomerNotificationBootstrapState();
}

class _CustomerNotificationBootstrapState
    extends ConsumerState<CustomerNotificationBootstrap>
    with WidgetsBindingObserver {
  StreamSubscription<CustomerPushMessage>? _foregroundSubscription;
  StreamSubscription<CustomerPushMessage>? _navigationSubscription;
  ProviderSubscription<AuthState>? _authSubscription;
  ProviderSubscription<Object?>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = ref.listenManual<AuthState>(authControllerProvider, (
      previous,
      next,
    ) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        unawaited(_start());
      } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        // Explicit logout hook token o'chishidan oldin shu amalni bajaradi.
        // Refresh 401/session-expired holatida esa bu listener local FCM
        // tokenini baribir bekor qiladi; backend DELETE best-effort.
        unawaited(ref.read(customerPushServiceProvider).unregister());
      }
    });
    _localeSubscription = ref.listenManual<Object?>(localeControllerProvider, (
      previous,
      next,
    ) {
      if (ref.read(authControllerProvider).isAuthenticated) {
        unawaited(ref.read(customerPushServiceProvider).syncRegistration());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authControllerProvider).isAuthenticated) {
        unawaited(_start());
      } else {
        unawaited(
          ref
              .read(customerPushServiceProvider)
              .retryPendingUnregister(canUseBackend: false),
        );
      }
    });
  }

  Future<void> _start() async {
    final service = ref.read(customerPushServiceProvider);
    _foregroundSubscription ??= service.foregroundMessages.listen(
      _handleForeground,
    );
    _navigationSubscription ??= service.navigationRequests.listen(_openMessage);
    await service.start();
  }

  void _handleForeground(CustomerPushMessage message) {
    ref.invalidate(notificationsControllerProvider);
    ref.read(notificationUnreadCountProvider.notifier).refresh();
    final storeType = StoreType.fromWire(message.storeTypeWire ?? '');
    if (storeType != null) {
      for (final query in orderQueriesForStore(storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
    }
    final orderId = message.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      ref.invalidate(orderDetailProvider(orderId));
      ref.invalidate(orderTrackingControllerProvider(orderId));
    }
    if (!mounted || _isCurrentOrder(message)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.title.isNotEmpty)
                Text(
                  message.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              if (message.body.isNotEmpty) Text(message.body),
            ],
          ),
          action: message.hasOrderTarget
              ? SnackBarAction(
                  label: l10n.notificationOpen,
                  onPressed: () => _openMessage(message),
                )
              : null,
        ),
      );
  }

  bool _isCurrentOrder(CustomerPushMessage message) {
    if (!message.hasOrderTarget) return false;
    final path = ref
        .read(appRouterProvider)
        .routeInformationProvider
        .value
        .uri
        .path;
    if (message.opensOrder) {
      return path ==
          Routes.orderDetail(message.storeTypeWire!, message.orderId!);
    }
    final segments = Uri.parse(path).pathSegments;
    return segments.length >= 2 &&
        segments[segments.length - 2] == 'orders' &&
        segments.last == message.orderId;
  }

  void _openMessage(CustomerPushMessage message) {
    unawaited(_openMessageAsync(message));
  }

  Future<void> _openMessageAsync(CustomerPushMessage message) async {
    if (!mounted || !message.hasOrderTarget) return;
    var storeType = StoreType.fromWire(message.storeTypeWire ?? '');
    if (storeType == null) {
      try {
        final order = await ref
            .read(ordersApiProvider)
            .detail(message.orderId!);
        storeType = StoreType.fromWire(order.storeTypeWire);
      } on Object {
        return;
      }
    }
    if (!mounted || storeType == null) return;
    final target = Routes.orderDetail(storeType.wire, message.orderId!);
    final router = ref.read(appRouterProvider);
    if (router.routeInformationProvider.value.uri.path != target) {
      await router.push(target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    final service = ref.read(customerPushServiceProvider);
    if (!ref.read(authControllerProvider).isAuthenticated) {
      await service.retryPendingUnregister(canUseBackend: false);
      return;
    }
    ref.invalidate(notificationsControllerProvider);
    await ref.read(notificationUnreadCountProvider.notifier).refresh();
    await service.start();
    await service.retryPendingUnregister(canUseBackend: true);
    await service.syncRegistration();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSubscription?.cancel();
    _navigationSubscription?.cancel();
    _authSubscription?.close();
    _localeSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
