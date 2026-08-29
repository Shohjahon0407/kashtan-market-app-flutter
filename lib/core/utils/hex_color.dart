import 'dart:ui' show Color;

/// Admin kiritgan rang stringlarini xavfsiz o'qish.
///
/// Hech qachon qo'riqsiz `Color(int.parse(...))` ishlatilmaydi — bitta buzuq
/// admin qiymati butun ekranni yiqitmasligi kerak. Buzuq/bo'sh → `null`,
/// chaqiruvchi o'z fallback rangini ishlatadi.
abstract final class HexColor {
  static final RegExp _hex = RegExp(r'^[0-9a-fA-F]{6}$|^[0-9a-fA-F]{8}$');

  /// `#RRGGBB`, `RRGGBB`, `#AARRGGBB`, `AARRGGBB` → [Color].
  static Color? tryParse(String? input) {
    final raw = input?.trim();
    if (raw == null || raw.isEmpty) return null;
    final hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!_hex.hasMatch(hex)) return null;
    final withAlpha = hex.length == 6 ? 'FF$hex' : hex;
    final value = int.tryParse(withAlpha, radix: 16);
    return value == null ? null : Color(value);
  }
}
