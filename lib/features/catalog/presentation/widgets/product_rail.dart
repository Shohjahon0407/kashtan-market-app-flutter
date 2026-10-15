import 'package:flutter/material.dart';

import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';
import 'product_card.dart';

/// Gorizontal mahsulot qatori: sarlavha + bir ekranda [visibleCards] ta
/// karta + ixtiyoriy "Barchasi" kartasi. Video ostida, mahsulot ichidagi
/// o'xshashlar, home "Siz uchun" va katalogdagi o'xshashlar — bitta widget.
class ProductRail extends StatelessWidget {
  const ProductRail({
    required this.title,
    required this.products,
    required this.keyPrefix,
    this.storeType,
    this.subtitle,
    this.cardHeight = 230,
    this.visibleCards = 3,
    this.maxItems = 15,
    this.onSeeAll,
    this.seeAllKey,
    this.storageKey,
    this.titleStyle,
    this.onReachEnd,
    this.loadingMore = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<ProductSummary> products;

  /// Kartaning do'kon turi: berilmasa — mahsulotning o'zidan (home'da
  /// har xil do'konlar aralash); aniqlanmaganlari tashlanadi.
  final StoreType? storeType;

  /// Karta kaliti: `ValueKey('$keyPrefix-<id>')`.
  final String keyPrefix;
  final double cardHeight;
  final double visibleCards;
  final int maxItems;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;
  final PageStorageKey<String>? storageKey;
  final TextStyle? titleStyle;

  /// Oxiriga ~3 karta qolganda chaqiriladi (cheksiz yon scroll).
  final VoidCallback? onReachEnd;

  /// Oxirida yuklanish belgisi ko'rsatilsinmi.
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    final entries = <(ProductSummary, StoreType)>[
      for (final product in products.take(maxItems))
        if (storeType ?? product.storeType case final type?) (product, type),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              titleStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppSpacing.sm;
            // Birinchi kadrda kenglik vaqtincha 0 bo'lishi mumkin (web,
            // sliver o'lchami almashganda) — manfiy kenglik xatosi bermasin.
            if (!constraints.hasBoundedWidth ||
                constraints.maxWidth <= gap * 2) {
              return SizedBox(height: cardHeight);
            }
            final gaps = visibleCards.ceil() - 1;
            final cardWidth =
                (constraints.maxWidth - gap * gaps) / visibleCards;
            final count =
                entries.length +
                (onSeeAll == null ? 0 : 1) +
                (loadingMore ? 1 : 0);
            final list = SizedBox(
              height: cardHeight,
              child: ListView.separated(
                key: storageKey,
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (context, index) {
                  if (loadingMore && index == count - 1) {
                    return SizedBox(
                      key: ValueKey('$keyPrefix-loading'),
                      width: cardWidth * .6,
                      child: const Center(
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }
                  if (index >= entries.length) {
                    return SizedBox(
                      key: seeAllKey,
                      width: cardWidth,
                      child: _SeeAllCard(onTap: onSeeAll!),
                    );
                  }
                  final (product, type) = entries[index];
                  return SizedBox(
                    key: ValueKey('$keyPrefix-${product.id}'),
                    width: cardWidth,
                    child: ProductCard(
                      product: product,
                      storeType: type,
                      compact: true,
                    ),
                  );
                },
              ),
            );
            final reachEnd = onReachEnd;
            if (reachEnd == null) return list;
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                final metrics = notification.metrics;
                if (metrics.axis == Axis.horizontal &&
                    metrics.extentAfter < cardWidth * 3) {
                  reachEnd();
                }
                return false;
              },
              child: list,
            );
          },
        ),
      ],
    );
  }
}

class _SeeAllCard extends StatelessWidget {
  const _SeeAllCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.primaryContainer,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_view_rounded, size: 30),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).videoSeeAllProducts,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}
