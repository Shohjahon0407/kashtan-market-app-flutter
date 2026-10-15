import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_receipt_paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('receipt tears only the edges, leaving the text area intact', () {
    const clipper = ReceiptPaperClipper();
    for (final width in [1.0, 260.0, 288.0, 398.0, 768.0]) {
      final path = clipper.getClip(Size(width, 400));
      expect(path.getBounds(), Rect.fromLTWH(0, 0, width, 400));
      expect(path.contains(Offset(width / 2, 200)), isTrue);
      expect(path.contains(Offset(width / 2, 22)), isTrue);
      expect(path.contains(Offset(width / 2, 376)), isTrue);
      expect(path.contains(const Offset(.01, .01)), isFalse);
      expect(path.contains(const Offset(.01, 399.99)), isFalse);
    }
    expect(clipper.getClip(Size.zero).computeMetrics(), isEmpty);
    expect(clipper.shouldReclip(clipper), isFalse);
  });
}
