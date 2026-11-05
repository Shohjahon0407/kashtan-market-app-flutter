import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/auth_gate.dart';
import '../../../core/routing/back_navigation.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_colors.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../checkout/presentation/widgets/store_minimum_panel.dart';
import '../../favorites/domain/favorites_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import 'widgets/catalog_loading_skeleton.dart';
import 'widgets/product_image.dart';
import 'widgets/shashlik_catalog.dart';
import 'widgets/shashlik_feedback.dart';

class ShashlikFamilyScreen extends ConsumerWidget {
  const ShashlikFamilyScreen({
    required this.familyKey,
    this.initialProductId,
    super.key,
  });
  final String familyKey;
  final String? initialProductId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = ShashlikFamilyKey.fromWire(familyKey);
    final catalog = ref.watch(catalogControllerProvider(StoreType.shashlik));
    final family = switch (catalog) {
      AsyncData(:final value) when key != null =>
        ShashlikCatalogGroups.fromProducts(
          value.items,
        ).families.where((item) => item.key == key).firstOrNull,
      _ => null,
    };
    if (family != null) {
      return _FamilyPage(
        key: ValueKey(family.key),
        family: family,
        initialProductId: initialProductId,
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(l10n.storeShashlik),
        backgroundColor: Colors.white,
      ),
      body: switch (catalog) {
        AsyncError(:final error) => StoreErrorView(
          message: error is ApiFailure
              ? error.localize(l10n)
              : l10n.errorUnknown,
          onRetry: () => ref
              .read(catalogControllerProvider(StoreType.shashlik).notifier)
              .refresh(),
        ),
        AsyncData() => StoreEmptyView(
          icon: Icons.inventory_2_outlined,
          title: l10n.catalogEmpty,
        ),
        _ => const CatalogRowsSkeleton(itemCount: 3),
      },
    );
  }
}

class _FamilyPage extends ConsumerStatefulWidget {
  const _FamilyPage({required this.family, this.initialProductId, super.key});
  final ShashlikFamily family;
  final String? initialProductId;
  @override
  ConsumerState<_FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<_FamilyPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pages;
  late String _selectedId;
  final _images = <String, String>{};
  bool _busy = false;
  String? _error;
  ProductSummary get _selected => widget.family.products.firstWhere(
    (p) => p.id == _selectedId,
    orElse: () => widget.family.products.first,
  );
  int get _index =>
      widget.family.products.indexWhere((p) => p.id == _selected.id);

