import 'package:beshkashtan_customer/features/videos/presentation/widgets/video_feed_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness({
    required VoidCallback onSingleTap,
    required GestureTapDownCallback onDoubleTapDown,
  }) => MaterialApp(
    home: Scaffold(
      body: VideoGestureSurface(
        key: const ValueKey('video-surface'),
        onSingleTap: onSingleTap,
        onDoubleTapDown: onDoubleTapDown,
        onLongPressStart: (_) {},
        onLongPressMoveUpdate: (_) {},
        onLongPressEnd: (_) {},
        onLongPressCancel: () {},
        child: const SizedBox.expand(),
      ),
    ),
  );

  testWidgets('video single tap ovozni bir marta toggle qiladi', (
    tester,
  ) async {
    var soundToggles = 0;
    var doubleLikes = 0;
    await tester.pumpWidget(
      harness(
        onSingleTap: () => soundToggles += 1,
        onDoubleTapDown: (_) => doubleLikes += 1,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('video-surface')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(soundToggles, 1);
    expect(doubleLikes, 0);
  });

  testWidgets('double tap like qiladi va ovozni toggle qilmaydi', (
    tester,
  ) async {
    var soundToggles = 0;
    var doubleLikes = 0;
    await tester.pumpWidget(
      harness(
        onSingleTap: () => soundToggles += 1,
        onDoubleTapDown: (_) => doubleLikes += 1,
      ),
    );

    final surface = find.byKey(const ValueKey('video-surface'));
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(surface);
    await tester.pump(const Duration(milliseconds: 350));

    expect(soundToggles, 0);
    expect(doubleLikes, 1);
  });
}
