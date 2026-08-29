import 'package:beshkashtan_customer/features/auth/domain/uzbek_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localDigits', () {
    test('turli kirish formatlari 9 raqamga keladi', () {
      expect(UzbekPhone.localDigits('901234567'), '901234567');
      expect(UzbekPhone.localDigits('+998901234567'), '901234567');
      expect(UzbekPhone.localDigits('998901234567'), '901234567');
      expect(UzbekPhone.localDigits('90 123 45 67'), '901234567');
      expect(UzbekPhone.localDigits('+998 (90) 123-45-67'), '901234567');
    });

    test('ortiqcha raqamlar kesiladi', () {
      expect(UzbekPhone.localDigits('9012345678999'), '901234567');
    });
  });

  group('isValidLocal', () {
    test('barcha amaldagi operator prefikslari o‘tadi', () {
      for (final prefix in UzbekPhone.operatorPrefixes) {
        expect(
          UzbekPhone.isValidLocal('${prefix}1234567'),
          isTrue,
          reason: prefix,
        );
      }
    });

    test('mavjud bo‘lmagan prefiks o‘tmaydi', () {
      // 12, 34, 89 — hech bir operatorga tegishli emas
      expect(UzbekPhone.isValidLocal('121234567'), isFalse);
      expect(UzbekPhone.isValidLocal('341234567'), isFalse);
      expect(UzbekPhone.isValidLocal('891234567'), isFalse);
    });

    test('uzunlik noto‘g‘ri bo‘lsa o‘tmaydi', () {
      expect(UzbekPhone.isValidLocal('9012345'), isFalse);
      expect(UzbekPhone.isValidLocal('9012345678'), isFalse);
      expect(UzbekPhone.isValidLocal(''), isFalse);
    });
  });

  group('normalize', () {
    test('to‘g‘ri raqam +998 bilan qaytadi', () {
      expect(UzbekPhone.normalize('90 123 45 67'), '+998901234567');
      expect(UzbekPhone.normalize('+998331234567'), '+998331234567');
    });

    test('yaroqsiz raqam null', () {
      expect(UzbekPhone.normalize('12 345 67 89'), isNull);
      expect(UzbekPhone.normalize('90123'), isNull);
    });
  });

  group('format', () {
    test('formatLocal — 90 123 45 67', () {
      expect(UzbekPhone.formatLocal('901234567'), '90 123 45 67');
      expect(UzbekPhone.formatLocal('9012'), '90 12');
      expect(UzbekPhone.formatLocal(''), '');
    });

    test('formatFull — +998 90 123 45 67', () {
      expect(UzbekPhone.formatFull('+998901234567'), '+998 90 123 45 67');
    });
  });
}
