import 'dart:ui' show Locale;

import 'package:beshkashtan_customer/core/localization/failure_l10n.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dekod (malformed) xatolarining dasturchi matni foydalanuvchiga
/// ko'rsatilmaydi — umumiy xato matni chiqadi; server matni esa qoladi.
void main() {
  late AppLocalizations ru;
  setUpAll(() async {
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  test('malformed → umumiy xato matni', () {
    const failure = UnknownFailure.malformed('cart javobi obyekt emas');
    final text = failure.localize(ru);
    expect(text, startsWith(ru.errorUnknown));
    // Debug'da texnik sabab qo'shiladi, release'da yo'q.
    expect(text.contains('cart javobi'), kDebugMode);
    expect(failure.isDiagnostic, isTrue);
  });

  test('server matnli UnknownFailure avvalgidek ko\'rsatiladi', () {
    const failure = UnknownFailure('Buyurtma allaqachon bekor qilingan');
    expect(failure.isDiagnostic, isFalse);
    expect(
      failure.localize(ru),
      startsWith('Buyurtma allaqachon bekor qilingan'),
    );
  });
}
