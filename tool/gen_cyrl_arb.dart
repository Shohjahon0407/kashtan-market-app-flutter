// ignore_for_file: avoid_print
//
// `lib/l10n/app_uz.arb` dan `lib/l10n/app_uz_Cyrl.arb` ni GENERATSIYA qiladi.
//
// Kirill fayl QO'LDA tahrirlanmaydi: 500+ kalitni ikki marta yozish va ularni
// sinxron ushlab turish real emas. Mexanik transliteratsiya noto'g'ri
// bo'lgan joylar uchun `lib/l10n/cyrl_overrides.json` bor.
//
// Ishlatish:
//   dart run tool/gen_cyrl_arb.dart          # generatsiya qiladi
//   dart run tool/gen_cyrl_arb.dart --check  # farq bo'lsa xato bilan chiqadi
//
// `--check` CI uchun: app_uz.arb o'zgargan-u, kirill fayl yangilanmagan
// holatni ushlaydi.

import 'dart:convert';
import 'dart:io';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';

const String _sourcePath = 'lib/l10n/app_uz.arb';
const String _targetPath = 'lib/l10n/app_uz_Cyrl.arb';
const String _overridesPath = 'lib/l10n/cyrl_overrides.json';

Future<int> main(List<String> args) async {
  final checkOnly = args.contains('--check');

  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Topilmadi: $_sourcePath');
    return 1;
  }

  final decoded = jsonDecode(await source.readAsString());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('$_sourcePath JSON obyekt emas.');
    return 1;
  }

  final overrides = _loadOverrides();
  final result = _transliterateArb(decoded, overrides);
  final rendered = '${const JsonEncoder.withIndent('  ').convert(result)}\n';

  final target = File(_targetPath);
  if (checkOnly) {
    final existing = target.existsSync() ? await target.readAsString() : '';
    if (existing == rendered) {
      print('✓ $_targetPath dolzarb');
      return 0;
    }
    stderr.writeln(
      '✖ $_targetPath eskirgan. `dart run tool/gen_cyrl_arb.dart` ni ishga tushiring.',
    );
    return 1;
  }

  await target.writeAsString(rendered);
  final count = result.keys.where((k) => !k.startsWith('@')).length;
  print('✓ $_targetPath yozildi ($count kalit)');
  return 0;
}

Map<String, String> _loadOverrides() {
  final file = File(_overridesPath);
  if (!file.existsSync()) return const {};
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) return const {};
  return decoded.map((k, v) => MapEntry(k, v.toString()));
}

Map<String, dynamic> _transliterateArb(
  Map<String, dynamic> source,
  Map<String, String> overrides,
) {
  final out = <String, dynamic>{};
  source.forEach((key, value) {
    // `@@locale` almashtiriladi, boshqa `@@` va `@key` metadata AYNAN ko'chiriladi.
    if (key == '@@locale') {
      out[key] = 'uz_Cyrl';
      return;
    }
    if (key.startsWith('@')) {
      out[key] = value;
      return;
    }
    if (overrides.containsKey(key)) {
      out[key] = overrides[key];
      return;
    }
    out[key] = value is String ? _transliterateIcu(value) : value;
  });
  return out;
}

/// ICU placeholder va plural/select kalit so'zlarini SAQLAB transliteratsiya
/// qiladi.
///
/// `{count, plural, =0{Element yo'q} other{{count} element}}` da:
///   - `count`, `plural`, `=0`, `other` — TEGILMAYDI (gen-l10n ularni parse qiladi)
///   - `Element yo'q`, `element` — transliteratsiya qilinadi
String _transliterateIcu(String value) {
  final out = StringBuffer();
  final buffer = StringBuffer();

  // ICU da xabar ichida haqiqiy apostrof `''` deb yoziladi. Uni avval bitta
  // apostrofga qaytaramiz (aks holda "yo''q" → "ёъъқ" bo'lib ketadi), keyin
  // natijada apostrof qolsa qayta ekranlaymiz. Kirillда apostrof odatda `ъ`
  // ga aylangani uchun qayta ekranlash deyarli hech qachon kerak bo'lmaydi.
  final isIcuMessage = value.contains('{');

  void flush() {
    if (buffer.isEmpty) return;
    final raw = isIcuMessage
        ? buffer.toString().replaceAll("''", "'")
        : buffer.toString();
    final cyrillic = UzbekTransliterator.toCyrillic(raw);
    out.write(
      isIcuMessage ? cyrillic.replaceAll("'", "''") : cyrillic,
    );
    buffer.clear();
  }

  var depth = 0;
  var i = 0;
  while (i < value.length) {
    final ch = value[i];

    if (ch == '{') {
      flush();
      depth++;
      // `{` dan keyingi ARGUMENT/KEYWORD qismini aynan ko'chiramiz:
      // yopuvchi `}` gacha yoki ichki `{` boshlanguncha.
      final header = _readIcuHeader(value, i);
      out.write(header);
      i += header.length;
      continue;
    }

    if (ch == '}') {
      flush();
      depth--;
      out.write(ch);
      i++;
      continue;
    }

    // Plural/select shoxlari orasidagi `=0`, `one`, `other` kalitlari
    // `_readIcuHeader` da emas, shu yerda uchraydi.
    if (depth > 0) {
      final keyword = _matchBranchKeyword(value, i);
      if (keyword != null) {
        flush();
        out.write(keyword);
        i += keyword.length;
        continue;
      }
    }

    buffer.write(ch);
    i++;
  }
  flush();
  return out.toString();
}

/// `{` dan boshlab, matn qismi boshlanguncha bo'lgan ICU sarlavhasi.
///
/// `{count}`            → `{count`
/// `{count, plural, `   → `{count, plural, `
String _readIcuHeader(String value, int start) {
  final rest = value.substring(start);
  final simple = RegExp(r'^\{[A-Za-z_][A-Za-z0-9_]*(?=[},])');
  final withType = RegExp(
    r'^\{\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*(plural|select|selectordinal)\s*,\s*',
  );
  final m = withType.firstMatch(rest) ?? simple.firstMatch(rest);
  return m?.group(0) ?? '{';
}

/// `=0`, `=1`, `zero`, `one`, `two`, `few`, `many`, `other`, yoki select
/// varianti — keyin darhol `{` keladi.
String? _matchBranchKeyword(String value, int index) {
  final rest = value.substring(index);
  final m = RegExp(r'^(=\d+|[A-Za-z_][A-Za-z0-9_]*)\s*(?=\{)').firstMatch(rest);
  return m?.group(0);
}
