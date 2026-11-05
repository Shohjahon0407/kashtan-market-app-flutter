import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/presentation/widgets/catalog_loading_skeleton.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/order_models.dart';
import '../domain/order_live_controller.dart';
import '../domain/orders_controller.dart';
import 'order_map_screen.dart';
import 'order_view.dart';
import 'widgets/order_tracking_map.dart';
import 'widgets/order_tracking_panel.dart';

/// Buyurtma kuzatuvi (Uzum Tezkor uslubi): tepada jonli xarita, pastda
/// tortiladigan panel — vaqt oynasi, 4 bosqich, kuryer, tafsilotlar.
/// Xaritasiz (pickup / koordinatasiz) buyurtmada oddiy ro'yxat.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    required this.storeType,
    required this.orderId,
    this.autoPay = false,
    super.key,
  });

  final StoreType storeType;
  final String orderId;

  /// Checkout'da Payme tanlangan — to'lov bir marta avtomatik boshlanadi.
  final bool autoPay;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _mutating = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // REST detail yangilanganda WS yamog'i tozalanadi (REST — haqiqat
    // manbai; yamoq faqat oraliqni yopadi).
    ref.listen(orderDetailProvider(widget.orderId), (previous, next) {
      if (next is AsyncData<OrderData> && !next.isLoading) {
        ref.read(orderLiveProvider(widget.orderId).notifier).clearPatch();
      }
    });
    final view = watchOrderView(ref, widget.orderId);
    return switch (view) {
      AsyncData(:final value)
          when value.storeTypeWire != widget.storeType.wire =>
        Scaffold(
          appBar: AppBar(title: Text(l10n.ordersTitle)),
          body: StoreEmptyView(
            icon: Icons.warning_amber_rounded,
            title: l10n.unsupportedStoreMessage,
          ),
        ),
      AsyncData(:final value) when orderHasMap(value) => _MapLayout(
        order: value,
        autoPay: widget.autoPay,
        mutating: _mutating,
        onCancel: () => _cancel(value),
        onOpenSummary: _openSummary,
        onOpenMap: _openMap,
        onHelp: _openHelp,
      ),
      AsyncData(:final value) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.ordersTitle),
          actions: [
            IconButton(
              key: const ValueKey('order-help'),
              tooltip: l10n.orderHelp,
              onPressed: _openHelp,
              icon: const Icon(Icons.headset_mic_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: OrderTrackingPanel(
            order: value,
            autoPay: widget.autoPay,
            mutating: _mutating,
            onCancel: () => _cancel(value),
            onOpenSummary: _openSummary,
            physics: const AlwaysScrollableScrollPhysics(),
          ),
        ),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: Text(l10n.ordersTitle)),
        body: StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.ordersTitle)),
        body: const CatalogRowsSkeleton(itemCount: 4),
      ),
    };
  }

  void _openSummary() =>
      context.push(Routes.orderSummary(widget.storeType.wire, widget.orderId));

  void _openMap() =>
      context.push(Routes.orderMap(widget.storeType.wire, widget.orderId));

  void _openHelp() =>
      pushAuthenticated(context, ref, Routes.requestsFor(kind: 'support'));

  Future<void> _refresh() async {
    ref.invalidate(orderDetailProvider(widget.orderId));
    await Future.wait([
      ref.read(orderDetailProvider(widget.orderId).future),
      ref
          .read(orderTrackingControllerProvider(widget.orderId).notifier)
          .refresh(),
    ]);
  }

  Future<void> _cancel(OrderData order) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.orderCancel),
        content: Text(l10n.orderCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonNo),
          ),
          FilledButton(
            style: AppButtons.dialogAction,
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonYes),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mutate(() => ref.read(ordersApiProvider).cancel(order.id));
  }

  Future<void> _mutate(Future<OrderData> Function() operation) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderTrackingControllerProvider(widget.orderId));
      for (final query in orderQueriesAffectedBy(widget.storeType)) {
        ref.invalidate(ordersControllerProvider(query));
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      // A courier may have picked up the order while confirmation was open.
      // Refresh capabilities even when the mutation is rejected by the server.
      ref.invalidate(orderDetailProvider(widget.orderId));
      await ref
          .read(orderTrackingControllerProvider(widget.orderId).notifier)
          .refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.localize(AppLocalizations.of(context))),
          ),
        );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
}

/// Xarita + tortiladigan panel.
class _MapLayout extends StatelessWidget {
  const _MapLayout({
    required this.order,
    required this.autoPay,
    required this.mutating,
    required this.onCancel,
    required this.onOpenSummary,
    required this.onOpenMap,
    required this.onHelp,
  });

  final OrderData order;
  final bool autoPay;
  final bool mutating;
  final VoidCallback onCancel;
  final VoidCallback onOpenSummary;
  final VoidCallback onOpenMap;
  final VoidCallback onHelp;

  static const initialSheet = .56;
  static const minSheet = .42;
  static const maxSheet = .96;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Xarita panel ostida ham davom etadi — panel tortilganda bo'sh
          // joy ko'rinmaydi. Markerlar panel ustidagi qismga sig'adi.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height * (1 - minSheet) + 24,
            child: OrderTrackingMap(
              key: const ValueKey('order-map'),
              home: LatLng(order.address!.latitude!, order.address!.longitude!),
              store: order.pickupBranch?.hasCoordinates ?? false
                  ? LatLng(
                      order.pickupBranch!.latitude!,
                      order.pickupBranch!.longitude!,
                    )
                  : null,
              courier: order.courierLocation,
              phase: order.courierPhase,
              vehicleType: order.courierVehicleType,
              serverDeadline: order.deliveryDeadlineAt,
              onTap: onOpenMap,
              chipOffset: EdgeInsets.only(top: top + 60, left: AppSpacing.lg),
              fitPadding: EdgeInsets.fromLTRB(
                56,
                top + 110,
                56,
                // Panel boshlang'ich balandligi xaritaning pastini yopadi.
                height * (initialSheet - minSheet) + 72,
              ),
            ),
          ),
          Positioned(
            top: top,
            left: AppSpacing.md,
            child: MapRoundButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: top,
            right: AppSpacing.md,
            child: MapHelpPill(label: l10n.orderHelp, onPressed: onHelp),
          ),
          DraggableScrollableSheet(
            initialChildSize: initialSheet,
            minChildSize: minSheet,
            maxChildSize: maxSheet,
            snap: true,
            snapSizes: const [initialSheet, maxSheet],
            builder: (context, controller) => DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, -6),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
                child: OrderTrackingPanel(
                  order: order,
                  autoPay: autoPay,
                  mutating: mutating,
                  onCancel: onCancel,
                  onOpenSummary: onOpenSummary,
                  scrollController: controller,
                  withHandle: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
