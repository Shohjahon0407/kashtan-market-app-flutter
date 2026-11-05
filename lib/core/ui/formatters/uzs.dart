import '../../localization/app_locale.dart';

/// Backend pul stringlarini ko'rsatish.
///
/// Server pulni STRING qaytaradi (`"15000.00"`). Double'ga o'tkazib
/// yaxlitlash xatosiga yo'l qo'ymaslik uchun string darajasida ishlaymiz:
/// kasr qismi tashlanadi (so'mda tiyin ko'rsatilmaydi), butun qism
/// mingliklarga bo'linadi.
abstract final class Uzs {
  /// Joriy tilga mos valyuta qo'shimchasi. Locale controller o'rnatadi —
  /// ruscha/kirill foydalanuvchi lotin "so'm" ko'rmasin. Chaqiruv joylari
  /// (o'nlab) o'zgarmaydi.
  static String suffix = suffixFor(AppLocale.uz);

  static String suffixFor(AppLocale locale) => switch (locale) {
    AppLocale.uz => "so'm",
    AppLocale.uzCyrl => 'сўм',
    AppLocale.ru => 'сум',
  };

  /// `"15000.00"` → `15 000 so'm`. Buzuq kiritmada bo'sh string.
  static String format(String? raw) {
    final grouped = groupDigits(raw);
    return grouped.isEmpty ? '' : '$grouped $suffix';
  }

  /// Keep fractional amounts where truncation would misstate a threshold.
  static String formatWithFraction(String? raw) {
    final grouped = groupDigits(raw);
    if (grouped.isEmpty) return '';
    final parts = raw!.trim().split('.');
    final cents = (parts.length > 1 ? parts[1] : '')
        .padRight(2, '0')
        .substring(0, 2);
    return '$grouped${cents == '00' ? '' : '.$cents'} $suffix';
  }

  /// Multiply a public unit price without floating-point rounding. Invalid
  /// prices stay unknown rather than becoming a fabricated zero total.
  static String? multiply(String? raw, int quantity) {
    final match = RegExp(
      r'^(\d+)(?:\.(\d{1,2}))?$',
    ).firstMatch(raw?.trim() ?? '');
    if (match == null || quantity < 1) return null;
    final minor =
        BigInt.parse(match[1]!) * BigInt.from(100) +
        BigInt.parse((match[2] ?? '').padRight(2, '0'));
    final total = minor * BigInt.from(quantity);
    return '${total ~/ BigInt.from(100)}.${(total % BigInt.from(100)).toString().padLeft(2, '0')}';
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
