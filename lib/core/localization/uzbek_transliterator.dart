/// O'zbek lotin ↔ kirill transliteratsiyasi.
///
/// Toza Dart — Flutter import'i YO'Q, chunki bu `compute()` orqali alohida
/// izolatda ishlaydi va to'liq unit-test qilinadi.
///
/// Nega umuman kerak: backend faqat `lang=uz|ru` ni biladi va butun bazada
/// matn **lotin** yozuvida. Kirill foydalanuvchisi uchun:
///   - kiruvchi matn  (server → app)  lotindan kirillga o'giriladi;
///   - chiquvchi matn (app → server) kirilldan lotinga qaytariladi,
///     aks holda qidiruv (`icontains name_uz`) 0 natija beradi.
library;

/// Foydalanuvchi tanlagan yozuv.
enum UzScript {
  /// Transliteratsiya qilinmaydi (uz-lotin yoki rus tili).
  none,

  /// O'zbek kirill.
  cyrillic,
}

abstract final class UzbekTransliterator {
  // ── Apostrof variantlari ───────────────────────────────────────────────────
  // Backenddagi `apps/catalog/normalization.py` bilan bir xil ro'yxat.
  static const List<String> _apostropheChars = [
    'ʻ', // ʻ modifier letter turned comma  (oʻ / gʻ)
    'ʼ', // ʼ modifier letter apostrophe    (tutuq belgisi)
    '‘', // ' left single quotation mark
    '’', // ' right single quotation mark
    '`', // grave accent
    '´', // ´ acute accent
  ];
  static const String _apostrophe = "'";

  // ── Lotin → kirill qoidalari (uzun-moslik-avval) ───────────────────────────
  // Tartib MUHIM: uch/ikki harfli birikmalar bitta harflardan oldin turishi
  // shart, aks holda "sh" → "сҳ" bo'lib ketadi.
  static const List<(String, String)> _toCyrillicDigraphs = [
    // Trigraflar BIRINCHI: "yo'q" da `yo`→ё emas, `y`+`o'`→йў bo'lishi kerak.
    // Aks holda "yo'q" → "ёъқ" chiqadi ("йўқ" o'rniga).
    ("yo'", 'йў'),
    ("yg'", 'йғ'),
    ("o'", 'ў'),
    ("g'", 'ғ'),
    ('sh', 'ш'),
    ('ch', 'ч'),
    ('yo', 'ё'),
    ('yu', 'ю'),
    ('ya', 'я'),
    ('ye', 'е'),
    ('ts', 'ц'),
  ];

  static const Map<String, String> _toCyrillicSingles = {
    'a': 'а',
    'b': 'б',
    'v': 'в',
    'g': 'г',
    'd': 'д',
    'j': 'ж',
    'z': 'з',
    'i': 'и',
    'y': 'й',
    'k': 'к',
    'l': 'л',
    'm': 'м',
    'n': 'н',
    'o': 'о',
    'p': 'п',
    'r': 'р',
    's': 'с',
    't': 'т',
    'u': 'у',
    'f': 'ф',
    'x': 'х',
    'h': 'ҳ',
    'q': 'қ',
    'e': 'е', // so'z boshida / unlidan keyin 'э' ga aylanadi (pastga qarang)
    'c': 'к',
    'w': 'в',
  };

  static const String _vowelsLatin = 'aeiou';

  // ── Kirill → lotin jadvali ─────────────────────────────────────────────────
  // Backenddagi `apps/catalog/normalization.py:53-62` NUSXASI.
  // Ikkalasi bir xil bo'lishi shart, aks holda qidiruv mos kelmaydi.
  static const Map<String, String> _toLatinMap = {
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'yo',
    'ж': 'j',
    'з': 'z',
    'и': 'i',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'x',
    'ц': 'ts',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'sh',
    'ъ': "'",
    'ы': 'i',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
    'ў': "o'",
    'қ': 'q',
    'ғ': "g'",
    'ҳ': 'h',
  };

  // ── Skip qoidalari ─────────────────────────────────────────────────────────

  /// Transliteratsiya qilinmaydigan brend/model nomlari.
  /// Kerak bo'lganda `assets/l10n/brand_whitelist.json` orqali kengaytiriladi.
  static Set<String> brandWhitelist = _defaultBrands;

  static const Set<String> _defaultBrands = {
    'coca-cola',
    'cola',
    'pepsi',
    'fanta',
    'sprite',
    'nestle',
    'nescafe',
    'lipton',
    'iphone',
    'samsung',
    'xiaomi',
    'lg',
    'sony',
    'bosch',
    'philips',
    'artel',
    'akfa',
    'wi-fi',
    'wifi',
    'usb',
    'led',
    'pvc',
    'oled',
    'android',
    'ios',
  };

  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final RegExp _hexColor = RegExp(r'^#?[0-9A-Fa-f]{6,8}$');
  static final RegExp _hasAsciiLetter = RegExp('[A-Za-z]');
  static final RegExp _hasCyrillicLetter = RegExp('[Ѐ-ӿ]');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final RegExp _tokenSplit = RegExp(r'(\s+)');

  // ── Umumiy qo'riqchi ───────────────────────────────────────────────────────

  /// Qiymat umuman tegilmasligi kerakmi.
  ///
  /// Bu allowlist'dagi kalitlar uchun ham qo'shimcha himoya: URL, UUID, rang
  /// kodi yoki umuman harf yo'q matn hech qachon o'zgartirilmaydi.
  static bool isProtected(String value) {
    if (value.isEmpty) return true;
    if (value.contains('://') || value.startsWith('/')) return true;
    if (_uuid.hasMatch(value)) return true;
    if (_hexColor.hasMatch(value)) return true;
    return false;
  }

