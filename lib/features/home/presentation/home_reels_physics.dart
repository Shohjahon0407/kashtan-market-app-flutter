import 'package:flutter/widgets.dart';

/// Reels hududida fling qaysi sahifada tugashi kerak — `PageScrollPhysics`
/// mantig'ining sof nusxasi (unit-test uchun ajratilgan).
///
/// Masofa tezlikdan hisoblanMAYDI: flick faqat ±0.5 sahifa qo'shib
/// yaxlitlaydi, shuning uchun har qanday kuchdagi fling ham roppa-rosa bitta
/// sahifa yuradi (Instagram Reels / YouTube Shorts kabi). Sekin, qisqa drag
/// esa eng yaqin sahifaga qaytadi.
///
/// `null` — nishon 0-sahifadan yuqorida, ya'ni foydalanuvchi Home kontentiga
/// chiqmoqchi; chaqiruvchi erkin (ota) simulyatsiyani ishlatadi.
double? calculateReelsTargetPage({
  required double page,
  required double velocity,
  required double toleranceVelocity,
  required int reelCount,
}) {
  if (reelCount <= 0) return null;
  // Sahifa chegarasida turganda float xatosi (2.9999) "keyingi sahifa"ni
  // o'sha sahifaning o'zi deb hisoblamasin.
  final nearest = page.roundToDouble();
  final snapped = (page - nearest).abs() < 1e-3 ? nearest : page;
  final double target;
  if (velocity > toleranceVelocity) {
    // Pastga flick: yo'nalishdagi KEYINGI chegara — hozir qayerda bo'lishidan
    // qat'i nazar, faqat bittasi.
    target = snapped.floorToDouble() + 1;
  } else if (velocity < -toleranceVelocity) {
    // Yuqoriga flick: OLDINGI chegara. (PageScrollPhysics'dagi `-0.5` +
    // round aynan butun sahifada turganda 2.5 → 3 bo'lib joyida qoldirardi.)
    target = snapped.ceilToDouble() - 1;
  } else {
    target = nearest;
  }
  if (target < 0) return null;
  return target.clamp(0, (reelCount - 1).toDouble());
}

/// Home scrollining physics'i: do'konlar qismida oddiy scroll, reels
/// hududida esa sahifalab snap.
///
/// Snap **ballistik simulyatsiyaning o'zida** — bitta uzluksiz spring.
/// Ilgari snap alohida bosqichda (`ScrollEnd` → `animateTo`) qilinardi: fling
/// avval 2–3 sahifa o'tib ketar, keyin orqaga animatsiya qilardi.
///
/// Hamma parametr **getter**: `Scrollable` bir xil turdagi physics'ni qayta
/// yaratmaydi (birinchi instansiya qoladi), shuning uchun build paytida
/// ushlangan qiymatlar eskirib qolardi — reel soni 0 dan boshlanadi va
/// snap hech qachon yoqilmasdi.
class HomeReelsScrollPhysics extends ScrollPhysics {
  const HomeReelsScrollPhysics({
    required this.reelsStart,
    required this.pageExtent,
    required this.reelCount,
    super.parent,
  });

  /// Reels hududining scroll offset'i; hali o'lchanmagan bo'lsa `null`.
  final double? Function() reelsStart;

  /// Bitta reel sahifasining balandligi (viewport).
  final double Function() pageExtent;

  final int Function() reelCount;

  /// Ota simulyatsiyasining "oxirini" o'qish uchun yetarlicha uzoq vaqt.
  /// `double.infinity` EMAS — spring formulasida `t * exp(-kt)` NaN beradi.
  static const _farFuture = 1e4;

  /// Spring'ga beriladigan tezlik chegarasi (px/s).
  ///
  /// Nishon baribir bitta sahifa; juda kuchli fling'da inersiya springni
  /// nishondan o'tkazib, keyingi reelni "mo'ralatib" qaytarardi. Cheklov
  /// bilan qattiq va yumshoq flick bir xil, aniq to'xtaydi (Reels kabi).
  static const _maxSnapVelocity = 2500.0;

  @override
  HomeReelsScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      HomeReelsScrollPhysics(
        reelsStart: reelsStart,
        pageExtent: pageExtent,
        reelCount: reelCount,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final start = reelsStart();
    final extent = pageExtent();
    final count = reelCount();
    // Hudud noma'lum, reel yo'q yoki chegaradan tashqarida (overscroll —
    // pull-to-refresh, ota bounce/clamp) — ota physics.
    if (start == null || count <= 0 || extent <= 0 || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final page = (position.pixels - start) / extent;

    if (page >= 0) {
      final targetPage = calculateReelsTargetPage(
        page: page,
        velocity: velocity,
        toleranceVelocity: tolerance.velocity,
        reelCount: count,
      );
      if (targetPage != null) {
        final target = (start + targetPage * extent).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((target - position.pixels).abs() < tolerance.distance) return null;
        return _spring(position, target, velocity, tolerance);
      }
      // 0-sahifadan yuqoriga — Home kontentiga (pastdagi magnit qoidasi
      // bilan).
    }

    // Home kontenti: erkin scroll. Lekin 1-reel yarmidan ko'pi ko'rinadigan
    // joyda to'xtaydigan fling uni to'liq ichkariga tortadi — yarim ko'ringan
    // reel bilan qolib ketmaslik uchun (magnit ±0.5 sahifa).
    final free = super.createBallisticSimulation(position, velocity);
    final end = free?.x(_farFuture) ?? position.pixels;
    if (end >= start - extent / 2 &&
        (end - start).abs() >= tolerance.distance) {
      return _spring(
        position,
        start.clamp(position.minScrollExtent, position.maxScrollExtent),
        velocity,
        tolerance,
      );
    }
    return free;
  }

  ScrollSpringSimulation _spring(
    ScrollMetrics position,
    double target,
    double velocity,
    Tolerance tolerance,
  ) => ScrollSpringSimulation(
    spring,
    position.pixels,
    target,
    velocity.clamp(-_maxSnapVelocity, _maxSnapVelocity),
    tolerance: tolerance,
  );

  @override
  bool get allowImplicitScrolling => false;
}
