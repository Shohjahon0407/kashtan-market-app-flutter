import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/failure_l10n.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';
import '../../domain/catalog_controller.dart';
import 'product_image.dart';

/// Only the image strip is paged. Detail, configuration and cart controls
/// belong to the selected product, not to neighboring preview cards.
class RestaurantDishPager extends ConsumerStatefulWidget {
  const RestaurantDishPager({
    required this.product,
    required this.imageUrl,
    required this.onChanged,
    this.categoryId,
    this.onNearbyChanged,
    super.key,
  });

  final ProductSummary? product;
  final String? imageUrl;
  final ValueChanged<ProductSummary> onChanged;
  final String? categoryId;
  final ValueChanged<List<ProductSummary>>? onNearbyChanged;

  @override
  ConsumerState<RestaurantDishPager> createState() =>
      _RestaurantDishPagerState();
}

class _RestaurantDishPagerState extends ConsumerState<RestaurantDishPager> {
  static const _viewportFraction = .82;
  static const _imageAspectRatio = 6 / 5;
  static const _neighborDrop = 24.0;
  static const _glowInset = 16.0;
  PageController _controller = PageController(
    viewportFraction: _viewportFraction,
    keepPage: false,
  );
  List<ProductSummary> _items = [];
  String? _categoryId, _next;
  bool _loading = false, _initialized = false;
  Object? _error;
  int _revision = 0;
  final Set<String> _visited = {};
  final Map<String, _WarmDishImage> _warmImages = {};
  bool _imageWarmupScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleImageWarmup();
  }

  @override
  void initState() {
    super.initState();
    _syncCategory();
  }

  @override
  void didUpdateWidget(covariant RestaurantDishPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCategory();
    _scheduleImageWarmup();
  }

  void _syncCategory() {
    if (widget.product == null) return;
    final category = widget.categoryId ?? widget.product?.category?.id;
    if (category == null || category.isEmpty || category == _categoryId) return;
    _categoryId = category;
    _initialized = false;
    _items = [];
    _next = null;
    _visited.clear();
    _revision++;
    _loading = false;
    unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    for (final image in _warmImages.values) {
      image.dispose();
    }
    _warmImages.clear();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleImageWarmup() {
    if (_imageWarmupScheduled) return;
    _imageWarmupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _imageWarmupScheduled = false;
      if (!mounted) return;
      final items = _items.isNotEmpty
          ? _items
          : <ProductSummary>[?widget.product];
      final selected = items.indexWhere((p) => p.id == widget.product?.id);
      if (selected < 0) return;
      // Keep only this dish and two neighbors each way decoded/live. This
      // avoids disk reads and placeholder frames during the next swipe,
      // without pinning every photo in a long menu in RAM.
      final urls = <String>{};
      for (
        var index = (selected - 2).clamp(0, items.length);
        index < items.length && index <= selected + 2;
        index++
      ) {
        final url = items[index].imageUrl;
        if (url != null && url.isNotEmpty) urls.add(url);
      }
      final activePhoto = widget.imageUrl;
      if (activePhoto != null && activePhoto.isNotEmpty) urls.add(activePhoto);
      for (final url in _warmImages.keys.toList()) {
        if (!urls.contains(url)) _warmImages.remove(url)?.dispose();
      }
      final configuration = createLocalImageConfiguration(context);
      for (final url in urls) {
        _warmImages.putIfAbsent(url, () {
          final stream = ProductImageView.decodedProvider(
            url,
            persistent: true,
          ).resolve(configuration);
          final listener = ImageStreamListener(
            (image, _) => image.dispose(),
            onError: (Object _, StackTrace? _) {
              // Loading/error UI belongs to the image, not speculative work.
            },
          );
          stream.addListener(listener);
          return _WarmDishImage(stream, listener);
        });
      }
    });
  }

  Future<void> _load() async {
    final category = _categoryId;
    final anchor = widget.product;
    if (_loading || category == null || anchor == null) return;
    final revision = ++_revision;
    // Called from init/update as well as from taps: no provider is mutated.
    setState(() {
      _loading = true;
      _error = null;
    });
    final firstLoad = !_initialized;
    final gathered = firstLoad ? <ProductSummary>[] : [..._items];
    final visited = firstLoad ? <String>{} : {..._visited};
    final ids = gathered.map((p) => p.id).toSet();
    var next = firstLoad ? null : _next;
    try {
      final api = ref.read(catalogApiProvider);
      do {
        final page = await api.fetchProducts(
          storeType: 'restaurant',
          categoryId: category,
          nextUrl: next,
        );
        if (!mounted || revision != _revision) return;
        for (final product in page.items) {
          // The category endpoint includes descendants. Keep that server
          // ordering/membership rather than dropping valid child dishes.
          if (product.storeTypeWire == 'restaurant' && ids.add(product.id)) {
            gathered.add(product);
          }
        }
        next = page.nextUrl;
        if (next?.isEmpty == true) next = null;
        if (next != null && !visited.add(next)) next = null;
        // Locate a deep-linked/preview product without making the user wait
        // for its detail, and without duplicating it in the category strip.
      } while (firstLoad && !ids.contains(anchor.id) && next != null);
      if (!mounted || revision != _revision) return;
      if (firstLoad && !ids.contains(anchor.id)) gathered.insert(0, anchor);
      if (firstLoad) {
        final old = _controller;
        _controller = PageController(
          viewportFraction: _viewportFraction,
          keepPage: false,
          initialPage: gathered.indexWhere((p) => p.id == anchor.id),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      setState(() {
        _items = gathered;
        _visited
          ..clear()
          ..addAll(visited);
        _next = next;
        _initialized = true;
        _loading = false;
      });
      _scheduleImageWarmup();
      _notifyNearby();
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _move(int index) {
    if (!_controller.hasClients) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _controller.animateToPage(
      index,
      duration: Duration(milliseconds: reduced ? 0 : 600),
      curve: Curves.easeInOutCubic,
    );
  }

  void _notifyNearby([int? selectedIndex]) {
    final index =
        selectedIndex ?? _items.indexWhere((p) => p.id == widget.product?.id);
    if (index < 0) return;
    widget.onNearbyChanged?.call([
      if (index + 1 < _items.length) _items[index + 1],
      if (index > 0) _items[index - 1],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(apiLangProvider, (previous, next) {
      if (previous == next) return;
      _categoryId = null;
      _syncCategory();
    });
    final l10n = AppLocalizations.of(context);
    final current = widget.product;
    final items = _items.isNotEmpty ? _items : <ProductSummary>[?current];
    final selected = items.indexWhere((p) => p.id == current?.id);
    final index = selected < 0 ? 0 : selected;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            key: const ValueKey('restaurant-detail-pager'),
            height:
                constraints.maxWidth * _viewportFraction / _imageAspectRatio +
                _neighborDrop +
                _glowInset,
            child: items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.stylus,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: PageView.builder(
                      key: ObjectKey(_controller),
                      controller: _controller,
                      allowImplicitScrolling: true,
                      itemCount: items.length,
                      onPageChanged: (page) {
                        widget.onChanged(items[page]);
                        _notifyNearby(page);
                        if (page >= items.length - 2 &&
                            _next != null &&
                            _error == null) {
                          unawaited(_load());
                        }
                      },
                      itemBuilder: (context, page) {
                        final product = items[page];
                        final active = product.id == current?.id;
                        final reduced = MediaQuery.disableAnimationsOf(context);
                        return Padding(
                          key: ValueKey('dish-page-${product.id}'),
                          padding: const EdgeInsets.only(top: _glowInset),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final position =
                                  _controller.hasClients &&
                                      _controller.position.hasContentDimensions
                                  ? _controller.page ??
                                        _controller.initialPage.toDouble()
                                  : _controller.initialPage.toDouble();
                              final distance = reduced
                                  ? (active ? 0.0 : 1.0)
                                  : (position - page).abs().clamp(0.0, 1.0);
                              final progress = Curves.easeInOutCubic.transform(
                                distance,
                              );
                              // Follow the finger continuously, rather than
                              // switching scale abruptly at onPageChanged.
                              return Transform.translate(
                                offset: Offset(0, _neighborDrop * progress),
                                child: Transform.scale(
                                  scale: 1 - .06 * progress,
                                  alignment: Alignment.topCenter,
                                  child: child,
                                ),
                              );
                            },
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Semantics(
                                  label: product.name,
                                  button: !active,
                                  child: GestureDetector(
                                    onTap: active ? null : () => _move(page),
                                    child: RepaintBoundary(
                                      child: DecoratedBox(
                                        key: ValueKey(
                                          'dish-glow-${product.id}',
                                        ),
                                        decoration: const BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(24),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x24087F5B),
                                              blurRadius: 20,
                                              spreadRadius: 1,
                                              offset: Offset.zero,
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: _imageAspectRatio,
                                            child: ProductImageView(
                                              persistent: true,
                                              keepPreviousImage: true,
                                              key: ValueKey(
                                                'dish-photo-${product.id}',
                                              ),
                                              imageUrl: active
                                                  ? widget.imageUrl
                                                  : product.imageUrl,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DishArrow(
                  key: const ValueKey('dish-previous-button'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).previousPageTooltip,
                  onPressed: index > 0 ? () => _move(index - 1) : null,
                  icon: Icons.chevron_left,
                ),
                Flexible(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      '${index + 1} / ${items.length}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _DishArrow(
                  key: const ValueKey('dish-next-button'),
                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                  onPressed: index < items.length - 1
                      ? () => _move(index + 1)
                      : null,
                  icon: Icons.chevron_right,
                ),
              ],
            ),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  _error is ApiFailure
                      ? (_error as ApiFailure).localize(l10n)
                      : l10n.errorUnknown,
                ),
                TextButton(
                  onPressed: () => unawaited(_load()),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DishArrow extends StatelessWidget {
  const _DishArrow({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(52),
      minimumSize: const Size.square(52),
      iconSize: 36,
      foregroundColor: const Color(0xFF151515),
      disabledForegroundColor: const Color(0xFFCBD5E1),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: onPressed == null
            ? const Color(0xFFF1F5F9)
            : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class _WarmDishImage {
  const _WarmDishImage(this.stream, this.listener);
  final ImageStream stream;
  final ImageStreamListener listener;
  void dispose() => stream.removeListener(listener);
}
