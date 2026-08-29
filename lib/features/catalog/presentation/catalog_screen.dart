import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/utils/debouncer.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../store/data/store_models.dart';
import '../../store/domain/store_landing_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import 'widgets/product_card.dart';
import 'widgets/product_image.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.storeType,
    this.initialCategoryId,
    super.key,
  });

  final StoreType storeType;
  final String? initialCategoryId;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(const Duration(milliseconds: 350));
  var _initialCategoryLoading = false;
  String? _householdCategoryId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialCategoryLoading = widget.initialCategoryId?.isNotEmpty ?? false;
    _householdCategoryId = widget.initialCategoryId;
    if (_initialCategoryLoading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _applyInitialCategory(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      ref.read(catalogControllerProvider(widget.storeType).notifier).loadMore();
    }
  }

  Future<void> _applyInitialCategory() async {
    try {
      await ref.read(catalogControllerProvider(widget.storeType).future);
      if (!mounted) return;
      await ref
          .read(catalogControllerProvider(widget.storeType).notifier)
          .applyFilter(categoryId: widget.initialCategoryId);
    } finally {
      if (mounted) setState(() => _initialCategoryLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty) _householdCategoryId = null;
    });
    _debouncer(() {
      _applySearch(value);
    });
  }

  void _submitSearch([String? value]) {
    _debouncer.cancel();
    _applySearch(value ?? _searchController.text);
  }

  void _applySearch(String value) {
    ref
        .read(catalogControllerProvider(widget.storeType).notifier)
        .applyFilter(query: value);
  }

  void _clearSearch() {
    _debouncer.cancel();
    _searchController.clear();
    // Controller.clear web/text-input implementatsiyasida onChanged'ni ham
    // uyg'otishi mumkin; u rejalashtirgan ikkinchi so'rovni bekor qilamiz.
    _debouncer.cancel();
    setState(() => _householdCategoryId = null);
    _applySearch('');
  }

  Future<void> _showHouseholdCategoryFilter(
    List<ProductCategory> categories,
  ) async {
    if (categories.isEmpty) return;
    final result = await showModalBottomSheet<_CategoryFilterResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CategoryFilterSheet(
        categories: categories,
        selectedId: _householdCategoryId,
      ),
    );
    if (!mounted || result == null) return;

    await _selectCategory(result.categoryId);
  }

  Future<void> _selectCategory(String? categoryId) async {
    _debouncer.cancel();
    _searchController.clear();
    // Controller.clear ayrim Web text-input implementatsiyalarida callback
    // rejalashtirishi mumkin; category so'rovini u bosib ketmasin.
    _debouncer.cancel();
    if (widget.storeType == StoreType.household && mounted) {
      setState(() => _householdCategoryId = categoryId);
    }
    await ref
        .read(catalogControllerProvider(widget.storeType).notifier)
        .applyFilter(categoryId: categoryId);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final watchedCatalog = ref.watch(
      catalogControllerProvider(widget.storeType),
    );
    final catalog = _initialCategoryLoading
        ? const AsyncValue<CatalogState>.loading()
        : watchedCatalog;
    final landing = ref.watch(storeLandingProvider(widget.storeType));
    final isSearching = _searchController.text.trim().isNotEmpty;
    final householdCategories = landing.value?.categories;
    final cart = ref
        .watch(cartControllerProvider(widget.storeType))
        .value
        ?.cart;
    final cartQuantity = cart?.totalQuantity ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(storeLandingProvider(widget.storeType));
          await ref
              .read(catalogControllerProvider(widget.storeType).notifier)
              .refresh();
        },
        child: CustomScrollView(
          key: PageStorageKey('catalog-${widget.storeType.wire}'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(_storeTitle(l10n, widget.storeType, landing.value)),
              actions: [
                IconButton(
                  key: const ValueKey('catalog-cart-button'),
                  tooltip: l10n.navCart,
                  onPressed: () =>
                      goToStoreTab(context, widget.storeType, StoreTab.cart),
                  icon: Badge(
                    isLabelVisible: cartQuantity > 0,
                    label: Text(cartQuantity > 99 ? '99+' : '$cartQuantity'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(68),
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      AppSpacing.xs,
                      AppSpacing.screenH,
                      AppSpacing.sm,
                    ),
                    child: TextField(
                      key: const ValueKey('catalog-search-field'),
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onSubmitted: _submitSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.catalogSearchHint,
                        prefixIcon: IconButton(
                          tooltip: l10n.commonSearch,
                          onPressed: _submitSearch,
                          icon: const Icon(Icons.search),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close),
                              ),
                            if (widget.storeType == StoreType.household)
                              IconButton(
                                key: const ValueKey(
                                  'household-category-filter',
                                ),
                                tooltip: l10n.catalogCategoryFilter,
                                onPressed:
                                    householdCategories == null ||
                                        householdCategories.isEmpty
                                    ? null
                                    : () => _showHouseholdCategoryFilter(
                                        householdCategories,
                                      ),
                                icon: Badge(
                                  isLabelVisible:
                                      !isSearching &&
                                      _householdCategoryId != null,
                                  smallSize: 7,
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color:
                                        !isSearching &&
                                            _householdCategoryId != null
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 48,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isSearching) ..._landingSlivers(context, landing),
            ..._catalogSlivers(context, catalog, isSearching: isSearching),
            SliverToBoxAdapter(
              child: SizedBox(
                height: cartQuantity > 0 ? AppSpacing.huge : AppSpacing.xxl,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cartQuantity == 0
          ? null
          : _MiniCartBar(
              quantity: cartQuantity,
              subtotal: cart?.subtotal ?? '0',
              onTap: () =>
                  goToStoreTab(context, widget.storeType, StoreTab.cart),
            ),
    );
  }

  List<Widget> _landingSlivers(
    BuildContext context,
    AsyncValue<StoreLandingData> landing,
  ) {
    final data = landing.value;
    if (data == null) {
      if (landing.isLoading) {
        return const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ];
      }
      return const [];
    }

    final visibleCategories = data.categories;
    final heroBanner = data.banners.isEmpty ? null : data.banners.first;
    return [
      if (heroBanner != null ||
          (data.header.showHeader &&
              (data.header.label.isNotEmpty ||
                  data.header.subtitle.isNotEmpty ||
                  data.header.imageUrl != null)))
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _StoreHero(
              header: data.header,
              banner: heroBanner,
              onTap: heroBanner == null ? null : () => _onBannerTap(heroBanner),
            ),
          ),
        ),
      if (visibleCategories.isNotEmpty)
        SliverToBoxAdapter(
          child: _CategoryRail(
            categories: visibleCategories,
            selectedId: ref
                .watch(catalogControllerProvider(widget.storeType))
                .value
                ?.categoryId,
            onSelected: _selectCategory,
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
    ];
  }

  List<Widget> _catalogSlivers(
    BuildContext context,
    AsyncValue<CatalogState> catalog, {
    required bool isSearching,
  }) {
    final l10n = AppLocalizations.of(context);
    return switch (catalog) {
      AsyncData(:final value) when value.items.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StoreEmptyView(
            icon: Icons.inventory_2_outlined,
            title: isSearching ? l10n.searchEmpty : l10n.catalogEmpty,
            action: isSearching
                ? FilledButton.tonalIcon(
                    onPressed: () => pushAuthenticated(
                      context,
                      ref,
                      Routes.requestsFor(
                        kind: 'missing_product',
                        storeType: widget.storeType.wire,
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(l10n.supportRequestProductAction),
                  )
                : null,
          ),
        ),
      ],
      AsyncData(:final value) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            0,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.70,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(
                product: value.items[index],
                storeType: widget.storeType,
                catalogStyle: true,
              ),
              childCount: value.items.length,
            ),
          ),
        ),
        if (value.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (value.loadMoreFailure != null)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: () => ref
                    .read(catalogControllerProvider(widget.storeType).notifier)
                    .loadMore(),
                child: Text(l10n.commonRetry),
              ),
            ),
          ),
      ],
      AsyncError(:final error) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StoreErrorView(
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
            onRetry: () => ref
                .read(catalogControllerProvider(widget.storeType).notifier)
                .refresh(),
          ),
        ),
      ],
      _ => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
  }

  void _onBannerTap(StoreBanner banner) {
    if (banner.targetProductId != null) {
      context.push(
        Routes.productDetail(widget.storeType.wire, banner.targetProductId!),
      );
      return;
    }
    if (banner.targetCategoryId != null) {
      ref
          .read(catalogControllerProvider(widget.storeType).notifier)
          .applyFilter(categoryId: banner.targetCategoryId);
      return;
    }
    final bundleId = banner.targetBundleId ?? banner.bundle?.id;
    if (bundleId != null) {
      ref
          .read(cartControllerProvider(widget.storeType).notifier)
          .addBundle(bundleId);
    }
  }
}

