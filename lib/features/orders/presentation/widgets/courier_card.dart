import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/order_models.dart';
import 'order_contact.dart';

/// Kuryer kartasi: initsial avatar + transport belgisi, ism, "Kuryer ·
/// transport", qo'ng'iroq tugmasi, izoh.
class CourierCard extends StatelessWidget {
  const CourierCard({required this.order, super.key});

  final OrderData order;

  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase());
    final result = parts.join();
    return result.isEmpty ? '•' : result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final vehicle = order.courierVehicleType;
    final subtitle = [
      l10n.orderCourierRole,
      if (vehicle.isNotEmpty) vehicleLabel(l10n, vehicle),
    ].join(' · ');
    return Container(
      key: const ValueKey('order-courier-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final call = SizedBox.square(
                dimension: 48,
                child: IconButton.filledTonal(
                  key: const ValueKey('order-call-courier'),
                  tooltip: l10n.orderCallCourier,
                  onPressed: () => callPhone(context, order.courierPhone),
                  icon: const Icon(Icons.call_rounded, size: 22),
                ),
              );
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.courierName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              if (MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _Avatar(name: order.courierName, vehicle: vehicle),
                        const Spacer(),
                        if (order.courierPhone.isNotEmpty) call,
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    identity,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(name: order.courierName, vehicle: vehicle),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: identity),
                      if (order.courierPhone.isNotEmpty && !stacked) ...[
                        const SizedBox(width: AppSpacing.sm),
                        call,
                      ],
                    ],
                  ),
                  if (order.courierPhone.isNotEmpty && stacked) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(alignment: Alignment.centerRight, child: call),
                  ],
                ],
              );
            },
          ),
          if (order.courierComment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      order.courierComment,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.vehicle});

  final String name;
  final String vehicle;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primarySoft,
          ),
          alignment: Alignment.center,
          child: Text(
            CourierCard.initialsOf(name),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(vehicleIcon(vehicle), size: 14, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
