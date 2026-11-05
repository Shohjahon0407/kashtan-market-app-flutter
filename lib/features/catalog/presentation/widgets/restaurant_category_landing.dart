import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/storage/product_image_cache.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_dimens.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';
import 'photo_category_landing.dart';

class _RestaurantVisualSpec {
  const _RestaurantVisualSpec(this.order, this.assetName);

  final int order;
  final String assetName;
}

const _assetRoot = 'assets/categories/restaurant';

const Map<String, _RestaurantVisualSpec> _visuals = {
  '1-taomlar': _RestaurantVisualSpec(0, 'first-courses.webp'),
  '2-taomlar': _RestaurantVisualSpec(1, 'main-courses.webp'),
  'oshlar': _RestaurantVisualSpec(2, 'plov.webp'),
  'xalim': _RestaurantVisualSpec(3, 'halim.webp'),
  'halim': _RestaurantVisualSpec(3, 'halim.webp'),
  'shashlik': _RestaurantVisualSpec(4, 'shashlik.webp'),
  'somsa': _RestaurantVisualSpec(5, 'somsa.webp'),
  'salatlar': _RestaurantVisualSpec(6, 'salads.webp'),
  'choy non': _RestaurantVisualSpec(7, 'tea-bread.webp'),
  'baliq': _RestaurantVisualSpec(100, 'fish.webp'),
  'shirinliklar': _RestaurantVisualSpec(101, 'desserts.webp'),
  'muzqaymoq': _RestaurantVisualSpec(102, 'ice-cream.webp'),
  'kampot': _RestaurantVisualSpec(103, 'compote.webp'),
  'kompot': _RestaurantVisualSpec(103, 'compote.webp'),
};

List<PhotoCategoryItem> buildRestaurantCategoryItems(
  List<ProductCategory> categories,
) {
  final items = <({PhotoCategoryItem item, int order, int sourceOrder})>[];
  for (var index = 0; index < categories.length; index++) {
    final category = categories[index];
    if (category.productCount <= 0) continue;
    final key = normalizeCategoryAssetKey(
      category.canonicalName ?? category.name,
    );
    final spec = _visuals[key];
    items.add((
      item: PhotoCategoryItem(
        category: category,
        assetPath: spec == null ? null : '$_assetRoot/${spec.assetName}',
      ),
      order: spec?.order ?? 1000 + category.sortOrder,
      sourceOrder: index,
    ));
  }
  items.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.sourceOrder.compareTo(b.sourceOrder);
  });
  return items.map((entry) => entry.item).toList(growable: false);
}

const ofiyatGreen = Color(0xFF15803D);

class OfiyatBrandTitle extends StatelessWidget {
  const OfiyatBrandTitle({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ofiyat milliy taomlari',
    excludeSemantics: true,
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ofiyat',
          style: TextStyle(
            color: ofiyatGreen,
            fontSize: 24,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        Text(
          'milliy taomlari',
          style: TextStyle(
            color: ofiyatGreen,
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

const _dishNameStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 1.25,
  color: Color(0xFF171717),
);
const _dishPriceStyle = TextStyle(
  fontSize: 16,
  height: 1.25,
  fontWeight: FontWeight.w700,
  color: ofiyatGreen,
);

double _cardHeight(BuildContext context, double width, {List<_Slide>? slides}) {
  final scaler = MediaQuery.textScalerOf(context);
  if (slides == null) {
    return width / 2 + 12 + scaler.scale(16) * 3.75;
  }
  double measure(String text, TextStyle style, {int? maxLines}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textScaler: scaler,
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final height = painter.height.ceilToDouble();
    painter.dispose();
    return height;
  }

  var metadataHeight = 0.0;
  for (final slide in slides) {
    final price = Uzs.format(slide.price);
    if (slide.name.isEmpty && price.isEmpty) continue;
    final height =
        8 +
        (slide.name.isEmpty
            ? 0
            : measure(slide.name, _dishNameStyle, maxLines: 2)) +
        (slide.name.isEmpty || price.isEmpty ? 0 : 4) +
        (price.isEmpty ? 0 : measure(price, _dishPriceStyle));
    metadataHeight = math.max(metadataHeight, height + 2);
  }
  return width / 2 + metadataHeight;
}

class RestaurantCategoryLandingSliver extends StatelessWidget {
  const RestaurantCategoryLandingSliver({
    required this.categories,
    required this.onCategoryTap,
    this.onProductTap,
    super.key,
  });
  final List<ProductCategory> categories;
  final ValueChanged<ProductCategory> onCategoryTap;
  final void Function(ProductCategory category, String productId)? onProductTap;

  @override
  Widget build(BuildContext context) {
    final items = buildRestaurantCategoryItems(categories);
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(AppLocalizations.of(context).catalogEmpty)),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) => _RestaurantCategoryCard(
          key: ValueKey('restaurant-category-${items[index].category.id}'),
          item: items[index],
          onTap: () => onCategoryTap(items[index].category),
          onProductTap: (id) => onProductTap == null
              ? onCategoryTap(items[index].category)
              : onProductTap!(items[index].category, id),
        ),
      ),
    );
  }
}

class RestaurantCategoryLandingSkeleton extends StatelessWidget {
  const RestaurantCategoryLandingSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      sliver: SliverList.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, index) => LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: MediaQuery.textScalerOf(context).scale(22),
                width: 160,
                color: color,
              ),
              const SizedBox(height: 8),
              Container(
                key: ValueKey('restaurant-category-skeleton-$index'),
                height: _cardHeight(context, constraints.maxWidth),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide(this.image, {this.name = '', this.price, this.productId});
  final String? image, price;
  final String? productId;
  final String name;
}

