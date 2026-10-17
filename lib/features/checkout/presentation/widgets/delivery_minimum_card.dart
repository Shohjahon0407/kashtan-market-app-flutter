import 'package:flutter/material.dart';

import '../../../../core/ui/formatters/uzs.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../cart/data/cart_models.dart';

class DeliveryMinimumCard extends StatelessWidget {
  const DeliveryMinimumCard({
    required this.cart,
    this.deliveryFee,
    this.statusOverride,
    this.onAddProducts,
    super.key,
  });

  final CartData cart;
  final String? deliveryFee;

  /// A pending or failed server calculation must not look like a confirmed total.
  final String? statusOverride;
  final VoidCallback? onAddProducts;

  @override
  Widget build(BuildContext context) {
    final minimum =
        double.tryParse(cart.minimumDeliveryOrderAmount ?? '0') ?? 0;
    if (minimum <= 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final met =
        statusOverride == null &&
        deliveryFee != null &&
        cart.meetsDeliveryMinimumIncluding(deliveryFee);
    final color = met
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF53645E);
    // Only the decorative progress ratio uses doubles; money comparisons are exact.
    final progress =
        (((double.tryParse(cart.subtotal) ?? 0) +
                    (double.tryParse(deliveryFee ?? '0') ?? 0)) /
                minimum)
            .clamp(0.0, 1.0);
    return Container(
      key: const ValueKey('checkout-delivery-minimum'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: met ? color.withValues(alpha: .06) : const Color(0xFFF0F2F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                met
                    ? Icons.check_circle_outline
                    : Icons.local_shipping_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.checkoutDeliveryMinimum(
                        Uzs.formatWithFraction(cart.minimumDeliveryOrderAmount),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusOverride ??
                          (met
                              ? l10n.checkoutMinimumReached
                              : deliveryFee == null
                              ? l10n.checkoutMinimumNeedsAddress
                              : l10n.checkoutMinimumRemaining(
                                  Uzs.formatWithFraction(
                                    cart.deliveryMinimumRemaining(
                                      deliveryFee: deliveryFee,
                                    ),
                                  ),
                                )),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.checkoutMinimumIncludesDelivery,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
            ),
          ),
          if (!met && onAddProducts != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAddProducts,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text(l10n.checkoutAddProducts),
            ),
          ],
        ],
      ),
    );
  }
}
