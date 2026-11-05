import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/routes.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/storage/account_scope.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../core/ui/widgets/smooth_press.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../checkout/presentation/widgets/store_minimum_panel.dart';
import '../../favorites/domain/favorites_controller.dart';
import '../../recommendations/domain/interaction_tracker.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../data/product_review_models.dart';
import '../domain/catalog_controller.dart';
import '../domain/product_report_controller.dart';
import 'widgets/catalog_loading_skeleton.dart';
import 'widgets/meat_product_image.dart';
import 'widgets/product_detail_image_zoom.dart';
import 'widgets/product_image.dart';
import 'widgets/product_rail.dart';
import 'widgets/product_reviews_section.dart';
import 'widgets/restaurant_dish_pager.dart';
import 'widgets/shashlik_catalog.dart';
import 'widgets/shashlik_feedback.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.storeType,
    required this.productId,
    this.categoryId,
    super.key,
  });

  final StoreType storeType;
  final String productId;
  final String? categoryId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with WidgetsBindingObserver {
  String? _initializedProductId;
  String? _variantId;
  final Map<String, Set<String>> _selectedAddons = {};
  bool _showValidation = false;
  late String _selectedProductId;
  ProductSummary? _selectedSummary;
  final Map<String, _DishDraft> _dishDrafts = {};
  // Route-lifetime LRU: keep successful details AND in-flight requests alive
  // across swipes. Neighbor responses never rebuild the selected dish.
  static const _detailCacheLimit = 64;
  final Map<String, AsyncValue<ProductDetail>> _dishDetails = {};
  final Map<String, ProviderSubscription<AsyncValue<ProductDetail>>>
  _detailRefs = {};
  final Map<String, ProviderSubscription<AsyncValue<List<ProductReview>>>>
  _reviewRefs = {};
  List<String> _nearbyDishIds = const [];
  bool _warmupScheduled = false;
  bool _cacheResetScheduled = false;
  int _detailGeneration = 0;
  int _photoIndex = 0;
  bool _quantitySheetOpen = false;
  final _detailScaffoldKey = GlobalKey<ScaffoldState>();
  bool get _restaurant => widget.storeType == StoreType.restaurant;

  // ── Qiziqish signali: qancha qaradi, qancha pastga tushdi ────────────────
  // `dispose`da `ref` ishlatib bo'lmaydi — tracker oldindan olinadi.
  late final InteractionTracker _tracker;
  final Stopwatch _dwell = Stopwatch();
  double _maxScrollDepth = 0;
  String _viewedName = '';
  StoreType? _viewedStoreType;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.productId;
    _tracker = ref.read(interactionTrackerProvider);
    WidgetsBinding.instance.addObserver(this);
    _dwell.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fonda turgan vaqt "qaradi" hisoblanmaydi.
    if (state == AppLifecycleState.resumed) {
      _dwell.start();
    } else {
      _dwell.stop();
    }
  }

  @override
  void dispose() {
    _detailGeneration++;
    for (final subscription in _detailRefs.values) {
      subscription.close();
    }
    _detailRefs.clear();
    for (final subscription in _reviewRefs.values) {
      subscription.close();
    }
    _reviewRefs.clear();
    WidgetsBinding.instance.removeObserver(this);
    _dwell.stop();
    final viewedId = _initializedProductId;
    if (viewedId != null) {
      final tracker = _tracker;
      final dwell = _dwell.elapsed;
      final depth = _maxScrollDepth;
      final name = _viewedName;
      final storeType = _viewedStoreType ?? widget.storeType;
      // Provider holatini widget daraxti yopilayotganda o'zgartirib bo'lmaydi.
      scheduleMicrotask(
        () => tracker.recordView(
          productId: viewedId,
          dwell: dwell,
          scrollDepth: depth,
          name: name,
          storeType: storeType,
        ),
      );
    }
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    final depth = metrics.maxScrollExtent <= 0
        ? 1.0
        : (metrics.pixels / metrics.maxScrollExtent).clamp(0.0, 1.0);
    if (depth > _maxScrollDepth) _maxScrollDepth = depth;
    return false;
  }

  void _initialize(ProductDetail detail) {
    if (_initializedProductId == detail.product.id) return;
    _saveDraft();
    _initializedProductId = detail.product.id;
    _viewedName = detail.product.name;
    _viewedStoreType = detail.product.storeType;
    final active = detail.product.variants.where((variant) => variant.isActive);
    _variantId = active.where((variant) => variant.isDefault).firstOrNull?.id;
    _variantId ??= active.firstOrNull?.id;
    _selectedAddons.clear();
    _showValidation = false;
    _photoIndex = 0;
    final draft = _dishDrafts[detail.product.id];
    if (_restaurant && draft != null) {
      _variantId = draft.variantId;
      _selectedAddons.addAll(
        draft.addons.map((key, value) => MapEntry(key, {...value})),
      );
      _showValidation = draft.showValidation;
      _photoIndex = draft.photoIndex;
    }
  }

  void _saveDraft() {
    final id = _initializedProductId;
    if (!_restaurant || id == null) return;
    _dishDrafts[id] = _DishDraft(
      _variantId,
      _selectedAddons.map((key, value) => MapEntry(key, {...value})),
      _showValidation,
      _photoIndex,
    );
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.productId != oldWidget.productId &&
        widget.productId != _selectedProductId) {
      _saveDraft();
      _selectedProductId = widget.productId;
      _selectedSummary = null;
    }
  }

  void _selectDish(ProductSummary product) {
    if (product.id == _selectedProductId) return;
    _saveDraft();
    setState(() {
      _selectedProductId = product.id;
      _selectedSummary = product;
    });
    final router = GoRouter.maybeOf(context);
    // replace retains the route's page key, so the carousel/drafts survive
    // while browser refresh and deep links still point at the current dish.
    if (router != null) {
      final path = Routes.productDetail(widget.storeType.wire, product.id);
      final target = widget.categoryId == null
          ? path
          : Uri.parse(path)
                .replace(queryParameters: {'category': widget.categoryId!})
                .toString();
      // Replace browser history too; swipes must not create Back entries.
      Router.neglect(context, () => router.replace<void>(target));
    }
  }

  void _scheduleDishWarmup() {
    if (_warmupScheduled) return;
    _warmupScheduled = true;
    scheduleMicrotask(() {
      _warmupScheduled = false;
      if (!mounted || !_restaurant || _cacheResetScheduled) return;
      _retainDish(_selectedProductId);
      // At most two speculative requests, with foreground selection taking
      // priority. Dropped/old neighbors are not fetched just for scrolling.
      for (final id in _nearbyDishIds) {
        if (_dishDetails.values.where((value) => value.isLoading).length >= 2) {
          break;
        }
        _retainDish(id);
      }
    });
  }

  void _retainDish(String id) {
    final held = _detailRefs.remove(id);
    if (held != null) {
      _detailRefs[id] = held;
      return;
    }
    if (_detailRefs.length >= _detailCacheLimit) {
      final evict = _detailRefs.keys
          .where(
            (key) => key != _selectedProductId && !_nearbyDishIds.contains(key),
          )
          .firstOrNull;
      if (evict != null) {
        _detailRefs.remove(evict)?.close();
        _reviewRefs.remove(evict)?.close();
        _dishDetails.remove(evict);
      }
    }
    final generation = _detailGeneration;
    _detailRefs[id] = ref.listenManual(restaurantProductDetailProvider(id), (
      previous,
      next,
    ) {
      if (!mounted || generation != _detailGeneration) return;
      // A background reconciliation must not blank a usable detail.
      if (!(next.isLoading && _dishDetails[id]?.asData != null)) {
        _dishDetails[id] = next;
      }
      if (id == _selectedProductId) setState(() {});
      if (!next.isLoading) _scheduleDishWarmup();
    }, fireImmediately: true);
  }

  void _resetDishCache() {
    if (_cacheResetScheduled) return;
    _cacheResetScheduled = true;
    _detailGeneration++;
    scheduleMicrotask(() {
      if (!mounted) return;
      _cacheResetScheduled = false;
      final ids = _detailRefs.keys.toList();
      for (final subscription in _detailRefs.values) {
        subscription.close();
      }
      _detailRefs.clear();
      for (final subscription in _reviewRefs.values) {
        subscription.close();
      }
      _reviewRefs.clear();
      _dishDetails.clear();
      _dishDrafts.clear();
      _initializedProductId = null;
      for (final id in ids) {
        ref.invalidate(productDetailProvider(id));
        ref.invalidate(productReviewsProvider(id));
        ref.invalidate(restaurantProductDetailProvider(id));
        ref.invalidate(restaurantProductReviewsProvider(id));
      }
      setState(() {});
      _scheduleDishWarmup();
    });
  }

  void _retainDishReviews(String id) {
    if (!mounted ||
        _cacheResetScheduled ||
        !_detailRefs.containsKey(id) ||
        _reviewRefs.containsKey(id)) {
      return;
    }
    // Retain only reviews actually shown; do not prefetch every review list.
    _reviewRefs[id] = ref.listenManual(
      restaurantProductReviewsProvider(id),
      (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_restaurant) {
      ref.listen(accountScopeProvider, (previous, next) {
        if (previous != next) _resetDishCache();
      });
      ref.listen(apiLangProvider, (previous, next) {
        if (previous != next) _resetDishCache();
      });
      _scheduleDishWarmup();
      return _buildRestaurant(
        context,
        _dishDetails[_selectedProductId] ?? const AsyncLoading<ProductDetail>(),
      );
    }
    final detail = ref.watch(productDetailProvider(widget.productId));
    // Snackbar pastdagi "savatga qo'shish" panelini to'smasligi uchun —
    // o'z Scaffold'i bo'yicha joylashadi (katalog ekranidagi kabi).
    return ScaffoldMessenger(
      child: Scaffold(
        key: _detailScaffoldKey,
        backgroundColor: widget.storeType == StoreType.meat
            ? Colors.white
            : null,
        appBar: AppBar(
          backgroundColor: widget.storeType == StoreType.meat
              ? Colors.white
              : null,
          surfaceTintColor: widget.storeType == StoreType.meat
              ? Colors.transparent
              : null,
          title: Text(
            widget.storeType == StoreType.meat
                ? l10n.storeMeat
                : l10n.catalogTitle,
          ),
        ),
        body: switch (detail) {
          AsyncData(:final value)
              when value.product.storeType != null &&
                  value.product.storeType != widget.storeType =>
            StoreEmptyView(
              icon: Icons.warning_amber_rounded,
              title: l10n.unsupportedStoreMessage,
            ),
          AsyncData(:final value) => _buildDetail(context, value),
          AsyncError(:final error) => StoreErrorView(
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
            onRetry: () =>
                ref.invalidate(productDetailProvider(widget.productId)),
          ),
          _ => const ProductDetailLoadingSkeleton(),
        },
        bottomNavigationBar:
            detail.value == null ||
                (detail.value!.product.storeType != null &&
                    detail.value!.product.storeType != widget.storeType)
            ? null
            : StoreMinimumPanel(
                storeType: widget.storeType,
                child: _buildBottomBar(context, detail.value!),
              ),
      ),
    );
  }

  Widget _buildRestaurant(
    BuildContext context,
    AsyncValue<ProductDetail> state,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = state.asData?.value;
    final wrongStore =
        value != null &&
        value.product.storeType != null &&
        value.product.storeType != StoreType.restaurant;
    final detail = wrongStore ? null : value;
    if (detail != null) {
      _initialize(detail);
      _selectedSummary = detail.product;
    }
    final product = _selectedSummary;
    final photos = <String?>[
      product?.imageUrl,
      ...?detail?.images.map((image) => image.url),
    ].whereType<String>().where((url) => url.isNotEmpty).toSet().toList();
    final photo = photos.isEmpty
        ? null
        : photos[_photoIndex.clamp(0, photos.length - 1)];
    final favoriteState = ref.watch(favoritesControllerProvider);
    final favorite = favoriteState.value?.contains(_selectedProductId) == true;
    final favoriteBusy =
        favoriteState.value?.busyProductIds.isNotEmpty ?? false;
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
    );
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              key: const ValueKey('restaurant-detail-favorite'),
              tooltip: l10n.favoritesTitle,
              isSelected: favorite,
              onPressed: product == null || favoriteBusy || wrongStore
                  ? null
                  : () async {
                      final target = product;
                      if (!await requireAuthentication(context, ref) ||
                          !context.mounted) {
                        return;
                      }
                      await ref
                          .read(favoritesControllerProvider.notifier)
                          .toggle(target);
                      if (!context.mounted) return;
                      final failure = ref
                          .read(favoritesControllerProvider)
                          .value
                          ?.mutationFailure;
                      if (failure != null) _showCartFailure(failure);
                    },
              icon: const Icon(Icons.favorite_border),
              selectedIcon: const Icon(
                Icons.favorite,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Material(
          key: const ValueKey('restaurant-detail-background'),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView(
              key: const PageStorageKey('restaurant-dish-detail-scroll'),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (!wrongStore)
                  RestaurantDishPager(
                    product: product,
                    categoryId: widget.categoryId,
                    imageUrl: photo,
                    onChanged: _selectDish,
                    onNearbyChanged: (products) {
                      _nearbyDishIds = products
                          .map((product) => product.id)
                          .toList();
                      _scheduleDishWarmup();
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: Text(
                      product?.name ?? l10n.commonLoading,
                      key: ValueKey('dish-title-$_selectedProductId'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF151515),
                      ),
                    ),
                  ),
                ),
                if (wrongStore)
                  StoreEmptyView(
                    icon: Icons.warning_amber_rounded,
                    title: l10n.unsupportedStoreMessage,
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: AnimatedSwitcher(
                      duration: duration,
                      child: Text(
                        Uzs.format(
                          detail == null
                              ? product?.price
                              : _configuredPrice(detail),
                        ),
                        key: ValueKey(
                          'dish-price-$_selectedProductId-${detail == null ? product?.price : _configuredPrice(detail)}',
                        ),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF15803D),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (product?.unit.isNotEmpty == true)
                    Text(
                      product!.unit,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (detail != null && photos.length > 1)
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        key: ValueKey('dish-thumbnails-$_selectedProductId'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => Semantics(
                          button: true,
                          selected: index == _photoIndex,
                          label:
                              '${product!.name}, ${index + 1} / ${photos.length}',
                          child: InkWell(
                            key: ValueKey('dish-thumbnail-$index'),
                            onTap: () => setState(() => _photoIndex = index),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 80,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  width: 2,
                                  color: index == _photoIndex
                                      ? const Color(0xFF15803D)
                                      : Colors.transparent,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ProductImageView(
                                  persistent: true,
                                  imageUrl: photos[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (detail != null)
                    _buildDetailContent(
                      context,
                      detail,
                      detail.product,
                      l10n,
                      theme,
                    ),
                  if (detail == null && state.hasError)
                    StoreErrorView(
                      message: state.error is ApiFailure
                          ? (state.error as ApiFailure).localize(l10n)
                          : l10n.errorUnknown,
                      onRetry: () => ref.invalidate(
                        restaurantProductDetailProvider(_selectedProductId),
                      ),
                    )
                  else if (detail == null)
                    const Padding(
                      key: ValueKey('dish-detail-loading'),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: SizedBox(
                        height: 64,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 120,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFFE9ECEF),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: wrongStore
            ? null
            : StoreMinimumPanel(
                storeType: widget.storeType,
                child: _buildRestaurantBottomBar(context, detail),
              ),
      ),
    );
  }

  String _configuredPrice(ProductDetail detail) {
    final base = _selectedPrice(detail.product);
    final addons = _selectedAddonItems(detail);
    final money = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!money.hasMatch(base) ||
        addons.any((addon) => !money.hasMatch(addon.price))) {
      return '';
    }
    // Decimal integer arithmetic, matching the existing cart's money policy.
    int minor(String value) {
      final parts = value.split('.');
      return (int.tryParse(parts.first) ?? 0) * 100 +
          (int.tryParse(
                (parts.length > 1 ? parts[1] : '')
                    .padRight(2, '0')
                    .substring(0, 2),
              ) ??
              0);
    }

    final total = addons.fold(
      minor(base),
      (sum, addon) => sum + minor(addon.price),
    );
    return '${total ~/ 100}.${(total % 100).toString().padLeft(2, '0')}';
  }

  Widget _buildRestaurantBottomBar(
    BuildContext context,
    ProductDetail? detail,
  ) {
    final l10n = AppLocalizations.of(context);
    final cartAsync = ref.watch(cartControllerProvider(widget.storeType));
    final cartState = cartAsync.value;
    final line = detail == null
        ? null
        : _findLine(_configuration(detail), cartState?.cart.items ?? []);
    final disabled =
        detail == null ||
        cartAsync.isLoading ||
        cartAsync.hasError ||
        cartState == null ||
        cartState.hasPendingMutation ||
        _inReview(detail) ||
        !detail.product.isPurchasable ||
        _isUnsatisfiable(detail) ||
        !_isValid(detail) ||
        line?.isOrderable == false;
    final controller = ref.read(
      cartControllerProvider(widget.storeType).notifier,
    );
    final add = FilledButton(
      key: const ValueKey('product-detail-add-to-cart'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: const Color(0xFF087F5B),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: disabled ? null : () => _addToCart(detail),
      child: Text(l10n.productAddShort, textAlign: TextAlign.center),
    );
    final quantity = line == null
        ? null
        : ConstrainedBox(
            key: const ValueKey('restaurant-dish-quantity'),
            constraints: const BoxConstraints(minHeight: 52),
            child: _QuantityControl(
              quantity: line.quantity,
              restaurant: true,
              onDecrement: disabled
                  ? null
                  : () => _runCartMutation(() => controller.decrement(line)),
              onIncrement: disabled
                  ? null
                  : () => _runCartMutation(() => controller.increment(line)),
            ),
          );
    final goToCart = FilledButton.tonal(
      key: const ValueKey('product-detail-go-to-cart'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        backgroundColor: const Color(0xFFCFE8DA),
        foregroundColor: const Color(0xFF2E443A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => goToStoreTab(context, widget.storeType, StoreTab.cart),
      child: Text(l10n.productGoToCart, textAlign: TextAlign.center),
    );
    return SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (quantity == null) return add;
              if (MediaQuery.textScalerOf(context).scale(16) > 23 &&
                  constraints.maxWidth < 480) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [quantity, const SizedBox(height: 8), goToCart],
                );
              }
              return Row(
                children: [
                  Expanded(child: quantity),
                  const SizedBox(width: 12),
                  Expanded(child: goToCart),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Server flagi YOKI shu sessiyada kartadan hozirgina yuborilgani.
  bool _inReview(ProductDetail detail) =>
      detail.product.inReview ||
      ref.watch(productReportControllerProvider).isReported(detail.product.id);

  Widget _buildDetail(BuildContext context, ProductDetail detail) {
    _initialize(detail);
    final product = detail.product;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final gallery = <String?>[
      ...detail.images.map((image) => image.url),
      product.imageUrl,
    ].whereType<String>().toSet().toList();

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: _buildDetailList(context, detail, gallery, product, l10n, theme),
    );
  }

  Widget _buildDetailList(
    BuildContext context,
    ProductDetail detail,
    List<String> gallery,
    ProductSummary product,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        Padding(
          padding: widget.storeType == StoreType.meat
              ? const EdgeInsets.fromLTRB(16, 4, 16, 0)
              : EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              widget.storeType == StoreType.meat ? 20 : 0,
            ),
            child: SizedBox(
              height:
                  math.min(MediaQuery.sizeOf(context).width, 420) *
                  (widget.storeType == StoreType.meat ? .75 : 1),
              child: widget.storeType == StoreType.meat && gallery.isEmpty
                  ? MeatProductImage(product: product)
                  : _ProductGallery(
                      imageUrls: gallery,
                      fallbackImageUrl: product.imageUrl,
                    ),
            ),
          ),
        ),
        _buildDetailContent(context, detail, product, l10n, theme),
      ],
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    ProductDetail detail,
    ProductSummary product,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.storeType == StoreType.meat) ...[
            Center(
              child: Text(
                product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                Uzs.format(_selectedPrice(product)),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            if (product.unit.isNotEmpty) Center(child: Text(product.unit)),
          ] else if (!_restaurant) ...[
            Text(
              product.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (product.unit.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                product.unit,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // Uzun narx / katta shrift toshib ketmasin — ikkala matn ham
            // Flexible, bir qatorda ellipsis bilan.
            Row(
              children: [
                Flexible(
                  child: Text(
                    Uzs.format(_selectedPrice(product)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (product.oldPrice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      Uzs.format(product.oldPrice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (_inReview(detail)) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_top,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.productInReviewDetail,
                        style: TextStyle(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!product.isPurchasable || _isUnsatisfiable(detail)) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              key: const ValueKey('product-detail-unavailable'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        !product.isPurchasable && product.isSoldOut
                            ? l10n.productSoldOutDetail
                            : l10n.productUnavailable,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (product.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.productDescription,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(product.description),
          ],
          if (product.variants.any((variant) => variant.isActive)) ...[
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.productVariant,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final variant in product.variants.where(
                  (variant) => variant.isActive,
                ))
                  ChoiceChip(
                    label: Text(
                      '${variant.name} · ${Uzs.format(variant.price)}',
                    ),
                    selected: _variantId == variant.id,
                    onSelected: (_) => setState(() => _variantId = variant.id),
                  ),
              ],
            ),
            if (_showValidation && _variantId == null)
              _ValidationText(text: l10n.productChooseMin),
          ],
          for (final group in detail.addonGroups) ...[
            const SizedBox(height: AppSpacing.xxl),
            _AddonGroupView(
              group: group,
              selected: _selectedAddons[group.id] ?? const {},
              showValidation: _showValidation,
              onToggle: (option) => _toggleAddon(context, group, option),
            ),
          ],
          ProductReviewsSection(
            detail: detail,
            onWatched: _restaurant ? _retainDishReviews : null,
          ),
          if (detail.relatedProducts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            // Gorizontal scroll: nomi/kategoriyasi/birga ko'rilgani
            // bo'yicha o'xshashlar (backend `related_products`).
            ProductRail(
              key: const ValueKey('product-related-rail'),
              title: l10n.productRelated,
              titleStyle: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              products: detail.relatedProducts,
              storeType: widget.storeType,
              keyPrefix: 'related-product',
              visibleCards: 2.4,
              cardHeight: 250,
              storageKey: PageStorageKey('related-${detail.product.id}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ProductDetail detail) {
    _initialize(detail);
    final l10n = AppLocalizations.of(context);
    final cartAsync = ref.watch(cartControllerProvider(widget.storeType));
    final cartState = cartAsync.value;
    final configuration = _configuration(detail);
    final line = _findLine(
      configuration,
      cartState?.cart.items ?? const <CartItem>[],
    );
    // Har bir tugma o'z kalitini kuzatadi — bitta amal butun ekranni
    // bloklamaydi.
    final waitingForCart = cartAsync.isLoading && cartState == null;
    final controller = ref.read(
      cartControllerProvider(widget.storeType).notifier,
    );
    if (widget.storeType == StoreType.meat &&
        !detail.requiresConfiguration &&
        !detail.product.requiresConfiguration) {
      final busy =
          _quantitySheetOpen ||
          waitingForCart ||
          cartAsync.hasError ||
          (cartState?.hasPendingMutation ?? false) ||
          (cartState?.unconfirmedKeys.isNotEmpty ?? true);
      Future<void> edit() async {
        if (_quantitySheetOpen) return;
        setState(() => _quantitySheetOpen = true);
        try {
          final changed = await showMeatQuantityEditor(
            context,
            detail.product,
            exactItem: line,
          );
          if (changed == true &&
              mounted &&
              _detailScaffoldKey.currentContext != null) {
            showShashlikSaved(_detailScaffoldKey.currentContext!);
          }
        } finally {
          if (mounted) setState(() => _quantitySheetOpen = false);
        }
      }

      return Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (line != null)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${line.quantity} ${detail.product.unit}'),
                      TextButton(
                        key: const ValueKey('meat-edit-quantity'),
                        onPressed: busy ? null : edit,
                        child: Text(l10n.commonEdit),
                      ),
                    ],
                  ),
                Text(
                  Uzs.formatWithFraction(
                    line?.subtotal ?? detail.product.price,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('meat-detail-action'),
                  onPressed: line != null
                      ? () =>
                            goToStoreTab(context, StoreType.meat, StoreTab.cart)
                      : busy ||
                            !detail.product.isPurchasable ||
                            _inReview(detail) ||
                            _isUnsatisfiable(detail)
                      ? null
                      : edit,
                  child: Text(
                    line != null
                        ? l10n.productGoToCart
                        : l10n.shashlikChooseQuantity,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.md,
          ),
          child: line == null
              ? SmoothPress(
                  enabled:
                      !_inReview(detail) &&
                      detail.product.isPurchasable &&
                      !_isUnsatisfiable(detail) &&
                      !waitingForCart &&
                      !cartAsync.hasError,
                  child: FilledButton(
                    key: const ValueKey('product-detail-add-to-cart'),
                    onPressed:
                        _inReview(detail) ||
                            !detail.product.isPurchasable ||
                            _isUnsatisfiable(detail) ||
                            waitingForCart ||
                            cartAsync.hasError
                        ? null
                        : () => _addToCart(detail),
                    child: Text(l10n.productAddShort),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: _QuantityControl(
                        quantity: line.quantity,
                        onDecrement: () =>
                            _runCartMutation(() => controller.decrement(line)),
                        onIncrement: () =>
                            _runCartMutation(() => controller.increment(line)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 10,
                      // Ikonkasiz — tor ekranda "Перейти в корзину" yorlig'i
                      // ikonka bilan sig'may qisqarib qolardi.
                      child: FilledButton.tonal(
                        key: const ValueKey('product-detail-go-to-cart'),
                        onPressed: () => goToStoreTab(
                          context,
                          widget.storeType,
                          StoreTab.cart,
                        ),
                        child: Text(l10n.productGoToCart),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _selectedPrice(ProductSummary product) {
    for (final variant in product.variants) {
      if (variant.id == _variantId) return variant.price;
    }
    return product.price;
  }

  void _toggleAddon(
    BuildContext context,
    AddonGroup group,
    AddonOption option,
  ) {
    final selected = {...?_selectedAddons[group.id]};
    if (selected.contains(option.id)) {
      selected.remove(option.id);
    } else if (group.selectionType == 'single') {
      selected
        ..clear()
        ..add(option.id);
    } else {
      final max = group.maxSelect;
      if (max > 0 && selected.length >= max) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).productChooseMax),
            ),
          );
        return;
      }
      selected.add(option.id);
    }
    setState(() => _selectedAddons[group.id] = selected);
  }

  /// UI faqat mavjud optsiyalar (`isAvailable`) va faol variantlarni
  /// (`isActive`) chizadi. Majburiy guruhda yetarli mavjud optsiya bo'lmasa
  /// yoki variantlar bor-u, faoli yo'q bo'lsa — mahsulotni to'plab bo'lmaydi:
  /// "kamida bittasini tanlang" deyish o'rniga tugma o'chiriladi.
  bool _isUnsatisfiable(ProductDetail detail) {
    final product = detail.product;
    if (product.variants.isNotEmpty &&
        !product.variants.any((variant) => variant.isActive)) {
      return true;
    }
    for (final group in detail.addonGroups) {
      final minimum = math.max(group.minSelect, group.isRequired ? 1 : 0);
      if (minimum == 0) continue;
      final available = group.options.where((option) => option.isAvailable);
      if (available.length < minimum) return true;
    }
    return false;
  }

  bool _isValid(ProductDetail detail) {
    if (detail.product.variants.isNotEmpty && _variantId == null) return false;
    for (final group in detail.addonGroups) {
      final count = _selectedAddons[group.id]?.length ?? 0;
      final minimum = math.max(group.minSelect, group.isRequired ? 1 : 0);
      if (count < minimum) return false;
      if (group.maxSelect > 0 && count > group.maxSelect) return false;
    }
    return true;
  }

  ProductVariant? _selectedVariant(ProductSummary product) {
    for (final variant in product.variants) {
      if (variant.id == _variantId) return variant;
    }
    return null;
  }

  List<SelectedAddon> _selectedAddonItems(ProductDetail detail) {
    final addons = <SelectedAddon>[];
    for (final group in detail.addonGroups) {
      final selected = _selectedAddons[group.id] ?? const <String>{};
      for (final option in group.options) {
        if (selected.contains(option.id)) {
          addons.add(
            SelectedAddon(
              id: option.id,
              name: option.name,
              price: option.price,
            ),
          );
        }
      }
    }
    return addons;
  }

  CartConfiguration _configuration(ProductDetail detail) => CartConfiguration(
    productId: detail.product.id,
    variantId: _selectedVariant(detail.product)?.id,
    addons: _selectedAddonItems(detail),
  );

  CartItem? _findLine(CartConfiguration configuration, List<CartItem> items) {
    for (final item in items) {
      if (item.configurationIdentity == configuration.identity) return item;
    }
    return null;
  }

  Future<void> _addToCart(ProductDetail detail) async {
    if (!_isValid(detail)) {
      setState(() => _showValidation = true);
      return;
    }
    await ref
        .read(cartControllerProvider(widget.storeType).notifier)
        .addProduct(
          detail.product,
          variant: _selectedVariant(detail.product),
          addons: _selectedAddonItems(detail),
          quantity: 1,
        );
    if (!mounted) return;
    final failure = ref
        .read(cartControllerProvider(widget.storeType))
        .value
        ?.mutationFailure;
    if (failure != null) _showCartFailure(failure);
  }

  Future<void> _runCartMutation(Future<void> Function() mutation) async {
    await mutation();
    if (!mounted) return;
    final failure = ref
        .read(cartControllerProvider(widget.storeType))
        .value
        ?.mutationFailure;
    if (failure != null) _showCartFailure(failure);
  }

  void _showCartFailure(ApiFailure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure.localize(AppLocalizations.of(context)))),
      );
  }
}

class _DishDraft {
  const _DishDraft(
    this.variantId,
    this.addons,
    this.showValidation,
    this.photoIndex,
  );
  final String? variantId;
  final Map<String, Set<String>> addons;
  final bool showValidation;
  final int photoIndex;
}

class _AddonGroupView extends StatelessWidget {
  const _AddonGroupView({
    required this.group,
    required this.selected,
    required this.showValidation,
    required this.onToggle,
  });

  final AddonGroup group;
  final Set<String> selected;
  final bool showValidation;
  final ValueChanged<AddonOption> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minimum = math.max(group.minSelect, group.isRequired ? 1 : 0);
    final invalid =
        selected.length < minimum ||
        (group.maxSelect > 0 && selected.length > group.maxSelect);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (minimum > 0)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(l10n.productRequired),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final option in group.options.where((item) => item.isAvailable))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected.contains(option.id),
            onChanged: (_) => onToggle(option),
            title: Text(option.name),
            secondary: option.price == '0' || option.price == '0.00'
                ? null
                : Text('+${Uzs.format(option.price)}'),
          ),
        if (showValidation && invalid)
          _ValidationText(text: l10n.productChooseMin),
      ],
    );
  }
}

class _ValidationText extends StatelessWidget {
  const _ValidationText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

class _ProductGallery extends StatefulWidget {
  const _ProductGallery({
    required this.imageUrls,
    required this.fallbackImageUrl,
  });

  final List<String> imageUrls;
  final String? fallbackImageUrl;

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final _controller = PageController();
  int _index = 0;
  bool _imageZoomed = false;

  @override
  void didUpdateWidget(covariant _ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls == widget.imageUrls) return;
    _imageZoomed = false;
    if (_index != 0) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return ProductImageView(imageUrl: widget.fallbackImageUrl);
    }
    final hasMultiple = widget.imageUrls.length >= 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: const ValueKey('product-detail-gallery'),
          controller: _controller,
          physics: _imageZoomed ? const NeverScrollableScrollPhysics() : null,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) => setState(() {
            _index = index;
            _imageZoomed = false;
          }),
          itemBuilder: (_, index) {
            final imageUrl = widget.imageUrls[index];
            // Zoomni CachedNetworkImage.imageBuilder ichiga qo'ymaymiz: Web
            // cache/CORS yoki placeholder almashinuvida imageBuilder qayta
            // yaratilishi mumkin va gesture hit-area faqat rasmning o'z
            // o'lchamida qolib ketadi. Butun galereya sahifasini o'rash tapni
            // har doim bir xil va to'liq maydonda ushlaydi.
            return ProductDetailImageZoom(
              key: ValueKey('product-detail-image-zoom-$imageUrl'),
              onZoomChanged: (zoomed) {
                if (!mounted || _imageZoomed == zoomed) return;
                setState(() => _imageZoomed = zoomed);
              },
              child: ProductImageView(imageUrl: imageUrl, fit: BoxFit.contain),
            );
          },
        ),
        if (!_imageZoomed && hasMultiple && _index > 0)
          Positioned(
            left: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _GalleryArrow(
                key: const ValueKey('product-gallery-previous'),
                icon: Icons.chevron_left_rounded,
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onPressed: () => _goTo(_index - 1),
              ),
            ),
          ),
        if (!_imageZoomed &&
            hasMultiple &&
            _index < widget.imageUrls.length - 1)
          Positioned(
            right: AppSpacing.sm,
            top: 0,
            bottom: 0,
            child: Center(
              child: _GalleryArrow(
                key: const ValueKey('product-gallery-next'),
                icon: Icons.chevron_right_rounded,
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onPressed: () => _goTo(_index + 1),
              ),
            ),
          ),
        if (!_imageZoomed && hasMultiple)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.sm,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.imageUrls.length}',
                    key: const ValueKey('product-gallery-position'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index.clamp(0, widget.imageUrls.length - 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.58),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: Colors.white,
      icon: Icon(icon),
    ),
  );
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.restaurant = false,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool restaurant;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SmoothPress(
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: restaurant
                ? AppLocalizations.of(context).cartDecreaseQuantity
                : null,
            color: restaurant ? const Color(0xFF404D48) : null,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
          ),
        ),
        Text(
          '$quantity',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: restaurant ? const Color(0xFF151B27) : null,
            fontWeight: restaurant ? FontWeight.w700 : null,
          ),
        ),
        SmoothPress(
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: restaurant
                ? AppLocalizations.of(context).cartIncreaseQuantity
                : null,
            color: restaurant ? const Color(0xFF404D48) : null,
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    ),
  );
}
