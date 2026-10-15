import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Rangli splashsiz, faqat bosilgan elementning o'zida seziladigan ixcham
/// press feedback. [Listener] gesture arena'ga aralashmaydi, shuning uchun
/// ichidagi Button/InkWell o'z tap semantikasini saqlab qoladi.
class SmoothPress extends StatefulWidget {
  const SmoothPress({
    required this.child,
    this.enabled = true,
    this.scale = 0.96,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<SmoothPress> createState() => _SmoothPressState();
}

class _SmoothPressState extends State<SmoothPress> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(covariant SmoothPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled
          ? (event) {
              if (event.buttons == kPrimaryButton) _setPressed(true);
            }
          : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        scale: widget.enabled && _pressed ? widget.scale : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
