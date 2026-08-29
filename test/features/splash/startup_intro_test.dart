import 'package:beshkashtan_customer/features/splash/presentation/startup_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const overlayKey = ValueKey('startup-intro-overlay');
  const scaleKey = ValueKey('startup-intro-wordmark-scale');

  Widget app({
    required bool isReady,
    bool reduceMotion = false,
    VoidCallback? onBackgroundTap,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: StartupIntro(
          isAppReady: isReady,
          child: Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: onBackgroundTap,
                child: const Text('Home action'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double currentScale(WidgetTester tester) {
    return tester.widget<Transform>(find.byKey(scaleKey)).transform.storage[0];
  }

  testWidgets('oq overlay va BESHKASHTAN fade/zoom bilan 2.5s ishlaydi', (
    tester,
  ) async {
    await tester.pumpWidget(app(isReady: true));
    await tester.pump();

    expect(find.byKey(overlayKey), findsOneWidget);
    expect(find.text('BESHKASHTAN'), findsOneWidget);
    final wordmark = tester.widget<Text>(find.text('BESHKASHTAN'));
    expect(wordmark.style?.inherit, isFalse);
    expect(wordmark.style?.decoration, TextDecoration.none);
    expect(wordmark.style?.fontSize, greaterThanOrEqualTo(30));
    expect(
      tester.widget<ColoredBox>(find.byType(ColoredBox).last).color,
      Colors.white,
    );
    final initialScale = currentScale(tester);

    await tester.pump(
      Duration(milliseconds: StartupIntro.entryDuration.inMilliseconds ~/ 2),
    );
    expect(currentScale(tester), greaterThan(initialScale));

    await tester.pump(
      Duration(
        milliseconds:
            StartupIntro.entryDuration.inMilliseconds -
            (StartupIntro.entryDuration.inMilliseconds ~/ 2),
      ),
    );
    expect(currentScale(tester), closeTo(1, 0.001));
    await tester.pump();

    await tester.pump(StartupIntro.holdDuration);
    expect(find.byKey(overlayKey), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));

    await tester.pump(
      Duration(milliseconds: StartupIntro.exitDuration.inMilliseconds ~/ 2),
    );
    expect(currentScale(tester), greaterThan(1));
    await tester.pumpAndSettle();
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('session tayyor bo‘lmaguncha final zoom boshlanmaydi', (
    tester,
  ) async {
    await tester.pumpWidget(app(isReady: false));
    await tester.pump();
    await tester.pump(StartupIntro.entryDuration);
    await tester.pump();
    await tester.pump(StartupIntro.holdDuration);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(overlayKey), findsOneWidget);
    expect(currentScale(tester), closeTo(1, 0.001));

    await tester.pumpWidget(app(isReady: true));
    await tester.pump();
    await tester.pump(
      Duration(milliseconds: StartupIntro.exitDuration.inMilliseconds ~/ 2),
    );
    expect(currentScale(tester), greaterThan(1));
    await tester.pumpAndSettle();
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('intro fon interactionini bloklaydi va keyin qayta chiqmaydi', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(app(isReady: true, onBackgroundTap: () => taps++));
    await tester.pump();

    await tester.tap(find.text('Home action'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);

    await tester.pump(StartupIntro.entryDuration);
    await tester.pump();
    await tester.pump(StartupIntro.holdDuration);
    await tester.pump();
    await tester.pump(StartupIntro.exitDuration);
    await tester.pumpAndSettle();
    expect(find.byKey(overlayKey), findsNothing);

    await tester.tap(find.text('Home action'));
    expect(taps, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(overlayKey), findsNothing);
  });

  testWidgets('reduced motion ulkan scale ishlatmaydi', (tester) async {
    await tester.pumpWidget(app(isReady: true, reduceMotion: true));
    await tester.pump();
    expect(currentScale(tester), 1);

    await tester.pump(StartupIntro.entryDuration);
    await tester.pump();
    await tester.pump(StartupIntro.holdDuration);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(currentScale(tester), 1);

    await tester.pumpAndSettle();
    expect(find.byKey(overlayKey), findsNothing);
  });
}
