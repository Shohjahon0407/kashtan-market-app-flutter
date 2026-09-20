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
import '../../../core/ui/theme/contrast.dart';
import '../../../core/utils/debouncer.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../store/data/store_models.dart';
import '../../store/domain/store_landing_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import 'widgets/household_category_landing.dart';
import 'widgets/product_card.dart';
import 'widgets/product_image.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    required this.storeType,
    this.initialCategoryId,
    this.searchOnly = false,
    super.key,
  });

  final StoreType storeType;
  final String? initialCategoryId;
  final bool searchOnly;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(const Duration(milliseconds: 350));
  var _initialCategoryLoading = false;

  bool get _isHouseholdLanding =>
      widget.storeType == StoreType.household &&
      !widget.searchOnly &&
      (widget.initialCategoryId?.isEmpty ?? true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initialCategoryLoading = widget.initialCategoryId?.isNotEmpty ?? false;
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
    if (_isHouseholdLanding) return;
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
    setState(() {});
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
    setState(() {});
    _applySearch('');
  }

  Future<void> _selectCategory(String? categoryId) async {
    _debouncer.cancel();
    _searchController.clear();
    // Controller.clear ayrim Web text-input implementatsiyalarida callback
    // rejalashtirishi mumkin; category so'rovini u bosib ketmasin.
    _debouncer.cancel();
    await ref
        .read(catalogControllerProvider(widget.storeType).notifier)
        .applyFilter(categoryId: categoryId);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else if (widget.storeType == StoreType.household &&
        (widget.searchOnly || widget.initialCategoryId != null)) {
      context.go(Routes.storeCatalog(widget.storeType.wire));
    } else {
      context.go(Routes.home);
    }
  }

  void _openHouseholdSearch() {
    context.push(Routes.storeCatalogSearch(widget.storeType.wire));
  }

  void _openHouseholdCategory(ProductCategory category) {
    context.push(
      Routes.storeCategoryProducts(widget.storeType.wire, category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final landing = ref.watch(storeLandingProvider(widget.storeType));
    final cart = ref
        .watch(cartControllerProvider(widget.storeType))
        .value
        ?.cart;
    final cartQuantity = cart?.totalQuantity ?? 0;

    if (_isHouseholdLanding) {
      return _buildHouseholdLanding(
        context,
        l10n: l10n,
        landing: landing,
        cartQuantity: cartQuantity,
      );
    }

    final watchedCatalog = ref.watch(
      catalogControllerProvider(widget.storeType),
    );
    final catalog = _initialCategoryLoading
        ? const AsyncValue<CatalogState>.loading()
        : watchedCatalog;
    final isSearching = _searchController.text.trim().isNotEmpty;
    final showSearchField =
        widget.storeType != StoreType.household || widget.searchOnly;

    // Snackbar'lar SHU ekranning Scaffold'i bo'yicha joylashsin: floating
    // snackbar o'z Scaffold'ining bottomNavigationBar'idan YUQORIDA chiziladi.
    // Busiz u tashqi shell Scaffold'iga tegishli bo'lib, pastdagi yashil
    // "SAVAT" panelini to'sib qo'yardi.
    return ScaffoldMessenger(
      child: Scaffold(
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
                title: Text(
                  _catalogTitle(
                    l10n,
                    widget.storeType,
                    landing.value,
                    categoryId: widget.initialCategoryId,
                    searchOnly: widget.searchOnly,
                  ),
                ),
                actions: [
                  if (widget.storeType == StoreType.household &&
                      !widget.searchOnly)
                    IconButton(
                      key: const ValueKey('household-search-button'),
                      tooltip: l10n.commonSearch,
                      onPressed: _openHouseholdSearch,
                      icon: const Icon(Icons.search),
                    ),
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
                bottom: showSearchField
                    ? PreferredSize(
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
                              autofocus: widget.searchOnly,
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
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: l10n.commonClose,
                                        onPressed: _clearSearch,
                                        icon: const Icon(Icons.close),
                                      ),
                                suffixIconConstraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              if (!isSearching && widget.storeType != StoreType.household)
                ..._landingSlivers(context, landing),
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
      ),
    );
  }

  Widget _buildHouseholdLanding(
    BuildContext context, {
    required AppLocalizations l10n,
    required AsyncValue<StoreLandingData> landing,
    required int cartQuantity,
  }) {
    final title = landing.value?.header.label.trim();
    return ScaffoldMessenger(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(storeLandingProvider(widget.storeType));
            await ref.read(storeLandingProvider(widget.storeType).future);
          },
          child: CustomScrollView(
            key: const PageStorageKey('catalog-household-categories'),
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
                title: Text(
                  title == null || title.isEmpty ? l10n.storeHousehold : title,
                ),
                actions: [
                  IconButton(
                    key: const ValueKey('household-search-button'),
                    tooltip: l10n.commonSearch,
                    onPressed: _openHouseholdSearch,
                    icon: const Icon(Icons.search),
                  ),
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
              ),
              ...switch (landing) {
                AsyncData(:final value) => [
                  HouseholdCategoryLandingSliver(
                    categories: value.categories,
                    onCategoryTap: _openHouseholdCategory,
                  ),
                ],
                AsyncError(:final error) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: StoreErrorView(
                      message: error is ApiFailure
                          ? error.localize(l10n)
                          : l10n.errorUnknown,
                      onRetry: () => ref.invalidate(
                        storeLandingProvider(widget.storeType),
                      ),
                    ),
                  ),
                ],
                _ => const [HouseholdCategoryLandingSkeleton()],
              },
            ],
          ),
        ),
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
    final background =
        banner?.backgroundColor ??
        header.accentColor ??
        colors.primaryContainer;
    // Rasmsiz hero: admin matn rangini bermagan bo'lsa fon yorqinligiga
    // qarab tanlanadi — to'q fon ustida to'q matn bo'lib qolmasin.
    final foreground = imageUrl == null
        ? banner?.textColor ?? onAccent(background)
        : Colors.white;

    return Material(
      color: background,
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

String _catalogTitle(
  AppLocalizations l10n,
  StoreType storeType,
  StoreLandingData? landing, {
  String? categoryId,
  bool searchOnly = false,
}) {
  if (searchOnly) return l10n.commonSearch;
  if (storeType != StoreType.household) return _storeName(l10n, storeType);
  if (categoryId != null) {
    for (final category in landing?.categories ?? const <ProductCategory>[]) {
      if (category.id == categoryId) return category.name;
    }
  }
  final label = landing?.header.label.trim();
  return label == null || label.isEmpty ? l10n.storeHousehold : label;
}