class _CategoryFilterResult {
  const _CategoryFilterResult(this.categoryId);

  final String? categoryId;
}

class _CategoryFilterSheet extends StatelessWidget {
  const _CategoryFilterSheet({
    required this.categories,
    required this.selectedId,
  });

  final List<ProductCategory> categories;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preferredHeight = 78.0 + ((categories.length + 1) * 52.0);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;
    final height = preferredHeight.clamp(180.0, maxHeight).toDouble();
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                0,
                AppSpacing.screenH,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.catalogCategoryFilter,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  _CategoryFilterTile(
                    key: const ValueKey('household-category-all'),
                    label: l10n.commonAll,
                    selected: selectedId == null,
                    onTap: () => Navigator.pop(
                      context,
                      const _CategoryFilterResult(null),
                    ),
                  ),
                  for (final category in categories)
                    _CategoryFilterTile(
                      key: ValueKey('household-category-${category.id}'),
                      label: category.name,
                      selected: selectedId == category.id,
                      onTap: () => Navigator.pop(
                        context,
                        _CategoryFilterResult(category.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterTile extends StatelessWidget {
  const _CategoryFilterTile({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? colors.primary : colors.onSurface,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: colors.primary)
          : null,
      onTap: onTap,
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.header,
    required this.banner,
    required this.onTap,
  });

  final StoreHeader header;
  final StoreBanner? banner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = banner?.title.trim().isNotEmpty == true
        ? banner!.title.trim()
        : header.label.trim();
    final subtitle = banner?.subtitle.trim().isNotEmpty == true
        ? banner!.subtitle.trim()
        : header.subtitle.trim();
    final imageUrl = banner?.imageUrl ?? header.imageUrl;
    final foreground = imageUrl == null
        ? banner?.textColor ?? colors.onPrimaryContainer
        : Colors.white;

    return Material(
      color:
          banner?.backgroundColor ??
          header.accentColor ??
          colors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 116,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null)
                ProductImageView(imageUrl: imageUrl)
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xl),
                    child: Icon(
                      Icons.storefront_outlined,
                      size: 44,
                      color: foreground.withValues(alpha: 0.42),
                    ),
                  ),
                ),
              if (imageUrl != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.70),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: foreground),
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

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ProductCategory> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 50,
      child: ListView(
        key: const ValueKey('catalog-category-rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenH,
          vertical: AppSpacing.xs,
        ),
        children: [
          ChoiceChip(
            label: Text(l10n.commonAll),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              avatar: category.iconUrl == null
                  ? null
                  : CircleAvatar(
                      // Disk keshli provider — ikonkalar oflaynda ham chiqadi.
                      backgroundImage: CachedNetworkImageProvider(
                        category.iconUrl!,
                      ),
                    ),
              label: Text(category.name),
              selected: selectedId == category.id,
              onSelected: (_) => onSelected(category.id),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniCartBar extends StatelessWidget {
  const _MiniCartBar({
    required this.quantity,
    required this.subtotal,
    required this.onTap,
  });

  final int quantity;
  final String subtotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xs,
              AppSpacing.screenH,
              AppSpacing.sm,
            ),
            child: Material(
              color: colors.primary,
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('catalog-mini-cart'),
                onTap: onTap,
                child: SizedBox(
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 19,
                          color: colors.onPrimary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '${l10n.cartTitle.toUpperCase()} · '
                            '${l10n.cartItemsCount(quantity)}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Text(
                          Uzs.format(subtotal),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _storeName(AppLocalizations l10n, StoreType storeType) =>
    switch (storeType) {
      StoreType.grocery => l10n.storeGrocery,
      StoreType.household => l10n.storeHousehold,
      StoreType.restaurant => l10n.storeRestaurant,
      StoreType.shashlik => l10n.storeShashlik,
      StoreType.meat => l10n.storeMeat,
    };

String _storeTitle(
  AppLocalizations l10n,
  StoreType storeType,
  StoreLandingData? landing,
) {
  if (storeType != StoreType.household) return _storeName(l10n, storeType);

  final headerLabel = landing?.header.label.trim().toLowerCase() ?? '';
  String? description;
  if (headerLabel.isNotEmpty) {
    for (final store in landing?.stores ?? const <StoreInfo>[]) {
      if (store.name.trim().toLowerCase() == headerLabel &&
          store.description.trim().isNotEmpty) {
        description = store.description;
        break;
      }
    }
  }

  final rawCount = RegExp(
    r'\d[\d\s.,]*',
  ).firstMatch(description ?? '')?.group(0);
  final digits = rawCount?.replaceAll(RegExp(r'\D'), '');
  final count = int.tryParse(digits ?? '') ?? 1005;
  return l10n.catalogProductVarietyCount(count);
}
