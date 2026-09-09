import 'package:flutter/foundation.dart' show kDebugMode;

import '../../generated/l10n/app_localizations.dart';
import '../network/api_failure.dart';

/// [ApiFailure] → foydalanuvchiga ko'rsatiladigan matn.
///
/// Server xatolari FAQAT o'zbek lotinida keladi — rus va kirill
/// foydalanuvchilari uchun har bir ma'lum xato o'z ARB kalitiga map qilinadi.
/// Faqat nomalum holatda server matni fallback bo'ladi (kirill
/// foydalanuvchisi uchun uni javob transformatori allaqachon o'girgan).
extension ApiFailureL10n on ApiFailure {
  /// Foydalanuvchiga ko'rsatiladigan matn.
  ///
  /// Debug build'da oxiriga texnik sabab qo'shiladi — qurilmada
  /// diagnostika qilishni ancha osonlashtiradi. Release'da faqat
  /// tarjima qilingan matn chiqadi.
  String localize(AppLocalizations l10n) {
    final text = _localize(l10n);
    if (!kDebugMode || message.isEmpty || message == text) return text;
    return '$text\n[debug] $message';
  }

  String _localize(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    CancelledFailure() => '',
    UnauthorizedFailure() => l10n.errorSessionExpired,
    ForbiddenFailure() => l10n.errorForbidden,
    NotFoundFailure() => l10n.errorNotFound,
    ServerFailure() => l10n.errorServer,
    ThrottledFailure(:final retryAfter) =>
      retryAfter == null
          ? l10n.errorThrottled
          : l10n.errorThrottledSeconds(retryAfter.inSeconds),
    AuthCodeFailure(:final code) => switch (code) {
      AuthErrorCode.otpCooldown => l10n.authErrorOtpCooldown,
      AuthErrorCode.otpHourLimit => l10n.authErrorOtpHourLimit,
      AuthErrorCode.otpInvalid => l10n.authErrorOtpInvalid,
      AuthErrorCode.otpExpired => l10n.authErrorOtpExpired,
      AuthErrorCode.otpAttemptsExhausted => l10n.authErrorOtpAttempts,
      AuthErrorCode.smsFailed => l10n.authErrorSmsFailed,
      AuthErrorCode.invalidRefresh => l10n.errorSessionExpired,
      AuthErrorCode.notCourier => _fallback(l10n),
      AuthErrorCode.unknown => _fallback(l10n),
    },
    ValidationFailure(:final fields) => _localizeValidation(l10n, fields),
    UnknownFailure(:final isDiagnostic) =>
      isDiagnostic ? l10n.errorUnknown : _fallback(l10n),
  };

  String _localizeValidation(
    AppLocalizations l10n,
    Map<String, List<String>> fields,
  ) {
    // Ma'lum maydonlar o'z l10n matniga ega; qolganlari server matni bilan.
    if (fields.containsKey('phone_number')) return l10n.authErrorInvalidPhone;
    if (fields.containsKey('otp_code')) return l10n.authErrorOtpInvalid;
    return _fallback(l10n);
  }

  String _fallback(AppLocalizations l10n) =>
      message.isNotEmpty ? message : l10n.errorUnknown;
}
