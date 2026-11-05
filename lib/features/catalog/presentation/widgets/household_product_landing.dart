import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../favorites/domain/favorites_controller.dart';
import '../../data/product_models.dart';
import '../../domain/household_category_previews.dart';
import '../../domain/product_report_controller.dart';
import 'household_category_landing.dart';
import 'product_card.dart';
import 'product_image.dart';
import 'shashlik_feedback.dart';
import 'shashlik_variant_ribbon.dart';

const _nameStyle = TextStyle(
  fontSize: 13,
  height: 1.2,
  fontWeight: FontWeight.w700,
  color: AppColors.lightTextPrimary,
);
const _priceStyle = TextStyle(
  fontSize: 12,
  height: 1.25,
  fontWeight: FontWeight.w800,
  color: AppColors.primary,
);

/// Root-only mini ribbons. Category grids and their navigation stay unchanged.
class HouseholdProductLandingSliver extends StatelessWidget {
  const HouseholdProductLandingSliver({
    required this.categories,
    required this.onCategoryTap,
    this.selectedCategoryId,
    super.key,
  });
  final List<ProductCategory> categories;
  final ValueChanged<ProductCategory> onCategoryTap;
  final String? selectedCategoryId;
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final section in buildHouseholdCategorySections(categories))
        ...section.items.where(
          (item) =>
              selectedCategoryId == null ||
              item.category.id == selectedCategoryId,
        ),
    ];
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(AppLocalizations.of(context).catalogEmpty)),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (_, index) => _CategoryProducts(
          key: ValueKey(
            'household-product-category-${items[index].category.id}',
          ),
          category: items[index].category,
          onOpen: () => onCategoryTap(items[index].category),
        ),
      ),
    );
  }
}

class _CategoryProducts extends ConsumerWidget {
  const _CategoryProducts({
    required this.category,
    required this.onOpen,
    super.key,
  });
  final ProductCategory category;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final previews = ref.watch(householdCategoryPreviewsProvider(category.id));
    final products = previews.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey('household-category-title-${category.id}'),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    header: true,
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: ValueKey('household-category-all-${category.id}'),
              onPressed: onOpen,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppColors.primary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.commonAll),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ],
        ),
        if (products != null && products.isNotEmpty)
          ShashlikVariantRibbon.products(
            id: 'household-category-${category.id}',
            productKeyPrefix: 'household',
            products: products,
            titleFor: (p) => p.name,
            imageFor: (p) =>
                ProductImageView(imageUrl: p.imageUrl, disableFade: true),
            widthFor: _cardWidth,
            itemSpacing: 8,
            autoScroll: false,
            heightFor: (context, width) => _height(context, width, products),
            cardFor: (p) =>
                _MiniProductCard(product: p, categoryId: category.id),
            onOpen: (p) => openStoreProduct(
              context,
              StoreType.household,
              p.id,
              categoryId: category.id,
            ),
          )
        else if (previews.isLoading)
          const _RowSkeleton()
        else if (previews.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previews.error is ApiFailure
                      ? (previews.error! as ApiFailure).localize(l10n)
                      : l10n.errorUnknown,
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(
                    householdCategoryPreviewsProvider(category.id),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Two complete cards and a visible next-card peek. At large fonts prioritize
// names, prices and real touch targets over a fixed number of columns.
double _cardWidth(BuildContext context, double available) => math.min(
  available,
  MediaQuery.textScalerOf(context).scale(13) > 19
      ? math.min(240, math.max(180, available * .56))
      : math.min(180, (available - 16) / 2.3),
);

double _height(
  BuildContext context,
  double width,
  List<ProductSummary> products,
) {
  double measure(String text, TextStyle style, {int? lines}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: lines,
    )..layout(maxWidth: math.max(1, width - 16));
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  var metadata = 0.0;
  for (final p in products) {
    metadata = math.max(
      metadata,
      measure(p.name, _nameStyle, lines: 2) +
          4 +
          measure(Uzs.format(p.price), _priceStyle),
    );
  }
  return math.max(96, width / 1.2) + 8 + metadata + 48 + 8;
}

class _MiniProductCard extends ConsumerWidget {
  const _MiniProductCard({required this.product, required this.categoryId});
  final ProductSummary product;
  final String categoryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorite = ref.watch(
      favoritesControllerProvider.select(
        (s) => (
          selected: s.value?.contains(product.id) ?? false,
          busy: s.value?.busyProductIds.isNotEmpty ?? false,
        ),
      ),
    );
    final reported = ref.watch(
      productReportControllerProvider.select((s) => s.isReported(product.id)),
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E3E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('household-preview-${product.id}'),
        onTap: () => openStoreProduct(
          context,
          StoreType.household,
          product.id,
          categoryId: categoryId,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => AspectRatio(
                // Keep the two 48px photo actions from overlapping on 320px
                // screens, without reserving an entire extra footer for add.
                aspectRatio:
                    constraints.maxWidth /
                    math.max(96, constraints.maxWidth / 1.2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: ProductImageView(
                        imageUrl: product.imageUrl,
                        // Hardware products have very different proportions;
                        // show their entire silhouette instead of cropping it.
                        fit: BoxFit.contain,
                        disableFade: true,
                        memCacheWidth: 360,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        key: ValueKey('household-favorite-${product.id}'),
                        tooltip: l10n.favoritesTitle,
                        isSelected: favorite.selected,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: favorite.busy
                            ? null
                            : () async {
                                if (!await requireAuthentication(
                                      context,
                                      ref,
                                    ) ||
                                    !context.mounted) {
                                  return;
                                }
                                await ref
                                    .read(favoritesControllerProvider.notifier)
                                    .toggle(product);
                              },
                        icon: _favoriteIcon(false),
                        selectedIcon: _favoriteIcon(true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(
                product.name,
                style: _nameStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Text(Uzs.format(product.price), style: _priceStyle),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ProductCartControl(
                product: product,
                storeType: StoreType.household,
                inReview: product.inReview || reported,
                iconOnlyWhenEmpty: true,
                large: true,
                onAdded: () => showShashlikSaved(context),
                cornerWhenEmpty: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _favoriteIcon(bool selected) => Container(
  width: 28,
  height: 28,
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: .94),
    shape: BoxShape.circle,
  ),
  child: Icon(
    selected ? Icons.favorite : Icons.favorite_border,
    size: 18,
    color: selected ? Colors.red : AppColors.lightTextPrimary,
  ),
);

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = _cardWidth(context, constraints.maxWidth);
      final count = math.max(
        1,
        ((constraints.maxWidth + 8) / (width + 8)).floor(),
      );
      return SizedBox(
        height: math.max(96, width / 1.2) + 110,
        child: Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Container(
                width: width,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class HouseholdProductLandingSkeleton extends StatelessWidget {
  const HouseholdProductLandingSkeleton({super.key});
  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.all(12),
    sliver: SliverList.separated(
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24, width: 180, color: const Color(0xFFF1F3F4)),
          const SizedBox(height: 16),
          const _RowSkeleton(),
        ],
      ),
    ),
  );
}
