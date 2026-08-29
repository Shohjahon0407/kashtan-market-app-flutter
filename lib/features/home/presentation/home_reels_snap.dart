import 'dart:math' as math;

/// Home kontentidan reels sahifalariga o'tish uchun bitta scroll yakunidagi
/// aniq nishon. [settledIndex] `-1` bo'lsa foydalanuvchi Home kontentida.
class HomeReelsSnapDecision {
  const HomeReelsSnapDecision({
    required this.offset,
    required this.settledIndex,
  });

  final double offset;
  final int settledIndex;
}

/// Har bir gesture/wheel burst faqat bitta reelga o'tishini ta'minlaydi.
///
/// [scrollDelta] musbat bo'lsa pastga, manfiy bo'lsa yuqoriga scroll qilingan.
HomeReelsSnapDecision? calculateHomeReelsSnap({
  required int settledIndex,
  required double pixels,
  required double viewportExtent,
  required double reelsStart,
  required int reelCount,
  required double scrollDelta,
}) {
  if (reelCount <= 0 || viewportExtent <= 0 || scrollDelta == 0) return null;

  if (settledIndex < 0) {
    final reelEnteredViewport = pixels + viewportExtent >= reelsStart;
    if (scrollDelta > 0 && reelEnteredViewport) {
      return HomeReelsSnapDecision(offset: reelsStart, settledIndex: 0);
    }
    return null;
  }

  final safeIndex = settledIndex.clamp(0, reelCount - 1);
  if (scrollDelta > 0) {
    final next = math.min(safeIndex + 1, reelCount - 1);
    return HomeReelsSnapDecision(
      offset: reelsStart + next * viewportExtent,
      settledIndex: next,
    );
  }

  if (safeIndex == 0) {
    return HomeReelsSnapDecision(
      offset: math.max(0, reelsStart - viewportExtent),
      settledIndex: -1,
    );
  }

  final previous = safeIndex - 1;
  return HomeReelsSnapDecision(
    offset: reelsStart + previous * viewportExtent,
    settledIndex: previous,
  );
}
