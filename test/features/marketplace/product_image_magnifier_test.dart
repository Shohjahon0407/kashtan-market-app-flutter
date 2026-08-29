import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image_magnifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const targetKey = ValueKey('magnifier-target');
  const overlayKey = ValueKey('product-image-magnifier-overlay');
  const lensKey = ValueKey('product-image-magnifier-lens');

  Widget testApp({VoidCallback? onTap, bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 180,
              child: GestureDetector(
                onTap: onTap,
                child: const ProductImageMagnifier(
                  key: targetKey,
                  child: ColoredBox(color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('300 ms dan keyin 1.75x dumaloq lupa ochiladi', (tester) async {
    await tester.pumpWidget(testApp());
    final targetCenter = tester.getCenter(find.byKey(targetKey));
    final gesture = await tester.startGesture(targetCenter);

    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byKey(overlayKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(overlayKey), findsOneWidget);
    final lens = tester.widget<RawMagnifier>(find.byKey(lensKey));
    expect(lens.magnificationScale, 1.75);
    expect(lens.decoration.shape, isA<CircleBorder>());
    expect(
      tester.getRect(find.byKey(overlayKey)).center.dy,
      lessThan(targetCenter.dy),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('lupa barmoq bilan yuradi va focal nuqta barmoqda qoladi', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(disableAnimations: true));
    final start = tester.getCenter(find.byKey(targetKey));
    final gesture = await tester.startGesture(start);
    await tester.pump(ProductImageMagnifier.holdDuration);

    final firstRect = tester.getRect(find.byKey(overlayKey));
    final firstLens = tester.widget<RawMagnifier>(find.byKey(lensKey));
    expect(firstRect.center + firstLens.focalPointOffset, start);

    const movement = Offset(40, 24);
    await gesture.moveBy(movement);
    await tester.pump();

    final movedRect = tester.getRect(find.byKey(overlayKey));
    final movedLens = tester.widget<RawMagnifier>(find.byKey(lensKey));
    expect(movedRect.center.dx, greaterThan(firstRect.center.dx));
    expect(movedRect.center.dy, greaterThan(firstRect.center.dy));
    expect(movedRect.center + movedLens.focalPointOffset, start + movement);

    await gesture.up();
    await tester.pump();
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('oddiy tap saqlanadi, long-press esa tapni chaqirmaydi', (
    tester,
  ) async {
    var tapCount = 0;
    await tester.pumpWidget(testApp(onTap: () => tapCount++));

    await tester.tap(find.byKey(targetKey));
    await tester.pump();
    expect(tapCount, 1);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await tester.pump(ProductImageMagnifier.holdDuration);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapCount, 1);
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('300 ms dan oldingi drag scrollni egallamaydi', (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: const [
              SizedBox(height: 100),
              SizedBox(
                key: targetKey,
                height: 260,
                child: ProductImageMagnifier(
                  child: ColoredBox(color: Colors.green),
                ),
              ),
              SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    );

    await tester.timedDrag(
      find.byKey(targetKey),
      const Offset(0, -120),
      const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(scrollController.offset, greaterThan(0));
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('rasmsiz placeholderda lupa gesture mavjud emas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 180,
              child: ProductImageView(
                key: targetKey,
                imageUrl: null,
                imageBuilder: _loadedImageBuilder,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await tester.pump(ProductImageMagnifier.holdDuration);
    expect(find.byKey(overlayKey), findsNothing);
    await gesture.up();
  });

  testWidgets('widget dispose bo‘lsa ochiq overlay ham tozalanadi', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(disableAnimations: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await tester.pump(ProductImageMagnifier.holdDuration);
    expect(find.byKey(overlayKey), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(find.byKey(overlayKey), findsNothing);
    await gesture.up();
  });
}

Widget _loadedImageBuilder(BuildContext context, ImageProvider imageProvider) {
  return ProductImageMagnifier(child: Image(image: imageProvider));
}
