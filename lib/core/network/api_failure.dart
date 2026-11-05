/// Ilova ichida yuradigan yagona xato turi.
///
/// Dio `DioException` lari [ApiFailure] ga `ErrorInterceptor` da aylantiriladi,
/// shundan keyin repository va provider'lar Dio haqida umuman bilmaydi.
library;

/// `/auth/*` endpointlari qaytaradigan mashina o'qiy oladigan kodlar.
///
/// Backend auth uchun DRF standartidan farqli konvert ishlatadi:
/// `{"success": false, "message": "...", "code": "otp_cooldown"}`.
enum AuthErrorCode {
  /// 60 soniyalik qayta yuborish kutuvi tugamagan.
  otpCooldown('otp_cooldown'),

  /// Soatiga 5 marta cheklovi tugagan.
  otpHourLimit('otp_hour_limit'),

  /// Kod noto'g'ri.
  otpInvalid('otp_invalid'),

  /// Kodning 120 soniyalik muddati o'tgan.
  otpExpired('otp_expired'),

  /// 5 marta noto'g'ri kiritilgan.
  otpAttemptsExhausted('otp_attempts_exhausted'),

  /// SMS provayderi (Eskiz) xato qaytardi.
  smsFailed('sms_failed'),

  /// Bu raqam kuryer sifatida ro'yxatdan o'tmagan (kuryer ilovasi uchun).
  notCourier('not_courier'),

  /// Refresh token yaroqsiz yoki muddati o'tgan.
  invalidRefresh('invalid_refresh'),

  unknown('');

  const AuthErrorCode(this.wire);

  final String wire;

  static AuthErrorCode fromWire(String? value) {
    if (value == null || value.isEmpty) return AuthErrorCode.unknown;
    for (final code in AuthErrorCode.values) {
      if (code.wire == value) return code;
    }
    return AuthErrorCode.unknown;
  }
}

/// Barcha tarmoq xatolarining ildizi.
///
/// [message] — serverdan kelgan XOM matn (o'zbek lotinida). UI uni to'g'ridan
/// to'g'ri ko'rsatmasligi kerak: avval `ApiFailure.localize()` orqali o'z
/// l10n matnimizga urinib ko'riladi, faqat topilmasa shu matn fallback bo'ladi.
sealed class ApiFailure implements Exception {
  const ApiFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Internet yo'q, taymaut yoki DNS xatosi. Qayta urinish mantiqli.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure([super.message = '']) : isTimeout = false;
  const NetworkFailure.timeout([super.message = '']) : isTimeout = true;

  final bool isTimeout;
}

/// 400 — maydonlarga bog'langan validatsiya xatosi.
final class ValidationFailure extends ApiFailure {
  const ValidationFailure(super.message, this.fields);

  /// `{"address_id": ["Lokatsiya tanlanmagan"]}` ko'rinishida.
  final Map<String, List<String>> fields;

  /// Berilgan maydon uchun birinchi xabar.
  String? forField(String name) {
    final list = fields[name];
    return (list == null || list.isEmpty) ? null : list.first;
  }
}

/// `/auth/*` ning maxsus konverti.
final class AuthCodeFailure extends ApiFailure {
  const AuthCodeFailure(super.message, this.code);

  final AuthErrorCode code;
}

/// 401 — token yo'q yoki refresh ham ishlamadi. Sessiya tugaydi.
final class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure([super.message = '']);
}

/// 403.
final class ForbiddenFailure extends ApiFailure {
  const ForbiddenFailure([super.message = '']);
}

/// 404.
final class NotFoundFailure extends ApiFailure {
  const NotFoundFailure([super.message = '']);
}

/// 429 — throttle (`otp_send` 5/min, `product_search` 60/min).
final class ThrottledFailure extends ApiFailure {
  const ThrottledFailure(super.message, {this.retryAfter});

  final Duration? retryAfter;
}

/// 5xx.
final class ServerFailure extends ApiFailure {
  const ServerFailure(super.message, this.statusCode);

  final int statusCode;
}

/// Boshqa hech qaysi turga tushmagan holat.
final class UnknownFailure extends ApiFailure {
  const UnknownFailure([super.message = '']) : isDiagnostic = false;

  /// Ilova kutgan javob shakli kelmadi (dekod xatosi). Matn dasturchi uchun —
  /// foydalanuvchiga faqat umumiy xato ko'rsatiladi, debug build'da ham.
  const UnknownFailure.malformed(super.message) : isDiagnostic = true;

  final bool isDiagnostic;
}

/// So'rov bekor qilindi (masalan qidiruv matni o'zgardi).
/// UI buni xato sifatida ko'rsatmasligi kerak.
final class CancelledFailure extends ApiFailure {
  const CancelledFailure([super.message = '']);
}