  @override
  void initState() {
    super.initState();
    _selectedId =
        widget.family.products.any((p) => p.id == widget.initialProductId)
        ? widget.initialProductId!
        : widget.family.products.first.id;
    _pages = PageController(viewportFraction: .82, initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (_busy || index < 0 || index >= widget.family.products.length) return;
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _pages.jumpToPage(index);
      return;
    }
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _FamilyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.initialProductId;
    if (id == null || id == _selectedId) return;
    final index = widget.family.products.indexWhere((p) => p.id == id);
    if (index < 0) return;
    _selectedId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pages.hasClients) _pages.jumpToPage(index);
    });
  }

  void _selectProduct(int index) {
    final id = widget.family.products[index].id;
    setState(() {
      _selectedId = id;
      _error = null;
    });
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = GoRouterState.of(context).uri;
    final target = uri.replace(
      queryParameters: {...uri.queryParameters, 'product': id},
    );
    if (target != uri) {
      Router.neglect(context, () => router.replace<void>(target.toString()));
    }
  }

  Future<void> _editQuantity(ProductSummary product, bool configuration) async {
    if (_busy) return;
    if (configuration) {
      openStoreProduct(context, StoreType.shashlik, product.id);
      return;
    }
    setState(() => _busy = true);
    final changed = await showShashlikFamilySelector(
      context,
      widget.family,
      initialProductId: product.id,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed == true && _scaffoldKey.currentContext != null) {
      showShashlikSaved(_scaffoldKey.currentContext!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = _selected;
    final detail = ref.watch(productDetailProvider(product.id)).value;
    final actual = detail?.product ?? product;
    final cart = ref
        .watch(cartControllerProvider(StoreType.shashlik))
        .value
        ?.cart;
    final favorite = ref.watch(favoritesControllerProvider);
    final isFavorite = favorite.value?.contains(product.id) ?? false;
    final favoriteBusy =
        favorite.value == null ||
        (favorite.value?.busyProductIds.isNotEmpty ?? false);
    final measure = widget.family.measureOf(product);
    final line = cart?.items
        .where(
          (i) =>
              i.product.id == product.id &&
              i.variant == null &&
              i.selectedAddons.isEmpty &&
              i.note.isEmpty,
        )
        .firstOrNull;
    final total = line?.subtotal ?? actual.price;
    final configuration =
        actual.requiresConfiguration ||
        (detail?.addonGroups.isNotEmpty ?? false);
    final canBuy =
        actual.isPurchasable && !actual.inReview && !actual.isSoldOut;
    final reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    void goCart() => goToStoreTab(context, StoreType.shashlik, StoreTab.cart);
    final imageUrls =
        detail?.images.map((i) => i.url).whereType<String>().toList() ??
        <String>[];

    return PopScope(
      canPop: !_busy,
      child: ScaffoldMessenger(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          appBar: AppBar(
            leading: const AppBackButton(),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: l10n.navFavorites,
                onPressed: favoriteBusy || _busy
                    ? null
                    : () async {
                        if (!await requireAuthentication(context, ref) ||
                            !context.mounted) {
                          return;
                        }
                        await ref
                            .read(favoritesControllerProvider.notifier)
                            .toggle(actual);
                        if (!context.mounted) return;
                        final failure = ref
                            .read(favoritesControllerProvider)
                            .value
                            ?.mutationFailure;
                        if (failure != null) {
                          setState(() => _error = failure.localize(l10n));
                        }
                      },
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite
                      ? AppColors.primary
                      : AppColors.lightTextPrimary,
                ),
              ),
              IconButton(
                key: const ValueKey('shashlik-family-cart-button'),
                tooltip: l10n.navCart,
                onPressed: goCart,
                icon: Badge(
                  isLabelVisible: (cart?.totalQuantity ?? 0) > 0,
                  label: Text('${cart?.totalQuantity ?? 0}'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            key: PageStorageKey(
              'shashlik-family-detail-${widget.family.key.wire}',
            ),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height:
                        (constraints.maxWidth * .82).clamp(0.0, 500.0) * .83 +
                        20,
                    child: PageView.builder(
                      key: const ValueKey('shashlik-family-gallery'),
                      controller: _pages,
                      physics: _busy || widget.family.products.length == 1
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: widget.family.products.length,
                      onPageChanged: _selectProduct,
                      itemBuilder: (context, index) {
                        final p = widget.family.products[index];
                        final selected = p.id == product.id;
                        return AnimatedPadding(
                          duration: reduce
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          padding: EdgeInsets.fromLTRB(
                            6,
                            selected ? 0 : 20,
                            6,
                            selected ? 12 : 0,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 500),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: AspectRatio(
                                  aspectRatio: 1.2,
                                  child: ProductImageView(
                                    imageUrl:
                                        _images[p.id] ??
                                        (selected
                                            ? actual.imageUrl
                                            : p.imageUrl) ??
                                        widget.family.imageUrl,
                                    keepPreviousImage: true,
                                    disableFade: true,
                                    memCacheWidth: 800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.family.products.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        key: const ValueKey('shashlik-family-previous'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).previousPageTooltip,
                        onPressed: _busy || _index <= 0
                            ? null
                            : () => _choose(_index - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${_index + 1} / ${widget.family.products.length}'),
                      IconButton(
                        key: const ValueKey('shashlik-family-next'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).nextPageTooltip,
                        onPressed:
                            _busy || _index >= widget.family.products.length - 1
                            ? null
                            : () => _choose(_index + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    shashlikFamilyTitle(l10n, widget.family.key),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                Text(
                  Uzs.format(actual.price),
                  key: const ValueKey('shashlik-family-unit-price'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    shashlikQuantityLabel(l10n, measure, 1),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (imageUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 70,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: imageUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, index) => InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(
                                  () => _images[product.id] = imageUrls[index],
                                ),
                          child: Container(
                            width: 70,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    (_images[product.id] ?? actual.imageUrl) ==
                                        imageUrls[index]
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ProductImageView(
                                imageUrl: imageUrls[index],
                                disableFade: true,
                                memCacheWidth: 200,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        shashlikOptionTitle(l10n, widget.family, product),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (actual.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          actual.description,
                          style: const TextStyle(
                            color: AppColors.lightTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (!canBuy) ...[
                        const SizedBox(height: 12),
                        Text(l10n.productUnavailable),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            key: const ValueKey('shashlik-detail-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: StoreMinimumPanel(
            storeType: StoreType.shashlik,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (line != null)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            shashlikQuantityLabel(l10n, measure, line.quantity),
                          ),
                          TextButton(
                            key: const ValueKey(
                              'shashlik-family-edit-quantity',
                            ),
                            onPressed: _busy
                                ? null
                                : () => _editQuantity(actual, configuration),
                            child: Text(l10n.commonEdit),
                          ),
                        ],
                      ),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          Uzs.formatWithFraction(total),
                          key: const ValueKey('shashlik-family-total'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        FilledButton.icon(
                          key: ValueKey(
                            line == null
                                ? 'shashlik-family-submit'
                                : 'shashlik-go-to-cart',
                          ),
                          onPressed: _busy || (!canBuy && line == null)
                              ? null
                              : line != null
                              ? goCart
                              : () => _editQuantity(actual, configuration),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            line != null
                                ? l10n.productGoToCart
                                : configuration
                                ? l10n.productChooseOptions
                                : l10n.shashlikChooseQuantity,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
