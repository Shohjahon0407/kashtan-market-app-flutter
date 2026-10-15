import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/catalog_product_images.dart';
import '../../data/product_models.dart';
import 'product_card.dart';
import 'product_image_magnifier.dart';

export '../../data/catalog_product_images.dart'
    show MeatProductKind, meatProductKind;

const _assetRoot = 'assets/products/meat';

List<ProductSummary> sortMeatProducts(Iterable<ProductSummary> products) {
  final indexed = products.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final byKind = _kindOrder(
      meatProductKind(a.$2),
    ).compareTo(_kindOrder(meatProductKind(b.$2)));
    return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

int _kindOrder(MeatProductKind kind) => switch (kind) {
  MeatProductKind.lamb => 0,
  MeatProductKind.beef => 1,
  MeatProductKind.horse => 2,
  MeatProductKind.qazi => 3,
  MeatProductKind.beefLiver => 4,
  MeatProductKind.lambLiver => 5,
  MeatProductKind.other => 100,
};

String _productLabel(AppLocalizations l10n, ProductSummary product) =>
    switch (meatProductKind(product)) {
      MeatProductKind.lamb => l10n.meatProductLamb,
      MeatProductKind.beef => l10n.meatProductBeef,
      MeatProductKind.horse => l10n.meatProductHorse,
      MeatProductKind.qazi => l10n.meatProductQazi,
      MeatProductKind.beefLiver => l10n.meatProductBeefLiver,
      MeatProductKind.lambLiver => l10n.meatProductLambLiver,
      MeatProductKind.other => product.name,
    };

String _fallbackImage(MeatProductKind kind) => switch (kind) {
  MeatProductKind.lamb => '$_assetRoot/lamb-meat.webp',
  MeatProductKind.beef => '$_assetRoot/beef-meat.webp',
  MeatProductKind.horse => '$_assetRoot/horse-meat.webp',
  MeatProductKind.qazi => '$_assetRoot/qazi.webp',
  MeatProductKind.beefLiver => '$_assetRoot/beef-liver.webp',
  MeatProductKind.lambLiver => '$_assetRoot/lamb-liver.webp',
  MeatProductKind.other => 'assets/stores/meat.webp',
};

String? _animalIcon(MeatProductKind kind) => switch (kind) {
  MeatProductKind.lamb || MeatProductKind.lambLiver => '$_assetRoot/sheep.svg',
  MeatProductKind.beef || MeatProductKind.beefLiver => '$_assetRoot/cow.svg',
  MeatProductKind.horse || MeatProductKind.qazi => '$_assetRoot/horse.svg',
  MeatProductKind.other => null,
};

class MeatCatalogList extends StatelessWidget {
  const MeatCatalogList({
    required this.products,
    this.controller,
    this.footer,
    super.key,
  });

  final List<ProductSummary> products;
  final ScrollController? controller;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final sorted = sortMeatProducts(products);
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = AppSpacing.md;
        const verticalPadding = AppSpacing.sm;
        const gap = AppSpacing.sm;
        final gapTotal = gap * (sorted.length - 1).clamp(0, sorted.length);
        final availableForCards =
            constraints.maxHeight - (verticalPadding * 2) - gapTotal;
        final fittedHeight = sorted.isEmpty
            ? 0.0
            : availableForCards / sorted.length;
        final cardHeight = fittedHeight.clamp(76.0, 108.0);

        return ListView.separated(
          controller: controller,
          key: const ValueKey('meat-product-list'),
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: sorted.length + (footer == null ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: gap),
          itemBuilder: (context, index) => index == sorted.length
              ? footer!
              : SizedBox(
                  height: cardHeight,
                  child: MeatProductCard(product: sorted[index]),
                ),
        );
      },
    );
  }
}

class MeatCatalogSkeleton extends StatelessWidget {
  const MeatCatalogSkeleton({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = AppSpacing.sm;
      const verticalPadding = AppSpacing.sm;
      final available = constraints.maxHeight - verticalPadding * 2 - gap * 5;
      final height = (available / 6).clamp(76.0, 108.0);
      final color = Theme.of(context).colorScheme.surfaceContainerHighest;
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: verticalPadding,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: gap),
        itemBuilder: (_, _) => Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      );
    },
  );
}

class MeatProductCard extends StatelessWidget {
  const MeatProductCard({required this.product, super.key});

  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kind = meatProductKind(product);
    final icon = _animalIcon(kind);

    return Card(
      key: ValueKey('meat-product-card-${product.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStoreProduct(context, StoreType.meat, product.id),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageWidth = (constraints.maxHeight * 1.18).clamp(
              92.0,
              126.0,
            );
            return Row(
              children: [
                SizedBox(
                  width: imageWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _MeatProductImage(
                        product: product,
                        fallbackAsset: _fallbackImage(kind),
                      ),
                      if (product.imageCount >= 2)
                        Positioned(
                          right: AppSpacing.xs,
                          bottom: AppSpacing.xs,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.collections_outlined,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${product.imageCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  right: icon == null ? 0 : 34,
                                ),
                                child: Text(
                                  _productLabel(
                                    AppLocalizations.of(context),
                                    product,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      Uzs.format(product.price),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  ProductCartControl(
                                    product: product,
                                    storeType: StoreType.meat,
                                    compact: true,
                                    iconOnlyWhenEmpty: true,
                                    inlineCompact: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (icon != null)
                        Positioned(
                          top: AppSpacing.xs,
                          right: AppSpacing.xs,
                          child: Semantics(
                            label: _productLabel(
                              AppLocalizations.of(context),
                              product,
                            ),
                            child: DecoratedBox(
                              key: ValueKey(
                                'meat-animal-${kind.name}-${product.id}',
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: SvgPicture.asset(
                                  icon,
                                  width: 18,
                                  height: 18,
                                  colorFilter: ColorFilter.mode(
                                    colors.primary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MeatProductImage extends StatelessWidget {
  const _MeatProductImage({required this.product, required this.fallbackAsset});

  final ProductSummary product;
  final String fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final remote = product.imageUrl;
    if (remote == null || remote.isEmpty) return _localImage(context);
    return CachedNetworkImage(
      imageUrl: remote,
      fit: BoxFit.cover,
      memCacheWidth: 500,
      imageBuilder: (_, provider) => ProductImageMagnifier(
        key: ValueKey('meat-card-magnifier-${product.id}'),
        child: Image(image: provider, fit: BoxFit.cover),
      ),
      placeholder: (_, _) => _localImage(context),
      errorWidget: (_, _, _) => _localImage(context),
    );
  }

  Widget _localImage(BuildContext context) => ProductImageMagnifier(
    key: ValueKey('meat-card-magnifier-${product.id}'),
    child: Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      cacheWidth: 500,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.restaurant_outlined,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    ),
  );
}
