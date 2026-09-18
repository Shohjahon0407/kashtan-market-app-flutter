import '../../features/auth/data/auth_models.dart' show OtpPolicy;

/// SMS matnidan 6 xonali tasdiqlash kodini ajratib oladi.
///
/// Sof Dart — platformasiz test qilinadi. Kirish matni ixtiyoriy bo'lishi
/// mumkin: SMS User Consent butun xabarni qaytaradi, SMS Retriever esa
/// oxirida 11 belgilik ilova hash'i bo'lgan xabarni beradi.
abstract final class OtpSmsParser {
  /// Xabar oxiridagi SMS Retriever app hash'i (11 ta base64 belgi).
  ///
  /// U kodni qidirishdan OLDIN kesib tashlanadi: base64 alifbosida raqamlar
  /// ham bor, ya'ni hash ichida 6 ta ketma-ket raqam uchrashi mumkin
  /// (masalan `Ab1234567Cd`) va u kod deb o'qilib ketardi.
  static final _trailingHash = RegExp(r'[\s ]+[A-Za-z0-9+/]{11}\s*$');

  /// Harf yoki raqam bilan yopishmagan roppa-rosa N xonali guruh.
  ///
  /// `" : 123456"` — mos keladi; `+998901112233` (12 raqam) — kelmaydi.
  static final _codeGroup = RegExp(
    '(?<![0-9A-Za-z])([0-9]{${OtpPolicy.codeLength}})(?![0-9A-Za-z])',
  );

  /// Kalit so'zdan keyin kelgan kod — eng ishonchli nomzod.
  static final _afterKeyword = RegExp(
    r'(?:kodi?|код|code)\s*[:\-]?\s*'
    '(?<![0-9A-Za-z])([0-9]{${OtpPolicy.codeLength}})(?![0-9A-Za-z])',
    caseSensitive: false,
  );

  /// Kod topilmasa `null`.
  static String? extract(String? body) {
    if (body == null || body.isEmpty) return null;
    final stripped = body.replaceFirst(_trailingHash, '');

    final keyed = _afterKeyword.firstMatch(stripped);
    if (keyed != null) return keyed.group(1);

    final matches = _codeGroup.allMatches(stripped).toList();
    if (matches.isEmpty) return null;
    // Bir nechta nomzod bo'lsa oxirgisi olinadi: bizning shablonda kod
    // xabarning eng oxirida turadi, sana/sender esa oldinroq keladi.
    return matches.last.group(1);
  }
}
