import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends Mock implements AuthApi {}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: 'Ali',
  lastName: '',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: true,
  missingFields: ['full_name', 'location'],
);

const _verifyResult = VerifyOtpResult(
  access: 'acc',
  refresh: 'ref',
  user: _user,
  isNewUser: true,
);

void main() {
  late _MockAuthApi api;
  late InMemoryTokenStore tokens;
  late ProviderContainer container;

  Future<void> setUpContainer({String? access, String? refresh}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    api = _MockAuthApi();
    tokens = InMemoryTokenStore(access: access, refresh: refresh);
    container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
  }

  AuthController notifier() => container.read(authControllerProvider.notifier);
  AuthState state() => container.read(authControllerProvider);

  test(
    'a late session restore cannot sign the user back in after logout',
    () async {
      await setUpContainer(access: 'old-access', refresh: 'old-refresh');
      final pending = Completer<AuthUser>();
      final requested = Completer<void>();
      when(() => api.me()).thenAnswer((_) {
        requested.complete();
        return pending.future;
      });
      when(() => api.logout(any())).thenAnswer((_) async {});
      final restoring = notifier().restoreSession();
      await requested.future;
      await notifier().logout();
      pending.complete(_user);
      await restoring;
      expect(state().isAuthenticated, isFalse);
      expect(await tokens.readAccess(), isNull);
    },
  );

  group('sendCode', () {
    test('muvaffaqiyat: codeSent + codeSentAt o‘rnatiladi', () async {
      await setUpContainer();
      when(() => api.sendOtp(any())).thenAnswer((_) async {});

      await notifier().sendCode('901234567');

      expect(state().status, AuthStatus.codeSent);
      expect(state().phone, '+998901234567');
      expect(state().codeSentAt, isNotNull);
      verify(() => api.sendOtp('+998901234567')).called(1);
    });

    test('yaroqsiz raqam: so‘rov KETMAYDI, failure phone_number', () async {
      await setUpContainer();
      await notifier().sendCode('123456789'); // 12 — operator emas

      expect(state().status, AuthStatus.unauthenticated);
      expect(state().failure, isA<ValidationFailure>());
      verifyNever(() => api.sendOtp(any()));
    });

    test(
      'birinchi yuborish xatosi: unauthenticated + failure, codeSentAt yo‘q',
      () async {
        await setUpContainer();
        when(
          () => api.sendOtp(any()),
        ).thenThrow(const AuthCodeFailure('sms xato', AuthErrorCode.smsFailed));

        await notifier().sendCode('901234567');

        expect(state().status, AuthStatus.unauthenticated);
        expect(state().codeSentAt, isNull, reason: 'cooldown boshlanmasin');
        expect(
          (state().failure as AuthCodeFailure?)?.code,
          AuthErrorCode.smsFailed,
        );
      },
    );
  });

  group('resendCode', () {
    test('muvaffaqiyatsiz resend eski codeSentAt ni SAQLAYDI', () async {
      await setUpContainer();
      when(() => api.sendOtp(any())).thenAnswer((_) async {});
      await notifier().sendCode('901234567');
      final firstSentAt = state().codeSentAt;

      when(
        () => api.sendOtp(any()),
      ).thenThrow(const AuthCodeFailure('kuting', AuthErrorCode.otpCooldown));
      await notifier().resendCode();

      // OTP ekranida qolamiz, eski cooldown yo'qolmaydi (eski app bugi)
      expect(state().status, AuthStatus.codeSent);
      expect(state().codeSentAt, firstSentAt);
      expect(
        (state().failure as AuthCodeFailure?)?.code,
        AuthErrorCode.otpCooldown,
      );
    });
  });

  group('verifyCode', () {
    Future<void> reachCodeSent() async {
      when(() => api.sendOtp(any())).thenAnswer((_) async {});
      await notifier().sendCode('901234567');
    }

    test('muvaffaqiyat: tokenlar saqlanadi, authenticated', () async {
      await setUpContainer();
      await reachCodeSent();
      when(
        () => api.verifyOtp(
          normalizedPhone: any(named: 'normalizedPhone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => _verifyResult);

      await notifier().verifyCode('482913');

      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.id, 'u-1');
      expect(await tokens.readAccess(), 'acc');
      expect(await tokens.readRefresh(), 'ref');
    });

    test('noto‘g‘ri kod: codeSent ga qaytadi, failure bilan', () async {
      await setUpContainer();
      await reachCodeSent();
      when(
        () => api.verifyOtp(
          normalizedPhone: any(named: 'normalizedPhone'),
          code: any(named: 'code'),
        ),
      ).thenThrow(const AuthCodeFailure('xato', AuthErrorCode.otpInvalid));

      await notifier().verifyCode('000000');

      expect(state().status, AuthStatus.codeSent);
      expect(
        (state().failure as AuthCodeFailure?)?.code,
        AuthErrorCode.otpInvalid,
      );
      expect(await tokens.readAccess(), isNull);
    });

    test('6 xonadan boshqa uzunlik: so‘rov ketmaydi', () async {
      await setUpContainer();
      await reachCodeSent();

      await notifier().verifyCode('12345');

      verifyNever(
        () => api.verifyOtp(
          normalizedPhone: any(named: 'normalizedPhone'),
          code: any(named: 'code'),
        ),
      );
    });
  });

  group('restoreSession', () {
    test('birinchi awaitdan oldin checkingSession bo‘ladi', () async {
      await setUpContainer();
      final restore = notifier().restoreSession();

      expect(state().status, AuthStatus.checkingSession);

      await restore;
      expect(state().status, AuthStatus.unauthenticated);
    });

    test('token yo‘q → unauthenticated, me() chaqirilmaydi', () async {
      await setUpContainer();
      await notifier().restoreSession();
      expect(state().status, AuthStatus.unauthenticated);
      verifyNever(() => api.me());
    });

    test('token bor, me() OK → authenticated', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenAnswer((_) async => _user);

      await notifier().restoreSession();

      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.phoneNumber, '+998901234567');
    });

    test('401 → sessiya o‘chadi', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenThrow(const UnauthorizedFailure());

      await notifier().restoreSession();

      expect(state().status, AuthStatus.unauthenticated);
      expect(await tokens.readAccess(), isNull);
    });

    test(
      'refresh transient 401 cached sessiya va tokenlarni saqlaydi',
      () async {
        await setUpContainer(access: 'a', refresh: 'r');
        when(() => api.me()).thenAnswer((_) async => _user);
        await notifier().restoreSession();

        // AuthInterceptor transient refreshni original 401 emas, server yoki
        // network failure sifatida uzatadi.
        when(() => api.me()).thenThrow(const ServerFailure('vaqtincha', 503));
        await notifier().restoreSession();

        expect(state().status, AuthStatus.authenticated);
        expect(state().user?.id, _user.id);
        expect(await tokens.readAccess(), 'a');
        expect(await tokens.readRefresh(), 'r');
      },
    );

    test(
      'tarmoq xatosi + user keshi bor → sessiya SAQLANADI (offline)',
      () async {
        await setUpContainer(access: 'a', refresh: 'r');
        // Birinchi kirishda keshni yozamiz
        when(() => api.me()).thenAnswer((_) async => _user);
        await notifier().restoreSession();

        // Endi offline stsenariy: yangi container xuddi shu prefs bilan emas —
        // shu container'da qayta chaqiramiz
        when(() => api.me()).thenThrow(const NetworkFailure());
        await notifier().restoreSession();

        expect(state().status, AuthStatus.authenticated);
        expect(await tokens.readAccess(), 'a');
      },
    );
  });

  group("hisobni o'chirish", () {
    test('muvaffaqiyat: tokenlar va mehmon savat tokeni tozalanadi', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenAnswer((_) async => _user);
      await notifier().restoreSession();
      await tokens.saveGuestCartToken('guest-1');
      when(() => api.deleteAccount('123456')).thenAnswer((_) async {});

      await notifier().deleteAccount('123456');

      expect(state().status, AuthStatus.unauthenticated);
      expect(await tokens.readAccess(), isNull);
      expect(await tokens.readRefresh(), isNull);
      // logout() mehmon savat tokenini qoldiradi — o'chirishda esa qolmasligi kerak.
      expect(await tokens.readGuestCartToken(), isNull);
      verify(() => api.deleteAccount('123456')).called(1);
    });

    test('xato: hisob o\'chmaydi, foydalanuvchi tizimda qoladi', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenAnswer((_) async => _user);
      await notifier().restoreSession();
      when(
        () => api.deleteAccount('000000'),
      ).thenThrow(const ValidationFailure('Kod xato', {}));

      await expectLater(
        notifier().deleteAccount('000000'),
        throwsA(isA<ValidationFailure>()),
      );

      expect(state().status, AuthStatus.authenticated);
      expect(await tokens.readAccess(), 'a');
    });

    test('kod so\'rash xatosi yuqoriga uzatiladi', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenAnswer((_) async => _user);
      await notifier().restoreSession();
      when(() => api.requestDeleteAccountOtp()).thenThrow(
        const ValidationFailure('Sizda yakunlanmagan buyurtma bor', {}),
      );

      // `requestDeleteAccountCode` future qaytaradi, lekin mock sinxron
      // tashlaydi — shuning uchun funksiya ko'rinishida tekshiramiz.
      await expectLater(
        () => notifier().requestDeleteAccountCode(),
        throwsA(isA<ValidationFailure>()),
      );
      expect(state().status, AuthStatus.authenticated);
    });
  });

  group('logout / expireSession', () {
    test('logout: API chaqiriladi, lokal tozalanadi', () async {
      await setUpContainer(access: 'a', refresh: 'r');
      when(() => api.me()).thenAnswer((_) async => _user);
      await notifier().restoreSession();
      when(() => api.logout(any())).thenAnswer((_) async {});

      await notifier().logout();

      expect(state().status, AuthStatus.unauthenticated);
      expect(await tokens.readAccess(), isNull);
      verify(() => api.logout('r')).called(1);
    });

    test('expireSession faqat authenticated holatda ishlaydi', () async {
      await setUpContainer();
      when(() => api.sendOtp(any())).thenAnswer((_) async {});
      await notifier().sendCode('901234567');

      // OTP kiritish paytida tasodifiy 401 sessiyani buzmasligi kerak
      await notifier().expireSession();
      expect(state().status, AuthStatus.codeSent);
    });
  });
}
