import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/category_banners.dart';
import 'product_image.dart';

class CategoryProductBanners extends StatefulWidget {
  const CategoryProductBanners({
    required this.banners,
    required this.onTap,
    required this.onLoadMore,
    this.hasMore = false,
    this.loadMoreFailed = false,
    super.key,
  });
  final List<CategoryProductBanner> banners;
  final ValueChanged<CategoryProductBanner> onTap;
  final VoidCallback onLoadMore;
  final bool hasMore, loadMoreFailed;
  @override
  State<CategoryProductBanners> createState() => _CategoryProductBannersState();
}

class _CategoryProductBannersState extends State<CategoryProductBanners>
    with WidgetsBindingObserver, RouteAware {
  final _pages = PageController();
  Timer? _timer;
  ModalRoute<dynamic>? _route;
  bool _visible = false,
      _foreground = true,
      _covered = false,
      _dragging = false;
  int _index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
    _sync();
  }

  @override
  void didUpdateWidget(covariant CategoryProductBanners oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.banners.length && widget.banners.isNotEmpty) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
    _sync();
  }

  @override
  void didPushNext() {
    _covered = true;
    _sync();
  }

  @override
  void didPopNext() {
    _covered = false;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (!mounted ||
        !_visible ||
        !_foreground ||
        _covered ||
        _dragging ||
        widget.banners.length < 2 ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!_pages.hasClients || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      if (_index == widget.banners.length - 1 && widget.hasMore) {
        if (!widget.loadMoreFailed) widget.onLoadMore();
        return;
      }
      _go((_index + 1) % widget.banners.length);
    });
  }

  void _go(int page) {
    if (!_pages.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        ),
      );
    }
  }

  Widget _indicators(BuildContext context) {
    // Keep the strip compact even when many paginated banners are loaded.
    final count = math.min(7, widget.banners.length);
    final start = (_index - count ~/ 2).clamp(0, widget.banners.length - count);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: MaterialLocalizations.of(
        context,
      ).tabLabel(tabIndex: _index + 1, tabCount: widget.banners.length),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (offset) {
            final index = start + offset;
            final active = index == _index;
            final edge =
                (offset == 0 && start > 0) ||
                (offset == count - 1 && index < widget.banners.length - 1);
            return AnimatedContainer(
              key: ValueKey('category-banner-indicator-$index'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : (edge ? 4 : 6),
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return VisibilityDetector(
      key: ValueKey('category-banner-visibility-${widget.banners.first.id}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > .15;
        if (_visible != visible) {
          _visible = visible;
          _sync();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = widget.banners
                .map(
                  (banner) =>
                      _BannerCard.height(context, banner, constraints.maxWidth),
                )
                .reduce(math.max);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: height,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification &&
                          notification.dragDetails != null) {
                        _dragging = true;
                        _sync();
                      }
                      if (notification is ScrollEndNotification) {
                        _dragging = false;
                        _sync();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      key: const ValueKey('category-banner-carousel'),
                      controller: _pages,
                      itemCount: widget.banners.length,
                      onPageChanged: (index) {
                        setState(() => _index = index);
                        _sync();
                        if (index >= widget.banners.length - 3 &&
                            widget.hasMore &&
                            !widget.loadMoreFailed) {
                          widget.onLoadMore();
                        }
                      },
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _BannerCard(
                          banner: widget.banners[index],
                          onTap: () => widget.onTap(widget.banners[index]),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.banners.length > 1) _indicators(context),
                if (widget.loadMoreFailed)
                  TextButton(
                    onPressed: widget.onLoadMore,
                    child: Text(l10n.commonRetry),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Color _color(String raw, Color fallback) =>
    RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(raw)
    ? Color(int.parse('FF${raw.substring(1)}', radix: 16))
    : fallback;

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});
  final CategoryProductBanner banner;
  final VoidCallback onTap;
  static const titleStyle = TextStyle(
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );
  static const bodyStyle = TextStyle(fontSize: 12, height: 1.35);
  static const labelStyle = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
  static const priceStyle = TextStyle(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w900,
  );
  static double height(
    BuildContext context,
    CategoryProductBanner banner,
    double width,
  ) {
    final textWidth = math.max(50.0, (width - 48) * .58);
    double measure(String text, TextStyle style, [double inset = 0]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(20, textWidth - inset));
      final result = painter.height;
      painter.dispose();
      return result;
    }

    return math.max(
      180,
      48 +
          measure(banner.title, titleStyle) +
          (banner.subtitle.isEmpty
              ? 0
              : measure(banner.subtitle, bodyStyle) + 8) +
          (banner.badge.isEmpty
              ? 0
              : measure(banner.badge, labelStyle, 16) + 20) +
          measure(Uzs.format(banner.product.price), priceStyle) +
          8 +
          measure(
            banner.cta.isEmpty
                ? AppLocalizations.of(context).categoryAdDetails
                : banner.cta,
            labelStyle,
            44,
          ) +
          26,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = _color(banner.textColor, Colors.white);
    return Material(
      color: _color(banner.backgroundColor, const Color(0xFF087F65)),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 58,
                child: DefaultTextStyle(
                  style: bodyStyle.copyWith(color: foreground),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (banner.badge.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: foreground.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(banner.badge, style: labelStyle),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(banner.title, style: titleStyle),
                      if (banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(banner.subtitle),
                      ],
                      const SizedBox(height: 8),
                      Text(Uzs.format(banner.product.price), style: priceStyle),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  banner.cta.isEmpty
                                      ? AppLocalizations.of(
                                          context,
                                        ).categoryAdDetails
                                      : banner.cta,
                                  style: labelStyle.copyWith(
                                    color: const Color(0xFF123D32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward,
                                size: 16,
                                color: Color(0xFF123D32),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 42,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.white,
                      child: ProductImageView(
                        imageUrl: banner.imageUrl ?? banner.product.imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 480,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
