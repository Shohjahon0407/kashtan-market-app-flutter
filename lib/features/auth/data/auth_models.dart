/// Auth wire modellari.
///
/// Parsing QAT'IY — eski appdagi 3-4 kalitli alias fallback'lar YO'Q.
/// Backend ikkita farqli shakl qaytaradi va bu farq ATAYLAB ikkita nomli
/// konstruktor bilan kodlangan:
///   - `verify-otp`: user `"user"` ichida, onboarding bayroqlari ILDIZDA
///   - `auth/me`  : user maydonlari ildizda TEKIS
library;

/// Backenddagi `UserRoleChoices`.
enum UserRole {
  customer('customer'),
  admin('admin'),
  manager('manager'),
  courier('courier'),
  unknown('');

  const UserRole(this.wire);

  final String wire;

  static UserRole fromWire(String? value) {
    for (final role in UserRole.values) {
      if (role.wire == value) return role;
    }
    return UserRole.unknown;
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.isPhoneVerified,
    required this.requiresOnboarding,
    required this.missingFields,
  });

  /// `verify-otp` konverti: `{..., "user": {...}, "requires_onboarding": ...}`.
  factory AuthUser.fromVerifyEnvelope(Map<String, dynamic> envelope) {
    final user = envelope['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('verify-otp javobida "user" obyekti yo‘q');
    }
    return AuthUser._fromParts(user, envelope);
  }

  /// `GET /auth/me/` konverti: user maydonlari ildizda tekis.
  factory AuthUser.fromMeFlat(Map<String, dynamic> json) =>
      AuthUser._fromParts(json, json);

  /// Lokal saqlangan JSON (o'zimiz yozgan shakl — `toJson`).
  factory AuthUser.fromStorage(Map<String, dynamic> json) =>
      AuthUser._fromParts(json, json);

  factory AuthUser._fromParts(
    Map<String, dynamic> user,
    Map<String, dynamic> flags,
  ) {
    final id = user['id'];
    final phone = user['phone_number'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('user.id yo‘q yoki bo‘sh');
    }
    if (phone is! String || phone.isEmpty) {
      throw const FormatException('user.phone_number yo‘q yoki bo‘sh');
    }
    return AuthUser(
      id: id,
      phoneNumber: phone,
      firstName: (user['first_name'] as String?) ?? '',
      lastName: (user['last_name'] as String?) ?? '',
      role: UserRole.fromWire(user['role'] as String?),
      isPhoneVerified: user['is_phone_verified'] == true,
      requiresOnboarding: flags['requires_onboarding'] == true,
      missingFields: switch (flags['missing_fields']) {
        final List<dynamic> list => List.unmodifiable(list.map((e) => '$e')),
        _ => const [],
      },
    );
  }

  final String id;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final UserRole role;
  final bool isPhoneVerified;

  /// Router BUNI ISHLATMAYDI (flow qarori: onboarding yo'q, login → home).
  /// Checkout bosqichida ism/manzil so'rashda kerak bo'ladi.
  final bool requiresOnboarding;

  /// `full_name` va/yoki `location`.
  final List<String> missingFields;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone_number': phoneNumber,
    'first_name': firstName,
    'last_name': lastName,
    'role': role.wire,
    'is_phone_verified': isPhoneVerified,
    'requires_onboarding': requiresOnboarding,
    'missing_fields': missingFields,
  };

  AuthUser copyWith({
    String? firstName,
    String? lastName,
    bool? requiresOnboarding,
    List<String>? missingFields,
  }) => AuthUser(
    id: id,
    phoneNumber: phoneNumber,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    role: role,
    isPhoneVerified: isPhoneVerified,
    requiresOnboarding: requiresOnboarding ?? this.requiresOnboarding,
    missingFields: missingFields ?? this.missingFields,
  );
}

/// `verify-otp` muvaffaqiyatli natijasi.
class VerifyOtpResult {
  const VerifyOtpResult({
    required this.access,
    required this.refresh,
    required this.user,
    required this.isNewUser,
  });

  factory VerifyOtpResult.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    final refresh = json['refresh'];
    if (access is! String || access.isEmpty) {
      throw const FormatException('verify-otp javobida "access" yo‘q');
    }
    if (refresh is! String || refresh.isEmpty) {
      throw const FormatException('verify-otp javobida "refresh" yo‘q');
    }
    return VerifyOtpResult(
      access: access,
      refresh: refresh,
      user: AuthUser.fromVerifyEnvelope(json),
      isNewUser: json['is_new_user'] == true,
    );
  }

  final String access;
  final String refresh;
  final AuthUser user;
  final bool isNewUser;
}

/// OTP siyosati — server javobida KELMAYDI (tekshirilgan), server
/// sozlamalari bilan mos ravishda client'da qat'iy belgilangan.
abstract final class OtpPolicy {
  /// `OTP_LENGTH=6`
  static const int codeLength = 6;

  /// `OTP_RESEND_COOLDOWN_SECONDS=60`
  static const Duration resendCooldown = Duration(seconds: 60);

  /// `OTP_EXPIRE_SECONDS=120`
  static const Duration codeLifetime = Duration(seconds: 120);
}
