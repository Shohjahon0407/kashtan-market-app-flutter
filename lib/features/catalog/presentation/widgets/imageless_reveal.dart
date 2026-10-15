import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../generated/l10n/app_localizations.dart';

/// Observes raw touch movement without competing with the Scrollable's arena.
/// A NEW drag must start at the bottom. Ballistic, wheel and trackpad movement
/// can never arm the boundary; pointer cancellation can never reveal it.
class ImagelessRevealBoundary extends StatefulWidget {
  const ImagelessRevealBoundary({
    required this.controller,
    required this.enabled,
    required this.onReveal,
    required this.child,
    super.key,
  });
  final ScrollController controller;
  final bool enabled;
  final VoidCallback onReveal;
  final Widget child;

  @override
  State<ImagelessRevealBoundary> createState() =>
      _ImagelessRevealBoundaryState();
}

class _ImagelessRevealBoundaryState extends State<ImagelessRevealBoundary> {
  final _touches = <int>{};
  int? _pointer;
  Offset? _origin;
  VelocityTracker? _velocity;
  bool _ready = false;
  bool _scrollAccepted = false;

  void _setReady(bool value) {
    if (_ready != value) setState(() => _ready = value);
  }

  void _reset() {
    _pointer = null;
    _origin = null;
    _velocity = null;
    _scrollAccepted = false;
    _setReady(false);
  }

  @override
  void didUpdateWidget(ImagelessRevealBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointer = null;
      _origin = null;
      _velocity = null;
      _ready = false;
      _scrollAccepted = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) {
      if (event.kind != PointerDeviceKind.touch) return;
      _touches.add(event.pointer);
      _reset();
      if (_touches.length != 1 ||
          !widget.enabled ||
          !widget.controller.hasClients) {
        return;
      }
      if (widget.controller.position.extentAfter > 8) return;
      _pointer = event.pointer;
      _origin = event.position;
      _velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
    },
    onPointerMove: (event) {
      if (event.pointer != _pointer || _origin == null) return;
      _velocity?.addPosition(event.timeStamp, event.position);
      final delta = event.position - _origin!;
      _setReady(
        widget.enabled && -delta.dy >= 120 && delta.dy.abs() > delta.dx.abs(),
      );
    },
    onPointerUp: (event) {
      _touches.remove(event.pointer);
      if (event.pointer != _pointer) return;
      _velocity?.addPosition(event.timeStamp, event.position);
      final speed = _velocity?.getVelocity().pixelsPerSecond.dy.abs() ?? 0;
      final reveal =
          _ready && _scrollAccepted && widget.enabled && speed < 1500;
      _reset();
      if (reveal) widget.onReveal();
    },
    onPointerCancel: (event) {
      _touches.remove(event.pointer);
      _reset();
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_pointer != null &&
            notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical) {
          // Only the catalog Scrollable may authorize reveal. Child image
          // magnification or another gesture that won the arena cannot do so.
          if ((notification is ScrollStartNotification &&
                  notification.dragDetails != null) ||
              (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) ||
              (notification is OverscrollNotification &&
                  notification.dragDetails != null)) {
            _scrollAccepted = true;
          }
        }
        return false;
      },
      child: widget.child,
    ),
  );
}

/// Visually empty footer. Touch users reveal with a fresh bottom pull;
/// assistive technology retains an explicit, nonvisual alternative.
class ImagelessRevealPrompt extends StatelessWidget {
  const ImagelessRevealPrompt({required this.onReveal, super.key});
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey('imageless-reveal-prompt'),
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.catalogImagelessShow): onReveal,
      },
      child: const SizedBox(height: 24, width: double.infinity),
    );
  }
}
