Duration calculateReelSeekTarget({
  required Duration start,
  required Duration duration,
  required double horizontalDelta,
  required double width,
}) {
  final durationMs = duration.inMilliseconds;
  if (durationMs <= 0 || width <= 0) return start;
  final deltaMs = (horizontalDelta / width) * durationMs;
  final targetMs = (start.inMilliseconds + deltaMs)
      .round()
      .clamp(0, durationMs)
      .toInt();
  return Duration(milliseconds: targetMs);
}

/// Bir vaqtning o'zida saqlanadigan playerlar tartibi.
///
/// Aktiv video birinchi qaytadi — u darhol initialize/play bo'ladi. Keyingi
/// video swipe uchun preload qilinadi, oldingi esa orqaga qaytish uchun qoladi.
List<int> calculateReelPlayerWindow({
  required int center,
  required int itemCount,
}) {
  if (itemCount <= 0) return const [];
  final safeCenter = center.clamp(0, itemCount - 1);
  return <int>[
    safeCenter,
    safeCenter + 1,
    safeCenter - 1,
  ].where((index) => index >= 0 && index < itemCount).toList(growable: false);
}
