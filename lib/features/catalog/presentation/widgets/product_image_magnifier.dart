import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Product card rasmini barmoq ostidagi nuqtadan kattalashtirib ko'rsatadi.
///
/// Bu widget faqat muvaffaqiyatli yuklangan rasm atrofida ishlatiladi. Shuning
/// uchun loading/error placeholderlar long-press gesture'ini egallamaydi.
class ProductImageMagnifier extends StatefulWidget {
  const ProductImageMagnifier({required this.child, super.key});

  static const holdDuration = Duration(milliseconds: 300);
  static const magnificationScale = 1.75;

  final Widget child;

  @override
  State<ProductImageMagnifier> createState() => _ProductImageMagnifierState();
}

class _ProductImageMagnifierState extends State<ProductImageMagnifier>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static _ProductImageMagnifierState? _activeOwner;
  static const _edgePadding = 8.0;
  static const _fingerGap = 16.0;

  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  OverlayEntry? _overlayEntry;
  Offset _focalPoint = Offset.zero;
  Rect _imageBounds = Rect.zero;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _removeOverlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeOverlay();
    _animationController.dispose();
    super.dispose();
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    _activeOwner?._removeOverlay();
    _activeOwner = this;
    _imageBounds = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    _focalPoint = _clampToImage(details.globalPosition);
    _disableAnimations = MediaQuery.disableAnimationsOf(context);

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      _activeOwner = null;
      return;
    }

    _animationController.value = _disableAnimations ? 1 : 0;
    _overlayEntry = OverlayEntry(builder: _buildMagnifierOverlay);
    overlay.insert(_overlayEntry!);
    if (!_disableAnimations) unawaited(_animationController.forward());
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_overlayEntry == null) return;
    _focalPoint = _clampToImage(details.globalPosition);
    _overlayEntry?.markNeedsBuild();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    unawaited(_hideOverlay());
  }

  void _handleLongPressCancel() {
    unawaited(_hideOverlay());
  }

  Offset _clampToImage(Offset point) {
    return Offset(
      point.dx.clamp(_imageBounds.left, _imageBounds.right),
      point.dy.clamp(_imageBounds.top, _imageBounds.bottom),
    );
  }

  Widget _buildMagnifierOverlay(BuildContext overlayContext) {
    final mediaQuery = MediaQuery.of(overlayContext);
    final shortestSide = mediaQuery.size.shortestSide;
    final diameter = (shortestSide * 0.4).clamp(132.0, 168.0);
    final radius = diameter / 2;
    final desiredCenter = _focalPoint.translate(0, -(radius + _fingerGap));
    final safeBounds = Rect.fromLTRB(
      mediaQuery.padding.left + _edgePadding,
      mediaQuery.padding.top + _edgePadding,
      mediaQuery.size.width - mediaQuery.padding.right - _edgePadding,
      mediaQuery.size.height - mediaQuery.padding.bottom - _edgePadding,
    );
    final desiredRect = Rect.fromCenter(
      center: desiredCenter,
      width: diameter,
      height: diameter,
    );
    final lensRect = MagnifierController.shiftWithinBounds(
      rect: desiredRect,
      bounds: safeBounds,
    );
    final lensCenter = lensRect.center;

    return Positioned.fromRect(
      key: const ValueKey('product-image-magnifier-overlay'),
      rect: lensRect,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _animationController,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: RawMagnifier(
              key: const ValueKey('product-image-magnifier-lens'),
              size: Size.square(diameter),
              magnificationScale: ProductImageMagnifier.magnificationScale,
              focalPointOffset: _focalPoint - lensCenter,
              clipBehavior: Clip.antiAlias,
              decoration: MagnifierDecoration(
                shape: CircleBorder(
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 3,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.06),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _hideOverlay() async {
    final entry = _overlayEntry;
    if (entry == null) return;
    if (!_disableAnimations) await _animationController.reverse();
    if (_overlayEntry == entry) _removeOverlay();
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    entry?.remove();
    entry?.dispose();
    if (identical(_activeOwner, this)) _activeOwner = null;
    if (_animationController.isAnimating) _animationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: ProductImageMagnifier.holdDuration,
                debugOwner: this,
                allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
              ),
              (recognizer) {
                recognizer
                  ..onLongPressStart = _handleLongPressStart
                  ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
                  ..onLongPressEnd = _handleLongPressEnd
                  ..onLongPressCancel = _handleLongPressCancel;
              },
            ),
      },
      child: widget.child,
    );
  }
}
