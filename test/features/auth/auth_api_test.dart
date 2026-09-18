import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth wire kontrakti — backend `api/user/auth/` bilan aynan moslik.
/// Kutilgan JSON'lar backend manba kodidan olingan (views.py, serializers.py).
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, String? body) handler;
  final List<({String method, String path, Map<String, dynamic>? body})>
  requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    String? bodyText;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodyText = utf8.decode(bytes);
    }
    requests.add((
      method: options.method,
      path: options.path,
      body: bodyText == null || bodyText.isEmpty
          ? null
          : jsonDecode(bodyText) as Map<String, dynamic>,
    ));
    return handler(options, bodyText);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const Map<String, dynamic> _verifyEnvelope = {
  'success': true,
  'access': 'access-jwt',
  'refresh': 'refresh-jwt',
  'client_type': 'customer',
  'is_new_user': true,
  'user': {
    'id': '6f3f0f2a-6c1e-4a5e-9c2b-1f0e5a7b3c11',
    'phone_number': '+998901234567',
    'first_name': '',
    'last_name': '',
    'role': 'customer',
    'is_phone_verified': true,
  },
  'is_courier': false,
  'courier': null,
  'requires_onboarding': true,
  'missing_fields': ['full_name', 'location'],
};

void main() {
  late _ScriptedAdapter adapter;

  AuthApi build(ResponseBody Function(RequestOptions, String?) handler) {
    adapter = _ScriptedAdapter(handler);
    final client = ApiClient.create(
      tokenStore: InMemoryTokenStore(access: 'tok', refresh: 'ref'),
      apiLang: () => 'uz',
      script: () => UzScript.none,
      refresh: (_) async => null,
      onSessionExpired: () async {},
      adapter: adapter,
    );
    return AuthApi(client);
  }

  group('sendOtp', () {
    test('aynan {phone_number, client_type: customer} yuboradi', () async {
      final api = build(
        (_, _) => _json({
          'success': true,
          'message': 'OTP yuborildi',
          'phone_number': '+998901234567',
          'client_type': 'customer',
        }, 200),
      );

      final result = await api.sendOtp('+998901234567');

      final req = adapter.requests.single;
      expect(req.method, 'POST');
      expect(req.path, '/auth/send-otp/');
      expect(req.body, {
        'phone_number': '+998901234567',
        'client_type': 'customer',
      });
      // Bayroq yo'q bo'lsa 1-tap (SMS User Consent) rejimida qolamiz.
      expect(result.smsAppHash, isFalse);
    });

    test('sms_app_hash bayrog\'i o\'qiladi (0-tap rejimi)', () async {
      final api = build(
        (_, _) => _json({
          'success': true,
          'message': 'OTP yuborildi',
          'phone_number': '+998901234567',
          'client_type': 'customer',
          'sms_app_hash': true,
        }, 200),
      );

      final result = await api.sendOtp('+998901234567');

      expect(result.smsAppHash, isTrue);
    });

    test('otp_cooldown 429 → AuthCodeFailure', () async {
      final api = build(
        (_, _) => _json({
          'success': false,
          'message': "Yangi kod so'rashdan oldin biroz kuting.",
          'code': 'otp_cooldown',
        }, 429),
      );
      await expectLater(
        api.sendOtp('+998901234567'),
        throwsA(
          isA<AuthCodeFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.otpCooldown,
          ),
        ),
      );
    });

    test('DRF per-IP throttle (boshqa shakl!) → ThrottledFailure', () async {
      final api = build(
        (_, _) => _json({
          'detail': 'Request was throttled. Expected available in 42 seconds.',
        }, 429),
      );
      await expectLater(
        api.sendOtp('+998901234567'),
        throwsA(
          isA<ThrottledFailure>(), // Retry-After header yo'q, matn detail'da
        ),
      );
    });

    test('sms_failed 502 → AuthCodeFailure(smsFailed)', () async {
      final api = build(
        (_, _) => _json({
          'success': false,
          'message': "SMS yuborib bo'lmadi. Birozdan keyin urinib ko'ring.",
          'code': 'sms_failed',
        }, 502),
      );
      await expectLater(
        api.sendOtp('+998901234567'),
        throwsA(
          isA<AuthCodeFailure>().having(
            (f) => f.code,
            'code',
            AuthErrorCode.smsFailed,
          ),
        ),
      );
    });
  });

  group('verifyOtp', () {
    test(
      'so‘rov shakli va konvert parsing (user nested, bayroqlar ildizda)',
      () async {
        final api = build((_, _) => _json(_verifyEnvelope, 200));

        final result = await api.verifyOtp(
          normalizedPhone: '+998901234567',
          code: '482913',
        );

        final req = adapter.requests.single;
        expect(req.path, '/auth/verify-otp/');
        expect(req.body, {
          'phone_number': '+998901234567',
          'otp_code': '482913',
          'client_type': 'customer',
        });

        expect(result.access, 'access-jwt');
        expect(result.refresh, 'refresh-jwt');
        expect(result.isNewUser, isTrue);
        expect(result.user.id, '6f3f0f2a-6c1e-4a5e-9c2b-1f0e5a7b3c11');
        expect(result.user.phoneNumber, '+998901234567');
        expect(result.user.role, UserRole.customer);
        // Ildizdagi bayroqlar user'ga ko'chirilgan
        expect(result.user.requiresOnboarding, isTrue);
        expect(result.user.missingFields, ['full_name', 'location']);
      },
    );

    test('otp_invalid / otp_expired / otp_attempts_exhausted', () async {
      for (final (code, expected) in [
        ('otp_invalid', AuthErrorCode.otpInvalid),
        ('otp_expired', AuthErrorCode.otpExpired),
        ('otp_attempts_exhausted', AuthErrorCode.otpAttemptsExhausted),
      ]) {
        final api = build(
          (_, _) =>
              _json({'success': false, 'message': 'xato', 'code': code}, 400),
        );
        await expectLater(
          api.verifyOtp(normalizedPhone: '+998901234567', code: '000000'),
          throwsA(
            isA<AuthCodeFailure>().having((f) => f.code, 'code', expected),
          ),
          reason: code,
        );
      }
    });

    test(
      'access yo‘q javob FormatException bilan yiqiladi (jim emas)',
      () async {
        final api = build((_, _) => _json({'success': true}, 200));
        await expectLater(
          api.verifyOtp(normalizedPhone: '+998901234567', code: '482913'),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('me', () {
    test('TEKIS shaklni o‘qiydi (verify’dagi nested emas)', () async {
      final api = build(
        (_, _) => _json({
          'id': 'u-1',
          'phone_number': '+998901234567',
          'first_name': 'Ali',
          'last_name': 'Valiyev',
          'role': 'customer',
          'is_phone_verified': true,
          'client_type': 'customer',
          'is_courier': false,
          'courier': null,
          'requires_onboarding': false,
          'missing_fields': <String>[],
        }, 200),
      );

      final user = await api.me();
      expect(adapter.requests.single.path, '/auth/me/');
      expect(adapter.requests.single.method, 'GET');
      expect(user.fullName, 'Ali Valiyev');
      expect(user.requiresOnboarding, isFalse);
    });
  });

  group('logout', () {
    test('refresh bilan POST qiladi va xatoni yutadi', () async {
      final api = build((_, _) => _json({'detail': 'x'}, 401));
      // 401 bo'lsa ham tashlamasligi kerak
      await api.logout('refresh-jwt');
      expect(adapter.requests.single.body, {'refresh': 'refresh-jwt'});
    });

    test('refresh yo‘q bo‘lsa bo‘sh body', () async {
      final api = build(
        (_, _) => _json({'success': true, 'message': 'Tizimdan chiqildi'}, 200),
      );
      await api.logout(null);
      expect(adapter.requests.single.body, isEmpty); // bo'sh JSON obyekt {}
    });
  });
}
