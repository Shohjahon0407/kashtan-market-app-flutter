import 'dart:ui' show Locale;

import 'package:beshkashtan_customer/core/localization/failure_l10n.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Debug build'da ham texnik tafsilotlar foydalanuvchiga chiqarilmasin.
void main() {
  late AppLocalizations ru;
  setUpAll(() async {
    ru = await AppLocalizations.delegate.load(const Locale('ru'));
  });

  test('malformed → umumiy xato matni', () {
    const failure = UnknownFailure.malformed('cart javobi obyekt emas');
    final text = failure.localize(ru);
    expect(text, ru.errorUnknown);
    expect(text, isNot(contains('cart javobi')));
    expect(failure.isDiagnostic, isTrue);
  });

  test("noma'lum server xatosi foydalanuvchi tilida ko‘rsatiladi", () {
    const failure = UnknownFailure('Buyurtma allaqachon bekor qilingan');
    expect(failure.isDiagnostic, isFalse);
    expect(failure.localize(ru), ru.errorUnknown);
  });

  for (final locale in [
    const Locale('uz'),
    const Locale('uz', 'Cyrl'),
    const Locale('ru'),
  ]) {
    test(
      'all failures use safe localized copy, never raw diagnostics ($locale)',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        const raw =
            '[debug] connectionTimeout RequestOptions.connectTimeout 00:00:08.000000 '
            'SocketException https://private.example/internal <html>traceback</html>';
        final cases = <ApiFailure, String>{
          const NetworkFailure(raw): l10n.errorNetwork,
          const NetworkFailure.timeout(raw): l10n.errorNetworkSlow,
          const ServerFailure(raw, 503): l10n.errorServer,
          const UnknownFailure(raw): l10n.errorUnknown,
          const UnknownFailure.malformed(raw): l10n.errorUnknown,
          const UnauthorizedFailure(raw): l10n.errorSessionExpired,
          const ForbiddenFailure(raw): l10n.errorForbidden,
          const NotFoundFailure(raw): l10n.errorNotFound,
          const ThrottledFailure(raw): l10n.errorThrottled,
          const AuthCodeFailure(raw, AuthErrorCode.otpInvalid):
              l10n.authErrorOtpInvalid,
          const AuthCodeFailure(raw, AuthErrorCode.unknown): l10n.errorUnknown,
          const ValidationFailure(raw, {
            'other': [raw],
          }): l10n.errorValidation,
          const ValidationFailure(raw, {
            'reason_code': ['cart_changed'],
          }): l10n.checkoutCartChanged,
          const CancelledFailure(raw): '',
        };
        for (final entry in cases.entries) {
          final text = entry.key.localize(l10n);
          expect(text, entry.value, reason: entry.key.runtimeType.toString());
          expect(
            text,
            isNot(
              matches(
                RegExp(
                  r'debug|RequestOptions|SocketException|connectionTimeout|https?://|<html>|traceback|server|сервер',
                  caseSensitive: false,
                ),
              ),
            ),
          );
          expect(
            entry.key.message,
            raw,
          ); // diagnostics are still available internally
        }
        expect(
          l10n.connectionServerUnavailable,
          isNot(matches(RegExp(r'server|сервер', caseSensitive: false))),
        );
      },
    );
  }
}
