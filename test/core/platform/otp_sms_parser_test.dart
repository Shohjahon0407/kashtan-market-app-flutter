import 'package:beshkashtan_customer/core/platform/otp_sms_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eskiz tasdiqlagan matn (probellar AYNAN shunday, `" : "` bilan).
const _approved =
    'Assalomu alaykum hurmatli mijoz! '
    'Beshkashtan savdo majmuasi ilovasiga kirish kodi : 482913';

void main() {
  test('tasdiqlangan matndan kod ajratiladi', () {
    expect(OtpSmsParser.extract(_approved), '482913');
  });

  test('SMS Retriever hash\'i bilan ham ishlaydi', () {
    expect(OtpSmsParser.extract('$_approved FA+9qCX9VSu'), '482913');
  });

  test('hash ichidagi 6 raqam kod deb olinmaydi', () {
    // Base64 alifbosida raqamlar bor — hash avval kesilmasa, `123456`
    // kod sifatida o'qilib ketardi.
    expect(OtpSmsParser.extract('$_approved Ab1234567Cd'), '482913');
  });

  test('oxirida qator uzilishi bo\'lsa ham hash kesiladi', () {
    expect(OtpSmsParser.extract('$_approved FA+9qCX9VSu\n'), '482913');
  });

  test('telefon raqami kod bilan adashtirilmaydi', () {
    expect(OtpSmsParser.extract('+998901112233 uchun kod: 482913'), '482913');
  });

  test('kalit so\'zdan keyingi kod ustun', () {
    expect(
      OtpSmsParser.extract('123456 raqamli buyurtma. Kirish kodi : 482913'),
      '482913',
    );
  });

  test('ruscha va inglizcha kalit so\'zlar', () {
    expect(OtpSmsParser.extract('Ваш код: 482913'), '482913');
    expect(OtpSmsParser.extract('Your code 482913'), '482913');
  });

  test('kalit so\'zsiz matnda oxirgi nomzod olinadi', () {
    expect(OtpSmsParser.extract('111111 va 482913'), '482913');
  });

  test('mos kelmaydigan kiritmalar null qaytaradi', () {
    expect(OtpSmsParser.extract(null), isNull);
    expect(OtpSmsParser.extract(''), isNull);
    expect(OtpSmsParser.extract('kod yo\'q'), isNull);
    // 7 xonali guruh — bizning kod emas.
    expect(OtpSmsParser.extract('1234567'), isNull);
    // Harfga yopishgan raqamlar.
    expect(OtpSmsParser.extract('qCX9123456A'), isNull);
  });
}
