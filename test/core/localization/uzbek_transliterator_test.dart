import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toCyrillic', () {
    test('digraflar bitta harflardan oldin qo‘llanadi', () {
      expect(UzbekTransliterator.toCyrillic('shakar'), 'шакар');
      expect(UzbekTransliterator.toCyrillic('choy'), 'чой');
      expect(UzbekTransliterator.toCyrillic('yogurt'), 'ёгурт');
      expect(UzbekTransliterator.toCyrillic('yulduz'), 'юлдуз');
      expect(UzbekTransliterator.toCyrillic('yaxshi'), 'яхши');
    });

    test("o' va g' maxsus harflari", () {
      expect(UzbekTransliterator.toCyrillic("o'zbek"), 'ўзбек');
      expect(UzbekTransliterator.toCyrillic("g'isht"), 'ғишт');
      expect(UzbekTransliterator.toCyrillic("do'kon"), 'дўкон');
    });

    test('apostrof variantlari bir xil natija beradi', () {
      const variants = ["o'zbek", 'oʻzbek', 'o‘zbek', 'o’zbek', 'o`zbek'];
      for (final v in variants) {
        expect(UzbekTransliterator.toCyrillic(v), 'ўзбек', reason: v);
      }
    });

    test('q, x, h harflari to‘g‘ri ajratiladi', () {
      expect(UzbekTransliterator.toCyrillic('qand'), 'қанд');
      expect(UzbekTransliterator.toCyrillic('xona'), 'хона');
      expect(UzbekTransliterator.toCyrillic('hovli'), 'ҳовли');
    });

    test('kontekstli e: so‘z boshida э, ichida е', () {
      expect(UzbekTransliterator.toCyrillic('eshik'), 'эшик');
      expect(UzbekTransliterator.toCyrillic('non'), 'нон');
      expect(UzbekTransliterator.toCyrillic('kel'), 'кел');
      expect(UzbekTransliterator.toCyrillic('non eshik'), 'нон эшик');
    });

    test('registr saqlanadi', () {
      expect(UzbekTransliterator.toCyrillic('Shakar'), 'Шакар');
      expect(UzbekTransliterator.toCyrillic('Choy'), 'Чой');
      expect(UzbekTransliterator.toCyrillic('Non'), 'Нон');
    });

    test('so‘z ichidagi tutuq belgisi ъ ga aylanadi', () {
      expect(UzbekTransliterator.toCyrillic("ma'no"), 'маъно');
    });

    test("yo' birikmasi: y + o' bo‘lib bo‘linadi, yo + ' emas", () {
      // Regressiya: avval "yo'q" → "ёъқ" chiqardi, to‘g‘risi "йўқ".
      expect(UzbekTransliterator.toCyrillic("yo'q"), 'йўқ');
      expect(UzbekTransliterator.toCyrillic("Yo'q"), 'Йўқ');
      expect(UzbekTransliterator.toCyrillic("yo'l"), 'йўл');
      // Apostrofsiz `yo` esa baribir ё bo‘lib qoladi.
      expect(UzbekTransliterator.toCyrillic('yosh'), 'ёш');
    });

    test('idempotent — kirill matn o‘zgarmaydi', () {
      const cyr = 'шакар чой ўзбек';
      expect(UzbekTransliterator.toCyrillic(cyr), cyr);
      final once = UzbekTransliterator.toCyrillic('shakar choy');
      expect(UzbekTransliterator.toCyrillic(once), once);
    });

    test('himoyalangan qiymatlar tegilmaydi', () {
      const url = 'https://api.beshkashtan.uz/media/products/a.jpg';
      const uuid = 'd99e20ce-40bb-4217-8743-20fca14257c9';
      const hex = '#80FFE2';
      const money = '15000.00';
      for (final v in [url, uuid, hex, money, '/media/x.png', '']) {
        expect(UzbekTransliterator.toCyrillic(v), v, reason: v);
      }
    });

    test('raqamli tokenlar va brendlar skip qilinadi', () {
      expect(UzbekTransliterator.toCyrillic('Coca-Cola'), 'Coca-Cola');
      expect(UzbekTransliterator.toCyrillic('iPhone'), 'iPhone');
      expect(UzbekTransliterator.toCyrillic('sut 1L'), 'сут 1L');
      expect(UzbekTransliterator.toCyrillic('A4 qogoz'), 'A4 қогоз');
    });

    test('bo‘shliqlar va tinish belgilari saqlanadi', () {
      expect(
        UzbekTransliterator.toCyrillic('Sut, non va choy!'),
        'Сут, нон ва чой!',
      );
    });
  });

  group('toLatin (backend normalization.py bilan bir xil)', () {
    test('asosiy harflar', () {
      expect(UzbekTransliterator.toLatin('сут'), 'sut');
      expect(UzbekTransliterator.toLatin('шакар'), 'shakar');
      expect(UzbekTransliterator.toLatin('чой'), 'choy');
      expect(UzbekTransliterator.toLatin('ўзбек'), "o'zbek");
      expect(UzbekTransliterator.toLatin('ғишт'), "g'isht");
      expect(UzbekTransliterator.toLatin('қанд'), 'qand');
      expect(UzbekTransliterator.toLatin('ҳовли'), 'hovli');
    });

    test('rus harflari ham qo‘llab-quvvatlanadi', () {
      expect(UzbekTransliterator.toLatin('молоко'), 'moloko');
      expect(UzbekTransliterator.toLatin('цена'), 'tsena');
      expect(UzbekTransliterator.toLatin('щётка'), 'shyotka');
    });

    test('ь tushadi, ъ apostrofga aylanadi', () {
      expect(UzbekTransliterator.toLatin('соль'), 'sol');
      expect(UzbekTransliterator.toLatin('съезд'), "s'ezd");
    });

    test('lotin matn o‘zgarishsiz o‘tadi', () {
      expect(UzbekTransliterator.toLatin('sut 1L'), 'sut 1L');
      expect(UzbekTransliterator.toLatin('Coca-Cola'), 'Coca-Cola');
    });

    test('himoyalangan qiymatlar tegilmaydi', () {
      const uuid = 'd99e20ce-40bb-4217-8743-20fca14257c9';
      expect(UzbekTransliterator.toLatin(uuid), uuid);
    });
  });

  group('round-trip', () {
    test('lotin → kirill → lotin asosiy so‘zlarda tiklanadi', () {
      const words = [
        'sut',
        'non',
        'shakar',
        'choy',
        'qand',
        'xona',
        'moloko',
        'kartoshka',
        'pomidor',
      ];
      for (final w in words) {
        final cyr = UzbekTransliterator.toCyrillic(w);
        expect(UzbekTransliterator.toLatin(cyr), w, reason: w);
      }
    });
  });
}
