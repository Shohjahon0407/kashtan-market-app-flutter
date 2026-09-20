import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/uzbek_transliterator.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';

enum HouseholdCategoryGroup {
  homeTools,
  techTransport,
  kitchenLiving,
  clothingCare,
  kidsHobbyOther,
}

class HouseholdCategorySection {
  const HouseholdCategorySection({required this.group, required this.items});

  final HouseholdCategoryGroup group;
  final List<HouseholdCategoryItem> items;
}

class HouseholdCategoryItem {
  const HouseholdCategoryItem({required this.category, this.assetPath});

  final ProductCategory category;
  final String? assetPath;
}

class _VisualSpec {
  const _VisualSpec(this.group, this.order, this.assetName);

  final HouseholdCategoryGroup group;
  final int order;
  final String assetName;
}

const _assetRoot = 'assets/categories/household';

const Map<String, _VisualSpec> _visuals = {
  'qurilish mollari': _VisualSpec(
    HouseholdCategoryGroup.homeTools,
    0,
    'construction.webp',
  ),
  'ustachilik asboblari': _VisualSpec(
    HouseholdCategoryGroup.homeTools,
    1,
    'tools.webp',
  ),
  'arra zapchastlari': _VisualSpec(
    HouseholdCategoryGroup.homeTools,
    2,
    'chainsaw-parts.webp',
  ),
  'plastmassa': _VisualSpec(
    HouseholdCategoryGroup.homeTools,
    3,
    'plastic-housewares.webp',
  ),
  'maishiy texnika': _VisualSpec(
    HouseholdCategoryGroup.techTransport,
    0,
    'appliances.webp',
  ),
  'mp3 va elektronika': _VisualSpec(
    HouseholdCategoryGroup.techTransport,
    1,
    'electronics.webp',
  ),
  'telefon zapchastlari': _VisualSpec(
    HouseholdCategoryGroup.techTransport,
    2,
    'phone-parts.webp',
  ),
  'mashina aksessuarlari': _VisualSpec(
    HouseholdCategoryGroup.techTransport,
    3,
    'car-accessories.webp',
  ),
  'velosiped zapchastlari': _VisualSpec(
    HouseholdCategoryGroup.techTransport,
    4,
    'bicycle-parts.webp',
  ),
  'oshxona anjomlari': _VisualSpec(
    HouseholdCategoryGroup.kitchenLiving,
    0,
    'kitchenware.webp',
  ),
  'salafan va dasturxon': _VisualSpec(
    HouseholdCategoryGroup.kitchenLiving,
    1,
    'bags-tablecloths.webp',
  ),
  'konstovar': _VisualSpec(
    HouseholdCategoryGroup.kitchenLiving,
    2,
    'stationery.webp',
  ),
  'kiyim-kechak': _VisualSpec(
    HouseholdCategoryGroup.clothingCare,
    0,
    'clothing.webp',
  ),
  'oyoq kiyim': _VisualSpec(
    HouseholdCategoryGroup.clothingCare,
    1,
    'footwear.webp',
  ),
  'parfyumeriya': _VisualSpec(
    HouseholdCategoryGroup.clothingCare,
    2,
    'perfumery.webp',
  ),
  "o'yinchoqlar": _VisualSpec(
    HouseholdCategoryGroup.kidsHobbyOther,
    0,
    'toys.webp',
  ),
  "ko'k yashil to'r": _VisualSpec(
    HouseholdCategoryGroup.kidsHobbyOther,
    1,
    'fishing-supplies.webp',
  ),
  'turli xil mahsulotlar': _VisualSpec(
    HouseholdCategoryGroup.kidsHobbyOther,
    2,
    'assorted-goods.webp',
  ),
};

String normalizeHouseholdCategoryName(String value) =>
    UzbekTransliterator.toLatin(value.trim())
        .toLowerCase()
        .replaceAll(RegExp('[‘’`ʻʼ]'), "'")
        .replaceAll(RegExp(r'\s+'), ' ');

List<HouseholdCategorySection> buildHouseholdCategorySections(
  List<ProductCategory> categories,
) {
  final grouped =
      <
        HouseholdCategoryGroup,
        List<({HouseholdCategoryItem item, int order})>
      >{};

  for (final category in categories) {
    if (category.productCount <= 0) continue;
    final key = normalizeHouseholdCategoryName(
      category.canonicalName ?? category.name,
    );
    if (key == 'yespos imported') continue;
    final spec = _visuals[key];
    final group = spec?.group ?? HouseholdCategoryGroup.kidsHobbyOther;
    grouped.putIfAbsent(group, () => []).add((
      item: HouseholdCategoryItem(
        category: category,
        assetPath: spec == null ? null : '$_assetRoot/${spec.assetName}',
      ),
      order: spec?.order ?? 1000,
    ));
  }

  return [
    for (final group in HouseholdCategoryGroup.values)
      if (grouped[group]?.isNotEmpty ?? false)
        HouseholdCategorySection(
          group: group,
          items:
              (grouped[group]!..sort((a, b) {
                    final byOrder = a.order.compareTo(b.order);
                    return byOrder != 0
                        ? byOrder
                        : a.item.category.name.compareTo(b.item.category.name);
                  }))
                  .map((entry) => entry.item)
                  .toList(growable: false),
        ),
  ];
}

class HouseholdCategoryLandingSliver extends StatelessWidget {
  const HouseholdCategoryLandingSliver({
    required this.categories,
    required this.onCategoryTap,
    super.key,
  });

  final List<ProductCategory> categories;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final sections = buildHouseholdCategorySections(categories);
    if (sections.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(AppLocalizations.of(context).catalogEmpty)),
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
        itemBuilder: (context, index) => _CategorySectionView(
          key: ValueKey('household-section-${sections[index].group.name}'),
          section: sections[index],
          onCategoryTap: onCategoryTap,
        ),
      ),
    );
  }
}

class HouseholdCategoryLandingSkeleton extends StatelessWidget {
  const HouseholdCategoryLandingSkeleton({super.key});

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

class _CategorySectionView extends StatelessWidget {
  const _CategorySectionView({
    required this.section,
    required this.onCategoryTap,
    super.key,
  });

  final HouseholdCategorySection section;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final items = section.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _groupTitle(AppLocalizations.of(context), section.group),
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
          if (section.group == HouseholdCategoryGroup.homeTools &&
              items.length >= 4)
            _HomeToolsMosaic(items: items, onCategoryTap: onCategoryTap)
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

class _HomeToolsMosaic extends StatelessWidget {
  const _HomeToolsMosaic({required this.items, required this.onCategoryTap});

  final List<HouseholdCategoryItem> items;
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

  final List<HouseholdCategoryItem> items;
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

  final HouseholdCategoryItem item;
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
          key: ValueKey('household-category-card-${item.category.id}'),
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

  final HouseholdCategoryItem item;

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
      Icons.category_outlined,
      size: 42,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

String _groupTitle(
  AppLocalizations l10n,
  HouseholdCategoryGroup group,
) => switch (group) {
  HouseholdCategoryGroup.homeTools => l10n.householdSectionHomeTools,
  HouseholdCategoryGroup.techTransport => l10n.householdSectionTechTransport,
  HouseholdCategoryGroup.kitchenLiving => l10n.householdSectionKitchenLiving,
  HouseholdCategoryGroup.clothingCare => l10n.householdSectionClothingCare,
  HouseholdCategoryGroup.kidsHobbyOther => l10n.householdSectionKidsHobbyOther,
};
