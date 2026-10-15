import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A receipt silhouette, without clipping long item names or scaled text.
class CheckoutReceiptPaper extends StatelessWidget {
  const CheckoutReceiptPaper({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => PhysicalShape(
    clipper: const ReceiptPaperClipper(),
    clipBehavior: Clip.antiAlias,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: .12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 24),
      child: child,
    ),
  );
}

class ReceiptPaperClipper extends CustomClipper<Path> {
  const ReceiptPaperClipper();

  @override
  Path getClip(Size size) {
    if (!size.isFinite || size.isEmpty) return Path();
    final depth = math.min(5.0, size.height / 4);
    final teeth = math.max(2, (size.width / 14).ceil());
    final step = size.width / teeth;
    final path = Path()..moveTo(0, depth);
    for (var i = 0; i < teeth; i++) {
      path
        ..lineTo((i + .5) * step, 0)
        ..lineTo((i + 1) * step, depth);
    }
    path.lineTo(size.width, size.height - depth);
    for (var i = teeth - 1; i >= 0; i--) {
      path
        ..lineTo((i + .5) * step, size.height)
        ..lineTo(i * step, size.height - depth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(ReceiptPaperClipper oldClipper) => false;
}

class ReceiptDashedDivider extends StatelessWidget {
  const ReceiptDashedDivider({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 24,
    child: CustomPaint(
      painter: _DashedLinePainter(Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 4, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