  static bool _skipToken(String token) {
    if (token.isEmpty) return true;
    // "5L", "A4", "10103" kabi model/SKU bo'laklari
    if (_hasDigit.hasMatch(token)) return true;
    final bare = token.replaceAll(RegExp(r'[^\w\-]'), '');
    if (bare.isEmpty) return true;
    if (brandWhitelist.contains(bare.toLowerCase())) return true;
    // Qisqa ALL-CAPS — odatda SKU yoki qisqartma
    if (bare.length <= 4 &&
        bare == bare.toUpperCase() &&
        bare != bare.toLowerCase()) {
      return true;
    }
    return false;
  }

  // ── Lotin → kirill ─────────────────────────────────────────────────────────

  /// O'zbek lotin matnini kirillga o'giradi.
  ///
  /// Idempotent: allaqachon kirill bo'lgan matn o'zgarmaydi (kirill harflari
  /// hech bir qoidaga tushmaydi va o'zgarishsiz o'tadi).
  static String toCyrillic(String input) {
    if (input.isEmpty || isProtected(input)) return input;
    if (!_hasAsciiLetter.hasMatch(input)) return input;

    // `split` Dart'da ajratuvchini TASHLAB yuboradi (JS dan farqli), shuning
    // uchun bo'shliqlarni saqlash uchun splitMapJoin ishlatiladi.
    return input.splitMapJoin(
      _tokenSplit,
      onMatch: (m) => m[0]!,
      onNonMatch: (token) =>
          _skipToken(token) ? token : _tokenToCyrillic(token),
    );
  }

  static String _tokenToCyrillic(String token) {
    final src = _foldApostrophes(token);
    final lower = src.toLowerCase();
    final out = StringBuffer();

    var i = 0;
    while (i < src.length) {
      final matched = _matchDigraph(lower, i);
      if (matched != null) {
        final (latin, cyr) = matched;
        out.write(_applyCase(src, i, latin.length, cyr));
        i += latin.length;
        continue;
      }

      final ch = lower[i];

      // Kontekstli 'e': so'z boshida yoki unlidan keyin — 'э'.
      if (ch == 'e') {
        final prev = i == 0 ? '' : lower[i - 1];
        final atWordStart = i == 0 || !_isLatinLetter(prev);
        final afterVowel = prev.isNotEmpty && _vowelsLatin.contains(prev);
        final cyr = (atWordStart || afterVowel) ? 'э' : 'е';
        out.write(_applyCase(src, i, 1, cyr));
        i += 1;
        continue;
      }

      // Qolgan apostrof — tutuq belgisi.
      if (ch == _apostrophe) {
        out.write('ъ');
        i += 1;
        continue;
      }

      final single = _toCyrillicSingles[ch];
      if (single != null) {
        out.write(_applyCase(src, i, 1, single));
      } else {
        out.write(src[i]); // raqam, tinish belgisi, kirill, noma'lum harf
      }
      i += 1;
    }
    return out.toString();
  }

  static (String, String)? _matchDigraph(String lower, int i) {
    for (final (latin, cyr) in _toCyrillicDigraphs) {
      if (lower.startsWith(latin, i)) return (latin, cyr);
    }
    return null;
  }

  /// Manbadagi registrni natijaga ko'chiradi.
  ///
  /// `Sh` → `Ш`, `SH` → `Ш`, `sh` → `ш`. Ko'p harfli natijada (masalan `ц`
  /// bitta, lekin `yo`→`ё`) faqat birinchi harf katta bo'ladi, `SH` kabi
  /// to'liq katta yozuvda esa hammasi katta.
  static String _applyCase(String src, int start, int len, String replacement) {
    final chunk = src.substring(start, start + len);
    final hasUpper = chunk.toLowerCase() != chunk;
    if (!hasUpper) return replacement;

    final allUpper = chunk.toUpperCase() == chunk && len > 1;
    if (allUpper) return replacement.toUpperCase();

    if (replacement.length == 1) return replacement.toUpperCase();
    return replacement[0].toUpperCase() + replacement.substring(1);
  }

  static bool _isLatinLetter(String ch) =>
      ch.isNotEmpty && _hasAsciiLetter.hasMatch(ch);

  // ── Kirill → lotin ─────────────────────────────────────────────────────────

  /// Kirill matnni lotinga qaytaradi — backend qidiruvi/saqlashi uchun.
  ///
  /// Backenddagi `transliterate_cyrillic_to_latin` bilan bir xil natija berishi
  /// shart. Lotin harflar, raqam va tinish belgilari o'zgarishsiz o'tadi.
  static String toLatin(String input) {
    if (input.isEmpty || isProtected(input)) return input;
    if (!_hasCyrillicLetter.hasMatch(input)) return input;

    final out = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final lower = ch.toLowerCase();
      final mapped = _toLatinMap[lower];
      if (mapped == null) {
        out.write(ch);
        continue;
      }
      if (mapped.isEmpty) continue; // 'ь' tushib qoladi
      out.write(ch == lower ? mapped : _capitalize(mapped));
    }
    return out.toString();
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  // ── Yordamchi ──────────────────────────────────────────────────────────────

  /// Barcha apostrof variantlarini bitta ASCII `'` ga keltiradi.
  static String _foldApostrophes(String value) {
    var result = value;
    for (final ch in _apostropheChars) {
      result = result.replaceAll(ch, _apostrophe);
    }
    return result;
  }
}
