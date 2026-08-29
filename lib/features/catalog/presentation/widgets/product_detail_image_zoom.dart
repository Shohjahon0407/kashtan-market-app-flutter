import 'dart:async';

import 'package:flutter/material.dart';

/// Product detail galereyasidagi rasmning o'zini birinchi tapda
/// kattalashtiradi va keyingi draglarda barmoq harakatiga ergashtiradi.
///
/// Zoom yopiq paytda drag gesture'i egallanmaydi, shu sabab galereyaning
/// odatiy swipe navigatsiyasi saqlanadi. Ikkinchi tap zoomni yopadi.
class ProductDetailImageZoom extends StatefulWidget {
  const ProductDetailImageZoom({
    required this.child,
    this.onZoomChanged,
    super.key,
  });

  static const zoomScale = 1.80;

  final Widget child;
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<ProductDetailImageZoom> createState() => _ProductDetailImageZoomState();
}

class _ProductDetailImageZoomState extends State<ProductDetailImageZoom>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Offset _panOrigin = Offset.zero;
  Offset _panOriginOffset = Offset.zero;
  Offset _panOffset = Offset.zero;
  Size _viewportSize = Size.zero;
  int? _activePointer;
  bool _zoomed = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 110),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _resetImmediately();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoomed) {
      unawaited(_restoreImage());
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    _viewportSize = renderObject.size;
    _panOffset = Offset.zero;
    _disableAnimations = MediaQuery.disableAnimationsOf(context);
    _zoomed = true;
    widget.onZoomChanged?.call(true);
    if (_disableAnimations) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward(from: _controller.value));
    }
    setState(() {});
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_zoomed || _activePointer != null) return;
    _activePointer = event.pointer;
    _panOrigin = event.position;
    _panOriginOffset = _panOffset;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_zoomed || _activePointer != event.pointer) return;
    _updatePan(event.position);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_activePointer == event.pointer) _activePointer = null;
  }

  void _updatePan(Offset globalPosition) {
    final delta = globalPosition - _panOrigin;
    final overflowX =
        _viewportSize.width * (ProductDetailImageZoom.zoomScale - 1) / 2;
    final overflowY =
        _viewportSize.height * (ProductDetailImageZoom.zoomScale - 1) / 2;
    setState(() {
      _panOffset = Offset(
        (_panOriginOffset.dx + delta.dx).clamp(-overflowX, overflowX),
        (_panOriginOffset.dy + delta.dy).clamp(-overflowY, overflowY),
      );
    });
  }

  Future<void> _restoreImage() async {
    if (!_zoomed) return;
    if (_disableAnimations) {
      _controller.value = 0;
    } else {
      await _controller.reverse();
    }
    if (!mounted || !_zoomed) return;
    setState(() {
      _zoomed = false;
      _panOffset = Offset.zero;
      _activePointer = null;
    });
    widget.onZoomChanged?.call(false);
  }

  void _resetImmediately() {
    if (!_zoomed && _controller.value == 0) return;
    _controller.stop();
    _controller.value = 0;
    final wasZoomed = _zoomed;
    _zoomed = false;
    _panOffset = Offset.zero;
    _activePointer = null;
    if (mounted) setState(() {});
    if (wasZoomed) widget.onZoomChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleZoom,
          child: AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) {
              final progress = Curves.easeOutCubic.transform(_controller.value);
              final scale =
                  1 + ((ProductDetailImageZoom.zoomScale - 1) * progress);
              return Transform.translate(
                key: const ValueKey('product-detail-image-pan'),
                offset: _panOffset * progress,
                child: Transform.scale(
                  key: const ValueKey('product-detail-image-scale'),
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
