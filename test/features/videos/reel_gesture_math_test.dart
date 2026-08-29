import 'package:beshkashtan_customer/features/videos/domain/reel_gesture_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gorizontal gesture videoni oldinga va orqaga seek qiladi', () {
    const duration = Duration(seconds: 100);

    expect(
      calculateReelSeekTarget(
        start: const Duration(seconds: 40),
        duration: duration,
        horizontalDelta: 100,
        width: 400,
      ),
      const Duration(seconds: 65),
    );
    expect(
      calculateReelSeekTarget(
        start: const Duration(seconds: 40),
        duration: duration,
        horizontalDelta: -80,
        width: 400,
      ),
      const Duration(seconds: 20),
    );
  });

  test('seek video chegaralaridan chiqmaydi', () {
    const duration = Duration(seconds: 30);

    expect(
      calculateReelSeekTarget(
        start: const Duration(seconds: 25),
        duration: duration,
        horizontalDelta: 500,
        width: 100,
      ),
      duration,
    );
    expect(
      calculateReelSeekTarget(
        start: const Duration(seconds: 5),
        duration: duration,
        horizontalDelta: -500,
        width: 100,
      ),
      Duration.zero,
    );
  });

  test('player oynasi aktiv, keyingi va oldingi tartibida', () {
    expect(calculateReelPlayerWindow(center: 2, itemCount: 5), [2, 3, 1]);
    expect(calculateReelPlayerWindow(center: 0, itemCount: 5), [0, 1]);
    expect(calculateReelPlayerWindow(center: 4, itemCount: 5), [4, 3]);
    expect(calculateReelPlayerWindow(center: 0, itemCount: 0), isEmpty);
  });
}
