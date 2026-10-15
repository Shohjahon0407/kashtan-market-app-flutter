import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/store_scope/store_type.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../catalog/presentation/widgets/product_rail.dart';
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
          child: ProductRail(
            title: rail.category ?? l10n.videoProductsTitle,
            products: rail.products,
            storeType: storeType,
            keyPrefix: 'video-product',
            cardHeight: cardHeight,
            storageKey: PageStorageKey('video-products-$videoId'),
            seeAllKey: ValueKey('video-products-see-all-$videoId'),
            onSeeAll: () => context.push(
              Routes.storeCatalog(storeType.wire, categoryId: rail.categoryId),
            ),
          ),
        ),
      ),
    );
  }
}
