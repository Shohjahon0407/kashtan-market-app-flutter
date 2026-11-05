import 'package:flutter/material.dart';

import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/catalog_product_images.dart';
import '../../data/product_models.dart';
import 'meat_product_image.dart';
import 'shashlik_catalog.dart';
import 'shashlik_feedback.dart';
import 'shashlik_variant_ribbon.dart';

export '../../data/catalog_product_images.dart'
    show MeatProductKind, meatProductKind;

List<ProductSummary> sortMeatProducts(Iterable<ProductSummary> products) {
  final indexed = products.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final order = meatProductKind(
      a.$2,
    ).index.compareTo(meatProductKind(b.$2).index);
    return order != 0 ? order : a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

String meatSectionTitle(AppLocalizations l10n, ProductSummary product) =>
    switch (meatProductKind(product)) {
      MeatProductKind.lamb => l10n.meatProductLamb,
      MeatProductKind.beef => l10n.meatProductBeef,
      MeatProductKind.horse => l10n.meatProductHorse,
      MeatProductKind.qazi => l10n.meatProductQazi,
      MeatProductKind.beefLiver => l10n.meatProductBeefLiver,
      MeatProductKind.lambLiver => l10n.meatProductLambLiver,
      MeatProductKind.other => product.category?.name ?? product.name,
    };

String meatSectionId(ProductSummary product) {
  final kind = meatProductKind(product);
  return kind == MeatProductKind.other
      ? 'other-${product.category?.id ?? product.id}'
      : kind.name;
}

/// Natural-height sections replace rows squeezed into the viewport.
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
    final groups = <String, List<ProductSummary>>{};
    for (final product in sortMeatProducts(products)) {
      groups.putIfAbsent(meatSectionId(product), () => []).add(product);
    }
    final sections = groups.values.toList();
    return ListView.separated(
      key: const PageStorageKey('meat-product-list'),
      controller: controller,
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sections.length + (footer == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) => index == sections.length
          ? footer!
          : MeatProductCard(
              product: sections[index].first,
              products: sections[index],
            ),
    );
  }
}

class MeatCatalogSkeleton extends StatelessWidget {
  const MeatCatalogSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 3,
    separatorBuilder: (_, _) => const SizedBox(height: 24),
    itemBuilder: (_, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 160, height: 24, color: const Color(0xFFF1F3F4)),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    ),
  );
}

class MeatProductCard extends StatelessWidget {
  const MeatProductCard({required this.product, this.products, super.key});
  final ProductSummary product;
  final List<ProductSummary>? products;

  @override
  Widget build(BuildContext context) {
    final items = products ?? [product];
    final l10n = AppLocalizations.of(context);
    void open(ProductSummary item) =>
        openStoreProduct(context, StoreType.meat, item.id);
    return Column(
      key: ValueKey('meat-product-card-${product.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          meatSectionTitle(l10n, product),
          style: const TextStyle(
            fontFamily: 'RobotoCondensed',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ShashlikVariantRibbon.products(
          id: 'meat-${meatSectionId(product)}',
          products: items,
          onOpen: open,
          titleFor: (item) => item.name,
          priceFor: (item) =>
              '${Uzs.format(item.price)}${item.unit.isEmpty ? '' : ' / ${item.unit}'}',
          imageFor: (item) => MeatProductImage(product: item),
          onAdd: (item) async {
            if (item.requiresConfiguration) {
              open(item);
              return;
            }
            final saved = await showMeatQuantityEditor(context, item);
            if (saved == true && context.mounted) showShashlikSaved(context);
          },
        ),
      ],
    );
  }
}
