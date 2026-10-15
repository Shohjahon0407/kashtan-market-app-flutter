import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

class RestaurantCategoryLandingSliver extends StatelessWidget {
  const RestaurantCategoryLandingSliver({
    required this.categories,
    required this.onCategoryTap,
    super.key,
  });

  final List<ProductCategory> categories;
  final ValueChanged<ProductCategory> onCategoryTap;

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 358;
            return _RestaurantCategoryCard(
              key: ValueKey('restaurant-category-${items[index].category.id}'),
              item: items[index],
              height: compact ? 118 : 128,
              visibleImageCount: compact ? 2 : 3,
              onTap: () => onCategoryTap(items[index].category),
            );
          },
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.xxxl,
      ),
      sliver: SliverList.separated(
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => LayoutBuilder(
          builder: (context, constraints) => Container(
            key: ValueKey('restaurant-category-skeleton-$index'),
            height: constraints.maxWidth < 358 ? 118 : 128,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCategoryCard extends StatefulWidget {
  const _RestaurantCategoryCard({
    required this.item,
    required this.height,
    required this.visibleImageCount,
    required this.onTap,
    super.key,
  });

  final PhotoCategoryItem item;
  final double height;
  final int visibleImageCount;
  final VoidCallback onTap;

  @override
  State<_RestaurantCategoryCard> createState() =>
      _RestaurantCategoryCardState();
}

class _RestaurantCategoryCardState extends State<_RestaurantCategoryCard>
    with WidgetsBindingObserver {
  static const _slideInterval = Duration(seconds: 4);
  static const _slideDuration = Duration(milliseconds: 1200);

  late PageController _controller;
  Timer? _timer;
  bool _visible = false;
  bool _foreground = true;
  bool _userScrolling = false;

  List<String> get _images => widget.item.category.previewImageUrls;
  bool get _canSlide => _images.length > 1;
  int get _initialPage => _images.isEmpty ? 0 : _images.length * 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _newController();
  }

  PageController _newController() => PageController(
    initialPage: _initialPage,
    viewportFraction: 1 / widget.visibleImageCount,
  );

  @override
  void didUpdateWidget(covariant _RestaurantCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleImageCount != widget.visibleImageCount ||
        oldWidget.item.category.previewImageUrls !=
            widget.item.category.previewImageUrls) {
      _timer?.cancel();
      _controller.dispose();
      _controller = _newController();
      _syncTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  bool get _motionDisabled =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_canSlide || !_visible || !_foreground || _motionDisabled) return;
    _timer = Timer.periodic(_slideInterval, (_) => _showNextImage());
  }

  Future<void> _showNextImage() async {
    if (!mounted || !_controller.hasClients || _userScrolling) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true) ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    final current = _controller.page?.round() ?? _initialPage;
    await _controller.animateToPage(
      current + 1,
      duration: _slideDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = Semantics(
      button: true,
      label: widget.item.category.name,
      child: Material(
        key: ValueKey('photo-category-card-${widget.item.category.id}'),
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            height: widget.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: _buildImages()),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [.38, 1],
                        colors: [Colors.transparent, Color(0xA8000000)],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      widget.item.category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!_canSlide) return card;
    return VisibilityDetector(
      key: ValueKey(
        'restaurant-category-visibility-${widget.item.category.id}',
      ),
      onVisibilityChanged: (info) {
        final nextVisible = info.visibleFraction >= .15;
        if (_visible == nextVisible) return;
        _visible = nextVisible;
        _syncTimer();
      },
      child: card,
    );
  }

  Widget _buildImages() {
    if (_images.isEmpty) {
      return _CategoryImageTile(assetPath: widget.item.assetPath);
    }
    if (_images.length == 1) {
      return _CategoryImageTile(
        imageUrl: _images.first,
        assetPath: widget.item.assetPath,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _userScrolling = false;
        }
        return false;
      },
      child: PageView.builder(
        key: ValueKey(
          'restaurant-category-carousel-${widget.item.category.id}',
        ),
        controller: _controller,
        padEnds: false,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: _CategoryImageTile(
            imageUrl: _images[index % _images.length],
            assetPath: widget.item.assetPath,
          ),
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
    final fallback = _fallback(context);
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 420,
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
