import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_detail_image_zoom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const targetKey = ValueKey('detail-zoom-target');
const scaleKey = ValueKey('product-detail-image-scale');
const panKey = ValueKey('product-detail-image-pan');

void main() {
  Widget testApp({
    ValueChanged<bool>? onZoomChanged,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              height: 300,
              child: ProductDetailImageZoom(
                key: targetKey,
                onZoomChanged: onZoomChanged,
                child: const ColoredBox(color: Colors.orange),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('birinchi oddiy tap rasmning o‘zini markazdan 1.80x qiladi', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.tap(find.byKey(targetKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_scaleOf(tester), closeTo(1.80, 0.001));

    await tester.tap(find.byKey(targetKey));
    await tester.pumpAndSettle();
    expect(_scaleOf(tester), 1);
  });

  testWidgets(
    'kattalashgan rasm barmoq harakatiga ergashadi va clamp bo‘ladi',
    (tester) async {
      await tester.pumpWidget(testApp(disableAnimations: true));
      await tester.tap(find.byKey(targetKey));
      await tester.pump();
      expect(_scaleOf(tester), 1.80);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(targetKey)),
      );
      await gesture.moveBy(const Offset(40, -55));
      await tester.pump();
      expect(_translationOf(tester), const Offset(40, -55));

      await gesture.moveBy(const Offset(1000, 1000));
      await tester.pump();
      // 240x300 viewport va 1.80x zoom uchun bo‘sh chet ko‘rinmaslik chegarasi.
      final clamped = _translationOf(tester);
      expect(clamped.dx, closeTo(96, 0.001));
      expect(clamped.dy, closeTo(120, 0.001));

      await gesture.up();
      await tester.pump();
      expect(_scaleOf(tester), 1.80);
      expect(_translationOf(tester).dx, closeTo(96, 0.001));

      await tester.tap(find.byKey(targetKey));
      await tester.pump();
      expect(_scaleOf(tester), 1);
      expect(_translationOf(tester), Offset.zero);
    },
  );

  testWidgets('zoom holati callback bilan ochiladi va yopiladi', (
    tester,
  ) async {
    final values = <bool>[];
    await tester.pumpWidget(testApp(onZoomChanged: values.add));
    await tester.tap(find.byKey(targetKey));
    await tester.pump();
    expect(values, [true]);

    await tester.tap(find.byKey(targetKey));
    await tester.pumpAndSettle();
    expect(values, [true, false]);
  });

  testWidgets('zoom yopiq paytdagi drag odatiy scrollni buzmaydi', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: controller,
          children: const [
            SizedBox(height: 100),
            SizedBox(
              key: targetKey,
              width: 240,
              height: 300,
              child: ProductDetailImageZoom(
                child: ColoredBox(color: Colors.orange),
              ),
            ),
            SizedBox(height: 1000),
          ],
        ),
      ),
    );

    await tester.timedDrag(
      find.byKey(targetKey),
      const Offset(0, -120),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.offset, greaterThan(0));
    expect(_scaleOf(tester), 1);
  });
}

double _scaleOf(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(scaleKey))
    .transform
    .getMaxScaleOnAxis();

Offset _translationOf(WidgetTester tester) {
  final matrix = tester.widget<Transform>(find.byKey(panKey)).transform;
  return Offset(matrix.storage[12], matrix.storage[13]);
}
