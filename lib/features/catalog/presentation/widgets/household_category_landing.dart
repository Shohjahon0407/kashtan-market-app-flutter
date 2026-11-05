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
  const HouseholdCategoryItem({
    required this.category,
    this.assetPath,
    this.panelColor = const Color(0xFFF1EFEC),
  });

  final ProductCategory category;
  final String? assetPath;
  final Color panelColor;
}

class _VisualSpec {
  const _VisualSpec(this.group, this.order, this.assetName);

  final HouseholdCategoryGroup group;
  final int order;
  final String assetName;
}

const _assetRoot = 'assets/categories/household';

const _panelColors = <String, Color>{
  'construction.webp': Color(0xFFF2E7D5),
  'tools.webp': Color(0xFFEBEDF0),
  'chainsaw-parts.webp': Color(0xFFE4EBF2),
  'plastic-housewares.webp': Color(0xFFF7E2DC),
  'appliances.webp': Color(0xFFEEF2F4),
  'electronics.webp': Color(0xFFECE7F5),
  'phone-parts.webp': Color(0xFFE4EFF9),
  'car-accessories.webp': Color(0xFFE4E6E9),
  'bicycle-parts.webp': Color(0xFFF2DED3),
  'kitchenware.webp': Color(0xFFF7F0DF),
  'bags-tablecloths.webp': Color(0xFFFBE7D9),
  'stationery.webp': Color(0xFFF8F0CC),
  'clothing.webp': Color(0xFFF5E5EB),
  'footwear.webp': Color(0xFFECE4DA),
  'perfumery.webp': Color(0xFFF0E4F3),
  'toys.webp': Color(0xFFE0F0FA),
  'fishing-supplies.webp': Color(0xFFDEEFF1),
  'assorted-goods.webp': Color(0xFFF1EFEC),
};

const _categoryLabelStyle = TextStyle(
  color: Color(0xFF192331),
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.25,
);

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
        panelColor: _panelColors[spec?.assetName] ?? const Color(0xFFF1EFEC),
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
      padding: const EdgeInsets.all(16),
      sliver: SliverList.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 32),
        itemBuilder: (_, section) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 210, height: 24, color: color),
            const SizedBox(height: 12),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 12),
              Row(
                children: [
                  for (var column = 0; column < 2; column++) ...[
                    if (column > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        key: ValueKey(
                          'household-skeleton-$section-$row-$column',
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: ColoredBox(color: color),
                            ),
                            Container(
                              height: 62,
                              color: color.withValues(alpha: 0.55),
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 88,
                                height: 15,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        householdCategoryGroupTitle(
          AppLocalizations.of(context),
          section.group,
        ),
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 12),
      _CategoryPairGrid(items: section.items, onCategoryTap: onCategoryTap),
    ],
  );
}

class _CategoryPairGrid extends StatelessWidget {
  const _CategoryPairGrid({required this.items, required this.onCategoryTap});

  final List<HouseholdCategoryItem> items;
  final ValueChanged<ProductCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      final scaler = MediaQuery.textScalerOf(context);
      final labelStyle = DefaultTextStyle.of(
        context,
      ).style.merge(_categoryLabelStyle);
      // Only 18 labels: measuring once per row avoids an intrinsic layout pass
      // for images while retaining the full caption at any text scale.
      double captionHeight(HouseholdCategoryItem item) {
        final painter = TextPainter(
          text: TextSpan(text: item.category.name, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          locale: Localizations.localeOf(context),
        )..layout(maxWidth: width - 24);
        final measured = painter.height;
        painter.dispose();
        final minimum = scaler.scale(15) * 1.25 * 2;
        return (measured > minimum ? measured : minimum).ceilToDouble() + 24;
      }

      return Column(
        children: [
          for (var index = 0; index < items.length; index += 2) ...[
            if (index > 0) const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final left = items[index];
                final right = index + 1 < items.length
                    ? items[index + 1]
                    : null;
                final leftHeight = captionHeight(left);
                final rightHeight = right == null ? 0.0 : captionHeight(right);
                final height = leftHeight > rightHeight
                    ? leftHeight
                    : rightHeight;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _CategoryCard(
                        item: left,
                        captionHeight: height,
                        labelStyle: labelStyle,
                        onTap: () => onCategoryTap(left.category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: right == null
                          ? const SizedBox.shrink()
                          : _CategoryCard(
                              item: right,
                              captionHeight: height,
                              labelStyle: labelStyle,
                              onTap: () => onCategoryTap(right.category),
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      );
    },
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.item,
    required this.onTap,
    required this.captionHeight,
    required this.labelStyle,
  });

  final HouseholdCategoryItem item;
  final VoidCallback onTap;
  final double captionHeight;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: item.category.name,
    excludeSemantics: true,
    onTap: onTap,
    child: Material(
      color: item.panelColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('household-category-card-${item.category.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ExcludeSemantics(child: _CategoryImage(item: item)),
            ),
            SizedBox(
              height: captionHeight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.category.name,
                    key: ValueKey(
                      'household-category-label-${item.category.id}',
                    ),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.item});

  final HouseholdCategoryItem item;

  @override
  Widget build(BuildContext context) {
    final local = item.assetPath;
    if (local != null) {
      return Image.asset(
        local,
        fit: BoxFit.cover,
        cacheWidth: 768,
        errorBuilder: (_, _, _) => _remoteOrFallback(context),
      );
    }
    return _remoteOrFallback(context);
  }

  Widget _remoteOrFallback(BuildContext context) {
    final remote = item.category.imageUrl?.trim();
    if (remote != null && remote.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remote,
        fit: BoxFit.cover,
        memCacheWidth: 768,
        placeholder: (_, _) => _fallback(context),
        errorWidget: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => ColoredBox(
    color: item.panelColor,
    child: Icon(
      Icons.category_outlined,
      size: 42,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

String householdCategoryGroupTitle(
  AppLocalizations l10n,
  HouseholdCategoryGroup group,
) => switch (group) {
  HouseholdCategoryGroup.homeTools => l10n.householdSectionHomeTools,
  HouseholdCategoryGroup.techTransport => l10n.householdSectionTechTransport,
  HouseholdCategoryGroup.kitchenLiving => l10n.householdSectionKitchenLiving,
  HouseholdCategoryGroup.clothingCare => l10n.householdSectionClothingCare,
  HouseholdCategoryGroup.kidsHobbyOther => l10n.householdSectionKidsHobbyOther,
};
