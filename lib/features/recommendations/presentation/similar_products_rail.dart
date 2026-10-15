import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/data/catalog_product_images.dart';
import '../../catalog/presentation/widgets/product_rail.dart';
import '../domain/recommendations_controller.dart';

/// Katalog orasiga qo'yiladigan "«X»ga o'xshashlar" qatori — user hozirgina
/// ochib ko'rgan mahsulotga o'xshashlar keyingi scrollda chiqadi.
class SimilarProductsRail extends ConsumerWidget {
  const SimilarProductsRail({
    required this.productId,
    required this.productName,
    required this.storeType,
    this.imagesOnly = false,
    super.key,
  });

  final String productId;
  final String productName;
  final StoreType storeType;
  final bool imagesOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems =
        ref.watch(similarProductsProvider(productId)).value ?? const [];
    final items = imagesOnly
        ? allItems.where(catalogProductHasImage).toList()
        : allItems;
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final title = productName.isEmpty
        ? l10n.productRelated
        : l10n.catalogSimilarTo(productName);
    return Container(
      key: ValueKey('catalog-similar-$productId'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ProductRail(
        title: title,
        products: items,
        storeType: storeType,
        keyPrefix: 'catalog-similar-$productId',
        storageKey: PageStorageKey('catalog-similar-$productId'),
      ),
    );
  }
}
