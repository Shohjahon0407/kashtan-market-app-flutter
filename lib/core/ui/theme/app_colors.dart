import 'package:flutter/material.dart';

/// Design system: **toza / minimal, light-first**.
///
/// Asosiy tamoyil: ilova "kiyimi" deyarli neytral (oq/kulrang), RANG esa
/// kontentdan keladi. Buning sababi arxitekturaviy — bosh ekrandagi
/// kartochkalar (`store_hub`, `home_promo_cards`, `banners`) o'z ranglarini
/// ADMINDAN oladi. Agar ilova o'zi ham to'yingan rangli bo'lsa, admin qo'ygan
/// gradientlar bilan urishib ketadi va ekran "shovqinli" bo'ladi.
///
/// Shu sabab urg'u rangi ham 4 ta do'kon turining server ranglaridan
/// (mint #80FFE2, cyan #0AD3F5, orange #FF8A4C, red #FF6B6B) ataylab uzoq
/// tanlangan — chuqur yashil.
abstract final class AppColors {
  // ── Brend / urg'u ──────────────────────────────────────────────────────────

  /// Asosiy amal rangi: tugmalar, faol tab, narx urg'usi.
  /// Oq matn bilan kontrast 5.18:1 → WCAG AA (oddiy matn) ✓
  static const Color primary = Color(0xFF0B7C5C);
  static const Color primaryPressed = Color(0xFF096549);
  static const Color primarySoft = Color(0xFFE7F6F1);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Semantik ───────────────────────────────────────────────────────────────

  /// Chegirma, o'chirish, xato. Oq matn bilan 4.83:1 ✓
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSoft = Color(0xFFFEF3F2);

  static const Color warning = Color(0xFFB54708);
  static const Color warningSoft = Color(0xFFFFFAEB);

  static const Color success = Color(0xFF067647);
  static const Color successSoft = Color(0xFFECFDF3);

  static const Color info = Color(0xFF175CD3);
  static const Color infoSoft = Color(0xFFEFF8FF);

  // ── Yorug' mavzu ───────────────────────────────────────────────────────────

  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Sahifa foni — sof oq emas, shunda oq kartochkalar ko'rinadi.
  static const Color lightCanvas = Color(0xFFF7F8FA);
  static const Color lightSunken = Color(0xFFEEF0F3);
  static const Color lightBorder = Color(0xFFE4E7EC);
  static const Color lightBorderStrong = Color(0xFFD0D5DD);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475467);

  /// Hint/caption uchun. #98A2B3 chiroyliroq edi, lekin oq fonda atigi
  /// 2.58:1 berardi — katta matn uchun ham yetmaydi. 4.97:1 ✓
  static const Color lightTextTertiary = Color(0xFF667085);

  /// FAQAT dekorativ ajratgichlar/ikonkalar uchun — matn EMAS.
  static const Color lightTextDisabled = Color(0xFF98A2B3);

  // ── Quyuq mavzu ────────────────────────────────────────────────────────────
  // Tizim sozlamasiga ergashadi. Server kartochkalari yorqin bo'lgani uchun
  // quyuq fon ularni yanada ajratib ko'rsatadi.

  static const Color darkCanvas = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF131A22);
  static const Color darkSunken = Color(0xFF1B242E);
  static const Color darkBorder = Color(0xFF2A3540);
  static const Color darkBorderStrong = Color(0xFF3B4753);

  static const Color darkTextPrimary = Color(0xFFE7ECF2);
  static const Color darkTextSecondary = Color(0xFF98A6B5);

  /// Quyuq fonda 5.11:1 ✓ (#64748B atigi 3.68 berardi).
  static const Color darkTextTertiary = Color(0xFF7C8CA1);

  /// FAQAT dekorativ — matn EMAS.
  static const Color darkTextDisabled = Color(0xFF64748B);

  /// Quyuq fonda #0B7C5C juda to'q — yorqinroq variant.
  static const Color primaryDark = Color(0xFF2BC79A);
  static const Color primarySoftDark = Color(0xFF10291F);
  static const Color onPrimaryDark = Color(0xFF04120C);
}
