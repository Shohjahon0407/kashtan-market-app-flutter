import 'package:flutter/material.dart';

import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../checkout/presentation/widgets/store_minimum_panel.dart';

/// Lives in the catalogue Scaffold's bottomNavigationBar, above the shell
/// navbar. It reserves layout space instead of covering the last product.
class ShashlikCartBar extends StatefulWidget {
  const ShashlikCartBar({
    required this.quantity,
    required this.subtotal,
    required this.onTap,
    this.storeType,
    super.key,
  });

  final int quantity;
  final String subtotal;
  final VoidCallback onTap;
  final StoreType? storeType;

  @override
  State<ShashlikCartBar> createState() => _ShashlikCartBarState();
}

class _ShashlikCartBarState extends State<ShashlikCartBar> {
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      layoutBuilder: (current, previous) => SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (final old in previous)
              IgnorePointer(child: ExcludeSemantics(child: old)),
            ?current,
          ],
        ),
      ),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: widget.quantity <= 0 || (!_entered && !reduce)
          ? const SizedBox.shrink(key: ValueKey('shashlik-cart-empty'))
          : widget.storeType == null
          ? _CartAction(
              key: const ValueKey('shashlik-cart-content'),
              quantity: widget.quantity,
              subtotal: widget.subtotal,
              onTap: widget.onTap,
            )
          : StoreMinimumPanel(
              key: const ValueKey('shashlik-cart-content'),
              storeType: widget.storeType!,
              child: _CartAction(
                quantity: widget.quantity,
                subtotal: widget.subtotal,
                onTap: widget.onTap,
              ),
            ),
    );
  }
}

class _CartAction extends StatelessWidget {
  const _CartAction({
    required this.quantity,
    required this.subtotal,
    required this.onTap,
    super.key,
  });
  final int quantity;
  final String subtotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );
    final countStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: Colors.white);
    final price = Uzs.format(subtotal);
    double width(String text) => (TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).width;
    final label = Text(l10n.productGoToCart, style: labelStyle);
    final count = Text(l10n.cartItemsCount(quantity), style: countStyle);
    final amount = Text(price, style: labelStyle, textAlign: TextAlign.end);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).height < 480
                ? double.infinity
                : 560,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('shashlik-go-to-cart'),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked =
                            width(l10n.productGoToCart) + width(price) + 48 >
                            constraints.maxWidth;
                        final heading = Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: label),
                          ],
                        );
                        if (stacked) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              heading,
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: count),
                                  const SizedBox(width: 12),
                                  Expanded(child: amount),
                                ],
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [label, count],
                              ),
                            ),
                            const SizedBox(width: 12),
                            amount,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
