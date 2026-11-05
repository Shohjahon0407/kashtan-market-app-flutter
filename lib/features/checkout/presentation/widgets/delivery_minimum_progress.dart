import 'package:flutter/material.dart';

import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../cart/data/cart_models.dart';

/// A confirmed shortfall only; unknown shipping is never treated as zero.
class DeliveryMinimumProgress extends StatelessWidget {
  const DeliveryMinimumProgress({
    required this.cart,
    required this.deliveryFee,
    required this.onAddProducts,
    this.isConfirmed = true,
    super.key,
  });

  final CartData cart;
  final String? deliveryFee;
  final VoidCallback onAddProducts;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    if (cart.totalQuantity <= 0 ||
        !isConfirmed ||
        deliveryFee == null ||
        !cart.hasDeliveryMinimum ||
        cart.meetsDeliveryMinimumIncluding(deliveryFee)) {
      return const SizedBox.shrink();
    }
    final label = AppLocalizations.of(context).checkoutMinimumRemaining(
      Uzs.formatWithFraction(
        cart.deliveryMinimumRemaining(deliveryFee: deliveryFee),
      ),
    );
    // Money comparisons above use exact minor units. This ratio is decorative.
    final minimum = double.tryParse(cart.minimumDeliveryOrderAmount ?? '') ?? 0;
    final progress = minimum <= 0
        ? 1.0
        : (((double.tryParse(cart.subtotal) ?? 0) +
                      (double.tryParse(deliveryFee!) ?? 0)) /
                  minimum)
              .clamp(0.0, 1.0);
    return Semantics(
      key: const ValueKey('cart-minimum-progress'),
      button: true,
      liveRegion: true,
      label: label,
      value: '${(progress * 100).floor().clamp(0, 99)}%',
      onTap: onAddProducts,
      excludeSemantics: true,
      child: InkWell(
        onTap: onAddProducts,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.delivery_dining_rounded, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: progress, end: progress),
                duration:
                    MediaQuery.disableAnimationsOf(context) ||
                        MediaQuery.accessibleNavigationOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (_, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    color: AppColors.primary,
                    backgroundColor: AppColors.lightBorder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
