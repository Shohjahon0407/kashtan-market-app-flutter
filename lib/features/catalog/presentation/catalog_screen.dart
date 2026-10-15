import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/ui/theme/contrast.dart';
import '../../../core/utils/debouncer.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../recommendations/domain/interaction_tracker.dart';
import '../../recommendations/presentation/similar_products_rail.dart';
import '../../store/data/store_models.dart';
import '../../store/domain/store_landing_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import 'widgets/catalog_loading_skeleton.dart';
import 'widgets/household_category_landing.dart';
import 'widgets/imageless_reveal.dart';
import 'widgets/meat_product_card.dart';
import 'widgets/photo_category_landing.dart';
import 'widgets/product_card.dart';
import 'widgets/product_image.dart';
import 'widgets/restaurant_category_landing.dart';
import 'widgets/shashlik_catalog.dart';

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
  var _shashlikSection = ShashlikSection.kebabs;

  /// User ochib qaytgan mahsulotlar — grid'da shu mahsulot qatoridan keyin
  /// "«X»ga o'xshashlar" qatori chiqadi (keyingi scrollda ko'proq shunga
  /// o'xshash narsalar).
  final List<ProductViewSignal> _inlineSimilar = [];
  static const _maxInlineRails = 4;
  static const _minItemsBetweenRails = 12;
  static const _gridColumns = 2;

  void _onProductViewed(ProductViewSignal? signal) {
    if (signal == null || signal.storeType != widget.storeType) return;
    if (_isPhotoCategoryLanding || _isMeatCatalog || _isShashlikCatalog) return;
    final state = ref.read(catalogControllerProvider(widget.storeType)).value;
    if (state == null || state.query.isNotEmpty) return;
    final index = state.items.indexWhere((p) => p.id == signal.productId);
    if (index < 0) return;
    if (_inlineSimilar.any((s) => s.productId == signal.productId)) return;
    final tooClose = _inlineSimilar.any((existing) {
      final other = state.items.indexWhere((p) => p.id == existing.productId);
      return other >= 0 && (other - index).abs() < _minItemsBetweenRails;
    });
    if (tooClose) return;
    setState(() {
      _inlineSimilar.add(signal);
      while (_inlineSimilar.length > _maxInlineRails) {
        _inlineSimilar.removeAt(0);
      }
    });
  }

  /// Grid'ni o'xshashlar qatorlari bilan bo'laklarga ajratadi.
  List<Widget> _gridWithInlineRails(List<ProductSummary> items) {
    final breaks = <int, ProductViewSignal>{};
    for (final signal in _inlineSimilar) {
      final index = items.indexWhere((p) => p.id == signal.productId);
      if (index < 0) continue;
      // Shu mahsulot turgan qatorning oxiridan keyin.
      final rowEnd = ((index ~/ _gridColumns) + 1) * _gridColumns;
      if (rowEnd >= items.length) continue;
      breaks[rowEnd] = signal;
    }
    final cuts = breaks.keys.toList()..sort();
    final slivers = <Widget>[];
    var start = 0;
    for (final cut in [...cuts, items.length]) {
      if (cut > start) {
        slivers.add(_gridChunk(items, start, cut));
      }
      final signal = breaks[cut];
      if (signal != null) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            sliver: SliverToBoxAdapter(
              child: SimilarProductsRail(
                productId: signal.productId,
                productName: signal.name,
                storeType: widget.storeType,
                imagesOnly: true,
              ),
            ),
          ),
        );
      }
      start = cut;
    }
    return slivers;
  }

  Widget _gridChunk(List<ProductSummary> items, int start, int end) =>
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          start == 0 ? AppSpacing.md : AppSpacing.sm,
          AppSpacing.screenH,
          0,
        ),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridColumns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.70,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ProductCard(
              product: items[start + index],
              storeType: widget.storeType,
              catalogStyle: true,
            ),
            childCount: end - start,
          ),
        ),
      );

  bool get _supportsPhotoCategoryLanding =>
      widget.storeType == StoreType.household ||
      widget.storeType == StoreType.restaurant;

  bool get _isPhotoCategoryLanding =>
      _supportsPhotoCategoryLanding &&
      !widget.searchOnly &&
      (widget.initialCategoryId?.isEmpty ?? true);

  bool get _isMeatCatalog =>
      widget.storeType == StoreType.meat &&
      !widget.searchOnly &&
      (widget.initialCategoryId?.isEmpty ?? true);

  bool get _isShashlikCatalog =>
      widget.storeType == StoreType.shashlik &&
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
    if (!mounted ||
        !_scrollController.hasClients ||
        _isPhotoCategoryLanding ||
        _isShashlikCatalog ||
        _isMeatCatalog) {
      return;
    }
    if (_scrollController.position.extentAfter < 500) {
      final value = ref.read(catalogControllerProvider(widget.storeType)).value;
      if (value?.loadMoreFailure != null) return;
      ref.read(catalogControllerProvider(widget.storeType).notifier).loadMore();
    }
  }

  void _revealImageless() {
    ref
        .read(catalogControllerProvider(widget.storeType).notifier)
        .revealImageless();
  }

  Widget _revealBoundary(CatalogState? value, Widget child, {bool? enabled}) =>
      ImagelessRevealBoundary(
        controller: _scrollController,
        enabled: enabled ?? (value?.canRevealImageless ?? false),
        onReveal: _revealImageless,
        child: child,
      );

  Widget? _shashlikRevealPrompt(CatalogState value) =>
      !value.imagelessRevealed &&
          ShashlikCatalogGroups.fromProducts(
            value.items,
          ).hasImageless(_shashlikSection)
      ? ImagelessRevealPrompt(onReveal: _revealImageless)
      : null;

  Future<void> _applyInitialCategory() async {
    try {
      await ref.read(catalogControllerProvider(widget.storeType).future);
      if (!mounted) return;
      if (ref
              .read(catalogControllerProvider(widget.storeType))
              .value
              ?.categoryId ==
          widget.initialCategoryId) {
        return;
      }
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

  void _goBack() => appBack(context);

  void _openCategorySearch() {
    context.push(Routes.storeCatalogSearch(widget.storeType.wire));
  }

  void _openPhotoCategory(ProductCategory category) {
    context.push(
      Routes.storeCategoryProducts(widget.storeType.wire, category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProductViewSignal?>(
      lastProductViewProvider,
      (_, next) => _onProductViewed(next),
    );
    final l10n = AppLocalizations.of(context);
    final landing = ref.watch(storeLandingProvider(widget.storeType));
    final cart = ref
        .watch(cartControllerProvider(widget.storeType))
        .value
        ?.cart;
    final cartQuantity = cart?.totalQuantity ?? 0;

    if (_isPhotoCategoryLanding) {
      return _buildPhotoCategoryLanding(
        context,
        l10n: l10n,
        landing: landing,
        cartQuantity: cartQuantity,
      );
    }

    final watchedCatalog = ref.watch(
      catalogControllerProvider(widget.storeType),
    );
    final initialCategory = widget.initialCategoryId;
    final hasMatchingInitialCategory =
        initialCategory != null &&
        watchedCatalog.value?.categoryId == initialCategory;
    final catalog = _initialCategoryLoading && !hasMatchingInitialCategory
        ? const AsyncValue<CatalogState>.loading()
        : watchedCatalog;
    if (_isMeatCatalog) {
      return _buildMeatCatalog(
        context,
        l10n: l10n,
        catalog: catalog,
        cartQuantity: cartQuantity,
        cartSubtotal: cart?.subtotal ?? '0',
      );
    }
    if (_isShashlikCatalog) {
      return _buildShashlikCatalog(
        context,
        l10n: l10n,
        catalog: catalog,
        cartQuantity: cartQuantity,
      );
    }
    final isSearching = _searchController.text.trim().isNotEmpty;
    final showSearchField = !_supportsPhotoCategoryLanding || widget.searchOnly;
    if (catalog.value?.canAutoLoadMore ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }

    // Snackbar'lar SHU ekranning Scaffold'i bo'yicha joylashsin: floating
    // snackbar o'z Scaffold'ining bottomNavigationBar'idan YUQORIDA chiziladi.
    // Busiz u tashqi shell Scaffold'iga tegishli bo'lib, pastdagi yashil
    // "SAVAT" panelini to'sib qo'yardi.
    return ScaffoldMessenger(
      child: Scaffold(
        body: _revealBoundary(
          catalog.value,
          RefreshIndicator(
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
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
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
                    if (_supportsPhotoCategoryLanding && !widget.searchOnly)
                      IconButton(
                        key: ValueKey('${widget.storeType.wire}-search-button'),
                        tooltip: l10n.commonSearch,
                        onPressed: _openCategorySearch,
                        icon: const Icon(Icons.search),
                      ),
                    IconButton(
                      key: const ValueKey('catalog-cart-button'),
                      tooltip: l10n.navCart,
                      onPressed: () => goToStoreTab(
                        context,
                        widget.storeType,
                        StoreTab.cart,
                      ),
                      icon: Badge(
                        isLabelVisible: cartQuantity > 0,
                        label: Text(
                          cartQuantity > 99 ? '99+' : '$cartQuantity',
                        ),
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
                if (!isSearching && !_supportsPhotoCategoryLanding)
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

  Widget _buildMeatCatalog(
    BuildContext context, {
    required AppLocalizations l10n,
    required AsyncValue<CatalogState> catalog,
    required int cartQuantity,
    required String cartSubtotal,
  }) => ScaffoldMessenger(
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.storeMeat),
        actions: [
          IconButton(
            key: const ValueKey('catalog-cart-button'),
            tooltip: l10n.navCart,
            onPressed: () =>
                goToStoreTab(context, StoreType.meat, StoreTab.cart),
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text(cartQuantity > 99 ? '99+' : '$cartQuantity'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: _revealBoundary(
        catalog.value,
        RefreshIndicator(
          onRefresh: () => ref
              .read(catalogControllerProvider(StoreType.meat).notifier)
              .refresh(),
          child: switch (catalog) {
            AsyncData(:final value) when value.items.isNotEmpty =>
              MeatCatalogList(
                products: value.visibleItems,
                controller: _scrollController,
                footer: value.canRevealImageless
                    ? ImagelessRevealPrompt(onReveal: _revealImageless)
                    : null,
              ),
            AsyncData() => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: StoreEmptyView(
                    icon: Icons.inventory_2_outlined,
                    title: l10n.catalogEmpty,
                  ),
                ),
              ],
            ),
            AsyncError(:final error) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: StoreErrorView(
                    message: error is ApiFailure
                        ? error.localize(l10n)
                        : l10n.errorUnknown,
                    onRetry: () => ref
                        .read(
                          catalogControllerProvider(StoreType.meat).notifier,
                        )
                        .refresh(),
                  ),
                ),
              ],
            ),
            _ => const MeatCatalogSkeleton(),
          },
        ),
      ),
      bottomNavigationBar: cartQuantity == 0
          ? null
          : _MiniCartBar(
              quantity: cartQuantity,
              subtotal: cartSubtotal,
              onTap: () => goToStoreTab(context, StoreType.meat, StoreTab.cart),
            ),
    ),
  );

  Widget _buildShashlikCatalog(
    BuildContext context, {
    required AppLocalizations l10n,
    required AsyncValue<CatalogState> catalog,
    required int cartQuantity,
  }) => ScaffoldMessenger(
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.storeShashlik),
        actions: [
          IconButton(
            key: const ValueKey('catalog-cart-button'),
            tooltip: l10n.navCart,
            onPressed: () =>
                goToStoreTab(context, StoreType.shashlik, StoreTab.cart),
            icon: Badge(
              isLabelVisible: cartQuantity > 0,
              label: Text(cartQuantity > 99 ? '99+' : '$cartQuantity'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          ShashlikSectionSelector(
            selected: _shashlikSection,
            onSelected: (value) {
              if (value != _shashlikSection) {
                ref
                    .read(
                      catalogControllerProvider(StoreType.shashlik).notifier,
                    )
                    .hideImageless();
                setState(() => _shashlikSection = value);
              }
            },
          ),
          Expanded(
            child: _revealBoundary(
              catalog.value,
              RefreshIndicator(
                onRefresh: () => ref
                    .read(
                      catalogControllerProvider(StoreType.shashlik).notifier,
                    )
                    .refresh(),
                child: switch (catalog) {
                  AsyncData(:final value) when value.items.isNotEmpty =>
                    ShashlikCatalogList(
                      groups: ShashlikCatalogGroups.fromProducts(value.items),
                      section: _shashlikSection,
                      includeImageless: value.imagelessRevealed,
                      controller: _scrollController,
                      footer: _shashlikRevealPrompt(value),
                    ),
                  AsyncData() => CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: StoreEmptyView(
                          icon: Icons.inventory_2_outlined,
                          title: l10n.catalogEmpty,
                        ),
                      ),
                    ],
                  ),
                  AsyncError(:final error) => CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: StoreErrorView(
                          message: error is ApiFailure
                              ? error.localize(l10n)
                              : l10n.errorUnknown,
                          onRetry: () => ref
                              .read(
                                catalogControllerProvider(
                                  StoreType.shashlik,
                                ).notifier,
                              )
                              .refresh(),
                        ),
                      ),
                    ],
                  ),
                  _ => const CatalogRowsSkeleton(),
                },
              ),
              enabled:
                  catalog.value != null &&
                  _shashlikRevealPrompt(catalog.value!) != null,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildPhotoCategoryLanding(
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
            key: PageStorageKey('catalog-${widget.storeType.wire}-categories'),
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
                  title == null || title.isEmpty
                      ? _storeName(l10n, widget.storeType)
                      : title,
                ),
                actions: [
                  IconButton(
                    key: ValueKey('${widget.storeType.wire}-search-button'),
                    tooltip: l10n.commonSearch,
                    onPressed: _openCategorySearch,
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
                  if (widget.storeType == StoreType.household)
                    HouseholdCategoryLandingSliver(
                      categories: value.categories,
                      onCategoryTap: _openPhotoCategory,
                    )
                  else
                    RestaurantCategoryLandingSliver(
                      categories: value.categories,
                      onCategoryTap: _openPhotoCategory,
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
                _ => [
                  if (widget.storeType == StoreType.restaurant)
                    const RestaurantCategoryLandingSkeleton()
                  else
                    const PhotoCategoryLandingSkeleton(),
                ],
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
        return const [CatalogLandingSkeletonSliver()];
      }
      return const [];
    }

    final visibleCategories = data.categories;
    final heroBanner = data.banners.isEmpty ? null : data.banners.first;
    final showHero =
        widget.storeType != StoreType.meat &&
        (heroBanner != null ||
            (data.header.showHeader &&
                (data.header.label.isNotEmpty ||
                    data.header.subtitle.isNotEmpty ||
                    data.header.imageUrl != null)));
    return [
      if (showHero)
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
        if (value.query.isEmpty)
          ..._gridWithInlineRails(value.visibleItems)
        else
          _gridChunk(value.items, 0, value.items.length),
        if (value.canRevealImageless)
          SliverToBoxAdapter(
            child: ImagelessRevealPrompt(onReveal: _revealImageless),
          ),
        if (value.isLoadingMore) const CatalogGridSkeletonSliver(itemCount: 2),
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
      _ => const [CatalogGridSkeletonSliver()],
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
  final usesPhotoCategories =
      storeType == StoreType.household || storeType == StoreType.restaurant;
  if (!usesPhotoCategories) return _storeName(l10n, storeType);
  if (categoryId != null) {
    for (final category in landing?.categories ?? const <ProductCategory>[]) {
      if (category.id == categoryId) return category.name;
    }
  }
  final label = landing?.header.label.trim();
  return label == null || label.isEmpty ? _storeName(l10n, storeType) : label;
}
