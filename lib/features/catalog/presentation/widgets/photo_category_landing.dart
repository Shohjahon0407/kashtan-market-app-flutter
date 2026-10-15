import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/uzbek_transliterator.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../data/product_models.dart';

/// Backend matni locale interceptorida kirillga o‘girilgan bo‘lsa ham asset
/// mapping bir xil ishlashi uchun category kalitini lotinga qaytaradi.
String normalizeCategoryAssetKey(String value) =>
    UzbekTransliterator.toLatin(value.trim())
        .toLowerCase()
        .replaceAll(RegExp('[‘’`ʻʼ]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ');

class PhotoCategoryItem {
  const PhotoCategoryItem({required this.category, this.assetPath});

  final ProductCategory category;
  final String? assetPath;
}

class PhotoCategorySection {
  const PhotoCategorySection({
    required this.keyName,
    required this.title,
    required this.items,
    this.tallFourthCard = false,
  });

  final String keyName;
  final String title;
  final List<PhotoCategoryItem> items;
  final bool tallFourthCard;
}

class PhotoCategoryLandingSliver extends StatelessWidget {
  const PhotoCategoryLandingSliver({
    required this.sections,
    required this.emptyLabel,
    required this.onCategoryTap,
    super.key,
  });

  final List<PhotoCategorySection> sections;
  final String emptyLabel;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(emptyLabel)),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.lg,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      sliver: SliverList.separated(
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxxl),
        itemBuilder: (context, index) => _SectionView(
          key: ValueKey('photo-category-section-${sections[index].keyName}'),
          section: sections[index],
          onCategoryTap: onCategoryTap,
        ),
      ),
    );
  }
}

class PhotoCategoryLandingSkeleton extends StatelessWidget {
  const PhotoCategoryLandingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      sliver: SliverList.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xxxl),
        itemBuilder: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 210, height: 24, color: color),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 166,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (var index = 0; index < 2; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Container(
                      height: 148,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.onCategoryTap,
    super.key,
  });

  final PhotoCategorySection section;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final items = section.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CategoryCard(
          item: items.first,
          height: 166,
          onTap: () => onCategoryTap(items.first.category),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          if (section.tallFourthCard && items.length >= 4)
            _FeaturedMosaic(items: items, onCategoryTap: onCategoryTap)
          else
            _CategoryPairGrid(
              items: items.skip(1).toList(growable: false),
              onCategoryTap: onCategoryTap,
            ),
        ],
      ],
    );
  }
}

class _FeaturedMosaic extends StatelessWidget {
  const _FeaturedMosaic({required this.items, required this.onCategoryTap});

  final List<PhotoCategoryItem> items;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final stackedItems = items.skip(1).take(2).toList(growable: false);
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                for (var index = 0; index < stackedItems.length; index++) ...[
                  Expanded(
                    child: _CategoryCard(
                      item: stackedItems[index],
                      onTap: () => onCategoryTap(stackedItems[index].category),
                    ),
                  ),
                  if (index < stackedItems.length - 1)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _CategoryCard(
              item: items[3],
              onTap: () => onCategoryTap(items[3].category),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPairGrid extends StatelessWidget {
  const _CategoryPairGrid({required this.items, required this.onCategoryTap});

  final List<PhotoCategoryItem> items;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - AppSpacing.md) / 2;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final item in items)
            SizedBox(
              width: cardWidth,
              child: _CategoryCard(
                item: item,
                height: 150,
                onTap: () => onCategoryTap(item.category),
              ),
            ),
        ],
      );
    },
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item, required this.onTap, this.height});

  final PhotoCategoryItem item;
  final VoidCallback onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: item.category.name,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('photo-category-card-${item.category.id}'),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: _CategoryImage(item: item)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Color(0xB8000000)],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      item.category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 5),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.item});

  final PhotoCategoryItem item;

  @override
  Widget build(BuildContext context) {
    final local = item.assetPath;
    if (item.category.imageUrl case final remote?) {
      return CachedNetworkImage(
        imageUrl: remote,
        fit: BoxFit.cover,
        memCacheWidth: 900,
        placeholder: (_, _) => _localOrFallback(context, local),
        errorWidget: (_, _, _) => _localOrFallback(context, local),
      );
    }
    return _localOrFallback(context, local);
  }

  Widget _localOrFallback(BuildContext context, String? path) {
    if (path != null) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        cacheWidth: 900,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.restaurant_menu,
      size: 42,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}
