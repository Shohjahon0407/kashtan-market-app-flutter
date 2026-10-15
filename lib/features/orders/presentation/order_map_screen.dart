import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import 'order_view.dart';
import 'widgets/order_tracking_map.dart';

/// To'liq ekranli xarita: interaktiv, zoom tugmalari, "Buyurtmaga qaytish".
class OrderMapScreen extends ConsumerWidget {
  const OrderMapScreen({
    required this.storeType,
    required this.orderId,
    super.key,
  });

  final StoreType storeType;
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = watchOrderView(ref, orderId);
    final order = view.value;
    final top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (order != null && orderHasMap(order))
            OrderTrackingMap(
              key: const ValueKey('order-map-full'),
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
              interactive: true,
              showControls: true,
              chipOffset: EdgeInsets.only(top: top + 64, left: AppSpacing.lg),
              fitPadding: EdgeInsets.fromLTRB(56, top + 120, 56, bottom + 140),
            )
          else if (view.hasError)
            StoreErrorView(
              message: l10n.errorUnknown,
              onRetry: () => context.pop(),
            )
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: top,
            left: AppSpacing.md,
            child: MapRoundButton(
              icon: Icons.arrow_back_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => context.pop(),
            ),
          ),
          Positioned(
            top: top,
            right: AppSpacing.md,
            child: MapHelpPill(
              label: l10n.orderHelp,
              onPressed: () => pushAuthenticated(
                context,
                ref,
                Routes.requestsFor(kind: 'support'),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.screenH,
            right: AppSpacing.screenH,
            bottom: bottom + AppSpacing.lg,
            child: FilledButton(
              key: const ValueKey('order-map-back'),
              onPressed: () => context.pop(),
              child: Text(l10n.orderBackToOrder),
            ),
          ),
        ],
      ),
    );
  }
}

/// Xarita ustidagi dumaloq tugma (orqa).
class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    elevation: 3,
    shadowColor: Colors.black26,
    child: IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
  );
}

/// Xarita ustidagi "Yordam" pill tugmasi.
class MapHelpPill extends StatelessWidget {
  const MapHelpPill({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const StadiumBorder(),
    elevation: 3,
    shadowColor: Colors.black26,
    child: InkWell(
      key: const ValueKey('order-help'),
      customBorder: const StadiumBorder(),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.headset_mic_rounded, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
}
