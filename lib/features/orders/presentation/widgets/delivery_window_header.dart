import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/theme/app_colors.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/order_models.dart';
import 'order_status_badge.dart';

/// Panel sarlavhasi: "Yetkazib beradigan vaqtimiz" + katta "15:16 – 15:26".
/// Tasdiq kutilayotganda — vaqt hali yo'q; 1–2 kunlik — kun matni;
/// yetkazilgan — yashil belgi va vaqt; bekor — badge.
class DeliveryWindowHeader extends StatelessWidget {
  const DeliveryWindowHeader({required this.order, super.key});

  final OrderData order;

  static String formatWindow(DeliveryWindow window) {
    final format = DateFormat('HH:mm');
    return '${format.format(window.start)} – ${format.format(window.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stage = order.customerStage;

    if (stage == CustomerOrderStage.cancelled) {
      return const Center(
        child: OrderStatusBadge(stage: CustomerOrderStage.cancelled),
      );
    }
    if (stage == CustomerOrderStage.delivered) {
      final at = order.deliveredAt;
      return Column(
        key: const ValueKey('order-delivered-hero'),
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successSoft,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            at == null
                ? l10n.orderStatusDelivered
                : l10n.orderDeliveredAt(DateFormat('HH:mm').format(at)),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.success,
            ),
          ),
        ],
      );
    }

    final window = order.deliveryWindow;
    final String value;
    final TextStyle? style;
    if (window != null) {
      value = formatWindow(window);
      style = theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    } else if (order.isDelayedDelivery &&
        (stage == CustomerOrderStage.accepted ||
            stage == CustomerOrderStage.onWay)) {
      value = order.deliveryOption == 'one_day'
          ? l10n.orderDeliveryWithinOneDay
          : l10n.orderDeliveryWithinTwoDays;
      style = theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
      );
    } else {
      value = l10n.orderDeliveryWindowPending;
      style = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
    return Column(
      children: [
        Text(
          l10n.orderDeliveryWindowTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          key: const ValueKey('order-delivery-window'),
          textAlign: TextAlign.center,
          style: style,
        ),
      ],
    );
  }
}
