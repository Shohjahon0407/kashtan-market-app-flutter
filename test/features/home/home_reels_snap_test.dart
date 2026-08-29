import 'package:beshkashtan_customer/features/home/presentation/home_reels_snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = 800.0;
  const start = 620.0;

  test('video viewportga kirganda birinchi reelga snap qiladi', () {
    final result = calculateHomeReelsSnap(
      settledIndex: -1,
      pixels: 20,
      viewportExtent: viewport,
      reelsStart: start,
      reelCount: 4,
      scrollDelta: 40,
    );

    expect(result?.settledIndex, 0);
    expect(result?.offset, start);
  });

  test('video hali ko‘rinmasa Home erkin scroll qiladi', () {
    final result = calculateHomeReelsSnap(
      settledIndex: -1,
      pixels: 0,
      viewportExtent: 500,
      reelsStart: start,
      reelCount: 4,
      scrollDelta: 40,
    );

    expect(result, isNull);
  });

  test('tez fling ham faqat keyingi bitta reelga o‘tadi', () {
    final result = calculateHomeReelsSnap(
      settledIndex: 1,
      pixels: start + viewport * 3,
      viewportExtent: viewport,
      reelsStart: start,
      reelCount: 5,
      scrollDelta: 900,
    );

    expect(result?.settledIndex, 2);
    expect(result?.offset, start + viewport * 2);
  });

  test('birinchi videodan yuqoriga swipe Home pastiga qaytadi', () {
    final result = calculateHomeReelsSnap(
      settledIndex: 0,
      pixels: start - 100,
      viewportExtent: viewport,
      reelsStart: start,
      reelCount: 4,
      scrollDelta: -80,
    );

    expect(result?.settledIndex, -1);
    expect(result?.offset, 0);
  });

  test('oxirgi videodan pastga scroll oxirgi videoda qoladi', () {
    final result = calculateHomeReelsSnap(
      settledIndex: 3,
      pixels: start + viewport * 3,
      viewportExtent: viewport,
      reelsStart: start,
      reelCount: 4,
      scrollDelta: 80,
    );

    expect(result?.settledIndex, 3);
    expect(result?.offset, start + viewport * 3);
  });
}
