import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/routing/route_visibility.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/ui/formatters/uzs.dart';
import '../../../../core/ui/theme/app_colors.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../data/product_models.dart';
import 'product_image.dart';
import 'shashlik_catalog.dart';
import 'shashlik_feedback.dart';

/// Families are categories. Only that family's actual products appear here.
class ShashlikVariantRibbon extends StatefulWidget {
  const ShashlikVariantRibbon({
    required this.family,
    required this.onOpen,
    super.key,
  }) : items = null,
       ribbonId = null,
       titleFor = null,
       priceFor = null,
       imageFor = null,
       metadataFor = null,
       heightFor = null,
       cardFor = null,
       widthFor = null,
       itemSpacing = 12,
       autoScroll = true,
       productKeyPrefix = 'shashlik',
       onAdd = null;

  /// Reuses the same accessible, visibility-aware ribbon for meat sections.
  const ShashlikVariantRibbon.products({
    required List<ProductSummary> products,
    required String id,
    required this.onOpen,
    this.onAdd,
    required this.titleFor,
    required this.imageFor,
    this.priceFor,
    this.metadataFor,
    this.heightFor,
    this.cardFor,
    this.widthFor,
    this.itemSpacing = 12,
    this.autoScroll = true,
    this.productKeyPrefix = 'meat',
    super.key,
  }) : assert(cardFor != null || metadataFor != null || onAdd != null),
       family = null,
       items = products,
       ribbonId = id;

  final ShashlikFamily? family;
  final List<ProductSummary>? items;
  final String? ribbonId;
  final String Function(ProductSummary)? titleFor;
  final String Function(ProductSummary)? priceFor;
  final Widget Function(ProductSummary)? imageFor;
  final Widget Function(ProductSummary)? metadataFor;
  final double Function(BuildContext, double)? heightFor;
  final Widget Function(ProductSummary)? cardFor;
  final double Function(BuildContext, double)? widthFor;
  final double itemSpacing;

  /// Hardware shopping stays manual; other store ribbons keep their cadence.
  final bool autoScroll;
  final String productKeyPrefix;
  final Future<void> Function(ProductSummary)? onAdd;
  List<ProductSummary> get products => items ?? family!.products;
  String get id => ribbonId ?? 'shashlik-${family!.key.wire}';
  final ValueChanged<ProductSummary> onOpen;
  @override
  State<ShashlikVariantRibbon> createState() => _ShashlikVariantRibbonState();
}

