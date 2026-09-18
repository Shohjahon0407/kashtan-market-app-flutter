import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/platform/sms_autofill_service.dart';
import '../../../core/storage/json_disk_cache.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'auth_state.dart';
import 'uzbek_phone.dart';

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Push device kabi authenticated resurslarni token o'chirilishidan oldin
/// deaktivatsiya qilish hook'i. Root container concrete implementatsiya beradi.
/// Chiqish jarayoni ketyaptimi — profil tugmasi o'chiq turadi va spinner
/// ko'rsatadi (AuthState'da ataylab copyWith yo'q, shuning uchun alohida).
final logoutBusyProvider = NotifierProvider<LogoutBusyController, bool>(
  LogoutBusyController.new,
);

class LogoutBusyController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final onBeforeLogoutProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// JWT saqlangandan keyin guest resurslarni userga bog‘lash hook'i.
final onAfterLoginProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// Auth holat mashinasi.
///
/// Navigatsiya QILMAYDI — router `authControllerProvider` ni kuzatib,
/// redirect orqali o'zi yo'naltiradi (faqat deklarativ navigatsiya).
class AuthController extends Notifier<AuthState> {
  static const String _kUserJson = 'auth.user_json';
  int _sessionRevision = 0;

  @override
  AuthState build() {
    // Eski appdagi xato takrorlanmaydi: build() ichida side-effect yo'q.
    // Sessiya tekshiruvi main.dart'dan `restoreSession()` bilan chaqiriladi.
    return const AuthState.unauthenticated();
  }

  TokenStore get _tokens => ref.read(tokenStoreProvider);
  AuthApi get _api => ref.read(authApiProvider);

  // ── Sessiya tiklash (boot) ─────────────────────────────────────────────────

  /// `runApp` dan keyin bir marta chaqiriladi.
  ///
  /// Siyosat (eski appning eng to'g'ri qarori): faqat 401 sessiyani o'chiradi.
  /// Tarmoq yo'qligi yoki 5xx — saqlangan sessiya bilan davom etamiz,
  /// foydalanuvchi ilovani offline ham ocha oladi.
  static const _checkingTimeout = Duration(seconds: 3);

  Future<void> restoreSession() async {
    final revision = ++_sessionRevision;
    // `main()` bu metodni runApp'dan oldin chaqiradi. Holatni birinchi awaitdan
    // OLDIN o'zgartirish router va startup intro guest Home'ga muddatidan oldin
    // o'tib ketmasligini kafolatlaydi.
    state = const AuthState.checking();
    final access = await _tokens.readAccess();
    final refresh = await _tokens.readRefresh();
    if (!ref.mounted || revision != _sessionRevision) return;
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }

    // Kesh qilingan user bilan darhol authenticated — UI kutmaydi.
    final cached = _loadCachedUser();
    state = cached != null
        ? AuthState.authenticated(cached)
        : const AuthState.checking();

    // Keshlangan user bo'lmasa ekran `checking` da qoladi — shuning uchun
    // TAYMAUT: 3 soniyadan keyin ilova baribir ochiladi (mehmon ko'rinishi),
    // `me()` esa fonda davom etadi. Ilgari bu joy sekin tarmoqda splash'da
    // 60 soniyagacha ushlab turardi.
    Timer? checkingTimer;
    if (cached == null) {
      checkingTimer = Timer(_checkingTimeout, () {
        if (ref.mounted &&
            revision == _sessionRevision &&
            state.isCheckingSession) {
          state = const AuthState.unauthenticated();
        }
      });
    }

