import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/routing/auth_gate.dart';
import '../../../../core/routing/store_navigation.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../cart/data/cart_models.dart';
import '../../../cart/domain/cart_controller.dart';
import '../../../favorites/domain/favorites_controller.dart';
import '../../data/product_models.dart';
import '../../domain/product_report_controller.dart';
import 'product_image.dart';
import 'product_image_magnifier.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({
    required this.product,
    required this.storeType,
    this.compact = false,
    this.catalogStyle = false,
    super.key,
  });

  final ProductSummary product;
  final StoreType storeType;
  final bool compact;
  final bool catalogStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesControllerProvider).value;
    final favoriteBusy =
        favorites?.busyProductIds.contains(product.id) ?? false;
    final reportState = ref.watch(productReportControllerProvider);
    // Server flagi yoki shu sessiyada hozirgina yuborilgani — ikkalasi ham
    // "Tekshiruvda" holati.
    final inReview = product.inReview || reportState.isReported(product.id);
    final showReportButton =
        !inReview && ref.watch(reportButtonEnabledProvider(storeType));

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => openStoreProduct(context, storeType, product.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImageView(
                    imageUrl: product.imageUrl,
                    imageBuilder: (context, imageProvider) =>
                        ProductImageMagnifier(
                          key: ValueKey('product-card-magnifier-${product.id}'),
                          child: Image(image: imageProvider, fit: BoxFit.cover),
                        ),
                  ),
                  if (showReportButton)
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: Material(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: ValueKey('product-card-report-${product.id}'),
                          visualDensity: VisualDensity.compact,
                          tooltip: l10n.reportProductButton,
                          onPressed: reportState.isBusy(product.id)
                              ? null
                              : () => _confirmAndReport(context, ref),
                          icon: Icon(
                            Icons.flag_outlined,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (inReview)
                    Positioned(
                      top: AppSpacing.xs,
                      left: AppSpacing.xs,
                      child: Semantics(
                        key: ValueKey('product-card-in-review-${product.id}'),
                        label: l10n.productInReview,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer
                                .withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.hourglass_top,
                                  size: 13,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.productInReview,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l10n.favoritesTitle,
                        onPressed: favoriteBusy
                            ? null
                            : () async {
                                if (!await requireAuthentication(
                                  context,
                                  ref,
                                )) {
                                  return;
                                }
                                if (!context.mounted) return;
                                await ref
                                    .read(favoritesControllerProvider.notifier)
                                    .toggle(product);
                              },
                        icon: Icon(
                          favorites?.contains(product.id) == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: favorites?.contains(product.id) == true
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  if (product.imageCount >= 2)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppSpacing.xs,
                      child: Center(
                        child: Semantics(
                          key: ValueKey(
                            'product-card-image-count-${product.id}',
                          ),
                          label: l10n.productImageCount(product.imageCount),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.collections_outlined,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.imageCount}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Tekshiruvdagi mahsulot to'liq KO'RINIB turishi kerak —
                  // scrim faqat oddiy "mavjud emas" holatiga.
                  if (!product.isPurchasable && !inReview)
                    Positioned.fill(
                      child: ColoredBox(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.65,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Text(
                              product.isSoldOut
                                  ? l10n.productSoldOut
                                  : l10n.productUnavailable,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(
                compact || catalogStyle ? AppSpacing.sm : AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact || catalogStyle
                                ? theme.textTheme.labelLarge
                                : theme.textTheme.bodyMedium)
                            ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: compact || catalogStyle ? 3 : AppSpacing.xs),
                  if (catalogStyle)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            Uzs.format(product.price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ProductCartControl(
                          product: product,
                          storeType: storeType,
                          compact: true,
                          inReview: inReview,
                          iconOnlyWhenEmpty: true,
                          inlineCompact: true,
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      Uzs.format(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? theme.textTheme.labelMedium
                                  : theme.textTheme.titleSmall)
                              ?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                    ProductCartControl(
                      product: product,
                      storeType: storeType,
                      compact: compact,
                      inReview: inReview,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndReport(BuildContext context, WidgetRef ref) async {
    if (!await requireAuthentication(context, ref) || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reportProductConfirmTitle),
        content: Text(l10n.reportProductConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reportProductConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(productReportControllerProvider.notifier)
        .report(product.id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.reportProductSuccess)),
      );
      return;
    }
    final failure = ref.read(productReportControllerProvider).failure;
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.localize(l10n))));
    }
  }
}

class ProductCartControl extends ConsumerWidget {
  const ProductCartControl({
    required this.product,
    required this.storeType,
    this.compact = false,
    this.inReview = false,
    this.iconOnlyWhenEmpty = false,
    this.inlineCompact = false,
    super.key,
  });

  final ProductSummary product;
  final StoreType storeType;
  final bool compact;
  final bool inReview;
  final bool iconOnlyWhenEmpty;
  final bool inlineCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final provider = cartControllerProvider(storeType);
    final cartAsync = ref.watch(provider);
    final cartState = cartAsync.value;
    final simpleLine = _simpleLine(cartState?.cart.items ?? const []);
    final controller = ref.read(provider.notifier);
    final configuration = CartConfiguration(productId: product.id);
    final addBusy = cartState?.isBusy(configuration.identity) ?? false;
    final itemBusy = simpleLine == null
        ? false
        : cartState?.isBusy('item:${simpleLine.id}') ?? false;
    final waitingForCart = cartAsync.isLoading && cartState == null;
    final height = inlineCompact
        ? 34.0
        : compact
        ? 32.0
        : 40.0;

    // Tekshiruvda: stepper ham chiqmaydi — miqdor o'zgartirish ham bloklanadi.
    if (simpleLine != null && !product.requiresConfiguration && !inReview) {
      return SizedBox(
        key: ValueKey('product-card-stepper-${product.id}'),
        width: inlineCompact ? 104 : double.infinity,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SmallStepButton(
                  icon: Icons.remove,
                  onPressed: itemBusy
                      ? null
                      : () => _runMutation(
                          context,
                          ref,
                          () => controller.decrement(simpleLine),
                        ),
                ),
              ),
              Expanded(
                child: Center(
                  child: itemBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${simpleLine.quantity}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                ),
              ),
              Expanded(
                child: _SmallStepButton(
                  icon: Icons.add,
                  onPressed: itemBusy
                      ? null
                      : () => _runMutation(
                          context,
                          ref,
                          () => controller.increment(simpleLine),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final child = waitingForCart || addBusy
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : iconOnlyWhenEmpty
        ? const Icon(Icons.add, size: 18)
        : Text(
            inReview ? l10n.productInReview : l10n.productBuy,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    final onPressed =
        inReview ||
            !product.isPurchasable ||
            waitingForCart ||
            cartAsync.hasError ||
            addBusy
        ? null
        : product.requiresConfiguration
        ? () => openStoreProduct(context, storeType, product.id)
        : () => _addProduct(context, ref, controller);

    return SizedBox(
      width: inlineCompact ? 36 : double.infinity,
      height: height,
      child: iconOnlyWhenEmpty
          ? FilledButton(
              key: ValueKey('product-card-buy-${product.id}'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(),
              ),
              child: child,
            )
          : FilledButton.tonal(
              key: ValueKey('product-card-buy-${product.id}'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
                ),
                textStyle:
                    (compact
                            ? Theme.of(context).textTheme.labelSmall
                            : Theme.of(context).textTheme.labelLarge)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onPressed,
              child: child,
            ),
    );
  }

  CartItem? _simpleLine(List<CartItem> items) {
    for (final item in items) {
      if (item.product.id == product.id &&
          item.variant == null &&
          item.selectedAddons.isEmpty &&
          item.note.trim().isEmpty) {
        return item;
      }
    }
    return null;
  }

  Future<void> _addProduct(
    BuildContext context,
    WidgetRef ref,
    CartController controller,
  ) async {
    final success = await controller.addProduct(product);
    if (!context.mounted) return;
    if (success) {
      showProductAddedSnackBar(context);
      return;
    }
    final failure = ref
        .read(cartControllerProvider(storeType))
        .value
        ?.mutationFailure;
    if (failure == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure.localize(AppLocalizations.of(context)))),
      );
  }

  Future<void> _runMutation(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() mutation,
  ) async {
    await mutation();
    if (!context.mounted) return;
    final failure = ref
        .read(cartControllerProvider(storeType))
        .value
        ?.mutationFailure;
    if (failure == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure.localize(AppLocalizations.of(context)))),
      );
  }
}

void showProductAddedSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: colors.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: Text(l10n.productAdded)),
          ],
        ),
      ),
    );
}

class _SmallStepButton extends StatelessWidget {
  const _SmallStepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.expand(),
    padding: EdgeInsets.zero,
  );
}
