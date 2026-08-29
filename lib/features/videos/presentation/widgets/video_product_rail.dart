import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../catalog/presentation/widgets/product_card.dart';
import '../../data/video_models.dart';
import '../../domain/video_feed_controller.dart';

class VideoProductRailSection extends ConsumerWidget {
  const VideoProductRailSection({
    required this.videoId,
    this.cardHeight = 230,
    super.key,
  });

  final String videoId;
  final double cardHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rail = ref.watch(videoProductRailProvider(videoId));
    return switch (rail) {
      AsyncData(:final value) when value.products.isEmpty =>
        const SizedBox.shrink(),
      AsyncData(:final value) => _LoadedRail(
        rail: value,
        videoId: videoId,
        cardHeight: cardHeight,
      ),
      AsyncError(:final error) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    error is ApiFailure
                        ? error.localize(AppLocalizations.of(context))
                        : AppLocalizations.of(context).videoProductsLoadError,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(videoProductRailProvider(videoId)),
                  child: Text(AppLocalizations.of(context).commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _LoadedRail extends StatelessWidget {
  const _LoadedRail({
    required this.rail,
    required this.videoId,
    required this.cardHeight,
  });

  final VideoProductRail rail;
  final String videoId;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final storeType = StoreType.fromWire(rail.storeType);
    if (storeType == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rail.category ?? l10n.videoProductsTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = AppSpacing.sm;
                  final cardWidth = (constraints.maxWidth - (gap * 2)) / 3;
                  final products = rail.products.take(15).toList();
                  return SizedBox(
                    height: cardHeight,
                    child: ListView.separated(
                      key: PageStorageKey('video-products-$videoId'),
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: gap),
                      itemBuilder: (context, index) => SizedBox(
                        key: index < products.length
                            ? ValueKey('video-product-${products[index].id}')
                            : ValueKey('video-products-see-all-$videoId'),
                        width: cardWidth,
                        child: index < products.length
                            ? ProductCard(
                                product: products[index],
                                storeType: storeType,
                                compact: true,
                              )
                            : _SeeAllCard(
                                onTap: () => context.push(
                                  Routes.storeCatalog(
                                    storeType.wire,
                                    categoryId: rail.categoryId,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllCard extends StatelessWidget {
  const _SeeAllCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.primaryContainer,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_view_rounded, size: 30),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppLocalizations.of(context).videoSeeAllProducts,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}
