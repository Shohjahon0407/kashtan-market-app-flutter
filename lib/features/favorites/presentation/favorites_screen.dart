import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/presentation/widgets/catalog_loading_skeleton.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../../store/presentation/widgets/store_switch_button.dart';
import '../domain/favorites_controller.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({required this.storeType, super.key});

  final StoreType storeType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.favoritesTitle),
        actions: [StoreSwitchButton(storeType: storeType)],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(favoritesControllerProvider.notifier).refresh(),
        child: switch (favorites) {
          AsyncData(:final value) when value.forStore(storeType).isEmpty =>
            StoreEmptyView(
              icon: Icons.favorite_border,
              title: l10n.favoritesEmpty,
            ),
          AsyncData(:final value) => GridView.builder(
            key: PageStorageKey('favorites-${storeType.wire}'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenH),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.58,
            ),
            itemCount: value.forStore(storeType).length,
            itemBuilder: (context, index) => ProductCard(
              product: value.forStore(storeType)[index].product,
              storeType: storeType,
            ),
          ),
          AsyncError(:final error) => StoreErrorView(
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
            onRetry: () =>
                ref.read(favoritesControllerProvider.notifier).refresh(),
          ),
          _ => const CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [CatalogGridSkeletonSliver()],
          ),
        },
      ),
    );
  }
}
