import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/formatters/uzs.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/data/cart_models.dart';
import '../../cart/domain/cart_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import '../domain/product_report_controller.dart';
import 'widgets/product_card.dart';
import 'widgets/product_detail_image_zoom.dart';
import 'widgets/product_image.dart';
import 'widgets/product_reviews_section.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.storeType,
    required this.productId,
    super.key,
  });

  final StoreType storeType;
  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  String? _initializedProductId;
  String? _variantId;
  final Map<String, Set<String>> _selectedAddons = {};
  bool _showValidation = false;

  void _initialize(ProductDetail detail) {
    if (_initializedProductId == detail.product.id) return;
    _initializedProductId = detail.product.id;
    final active = detail.product.variants.where((variant) => variant.isActive);
    _variantId = active.where((variant) => variant.isDefault).firstOrNull?.id;
    _variantId ??= active.firstOrNull?.id;
    _selectedAddons.clear();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.productId));
    final l10n = AppLocalizations.of(context);
    // Snackbar pastdagi "savatga qo'shish" panelini to'smasligi uchun —
    // o'z Scaffold'i bo'yicha joylashadi (katalog ekranidagi kabi).
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.catalogTitle)),
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
          _ => const Center(child: CircularProgressIndicator()),
        },
        bottomNavigationBar: detail.value == null
            ? null
            : _buildBottomBar(context, detail.value!),
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

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        SizedBox(
          height: math.min(MediaQuery.sizeOf(context).width, 420),
          child: _ProductGallery(
            imageUrls: gallery,
            fallbackImageUrl: product.imageUrl,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              ] else if (!product.isPurchasable ||
                  _isUnsatisfiable(detail)) ...[
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
                        onSelected: (_) =>
                            setState(() => _variantId = variant.id),
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
              ProductReviewsSection(detail: detail),
              if (detail.relatedProducts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  l10n.productRelated,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: detail.relatedProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) => ProductCard(
                    product: detail.relatedProducts[index],
                    storeType: widget.storeType,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
    final addBusy =
        cartState?.isBusy(CartMutationKeys.add(configuration)) ?? false;
    final itemBusy =
        line != null &&
        (cartState?.isBusy(CartMutationKeys.item(line.id)) ?? false);
    final waitingForCart = cartAsync.isLoading && cartState == null;
    final controller = ref.read(
      cartControllerProvider(widget.storeType).notifier,
    );
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
              ? FilledButton(
                  key: const ValueKey('product-detail-add-to-cart'),
                  onPressed:
                      _inReview(detail) ||
                          !detail.product.isPurchasable ||
                          _isUnsatisfiable(detail) ||
                          waitingForCart ||
                          cartAsync.hasError ||
                          addBusy
                      ? null
                      : () => _addToCart(detail),
                  child: waitingForCart || addBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.productAddShort),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: _QuantityControl(
                        quantity: line.quantity,
                        busy: itemBusy,
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
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: busy ? null : onDecrement,
          icon: const Icon(Icons.remove),
        ),
        if (busy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          onPressed: busy ? null : onIncrement,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
