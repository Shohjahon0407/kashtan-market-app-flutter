import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_dimens.dart';

/// Katalog ochilayotganda markazda aylanuvchi indikator o'rniga final
/// layoutga o'xshash, animatsiyasiz placeholder. Bu GPU/CPU'ni band qilmaydi
/// va kontent kelganda sahifa sakrashini kamaytiradi.
class RestaurantProductListSkeletonSliver extends StatelessWidget {
  const RestaurantProductListSkeletonSliver({this.itemCount = 3, super.key});
  final int itemCount;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.all(AppSpacing.screenH),
    sliver: SliverList.separated(
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: constraints.maxWidth * 9 / 16 + 58,
              child: _ProductPlaceholder(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CatalogGridSkeletonSliver extends StatelessWidget {
  const CatalogGridSkeletonSliver({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.70,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, _) => _ProductPlaceholder(color: color),
          childCount: itemCount,
        ),
      ),
    );
  }
}

class CatalogLandingSkeletonSliver extends StatelessWidget {
  const CatalogLandingSkeletonSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    right: index == 2 ? 0 : AppSpacing.sm,
                  ),
                  child: Container(
                    width: 82,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogRowsSkeleton extends StatelessWidget {
  const CatalogRowsSkeleton({this.itemCount = 5, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      key: const ValueKey('catalog-rows-skeleton'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(
        height: 104,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class ProductDetailLoadingSkeleton extends StatelessWidget {
  const ProductDetailLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final width = MediaQuery.sizeOf(context).width;
    return ListView(
      key: const ValueKey('product-detail-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(height: width.clamp(260.0, 420.0), color: color),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(color, width: 210, height: 24),
              const SizedBox(height: AppSpacing.sm),
              _line(color, width: 96, height: 14),
              const SizedBox(height: AppSpacing.lg),
              _line(color, width: 150, height: 22),
              const SizedBox(height: AppSpacing.xl),
              _line(color, width: double.infinity, height: 15),
              const SizedBox(height: AppSpacing.sm),
              _line(color, width: 260, height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(Color color, {required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      );
}

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: double.infinity, height: 13, color: color),
              const SizedBox(height: AppSpacing.sm),
              Container(width: 82, height: 13, color: color),
            ],
          ),
        ),
      ],
    ),
  );
}
