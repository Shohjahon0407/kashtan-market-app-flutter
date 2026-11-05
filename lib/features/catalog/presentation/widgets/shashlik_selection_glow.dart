import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/theme/app_dimens.dart';

/// Only the outline repaints on each tick; photos and labels stay untouched.
class ShashlikSelectionGlow extends CustomPainter {
  ShashlikSelectionGlow({required this.phase}) : super(repaint: phase);

  final Animation<double> phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1.5),
          const Radius.circular(AppRadius.md - 1.5),
        ),
      );
    final metric = outline.computeMetrics().first;
    final start = phase.value * metric.length;
    final end = start + metric.length * .18;
    final light = metric.extractPath(start, end.clamp(0, metric.length));
    if (end > metric.length) {
      light.addPath(metric.extractPath(0, end - metric.length), Offset.zero);
    }
    canvas.drawPath(
      light,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x9932F27C)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
    canvas.drawPath(
      light,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF32F27C),
    );
  }

  @override
  bool shouldRepaint(ShashlikSelectionGlow oldDelegate) =>
      oldDelegate.phase != phase;
}
