import '../../../core/config/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import 'auth_models.dart';

/// Auth endpointlari — 1 metod = 1 endpoint, ichida shart yo'q.
///
/// Barcha metodlar [ApiFailure] tashlaydi (ApiClient kafolati).
/// `client_type: customer` MAJBURIY yuboriladi — busiz backend header'dan
/// taxmin qiladi.
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  static const String _clientType = 'customer';

  /// SMS kod yuborish. Muvaffaqiyat — hech qanday qiymat qaytarmaydi:
  /// javobda faqat `{success, message, phone_number, client_type}` bor,
  /// `otp_length`/`resend_after_seconds` YO'Q (client [OtpPolicy] ishlatadi).
  Future<void> sendOtp(String normalizedPhone) async {
    await _client.post(
      Api.sendOtp,
      body: {'phone_number': normalizedPhone, 'client_type': _clientType},
    );
  }

  /// Kodni tekshirish. Yangi foydalanuvchini backend o'zi yaratadi.
  Future<VerifyOtpResult> verifyOtp({
    required String normalizedPhone,
    required String code,
  }) async {
    final data = await _client.post(
      Api.verifyOtp,
      body: {
        'phone_number': normalizedPhone,
        'otp_code': code,
        'client_type': _clientType,
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('verify-otp javobi obyekt emas');
    }
    return VerifyOtpResult.fromJson(data);
  }

  /// Joriy foydalanuvchi (auth shakli — TEKIS, verify'dagi nested emas).
  Future<AuthUser> me() async {
    final data = await _client.get(Api.authMe);
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('auth/me javobi obyekt emas');
    }
    return AuthUser.fromMeFlat(data);
  }

  Future<AuthUser> updateName({
    required String firstName,
    required String lastName,
  }) async {
    final data = await _client.patch(
      Api.profile,
      body: {'first_name': firstName, 'last_name': lastName},
    );
    if (data is! Map<String, dynamic>) {
      throw const UnknownFailure.malformed('profile javobi obyekt emas');
    }
    return AuthUser.fromMeFlat(data);
  }

  /// Hisobni o'chirishni tasdiqlash uchun SMS kod so'raydi.
  /// Server qorovullari (faol buyurtma, kuryer hisobi) shu yerda ishlaydi.
  Future<void> requestDeleteAccountOtp() async {
    await _client.post(Api.deleteAccountRequestOtp);
  }

  /// Kodni tasdiqlab hisobni butunlay yopadi. Xato bo'lsa ApiFailure —
  /// logoutdan farqli: bu yerda xato YUTILMAYDI, hisob o'chmagan bo'lishi mumkin.
  Future<void> deleteAccount(String otpCode) async {
    await _client.post(Api.deleteAccount, body: {'otp_code': otpCode});
  }

  /// Refresh tokenni blacklist'ga qo'shadi. Xato tashlamaydi —
  /// logout har doim lokal darajada muvaffaqiyatli yakunlanishi kerak.
  Future<void> logout(String? refreshToken) async {
    try {
      await _client.post(
        Api.logout,
        body: refreshToken == null || refreshToken.isEmpty
            ? const <String, dynamic>{}
            : {'refresh': refreshToken},
      );
    } on ApiFailure {
      // Server sessiyani bekor qila olmasa ham lokal chiqish davom etadi.
    }
  }
}