    try {
      final user = await _api.me();
      checkingTimer?.cancel();
      if (!ref.mounted || revision != _sessionRevision) return;
      await _saveCachedUser(user);
      try {
        await ref.read(onAfterLoginProvider)();
      } on Object {
        // Guest savat merge yordamchi amal: secure storage yoki tarmoqdagi
        // noodatiy xato valid JWT sessiyasini bekor qilmasligi kerak.
        // Token saqlanadi va startup/resume/checkout oldidan qayta uriniladi.
      }
      if (!ref.mounted || revision != _sessionRevision) return;
      state = AuthState.authenticated(user);
    } on UnauthorizedFailure {
      if (!ref.mounted || revision != _sessionRevision) return;
      // Transient refresh endi NetworkFailure/ServerFailure sifatida keladi.
      // Bu branch faqat refresh token yoki yangilangan access aniq rad
      // etilganda ishlaydi.
      await _clearLocal();
      state = const AuthState.unauthenticated();
    } on ApiFailure {
      if (!ref.mounted || revision != _sessionRevision) return;
      // Offline / 5xx — sessiya saqlanadi.
      if (cached != null) {
        state = AuthState.authenticated(cached);
      } else {
        // Token bor lekin user keshi yo'q va server ham javob bermadi —
        // ehtiyotkor yo'l: sessiyani saqlab, keshsiz authenticated bo'lmaymiz.
        state = const AuthState.unauthenticated();
      }
    } finally {
      checkingTimer?.cancel();
    }
  }

  // ── OTP oqimi ──────────────────────────────────────────────────────────────

  /// 9 lokal raqam qabul qiladi, normallashtiradi va kod yuboradi.
  Future<void> sendCode(String localDigits) async {
    final normalized = UzbekPhone.normalize(localDigits);
    if (normalized == null) {
      // UI ham validatsiya qiladi; bu backstop. `phone_number` maydoni
      // failure_l10n da authErrorInvalidPhone ga map qilinadi.
      state = const AuthState.unauthenticated(
        failure: ValidationFailure('', {'phone_number': []}),
      );
      return;
    }
    await _sendTo(normalized);
  }

  /// OTP ekranidagi "qayta yuborish".
  Future<void> resendCode() async {
    final phone = state.phone;
    if (!UzbekPhone.isNormalized(phone)) {
      state = const AuthState.unauthenticated();
      return;
    }
    await _sendTo(phone!);
  }

  Future<void> _sendTo(String normalizedPhone) async {
    state = AuthState(
      status: AuthStatus.sendingCode,
      phone: normalizedPhone,
      // Oldingi codeSentAt saqlanadi: resend muvaffaqiyatsiz chiqsa
      // countdown noldan boshlanmasligi kerak (eski app xatosi).
      codeSentAt: state.phone == normalizedPhone ? state.codeSentAt : null,
    );
    try {
      final result = await _api.sendOtp(normalizedPhone);
      // Autofill rejimini SERVER aytadi: SMS'da Retriever hash'i bo'lsa
      // 0-tap, aks holda tizim oynasi. Ilovani yangilash shart emas.
      ref
          .read(smsAutofillModeProvider.notifier)
          .applyServerHint(serverAppendsHash: result.smsAppHash);
      state = AuthState(
        status: AuthStatus.codeSent,
        phone: normalizedPhone,
        codeSentAt: DateTime.now(),
      );
    } on ApiFailure catch (failure) {
      // Birinchi yuborishda telefon ekranida qolamiz; resend'da OTP
      // ekranida qolamiz — mavjud codeSentAt bo'yicha ajratamiz.
      final wasOnOtpScreen = state.codeSentAt != null;
      state = AuthState(
        status: wasOnOtpScreen
            ? AuthStatus.codeSent
            : AuthStatus.unauthenticated,
        phone: normalizedPhone,
        failure: failure,
        codeSentAt: state.codeSentAt,
      );
    }
  }

  Future<void> verifyCode(String code) async {
    _sessionRevision++;
    final phone = state.phone;
    if (!UzbekPhone.isNormalized(phone) ||
        code.length != OtpPolicy.codeLength) {
      return;
    }

    state = state.withStatus(AuthStatus.verifying);
    try {
      final result = await _api.verifyOtp(normalizedPhone: phone!, code: code);
      await _tokens.save(access: result.access, refresh: result.refresh);
      await _saveCachedUser(result.user);
      try {
        await ref.read(onAfterLoginProvider)();
      } on Object {
        // Auth muvaffaqiyatli. Guest token saqlanadi va checkout/startupda
        // merge coordinator qayta urinadi.
      }
      state = AuthState.authenticated(result.user);
    } on ApiFailure catch (failure) {
      state = state.withStatus(AuthStatus.codeSent, failure: failure);
    }
  }

  /// OTP ekranidan "raqamni o'zgartirish".
  void editPhone() {
    state = const AuthState.unauthenticated();
  }

  // ── Chiqish ────────────────────────────────────────────────────────────────

  bool _loggingOut = false;

  Future<void> logout() async {
    // Qayta bosishlar parallel logout ochmasin.
    if (_loggingOut) return;
    _loggingOut = true;
    ref.read(logoutBusyProvider.notifier).set(true);
    _sessionRevision++;
    try {
      // Push tokenini bekor qilish access token'ni talab qiladi — shuning
      // uchun lokal tozalashdan OLDIN, lekin vaqt chegarasi bilan: server
      // sekin bo'lsa foydalanuvchi 45 s "hech narsa bo'lmayapti" deb
      // o'tirmasin. Ikkalasi ham best-effort.
      await _bestEffort(ref.read(onBeforeLogoutProvider)());
      final refresh = await _tokens.readRefresh();
      await _bestEffort(_api.logout(refresh));
      await _clearLocal();
      state = const AuthState.unauthenticated();
    } finally {
      _loggingOut = false;
      if (ref.mounted) ref.read(logoutBusyProvider.notifier).set(false);
    }
  }

  /// Har bir tarmoq qadami uchun chegara; testda qisqartiriladi.
  @visibleForTesting
  static Duration logoutStepTimeout = const Duration(seconds: 5);

  static Future<void> _bestEffort(Future<void> future) async {
    try {
      await future.timeout(logoutStepTimeout);
    } on Object {
      // Chiqish baribir lokal tozalash bilan yakunlanadi.
    }
  }

  // ── Hisobni o'chirish ──────────────────────────────────────────────────────

  /// Hisobni o'chirishni tasdiqlash uchun SMS kod so'raydi.
  ///
  /// Server qorovullari (faol buyurtma, kuryer hisobi) shu bosqichda ishlaydi,
  /// shuning uchun xato ATAYLAB yutilmaydi — chaqiruvchi uni ko'rsatadi.
  Future<void> requestDeleteAccountCode() => _api.requestDeleteAccountOtp();

  /// Kodni tasdiqlab hisobni o'chiradi va lokal ma'lumotlarni to'liq tozalaydi.
  ///
  /// Server muvaffaqiyat qaytarmasa hech narsa tozalanmaydi — foydalanuvchi
  /// hisobida qoladi va qayta urinishi mumkin.
  Future<void> deleteAccount(String otpCode) async {
    await _api.deleteAccount(otpCode);
    _sessionRevision++;

    // Shu nuqtadan keyin hisob serverda o'chirilgan — lokal iz qolmasin.
    try {
      await ref.read(onBeforeLogoutProvider)();
    } on Object {
      // Push ro'yxatdan chiqishi bo'lmasa ham tozalash davom etadi.
    }
    await _clearLocal();
    await ref.read(guestCartTokenStoreProvider).clearGuestCartToken();
    await ref.read(prefsStoreProvider).clearSessionScoped();
    await ref.read(jsonDiskCacheProvider).clear();
    state = const AuthState.unauthenticated();
  }

  /// Murojaat yuborishda kontakt nomi bo'sh bo'lsa profilni yangilaydi.
  Future<AuthUser> updateName({
    required String firstName,
    required String lastName,
  }) async {
    final user = await _api.updateName(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
    await _saveCachedUser(user);
    state = AuthState.authenticated(user);
    return user;
  }

  /// Refresh ham o'lganda `AuthInterceptor` dan chaqiriladi.
  Future<void> expireSession() async {
    if (!state.isAuthenticated && !state.isCheckingSession) return;
    _sessionRevision++;
    await _clearLocal();
    state = const AuthState.unauthenticated();
  }

  // ── Lokal kesh ─────────────────────────────────────────────────────────────

  AuthUser? _loadCachedUser() {
    final raw = ref.read(prefsStoreProvider).getString(_kUserJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return AuthUser.fromStorage(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> _saveCachedUser(AuthUser user) => ref
      .read(prefsStoreProvider)
      .setString(_kUserJson, jsonEncode(user.toJson()));

  Future<void> _clearLocal() async {
    await _tokens.clear();
    await ref.read(prefsStoreProvider).remove(_kUserJson);
  }
}
