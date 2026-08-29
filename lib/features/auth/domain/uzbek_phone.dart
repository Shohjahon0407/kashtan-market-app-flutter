/// O'zbekiston telefon raqami bilan ishlash.
///
/// Backend normalizatsiyasi (`apps/common/validators.py`) bilan mos:
/// `+998XXXXXXXXX`, `998XXXXXXXXX` yoki 9 lokal raqam qabul qilinadi,
/// natija doim `+998` + 9 raqam.
abstract final class UzbekPhone {
  static const int localLength = 9;
  static const String countryCode = '+998';

  /// Amaldagi operator prefikslari.
  ///
  /// Client'da tekshiramiz, chunki har bir noto'g'ri raqamga yuborilgan
  /// so'rov serverda SMS narxini yoki soatlik limitni kuydirishi mumkin.
  /// (Eski app buni umuman tekshirmasdi.)
  static const Set<String> operatorPrefixes = {
    '20', // OQ
    '33', // Humans
    '50', // OQ
    '55', // Uzmobile CDMA→GSM
    '77', // Uzmobile
    '88', // Mobiuz
    '90', '91', // Beeline
    '93', '94', // Ucell
    '95', // Uzmobile
    '97', // Mobiuz
    '98', // Perfectum/Mobiuz
    '99', // Beeline
  };

  static final RegExp _nonDigits = RegExp(r'\D');
  static final RegExp _normalized = RegExp(r'^\+998\d{9}$');

  /// Matndan faqat raqamlarni oladi.
  static String digitsOnly(String input) => input.replaceAll(_nonDigits, '');

  /// 9 lokal raqamni ajratib oladi: `+998...`/`998...` prefikslarini tashlaydi.
  static String localDigits(String input) {
    var digits = digitsOnly(input);
    if (digits.startsWith('998') && digits.length > localLength) {
      digits = digits.substring(3);
    }
    if (digits.length > localLength) {
      digits = digits.substring(0, localLength);
    }
    return digits;
  }

  /// 9 lokal raqam to'g'rimi (uzunlik + operator prefiksi).
  static bool isValidLocal(String digits) =>
      digits.length == localLength &&
      !digits.contains(_nonDigits) &&
      operatorPrefixes.contains(digits.substring(0, 2));

  /// `+998XXXXXXXXX` ga keltiradi. Yaroqsiz kiritmada `null`.
  static String? normalize(String input) {
    final digits = localDigits(input);
    if (!isValidLocal(digits)) return null;
    return '$countryCode$digits';
  }

  static bool isNormalized(String? value) =>
      value != null && _normalized.hasMatch(value);

  /// `+998901234567` → `90 123 45 67` (ko'rsatish uchun).
  static String formatLocal(String digits) {
    final d = localDigits(digits);
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 7) buf.write(' ');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  /// `+998901234567` → `+998 90 123 45 67`.
  static String formatFull(String normalized) {
    if (!isNormalized(normalized)) return normalized;
    return '$countryCode ${formatLocal(normalized.substring(4))}';
  }
}
