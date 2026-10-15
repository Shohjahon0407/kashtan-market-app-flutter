import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/failure_l10n.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/store_navigation.dart';
import '../../../core/store_scope/store_type.dart';
import '../../../core/ui/theme/app_dimens.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../cart/domain/cart_controller.dart';
import '../../store/presentation/widgets/store_state_views.dart';
import '../data/product_models.dart';
import '../domain/catalog_controller.dart';
import 'widgets/catalog_loading_skeleton.dart';
import 'widgets/product_image.dart';
import 'widgets/shashlik_catalog.dart';

class ShashlikFamilyScreen extends ConsumerWidget {
  const ShashlikFamilyScreen({required this.familyKey, super.key});

  final String familyKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = ShashlikFamilyKey.fromWire(familyKey);
    final catalog = ref.watch(catalogControllerProvider(StoreType.shashlik));
    final cartQuantity =
        ref
            .watch(cartControllerProvider(StoreType.shashlik))
            .value
            ?.cart
            .totalQuantity ??
        0;

    final family = switch (catalog) {
      AsyncData(:final value) when key != null =>
        ShashlikCatalogGroups.fromProducts(
          value.items,
        ).families.where((item) => item.key == key).firstOrNull,
      _ => null,
    };

    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            key == null ? l10n.storeShashlik : shashlikFamilyTitle(l10n, key),
          ),
          actions: [
            IconButton(
              key: const ValueKey('shashlik-family-cart-button'),
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
        body: switch (catalog) {
          AsyncData() when family != null => _FamilyContent(family: family),
          AsyncData() => StoreEmptyView(
            icon: Icons.inventory_2_outlined,
            title: l10n.catalogEmpty,
          ),
          AsyncError(:final error) => StoreErrorView(
            message: error is ApiFailure
                ? error.localize(l10n)
                : l10n.errorUnknown,
            onRetry: () => ref
                .read(catalogControllerProvider(StoreType.shashlik).notifier)
                .refresh(),
          ),
          _ => const CatalogRowsSkeleton(itemCount: 3),
        },
      ),
    );
  }
}

class _FamilyContent extends ConsumerWidget {
  const _FamilyContent({required this.family});

  final ShashlikFamily family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = <String>[];

    void addImage(String? url) {
      if (url != null && url.isNotEmpty && !images.contains(url)) {
        images.add(url);
      }
    }

    for (final product in family.products) {
      final detail = ref.watch(productDetailProvider(product.id));
      final detailImages = detail.value?.images ?? const [];
      for (final image in detailImages) {
        addImage(image.url);
      }
      addImage(product.imageUrl);
    }

    return CustomScrollView(
      key: ValueKey('shashlik-family-detail-${family.key.wire}'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _FamilyGallery(images: images)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xl,
            AppSpacing.screenH,
            AppSpacing.xxxl,
          ),
          sliver: SliverList.separated(
            itemCount: family.products.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _FamilyOptionCard(
              family: family,
              product: family.products[index],
            ),
          ),
        ),
      ],
    );
  }
}

class _FamilyOptionCard extends StatelessWidget {
  const _FamilyOptionCard({required this.family, required this.product});

  final ShashlikFamily family;
  final ProductSummary product;

  @override
  Widget build(BuildContext context) => Semantics(
    label: shashlikOptionTitle(AppLocalizations.of(context), family, product),
    child: ShashlikProductRow(product: product, family: family),
  );
}

class _FamilyGallery extends StatefulWidget {
  const _FamilyGallery({required this.images});

  final List<String> images;

  @override
  State<_FamilyGallery> createState() => _FamilyGalleryState();
}

class _FamilyGalleryState extends State<_FamilyGallery>
    with WidgetsBindingObserver {
  final _controller = PageController();
  Timer? _timer;
  var _page = 0;
  var _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _FamilyGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images.length != oldWidget.images.length) {
      if (_page >= widget.images.length) _page = 0;
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_resumed || widget.images.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.images.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) _timer?.cancel();
    return AspectRatio(
      aspectRatio: 1.45,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.images.isEmpty)
            const ProductImageView(imageUrl: null)
          else
            PageView.builder(
              key: const ValueKey('shashlik-family-gallery'),
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) => CachedNetworkImage(
                imageUrl: widget.images[index],
                fit: BoxFit.cover,
                memCacheWidth: 1000,
                placeholder: (_, _) => const ProductImageView(imageUrl: null),
                errorWidget: (_, _, _) =>
                    const ProductImageView(imageUrl: null),
              ),
            ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.sm,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < widget.images.length; index++)
                    AnimatedContainer(
                      key: ValueKey('shashlik-gallery-dot-$index'),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      width: index == _page ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? colors.primary
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