List<_Slide> _slides(ProductCategory category) {
  final seen = <String>{};
  final products = [
    for (final product in category.previewProducts)
      if (product.id.isNotEmpty &&
          product.imageUrl?.isNotEmpty == true &&
          seen.add(product.id))
        _Slide(
          product.imageUrl,
          name: product.name,
          price: product.price,
          productId: product.id,
        ),
  ];
  if (products.isNotEmpty) return products.take(6).toList(growable: false);
  // Old cache/API has no reliable product metadata. Never zip photos with
  // unrelated names/prices, nor label the category name as a dish.
  return [for (final image in category.previewImageUrls.take(1)) _Slide(image)];
}

class _RestaurantCategoryCard extends StatefulWidget {
  const _RestaurantCategoryCard({
    required this.item,
    required this.onTap,
    required this.onProductTap,
    super.key,
  });
  final PhotoCategoryItem item;
  final VoidCallback onTap;
  final ValueChanged<String> onProductTap;
  @override
  State<_RestaurantCategoryCard> createState() =>
      _RestaurantCategoryCardState();
}

class _RestaurantCategoryCardState extends State<_RestaurantCategoryCard>
    with WidgetsBindingObserver {
  static const _interval = Duration(seconds: 3);
  static const _duration = Duration(milliseconds: 600);
  PageController? _controller;
  late int _page;
  bool _restored = false;
  Timer? _timer;
  bool _visible = false,
      _foreground = true,
      _userScrolling = false,
      _touching = false;
  List<_Slide> get slides => _slides(widget.item.category);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _page = slides.length * 1000;
  }

  @override
  void didUpdateWidget(covariant _RestaurantCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      final saved = PageStorage.maybeOf(context)?.readState(
        context,
        identifier: 'ofiyat-carousel-${widget.item.category.id}',
      );
      if (saved is int) _page = saved;
      _restored = true;
    }
    _syncTimer();
  }

  PageController _controllerFor(double fraction) {
    final old = _controller;
    if (old == null || (old.viewportFraction - fraction).abs() > .0001) {
      _controller = PageController(
        initialPage: _page,
        viewportFraction: fraction,
        keepPage: false,
      );
      // The old PageView detaches during this frame, before its controller
      // is disposed. Keep the selected page when rotating/resizing.
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }
    return _controller!;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    final media = MediaQuery.maybeOf(context);
    if (slides.length <= 1 ||
        !_visible ||
        !_foreground ||
        _userScrolling ||
        _touching ||
        media?.disableAnimations == true ||
        media?.accessibleNavigation == true ||
        !TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _timer = Timer.periodic(_interval, (_) => unawaited(_next()));
  }

  Future<void> _next() async {
    final controller = _controller;
    if (!mounted ||
        controller == null ||
        !controller.hasClients ||
        _userScrolling ||
        _touching ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    final page = controller.page?.round() ?? controller.initialPage;
    await controller.animateToPage(
      page + 1,
      duration: _duration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = slides;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    widget.item.category.name,
                    key: ValueKey(
                      'restaurant-category-heading-${widget.item.category.id}',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: widget.item.category.name,
                    style: const TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontSize: 24,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF171717),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: ValueKey(
                'restaurant-category-all-${widget.item.category.id}',
              ),
              onPressed: widget.onTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF171717),
                backgroundColor: const Color(0xFFF5F5F4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).commonAll,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final multiple = data.length > 1;
            final width = math.min(
              constraints.maxWidth * (multiple ? .82 : 1),
              380.0,
            );
            Widget dish(_Slide slide, int index) => _DishSlide(
              key: ValueKey(
                'restaurant-dish-${widget.item.category.id}-$index',
              ),
              imageKey: ValueKey(
                'restaurant-dish-image-${widget.item.category.id}-$index',
              ),
              slide: slide,
              asset: widget.item.assetPath,
              onTap: slide.productId == null
                  ? widget.onTap
                  : () => widget.onProductTap(slide.productId!),
            );
            final card = SizedBox(
              key: ValueKey('photo-category-card-${widget.item.category.id}'),
              height: _cardHeight(context, width, slides: data),
              child: Listener(
                onPointerDown: (_) {
                  _touching = true;
                  _syncTimer();
                },
                onPointerUp: (_) {
                  _touching = false;
                  _syncTimer();
                },
                onPointerCancel: (_) {
                  _touching = false;
                  _syncTimer();
                },
                child: !multiple
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: width,
                          child: dish(
                            data.firstOrNull ?? const _Slide(null),
                            0,
                          ),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (event) {
                          if (event is ScrollStartNotification &&
                              event.dragDetails != null) {
                            _userScrolling = true;
                            _syncTimer();
                          } else if (event is ScrollEndNotification &&
                              _userScrolling) {
                            _userScrolling = false;
                            _syncTimer();
                          }
                          return false;
                        },
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              ...ScrollConfiguration.of(context).dragDevices,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: PageView.builder(
                            key: ValueKey(
                              'restaurant-category-carousel-${widget.item.category.id}',
                            ),
                            controller: _controllerFor(
                              (width + 12) / constraints.maxWidth,
                            ),
                            padEnds: false,
                            onPageChanged: (page) {
                              _page = page;
                              PageStorage.maybeOf(context)?.writeState(
                                context,
                                page,
                                identifier:
                                    'ofiyat-carousel-${widget.item.category.id}',
                              );
                            },
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: dish(data[index % data.length], index),
                            ),
                          ),
                        ),
                      ),
              ),
            );
            if (data.length <= 1) return card;
            return VisibilityDetector(
              key: ValueKey(
                'restaurant-category-visibility-${widget.item.category.id}',
              ),
              onVisibilityChanged: (info) {
                if (!mounted) return;
                final visible = info.visibleFraction >= .5;
                if (_visible != visible) {
                  _visible = visible;
                  _syncTimer();
                }
              },
              child: card,
            );
          },
        ),
      ],
    );
  }
}

