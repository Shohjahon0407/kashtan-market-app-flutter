import '../../generated/l10n/app_localizations.dart';
import '../network/api_failure.dart';

/// [ApiFailure] → foydalanuvchiga ko'rsatiladigan matn.
///
/// Texnik sabablar va xom javoblar hech qaysi build'da customer UI'ga
/// chiqarilmaydi. Ular [ApiFailure.message] va diagnostika loglarida qoladi.
/// Ma'lum sabablar tarjima qilinadi, noma'lumlari xavfsiz umumiy matn oladi.
extension ApiFailureL10n on ApiFailure {
  /// Foydalanuvchiga ko'rsatiladigan matn.
  ///
  /// Debug hamda release'da bir xil, faqat foydalanuvchi uchun matn.
  String localize(AppLocalizations l10n) => _localize(l10n);

  String _localize(AppLocalizations l10n) => switch (this) {
    NetworkFailure(isTimeout: true) => l10n.errorNetworkSlow,
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
    // Ma'lum sabablar tarjima qilinadi, qolganlari xavfsiz umumiy matn oladi.
    if (fields.containsKey('phone_number')) return l10n.authErrorInvalidPhone;
    if (fields.containsKey('otp_code')) return l10n.authErrorOtpInvalid;
    final codes = fields['reason_code'] ?? const <String>[];
    return switch (codes.isEmpty ? '' : codes.first) {
      'store_unavailable' || 'product_unavailable' => l10n.cartUnavailable,
      'variant_unavailable' ||
      'variant_required' => l10n.cartVariantUnavailable,
      'addons_unavailable' => l10n.cartAddonsUnavailable,
      'cart_changed' => l10n.checkoutCartChanged,
      'cart_empty' => l10n.checkoutAddProducts,
      'invalid_address' => l10n.checkoutSelectAddress,
      'order_cannot_cancel' => l10n.orderCancellationUnavailable,
      'payme_unavailable' => l10n.paymeUnavailable,
      _ => l10n.errorValidation,
    };
  }

  String _fallback(AppLocalizations l10n) => l10n.errorUnknown;
}
