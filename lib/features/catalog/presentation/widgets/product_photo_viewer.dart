import 'package:flutter/material.dart';

import '../../../../generated/l10n/app_localizations.dart';
import 'product_image.dart';

/// Ovqat rasmini to'liq ekranda, tiniq ochadi: chimchilab (1–4x) yoki ikki
/// marta bosib kattalashtirish, rasmlar orasida surish, pastga surib yopish.
///
/// Qaytaradi: yopilgan paytdagi rasm indeksi (detail sahifasi shu rasmga
/// o'tadi).
Future<int?> showProductPhotoViewer(
  BuildContext context, {
  required List<String> photos,
  int initialIndex = 0,
  String? title,
}) {
  if (photos.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push<int>(
    PageRouteBuilder<int>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => ProductPhotoViewer(
        photos: photos,
        initialIndex: initialIndex.clamp(0, photos.length - 1),
        title: title,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class ProductPhotoViewer extends StatefulWidget {
  const ProductPhotoViewer({
    required this.photos,
    this.initialIndex = 0,
    this.title,
    super.key,
  });

  final List<String> photos;
  final int initialIndex;
  final String? title;

  @override
  State<ProductPhotoViewer> createState() => _ProductPhotoViewerState();
}

class _ProductPhotoViewerState extends State<ProductPhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  double _dragOffset = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    // To'liq ekran: ekran piksellaridan ikki baravar (zoom uchun), 2048 gacha.
    final decodeWidth =
        (size.width * MediaQuery.devicePixelRatioOf(context) * 2).round().clamp(
          1080,
          2048,
        );
    final fade = (1 - _dragOffset.abs() / (size.height * .6)).clamp(0.3, 1.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        key: const ValueKey('product-photo-viewer'),
        backgroundColor: Colors.black.withValues(alpha: fade),
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                // Pastga (yoki tepaga) surib yopish — faqat kattalashtirilmaganda.
                onVerticalDragUpdate: _zoomed
                    ? null
                    : (details) =>
                          setState(() => _dragOffset += details.delta.dy),
                onVerticalDragEnd: _zoomed
                    ? null
                    : (details) {
                        final fast = (details.primaryVelocity ?? 0).abs() > 700;
                        if (_dragOffset.abs() > 120 || fast) {
                          _close();
                        } else {
                          setState(() => _dragOffset = 0);
                        }
                      },
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: PageView.builder(
                    key: const ValueKey('product-photo-viewer-pages'),
                    controller: _pages,
                    physics: _zoomed
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    itemCount: widget.photos.length,
                    onPageChanged: (index) => setState(() {
                      _index = index;
                      _zoomed = false;
                    }),
                    itemBuilder: (context, index) => _ZoomablePhoto(
                      key: ValueKey('product-photo-viewer-page-$index'),
                      url: widget.photos[index],
                      decodeWidth: decodeWidth,
                      onZoomChanged: (zoomed) {
                        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('product-photo-viewer-close'),
                        tooltip: l10n.commonClose,
                        onPressed: _close,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: .35),
                        ),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.photos.length > 1)
                        Text(
                          '${_index + 1}/${widget.photos.length}',
                          key: const ValueKey('product-photo-viewer-counter'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.decodeWidth,
    required this.onZoomChanged,
    super.key,
  });

  final String url;
  final int decodeWidth;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  static const _doubleTapScale = 2.5;
  final _transform = TransformationController();
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_reportZoom)
      ..dispose();
    super.dispose();
  }

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  void _reportZoom() => widget.onZoomChanged(_isZoomed);

  void _toggleZoom() {
    if (_isZoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = _doubleTapScale;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        -_tapPosition.dx * (scale - 1),
        -_tapPosition.dy * (scale - 1),
        0,
      );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onDoubleTapDown: (details) => _tapPosition = details.localPosition,
    onDoubleTap: _toggleZoom,
    child: InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      child: SizedBox.expand(
        child: ProductImageView(
          imageUrl: widget.url,
          fit: BoxFit.contain,
          persistent: true,
          keepPreviousImage: true,
          memCacheWidth: widget.decodeWidth,
        ),
      ),
    ),
  );
}
