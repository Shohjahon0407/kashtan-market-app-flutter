import 'package:beshkashtan_customer/features/catalog/presentation/widgets/imageless_reveal.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ScrollController> mount(
    WidgetTester tester,
    VoidCallback reveal, {
    bool enabled = true,
    double height = 1500,
    double scale = 1,
    bool childOwnsDrag = false,
  }) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: ImagelessRevealBoundary(
              controller: controller,
              enabled: enabled,
              onReveal: reveal,
              child: ListView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: childOwnsDrag ? (_) {} : null,
                    child: SizedBox(height: height),
                  ),
                  ImagelessRevealPrompt(onReveal: reveal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('119 px does not reveal; 120 px plus release reveals once', (
    tester,
  ) async {
    var reveals = 0;
    final controller = await mount(tester, () => reveals++);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    const start = Offset(300, 450);
    final short = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await short.moveBy(const Offset(0, -119));
    await short.up();
    await tester.pumpAndSettle();
    expect(reveals, 0);
    final sufficient = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await sufficient.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(find.text('Qo‘yib yuboring'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(reveals, 0);
    await sufficient.up();
    await tester.pumpAndSettle();
    expect(reveals, 1);
  });

  testWidgets(
    'a fling that reaches bottom never opens; a new bottom drag does',
    (tester) async {
      var reveals = 0;
      final controller = await mount(tester, () => reveals++);
      await tester.fling(find.byType(ListView), const Offset(0, -1800), 10000);
      await tester.pumpAndSettle();
      expect(controller.position.extentAfter, 0);
      expect(reveals, 0);
      final gesture = await tester.startGesture(const Offset(300, 450));
      await gesture.moveBy(const Offset(0, -125));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reveals, 1);
    },
  );

  testWidgets('cancel, horizontal drag, multi touch and mouse do not reveal', (
    tester,
  ) async {
    var reveals = 0;
    final controller = await mount(tester, () => reveals++);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final cancelled = await tester.startGesture(const Offset(300, 450));
    await cancelled.moveBy(const Offset(0, -150));
    await cancelled.cancel();
    final horizontal = await tester.startGesture(const Offset(300, 450));
    await horizontal.moveBy(const Offset(-180, -120));
    await horizontal.up();
    final first = await tester.startGesture(
      const Offset(300, 450),
      pointer: 11,
    );
    final second = await tester.startGesture(
      const Offset(340, 450),
      pointer: 12,
    );
    await first.moveBy(const Offset(0, -150));
    await second.up();
    await first.up();
    final mouse = await tester.startGesture(
      const Offset(300, 450),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, -150));
    await mouse.up();
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(300, 450),
        scrollDelta: Offset(0, 300),
      ),
    );
    await tester.pumpAndSettle();
    expect(reveals, 0);
  });

  testWidgets('fast fling starting at the bottom does not reveal', (
    tester,
  ) async {
    var reveals = 0;
    final controller = await mount(tester, () => reveals++);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.fling(find.byType(ListView), const Offset(0, -180), 4000);
    await tester.pumpAndSettle();
    expect(reveals, 0);
  });

  testWidgets('short blank list and 320 px large text reveal only by pull', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reveals = 0;
    await mount(tester, () => reveals++, height: 0, scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('imageless-reveal-button')), findsNothing);
    expect(find.textContaining('Rasmsiz'), findsNothing);
    final gesture = await tester.startGesture(const Offset(280, 550));
    await gesture.moveBy(const Offset(0, -120));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reveals, 1);
  });

  testWidgets('disabled boundary never arms', (tester) async {
    var reveals = 0;
    final controller = await mount(
      tester,
      () => reveals++,
      enabled: false,
      height: 0,
    );
    expect(controller.position.extentAfter, 0);
    final gesture = await tester.startGesture(const Offset(300, 450));
    await gesture.moveBy(const Offset(0, -180));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reveals, 0);
  });

  testWidgets('child image/drag gesture cannot reveal the catalog', (
    tester,
  ) async {
    var reveals = 0;
    await mount(tester, () => reveals++, height: 300, childOwnsDrag: true);
    final gesture = await tester.startGesture(const Offset(300, 220));
    await gesture.moveBy(const Offset(0, -150));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reveals, 0);
  });
}
