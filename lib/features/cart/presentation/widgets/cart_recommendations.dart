import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/store_scope/store_type.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../catalog/presentation/widgets/product_card.dart';
import '../../domain/cart_recommendations_provider.dart';

class CartRecommendations extends ConsumerWidget {
  const CartRecommendations({
    this.storeType,
    this.minimumMode = false,
    this.showFallback = false,
    this.onBrowse,
    this.grid = false,
    super.key,
  });

  final StoreType? storeType;
  final bool minimumMode;
  final bool showFallback;
  final VoidCallback? onBrowse;

  /// Do'kon savatida: pastga davom etadigan 2 ustunli grid (Uzum kabi).
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = ref.watch(cartRecommendationsProvider(storeType));
    final products = response.value;
    if ((products == null || products.isEmpty) && !showFallback) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Padding(
      key: ValueKey('cart-recommendations-${storeType?.wire ?? 'all'}'),
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                minimumMode
                    ? l10n.cartMinimumRecommendations
                    : l10n.cartRecommendationsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (onBrowse != null)
                TextButton(
                  key: const ValueKey('cart-browse-products'),
                  onPressed: onBrowse,
                  child: Text(l10n.cartAllProducts),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (products == null)
            const LinearProgressIndicator(minHeight: 2)
          else if (products.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('cart-recommendations-retry'),
                onPressed: () =>
                    ref.invalidate(cartRecommendationsProvider(storeType)),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.commonRetry),
              ),
            )
          else if (grid)
            GridView.builder(
              key: PageStorageKey(
                'cart-suggestions-${storeType?.wire ?? 'all'}',
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                // Katta shriftda karta cho'ziladi — matn kesilmasin.
                childAspectRatio: (0.70 / math.max(1.0, scale * .9)).clamp(
                  0.42,
                  0.70,
                ),
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return KeyedSubtree(
                  key: ValueKey('cart-recommendation-${product.id}'),
                  child: ProductCard(
                    product: product,
                    storeType:
                        storeType ?? StoreType.fromWire(product.storeTypeWire)!,
                    catalogStyle: true,
                  ),
                );
              },
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
                  return const SizedBox.shrink();
                }
                final width = math.min(
                  constraints.maxWidth,
                  (constraints.maxWidth / 2.25).clamp(145.0, 205.0) *
                      math.max(1.0, scale * .8),
                );
                return SizedBox(
                  height: 250 + math.max(0.0, scale - 1) * 120,
                  child: ListView.separated(
                    key: PageStorageKey(
                      'cart-suggestions-${storeType?.wire ?? 'all'}',
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return SizedBox(
                        key: ValueKey('cart-recommendation-${product.id}'),
                        width: width,
                        child: ProductCard(
                          product: product,
                          storeType:
                              storeType ??
                              StoreType.fromWire(product.storeTypeWire)!,
                          compact: true,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