class _DishSlide extends StatelessWidget {
  const _DishSlide({
    required this.slide,
    required this.onTap,
    required this.imageKey,
    this.asset,
    super.key,
  });
  final _Slide slide;
  final String? asset;
  final VoidCallback onTap;
  final Key imageKey;
  @override
  Widget build(BuildContext context) {
    final price = Uzs.format(slide.price);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2,
              child: ClipRRect(
                key: imageKey,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: _CategoryImageTile(
                      imageUrl: slide.image,
                      assetPath: asset,
                    ),
                  ),
                ),
              ),
            ),
            if (slide.name.isNotEmpty || price.isNotEmpty)
              const SizedBox(height: 8),
            if (slide.name.isNotEmpty)
              Text(
                slide.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                semanticsLabel: slide.name,
                style: _dishNameStyle,
              ),
            if (slide.name.isNotEmpty && price.isNotEmpty)
              const SizedBox(height: 4),
            if (price.isNotEmpty) Text(price, style: _dishPriceStyle),
          ],
        ),
      ),
    );
  }
}

class _CategoryImageTile extends StatelessWidget {
  const _CategoryImageTile({this.imageUrl, this.assetPath});

  final String? imageUrl;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = url == null || url.isEmpty
        ? _fallback(context)
        : _placeholder(context);
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      cacheManager: ProductImageCache.persistentManager,
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      memCacheWidth:
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(320, 1280),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }

  Widget _fallback(BuildContext context) {
    final asset = assetPath;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.restaurant_rounded,
      color: Theme.of(context).colorScheme.outline,
      size: 38,
    ),
  );
}
