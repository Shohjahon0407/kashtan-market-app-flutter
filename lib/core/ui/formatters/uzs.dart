/// Backend pul stringlarini ko'rsatish.
///
/// Server pulni STRING qaytaradi (`"15000.00"`). Double'ga o'tkazib
/// yaxlitlash xatosiga yo'l qo'ymaslik uchun string darajasida ishlaymiz:
/// kasr qismi tashlanadi (so'mda tiyin ko'rsatilmaydi), butun qism
/// mingliklarga bo'linadi.
abstract final class Uzs {
  /// `"15000.00"` → `15 000 so'm`. Buzuq kiritmada bo'sh string.
  static String format(String? raw) {
    final grouped = groupDigits(raw);
    return grouped.isEmpty ? '' : "$grouped so'm";
  }

  /// Valyutasiz: `"15000.00"` → `15 000`.
  static String groupDigits(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return '';

    var intPart = value.split('.').first.replaceAll(' ', '');
    var negative = false;
    if (intPart.startsWith('-')) {
      negative = true;
      intPart = intPart.substring(1);
    }
    if (intPart.isEmpty || intPart.contains(RegExp(r'\D'))) return '';

    // Boshidagi ortiqcha nollarni tozalash ("007" -> "7", "000" -> "0")
    intPart = intPart.replaceFirst(RegExp('^0+(?=.)'), '');

    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      // Guruh ajratkichi — NBSP (\u00A0): narx qator o'rtasida
      // "15\n000" bo'lib sinmasligi uchun.
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('\u00A0');
      buf.write(intPart[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }
}