class _ShashlikVariantRibbonState extends State<ShashlikVariantRibbon>
    with WidgetsBindingObserver, RouteAware, AutomaticKeepAliveClientMixin {
  PageController? _controller;
  double? _fraction;
  Timer? _timer;
  int _page = 0;
  bool _visible = false, _foreground = true, _reduce = false, _touching = false;
  bool _covered = false, _tickers = true;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscribeToEnclosingRoutes(appRouteObserver, this, context);
    _tickers = TickerMode.valuesOf(context).enabled;
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _schedule();
  }

  @override
  void didPushNext() {
    _covered = true;
    _schedule();
  }

  @override
  void didPopNext() {
    _covered = false;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ShashlikVariantRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || _page >= widget.products.length) {
      _page = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (_controller?.hasClients ?? false)) {
          _controller!.jumpToPage(0);
        }
      });
    }
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted ||
        !widget.autoScroll ||
        !_visible ||
        !_foreground ||
        _covered ||
        !_tickers ||
        _reduce ||
        _touching ||
        widget.products.length < 2) {
      return;
    }
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == false ||
          !(_controller?.hasClients ?? false)) {
        _schedule();
        return;
      }
      // Several mini cards fit in one viewport. The final reachable page is
      // earlier than itemCount - 1; wrap there instead of stalling at the edge.
      final position = _controller!.position;
      if (position.maxScrollExtent <= 0) return;
      final lastPage =
          (position.maxScrollExtent /
                  (position.viewportDimension * _controller!.viewportFraction))
              .ceil();
      final next = _page >= lastPage ? 0 : _page + 1;
      unawaited(
        _controller!.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final single = products.length == 1;
        final width =
            widget.widthFor?.call(context, constraints.maxWidth) ??
            math.min(
              single ? constraints.maxWidth : constraints.maxWidth * .82,
              380.0,
            );
        final fraction =
            (width + (single ? 0 : widget.itemSpacing)) / constraints.maxWidth;
        if (_fraction != fraction) {
          final old = _controller;
          _controller = PageController(
            initialPage: _page.clamp(0, products.length - 1),
            viewportFraction: fraction,
          );
          _fraction = fraction;
          if (old != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
          }
        }
        final height =
            widget.heightFor?.call(context, width) ??
            width / 2 +
                math.max(
                  100.0,
                  MediaQuery.textScalerOf(context).scale(16) * 6.5,
                );
        return VisibilityDetector(
          key: ValueKey(
            widget.ribbonId == null
                ? 'shashlik-ribbon-visible-${widget.family!.key.wire}'
                : '${widget.id}-ribbon-visible',
          ),
          onVisibilityChanged: (info) {
            _visible = info.visibleFraction > .3;
            _schedule();
          },
          child: SizedBox(
            height: height,
            child: Listener(
              onPointerDown: (_) {
                _touching = true;
                _schedule();
              },
              onPointerUp: (_) {
                _touching = false;
                _schedule();
              },
              onPointerCancel: (_) {
                _touching = false;
                _schedule();
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) _timer?.cancel();
                  if (notification is ScrollEndNotification) _schedule();
                  return false;
                },
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PageView.builder(
                    key: PageStorageKey(
                      widget.ribbonId ??
                          'shashlik-ribbon-${widget.family!.key.wire}',
                    ),
                    controller: _controller,
                    padEnds: false,
                    itemCount: products.length,
                    onPageChanged: (page) {
                      _page = page;
                    },
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          right: single ? 0 : widget.itemSpacing,
                        ),
                        child:
                            widget.cardFor?.call(product) ??
                            Material(
                              color: Colors.white,
                              child: InkWell(
                                key: ValueKey(
                                  '${widget.productKeyPrefix}-preview-${product.id}',
                                ),
                                onTap: () => widget.onOpen(product),
                                borderRadius: BorderRadius.circular(18),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: AspectRatio(
                                        aspectRatio: 2,
                                        child:
                                            widget.imageFor?.call(product) ??
                                            ProductImageView(
                                              imageUrl:
                                                  product.imageUrl ??
                                                  widget.family!.imageUrl,
                                              memCacheWidth: 700,
                                              disableFade: true,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    widget.metadataFor?.call(product) ??
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    widget.titleFor?.call(
                                                          product,
                                                        ) ??
                                                        shashlikOptionTitle(
                                                          l10n,
                                                          widget.family!,
                                                          product,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: AppColors
                                                          .lightTextPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    widget.priceFor?.call(
                                                          product,
                                                        ) ??
                                                        Uzs.format(
                                                          product.price,
                                                        ),
                                                    maxLines: 2,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            SizedBox.square(
                                              dimension: 48,
                                              child: IconButton.outlined(
                                                key: ValueKey(
                                                  widget.family == null
                                                      ? 'meat-add-${product.id}'
                                                      : index == 0
                                                      ? 'shashlik-family-add-${widget.family!.key.wire}'
                                                      : 'shashlik-variant-add-${product.id}',
                                                ),
                                                tooltip: l10n.shashlikAddToCart,
                                                style: IconButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.primary,
                                                  side: const BorderSide(
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                onPressed:
                                                    !product.isPurchasable ||
                                                        product.inReview
                                                    ? null
                                                    : () async {
                                                        if (widget.onAdd !=
                                                            null) {
                                                          await widget.onAdd!(
                                                            product,
                                                          );
                                                          return;
                                                        }
                                                        if (product
                                                            .requiresConfiguration) {
                                                          widget.onOpen(
                                                            product,
                                                          );
                                                          return;
                                                        }
                                                        final added =
                                                            await showShashlikFamilySelector(
                                                              context,
                                                              widget.family!,
                                                              initialProductId:
                                                                  product.id,
                                                            );
                                                        if (added == true &&
                                                            context.mounted) {
                                                          showShashlikSaved(
                                                            context,
                                                          );
                                                        }
                                                      },
                                                icon: const Icon(Icons.add),
                                              ),
                                            ),
                                          ],
                                        ),
                                  ],
                                ),
                              ),
                            ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
