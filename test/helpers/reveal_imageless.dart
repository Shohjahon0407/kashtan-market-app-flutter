import 'package:beshkashtan_customer/features/catalog/presentation/widgets/imageless_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> revealImagelessProducts(WidgetTester tester) async {
  final boundary = find.byType(ImagelessRevealBoundary).first;
  final scrollable = find
      .descendant(of: boundary, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pump();
  final gesture = await tester.startGesture(tester.getCenter(boundary));
  await gesture.moveBy(const Offset(0, -120));
  await tester.pump(const Duration(milliseconds: 150));
  await gesture.up();
  await tester.pumpAndSettle();
}
