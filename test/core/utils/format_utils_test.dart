import 'dart:ui' show Color;

import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/core/utils/hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HexColor.tryParse', () {
    test('#RRGGBB / RRGGBB / #AARRGGBB', () {
      expect(HexColor.tryParse('#F59E0B'), const Color(0xFFF59E0B));
      expect(HexColor.tryParse('F59E0B'), const Color(0xFFF59E0B));
      expect(HexColor.tryParse('#80FFFFFF'), const Color(0x80FFFFFF));
    });

    test('buzuq qiymatlar null (crash EMAS)', () {
      for (final bad in [
        '',
        ' ',
        '#F59',
        'qizil',
        '#GGGGGG',
        'rgba(1,2,3)',
        null,
      ]) {
        expect(HexColor.tryParse(bad), isNull, reason: '$bad');
      }
    });
  });

  group('Uzs.format', () {
    test('server stringlari (guruh ajratkichi — NBSP)', () {
      expect(Uzs.format('15000.00'), "15\u00A0000 so'm");
      expect(Uzs.format('1234567.50'), "1\u00A0234\u00A0567 so'm");
      expect(Uzs.format('500.00'), "500 so'm");
      expect(Uzs.format('0.00'), "0 so'm");
    });

    test('buzuq kiritmada bo‘sh', () {
      expect(Uzs.format(null), '');
      expect(Uzs.format(''), '');
      expect(Uzs.format('abc'), '');
    });
  });
}
