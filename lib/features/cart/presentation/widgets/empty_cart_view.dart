import 'package:flutter/material.dart';

import '../../../../generated/l10n/app_localizations.dart';

class EmptyCartView extends StatelessWidget {
  const EmptyCartView({this.storeLabel, this.onBrowse, super.key});

  final String? storeLabel;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey('empty-cart-view'),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          // Native vector shapes remain crisp offline and add no image payload.
          ExcludeSemantics(
            child: SizedBox(
              width: 200,
              height: 166,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: .07),
                    ),
                  ),
                  Transform.rotate(
                    angle: -.08,
                    child: Icon(
                      Icons.shopping_basket_outlined,
                      size: 108,
                      color: colors.primary,
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 24,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: colors.primary.withValues(alpha: .55),
                    ),
                  ),
                  Positioned(
                    left: 17,
                    bottom: 32,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (storeLabel != null) ...[
            const SizedBox(height: 10),
            Text(
              storeLabel!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colors.primary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.cartEmptyNow,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.cartEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (onBrowse != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.storefront_outlined, size: 20),
              label: Text(l10n.navProducts),
            ),
          ],
        ],
      ),
    );
  }
}
