import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/presentation/widgets/catalog_loading_skeleton.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../../home/domain/home_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/order_models.dart';
import '../domain/orders_controller.dart';
import 'widgets/order_contact.dart';

/// "Buyurtma tafsilotlari": mahsulotlar va hisob-kitob (Jami, mahsulotlar,
/// yetkazish, to'lov usuli). Buyurtma raqami ko'rsatilMAYDI.
class OrderSummaryScreen extends ConsumerWidget {
  const OrderSummaryScreen({
    required this.storeType,
    required this.orderId,
    super.key,
  });

  final StoreType storeType;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(orderDetailProvider(orderId));
    final storeLabel =
        ref
            .watch(homeControllerProvider)
            .value
            ?.storeHub
            .where((item) => item.storeTypeWire == storeType.wire)
            .map((item) => item.label)
            .firstOrNull ??
        '';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(l10n.orderSummaryTitle),
            if (storeLabel.isNotEmpty)
              Text(
                storeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: switch (detail) {
        AsyncData(:final value) => _SummaryBody(order: value),
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        _ => const CatalogRowsSkeleton(itemCount: 4),
      },
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.order});

  final OrderData order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deliveryFee = double.tryParse(order.deliveryFee) ?? 0;
    final payment = paymentMethodLabel(l10n, order.paymentMethod);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.huge,
      ),
      children: [
        for (final item in order.items) _OrderItemTile(item: item),
        const SizedBox(height: AppSpacing.xl),
        Container(
          key: const ValueKey('order-summary-totals'),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.cartTotal,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    Uzs.format(order.total),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _TotalRow(
                label: l10n.cartSubtotal,
                value: Uzs.format(order.subtotal),
              ),
              _TotalRow(
                label: l10n.cartDeliveryFee,
                value: deliveryFee > 0
                    ? Uzs.format(order.deliveryFee)
                    : l10n.orderDeliveryFree,
                emphasizeValue: deliveryFee <= 0,
              ),
              if (payment.isNotEmpty)
                _TotalRow(label: l10n.orderPaymentMethodLabel, value: payment),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasizeValue ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = [
      item.variantName,
      ...item.addons.map((addon) => addon.name),
      item.note,
    ].where((value) => value.isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox.square(
              dimension: 60,
              child: ProductImageView(imageUrl: item.imageUrl, iconSize: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${item.quantity} × ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: Uzs.format(item.price),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    extras,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Uzs.format(item.totalPrice),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
