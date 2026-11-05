import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/lifecycle/visible_clock.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../payments/presentation/payme_payment_section.dart';
import '../../data/order_models.dart';
import 'courier_card.dart';
import 'delivery_window_header.dart';
import 'order_contact.dart';
import 'order_stage_stepper.dart';
import 'order_status_badge.dart';

/// Buyurtma kuzatuv paneli (xarita ostidagi varaq yoki oddiy ro'yxat):
/// vaqt oynasi → 4 bosqich → kuryer → tafsilotlar → Payme → manzil → bekor.
class OrderTrackingPanel extends ConsumerWidget {
  const OrderTrackingPanel({
    required this.order,
    required this.mutating,
    required this.onCancel,
    required this.onOpenSummary,
    this.autoPay = false,
    this.scrollController,
    this.withHandle = false,
    this.physics,
    super.key,
  });

  final OrderData order;
  final bool autoPay;
  final bool mutating;
  final VoidCallback onCancel;
  final VoidCallback onOpenSummary;
  final ScrollController? scrollController;
  final bool withHandle;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stage = order.customerStage;
    final hint = OrderStageStepper.stageHint(l10n, stage);
    final showCourier =
        order.isDelivery &&
        order.courierName.isNotEmpty &&
        stage != CustomerOrderStage.searching &&
        stage != CustomerOrderStage.cancelled;

    return ListView(
      controller: scrollController,
      physics: physics,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.huge,
      ),
      children: [
        if (withHandle)
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        if (order.paymentMethod == 'payme' &&
            const {'unpaid', 'pending'}.contains(order.paymentStatus) &&
            order.status == 'pending')
          Text(
            l10n.paymeAwaitingPayment,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          )
        else if (order.isDelivery) ...[
          DeliveryWindowHeader(order: order),
          if (stage.stepIndex != null) ...[
            const SizedBox(height: AppSpacing.xl),
            OrderStageStepper(stage: stage),
            const SizedBox(height: AppSpacing.lg),
            Text(
              OrderStageStepper.stageTitle(l10n, stage),
              key: const ValueKey('order-stage-title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (hint != null && stage != CustomerOrderStage.delivered) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (stage == CustomerOrderStage.searching) ...[
              const SizedBox(height: AppSpacing.sm),
              _WaitingElapsed(createdAt: order.createdDateTime),
            ],
          ],
        ] else
          Center(child: OrderStatusBadge(stage: stage)),
        if (showCourier) ...[
          const SizedBox(height: AppSpacing.xl),
          CourierCard(order: order),
        ],
        const SizedBox(height: AppSpacing.xl),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        _SummaryEntry(order: order, onTap: onOpenSummary),
        if (order.paymentMethod == 'payme') ...[
          const SizedBox(height: AppSpacing.lg),
          PaymePaymentSection(order: order, autoStart: autoPay),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.orderDeliveryDetails,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (order.address != null)
          _DetailRow(
            icon: Icons.home_rounded,
            label: l10n.orderAddress,
            value: order.address!.formattedAddress,
          ),
        if (order.customerPhone.isNotEmpty)
          _DetailRow(
            icon: Icons.call_rounded,
            label: l10n.orderRecipientPhone,
            value: order.customerPhone,
          ),
        if (order.pickupBranch != null && !order.isDelivery)
          _DetailRow(
            icon: Icons.storefront_rounded,
            label: l10n.orderPickupBranch,
            value: [
              order.pickupBranch!.name,
              order.pickupBranch!.address,
            ].where((value) => value.isNotEmpty).join(', '),
          ),
        if (order.canCancel) ...[
          const SizedBox(height: AppSpacing.xl),
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
        if (order.cancellationRequiresCall) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.orderCancelCallCourier,
            key: const ValueKey('order-cancel-call-hint'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (order.courierPhone.trim().isNotEmpty)
            OutlinedButton.icon(
              key: const ValueKey('order-cancel-call-courier'),
              onPressed: () => callPhone(context, order.courierPhone),
              icon: const Icon(Icons.call_rounded),
              label: Text(l10n.orderCancelCallAction),
            )
          else
            Text(l10n.orderCourierPhoneUnavailable),
        ],
      ],
    );
  }
}

class _SummaryEntry extends StatelessWidget {
  const _SummaryEntry({required this.order, required this.onTap});

  final OrderData order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = order.items.fold<int>(0, (sum, item) => sum + item.quantity);
    return ListTile(
      key: const ValueKey('order-summary-entry'),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.receipt_long_rounded),
      ),
      title: Text(
        l10n.orderSummaryTitle,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '${l10n.orderSummaryProducts(count)} · ${Uzs.format(order.total)}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kutilmoqda: mm:ss" — faqat ekran ko'rinib turganda yuradi.
class _WaitingElapsed extends StatefulWidget {
  const _WaitingElapsed({required this.createdAt});

  final DateTime? createdAt;

  @override
  State<_WaitingElapsed> createState() => _WaitingElapsedState();
}

class _WaitingElapsedState extends State<_WaitingElapsed>
    with WidgetsBindingObserver, RouteAware, VisibleClock {
  @override
  void onVisibleTick() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.orderWaitingElapsed(formatElapsed(widget.createdAt)),
      key: const ValueKey('order-waiting-elapsed'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

String formatElapsed(DateTime? createdAt) {
  if (createdAt == null) return '00:00';
  final seconds = math.max(0, DateTime.now().difference(createdAt).inSeconds);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return hours > 0
      ? '${two(hours)}:${two(minutes)}:${two(remainingSeconds)}'
      : '${two(minutes)}:${two(remainingSeconds)}';
}
