import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/home_models.dart';
import 'store_grid.dart';

/// Do'konlar bo'limi — Home'da ham, Do'konlar tabida ham AYNAN shu daraxt
/// (kalitlar, tartib, uslublar bir xil).
class StoresSection extends StatelessWidget {
  const StoresSection({
    super.key,
    required this.items,
    required this.onMissingProductTap,
  });

  final List<StoreHubItem> items;
  final VoidCallback onMissingProductTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final orderedItems = [...items]..sort(_compareHomeStores);
    final totalCardCount = orderedItems.length + 1;
    final count = totalCardCount.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.homeStoresTitle.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              '$count / $count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StoreGrid(
          items: orderedItems,
          trailingCard: MissingProductGridCard(
            number: totalCardCount,
            onTap: onMissingProductTap,
          ),
          onTap: (item) =>
              context.push(Routes.storeCatalog(item.storeTypeWire)),
        ),
      ],
    );
  }

  static int _compareHomeStores(StoreHubItem left, StoreHubItem right) {
    final priority = _homeStorePriority(
      left.storeType,
    ).compareTo(_homeStorePriority(right.storeType));
    if (priority != 0) return priority;
    return left.sortOrder.compareTo(right.sortOrder);
  }

  static int _homeStorePriority(StoreType? storeType) => switch (storeType) {
    StoreType.household => 0,
    StoreType.grocery => 1,
    StoreType.shashlik => 2,
    StoreType.restaurant => 3,
    StoreType.meat => 4,
    null => 5,
  };
}

class MissingProductGridCard extends StatelessWidget {
  const MissingProductGridCard({
    super.key,
    required this.number,
    required this.onTap,
  });

  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const ValueKey('home-missing-product-card'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/stores/missing_product.webp',
                    key: const ValueKey('home-missing-product-image'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: colors.primaryContainer,
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: colors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.primary),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          number.toString().padLeft(2, '0'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 7, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.supportMissingProductTitle.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10.5,
                              height: 1.08,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.supportMissingProductSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeErrorView extends StatelessWidget {
  const HomeErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}

class StoresSkeleton extends StatelessWidget {
  const StoresSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _box(base, height: 12, width: 84),
              const Spacer(),
              _box(base, height: 10, width: 42),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var row = 0; row < 3; row++) ...[
            Row(
              children: [
                Expanded(child: _card(base)),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: _card(base)),
              ],
            ),
            if (row < 2) const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  static Widget _box(Color color, {required double height, double? width}) =>
      Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      );

  static Widget _card(Color color) => AspectRatio(
    aspectRatio: 0.90,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    ),
  );
}
