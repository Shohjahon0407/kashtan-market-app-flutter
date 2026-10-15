import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/utils/debouncer.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../catalog/data/product_models.dart';
import '../../catalog/presentation/widgets/product_card.dart';
import '../../catalog/presentation/widgets/product_image.dart';
import '../domain/search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _debouncer = Debouncer(const Duration(milliseconds: 350));

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _scroll.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  void _onChanged(String value) {
    setState(() {});
    _debouncer(() => ref.read(searchControllerProvider.notifier).search(value));
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    ref.read(searchControllerProvider.notifier).search('');
    _focus.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(searchControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.screenH,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: () => appBack(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('global-search-field'),
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          onSubmitted: (value) {
                            _debouncer.cancel();
                            ref
                                .read(searchControllerProvider.notifier)
                                .search(value);
                          },
                          decoration: InputDecoration(
                            hintText: l10n.searchHint,
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _controller.text.isEmpty
                                ? null
                                : IconButton(
                                    key: const ValueKey('global-search-clear'),
                                    tooltip: l10n.commonClose,
                                    onPressed: _clear,
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _SearchBody(state: state, scroll: _scroll),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.state, required this.scroll});

  final SearchState state;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (state.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    if (state.failure != null) {
      return _CenteredHint(
        icon: Icons.error_outline,
        text: state.failure!.localize(l10n),
      );
    }
    if (!state.searched) {
      return _CenteredHint(
        icon: Icons.manage_search,
        text: l10n.searchStartTyping,
      );
    }

    final products = state.items
        .where((item) => item.storeType != null)
        .toList();
    return CustomScrollView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  l10n.searchResultsCount(products.length).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        ),
        if (products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: _CenteredHint(
                icon: Icons.search_off,
                text: l10n.searchEmpty,
                compact: true,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenH,
              vertical: AppSpacing.sm,
            ),
            sliver: SliverList.separated(
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  _SearchProductTile(product: products[index]),
              separatorBuilder: (_, _) => const SizedBox(height: 2),
            ),
          ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xxxl,
          ),
          sliver: SliverToBoxAdapter(
            child: _MissingResultCta(
              onTap: () =>
                  pushAuthenticated(context, ref, Routes.missingProductRequest),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchProductTile extends StatelessWidget {
  const _SearchProductTile({required this.product});

  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    final storeType = product.storeType!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        onTap: () =>
            context.push(Routes.productDetail(storeType.wire, product.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 62,
                child: ProductImageView(imageUrl: product.imageUrl),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _storeLabel(
                        AppLocalizations.of(context),
                        storeType,
                      ).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Uzs.format(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ProductCartControl(
                      product: product,
                      storeType: storeType,
                      compact: true,
                      inReview: product.inReview,
                      iconOnlyWhenEmpty: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingResultCta extends StatelessWidget {
  const _MissingResultCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      key: const ValueKey('search-missing-product-cta'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.searchMissingTitle.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.searchMissingSubtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                color: colors.primary,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_forward,
                  color: colors.onPrimary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 34 : 48,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _storeLabel(AppLocalizations l10n, StoreType store) => switch (store) {
  StoreType.grocery => l10n.storeGrocery,
  StoreType.household => l10n.storeHousehold,
  StoreType.restaurant => l10n.storeRestaurant,
  StoreType.shashlik => l10n.storeShashlik,
  StoreType.meat => l10n.storeMeat,
};
