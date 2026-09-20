import 'package:beshkashtan_customer/features/home/presentation/home_reels_physics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reels sahifalash qarori: har qanday kuchdagi fling ham bitta sahifa.
void main() {
  const tolerance = 50.0; // px/s

  double? target({
    required double page,
    required double velocity,
    int reelCount = 10,
  }) => calculateReelsTargetPage(
    page: page,
    velocity: velocity,
    toleranceVelocity: tolerance,
    reelCount: reelCount,
  );

  test('pastga flick — kuchi qanday bo\'lmasin FAQAT keyingi sahifa', () {
    expect(target(page: 0, velocity: 300), 1);
    expect(target(page: 0, velocity: 9000), 1);
    expect(target(page: 3.1, velocity: 20000), 4);
  });

  test('yuqoriga flick — faqat oldingi sahifa', () {
    expect(target(page: 3, velocity: -300), 2);
    expect(target(page: 3, velocity: -9000), 2);
  });

  test('sekin qisqa drag eng yaqin sahifaga qaytadi', () {
    expect(target(page: 0.2, velocity: 0), 0);
    expect(target(page: 0.7, velocity: 10), 1);
    expect(target(page: 2.49, velocity: -10), 2);
  });

  test('oxirgi sahifadan pastga — joyida qoladi', () {
    expect(target(page: 9, velocity: 5000, reelCount: 10), 9);
    expect(target(page: 9.2, velocity: 5000, reelCount: 10), 9);
  });

  test('0-sahifadan yuqoriga — null (Home kontentiga)', () {
    expect(target(page: 0, velocity: -3000), isNull);
    // Yarmidan o'tmagan holda yuqoriga flick — 0-sahifaga qaytadi.
    expect(target(page: 0.3, velocity: -3000), 0);
  });

  test('reel yo\'q bo\'lsa null', () {
    expect(target(page: 0, velocity: 100, reelCount: 0), isNull);
  });
}
