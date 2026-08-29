import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backenddagi `apps/catalog/normalization.py::transliterate_cyrillic_to_latin`
/// bilan BIT-BIT bir xillikni tekshiradi.
///
/// Kutilgan qiymatlar backend funksiyasini haqiqiy ishga tushirib olingan.
/// Bu jadval mos kelmasa kirill foydalanuvchining qidiruvi jimgina 0 natija
/// beradi — shuning uchun test alohida faylda va aniq nomlangan.
void main() {
  const backendExpectations = <String, String>{
    'сут': 'sut',
    'шакар': 'shakar',
    'чой': 'choy',
    'ўзбек': "o'zbek",
    'ғишт': "g'isht",
    'қанд': 'qand',
    'ҳовли': 'hovli',
    'молоко': 'moloko',
    'цена': 'tsena',
    'щётка': 'shyotka',
    'соль': 'sol',
    'съезд': "s'ezd",
    'картошка': 'kartoshka',
    'помидор': 'pomidor',
    'нон': 'non',
    'хона': 'xona',
    'ёғ': "yog'",
    'юлдуз': 'yulduz',
    'яхши': 'yaxshi',
    'эшик': 'eshik',
    'кел': 'kel',
  };

  test('toLatin backend jadvali bilan aynan mos', () {
    backendExpectations.forEach((cyrillic, expectedLatin) {
      expect(
        UzbekTransliterator.toLatin(cyrillic),
        expectedLatin,
        reason: 'backend "$cyrillic" uchun "$expectedLatin" qaytaradi',
      );
    });
  });
}
