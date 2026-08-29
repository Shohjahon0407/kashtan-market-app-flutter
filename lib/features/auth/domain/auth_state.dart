import '../../../core/network/api_failure.dart';
import '../data/auth_models.dart';

/// Auth holat mashinasi statuslari.
///
/// Eski appdan farq: `error` alohida status EMAS — xato [AuthState.failure]
/// maydonida yashaydi, status esa amalga mos joyga qaytadi
/// (`unauthenticated` yoki `codeSent`). Bu "error holatidan qanday
/// chiqamiz" degan noaniqliklarni yo'q qiladi.
enum AuthStatus {
  /// Saqlangan sessiya `GET /auth/me/` bilan tekshirilmoqda.
  checkingSession,

  /// Kirilmagan — telefon ekrani.
  unauthenticated,

  /// `send-otp` so'rovi ketmoqda.
  sendingCode,

  /// Kod yuborildi — OTP ekrani.
  codeSent,

  /// `verify-otp` so'rovi ketmoqda.
  verifying,

  /// Sessiya faol.
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.phone,
    this.user,
    this.failure,
    this.codeSentAt,
  });

  const AuthState.unauthenticated({this.failure})
    : status = AuthStatus.unauthenticated,
      phone = null,
      user = null,
      codeSentAt = null;

  const AuthState.checking()
    : status = AuthStatus.checkingSession,
      phone = null,
      user = null,
      failure = null,
      codeSentAt = null;

  const AuthState.authenticated(AuthUser this.user)
    : status = AuthStatus.authenticated,
      phone = null,
      failure = null,
      codeSentAt = null;

  final AuthStatus status;

  /// Normallashgan `+998XXXXXXXXX` — telefon ekranidan OTP ekraniga
  /// FAQAT shu orqali o'tadi (route param emas).
  final String? phone;

  final AuthUser? user;

  /// Oxirgi amaldagi xato. UI `failure_l10n` orqali ko'rsatadi.
  /// Foydalanuvchi yozishni boshlaganda UI o'zi yashiradi.
  final ApiFailure? failure;

  /// Kod muvaffaqiyatli yuborilgan PAYT (wall-clock).
  /// Resend countdown va 120s amal qilish indikatori shundan hisoblanadi.
  /// MUHIM: muvaffaqiyatsiz yuborishda YANGILANMAYDI (eski app xatosi).
  final DateTime? codeSentAt;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isCheckingSession => status == AuthStatus.checkingSession;
  bool get isSendingCode => status == AuthStatus.sendingCode;
  bool get isVerifying => status == AuthStatus.verifying;
  bool get isBusy => isSendingCode || isVerifying;

  /// copyWith ATAYLAB yo'q.
  ///
  /// Eski appda `copyWith` ikki xil semantikaga ega edi (failure har safar
  /// o'chirilar, phone esa hech qachon tozalab bo'lmas edi) va bu bug'lar
  /// manbai bo'lgan. Har o'tish uchun aniq nomli konstruktor/metod ishlatiladi.
  AuthState withStatus(
    AuthStatus next, {
    ApiFailure? failure,
    DateTime? codeSentAt,
  }) => AuthState(
    status: next,
    phone: phone,
    user: user,
    failure: failure,
    codeSentAt: codeSentAt ?? this.codeSentAt,
  );
}
