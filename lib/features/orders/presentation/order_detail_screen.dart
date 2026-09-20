import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_buttons.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../payments/presentation/payme_payment_section.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/order_models.dart';
import '../domain/order_realtime_controller.dart';
import '../domain/orders_controller.dart';
import 'widgets/order_delivery_status.dart';
import 'widgets/order_status_badge.dart';

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
    // Faqat SHU buyurtma hodisalarida qayta qurish — har WS pong/kuryer
    // lokatsiya kadrida butun ekran (xarita bilan) rebuild bo'lmasin.
    ref.watch(
      orderRealtimeProvider.select(
        (value) => value.lastOrderId == widget.orderId ? value.revision : 0,
      ),
    );
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(orderDetailProvider(widget.orderId));
    final tracking = ref.watch(orderTrackingControllerProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersTitle)),
      body: switch (detail) {
        AsyncData(:final value)
            when value.storeTypeWire != widget.storeType.wire =>
          StoreEmptyView(
            icon: Icons.warning_amber_rounded,
            title: l10n.unsupportedStoreMessage,
          ),
        AsyncData(:final value) => _OrderBody(
          order: tracking.value == null
              ? value
              : value.withTracking(tracking.value!),
          courierLocation: tracking.value?.courierLocation,
          autoPay: widget.autoPay,
          mutating: _mutating,
          onCancel: () => _cancel(value),
          onRefresh: () async {
            ref.invalidate(orderDetailProvider(widget.orderId));
            await Future.wait([
              ref.read(orderDetailProvider(widget.orderId).future),
              ref
                  .read(
                    orderTrackingControllerProvider(widget.orderId).notifier,
                  )
                  .refresh(),
            ]);
          },
        ),
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
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

class _OrderBody extends StatelessWidget {
  const _OrderBody({
    required this.order,
    required this.mutating,
    required this.onCancel,
    required this.onRefresh,
    this.autoPay = false,
    this.courierLocation,
  });

  final OrderData order;
  final bool autoPay;
  final bool mutating;
  final VoidCallback onCancel;
  final Future<void> Function() onRefresh;
  final CourierLocation? courierLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenH),
        children: [
          if (order.isDelivery)
            OrderDeliveryStatus(order: order, location: courierLocation)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: OrderStatusBadge(stage: order.customerStage),
            ),
          const SizedBox(height: AppSpacing.xxl),
          _Section(title: l10n.orderItems),
          const SizedBox(height: AppSpacing.sm),
          for (final item in order.items) _OrderItemTile(item: item),
          const SizedBox(height: AppSpacing.lg),
          _PriceRow(label: l10n.cartSubtotal, value: order.subtotal),
          if (_hasPositiveValue(order.deliveryFee))
            _PriceRow(label: l10n.cartDeliveryFee, value: order.deliveryFee),
          const Divider(),
          _PriceRow(
            label: l10n.cartTotal,
            value: order.total,
            emphasized: true,
          ),
          if (order.status != 'cancelled') ...[
            const SizedBox(height: AppSpacing.xxl),
            PaymePaymentSection(order: order, autoStart: autoPay),
          ],
          if (order.address != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: l10n.orderAddress),
            const SizedBox(height: AppSpacing.sm),
            Text(order.address!.formattedAddress),
          ],
          if (order.pickupBranch != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: l10n.orderPickupBranch),
            const SizedBox(height: AppSpacing.sm),
            Text(order.pickupBranch!.name),
            if (order.pickupBranch!.address.isNotEmpty)
              Text(order.pickupBranch!.address),
          ],
          if (order.isDelivered &&
              (order.courierName.isNotEmpty ||
                  order.courierPhone.isNotEmpty ||
                  order.courierComment.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xxl),
            _Section(title: l10n.orderCourier),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
              title: order.courierName.isEmpty ? null : Text(order.courierName),
              subtitle: Text(
                [
                  order.courierPhone,
                  order.courierVehicleType,
                  order.courierComment,
                ].where((value) => value.isNotEmpty).join(' · '),
              ),
            ),
          ],
          if (order.canCancel) ...[
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton.icon(
              onPressed: mutating ? null : onCancel,
              icon: mutating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(l10n.orderCancel),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: SizedBox.square(
        dimension: 52,
        child: ProductImageView(imageUrl: item.imageUrl, iconSize: 22),
      ),
    ),
    title: Text('${item.productName} × ${item.quantity}'),
    subtitle: Text(
      [
        item.variantName,
        ...item.addons.map((addon) => addon.name),
        item.note,
      ].where((value) => value.isNotEmpty).join(', '),
    ),
    trailing: Text(Uzs.format(item.totalPrice)),
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          Uzs.format(value),
          style: emphasized
              ? Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
              : null,
        ),
      ],
    ),
  );
}

bool _hasPositiveValue(String value) => (double.tryParse(value) ?? 0) > 0;
