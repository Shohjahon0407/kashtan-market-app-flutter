import 'dart:async';

import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/interceptors/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _err({
  int? status,
  Object? body,
  DioExceptionType type = DioExceptionType.badResponse,
  Map<String, List<String>> headers = const {},
  Object? cause,
}) {
  final options = RequestOptions(path: '/x/');
  return DioException(
    requestOptions: options,
    type: type,
    error: cause,
    response: status == null
        ? null
        : Response<dynamic>(
            requestOptions: options,
            statusCode: status,
            data: body,
            headers: Headers.fromMap(headers),
          ),
  );
}

void main() {
  group('transport xatolari', () {
    test('taymautlar NetworkFailure', () {
      for (final t in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
      ]) {
        expect(
          ErrorInterceptor.mapToFailure(_err(type: t)),
          isA<NetworkFailure>(),
          reason: t.name,
        );
      }
    });

    test('bekor qilish CancelledFailure — UI da xato ko‘rsatilmaydi', () {
      expect(
        ErrorInterceptor.mapToFailure(_err(type: DioExceptionType.cancel)),
        isA<CancelledFailure>(),
      );
    });

    test(
      'timeout is distinct from disconnection without parsing raw strings',
      () {
        for (final type in [
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        ]) {
          final failure =
              ErrorInterceptor.mapToFailure(_err(type: type)) as NetworkFailure;
          expect(failure.isTimeout, isTrue);
          expect(failure.message, contains(type.name));
        }
        final disconnected =
            ErrorInterceptor.mapToFailure(
                  _err(type: DioExceptionType.connectionError),
                )
                as NetworkFailure;
        expect(disconnected.isTimeout, isFalse);
        final timeout =
            ErrorInterceptor.mapToFailure(
                  _err(
                    type: DioExceptionType.unknown,
                    cause: TimeoutException('private diagnostic'),
                  ),
                )
                as NetworkFailure;
        expect(timeout.isTimeout, isTrue);
        const propagated = NetworkFailure.timeout('retained diagnostic');
        expect(
          ErrorInterceptor.mapToFailure(
            _err(type: DioExceptionType.unknown, cause: propagated),
          ),
          same(propagated),
        );
      },
    );
  });

  group('auth konverti status tekshiruvidan OLDIN keladi', () {
    test('otp_cooldown 429 emas, AuthCodeFailure sifatida keladi', () {
      final f = ErrorInterceptor.mapToFailure(
        _err(
          status: 429,
          body: {
            'success': false,
            'message': 'Iltimos, 60 soniyadan keyin urinib ko‘ring',
            'code': 'otp_cooldown',
          },
        ),
      );
      expect(f, isA<AuthCodeFailure>());
      expect((f as AuthCodeFailure).code, AuthErrorCode.otpCooldown);
      expect(f.message, contains('60'));
    });

    test('400 dagi otp_invalid ham AuthCodeFailure', () {
      final f = ErrorInterceptor.mapToFailure(
        _err(
          status: 400,
          body: {
            'success': false,
            'message': 'OTP kodi noto‘g‘ri',
            'code': 'otp_invalid',
          },
        ),
      );
      expect((f as AuthCodeFailure).code, AuthErrorCode.otpInvalid);
    });

    test('noma’lum kod unknown ga tushadi, yiqilmaydi', () {
      final f = ErrorInterceptor.mapToFailure(
        _err(
          status: 400,
          body: {'success': false, 'message': 'x', 'code': 'yangi_kod_2030'},
        ),
      );
      expect((f as AuthCodeFailure).code, AuthErrorCode.unknown);
    });
  });

  group('DRF status kodlari', () {
    test('400 maydonlarga bog‘lanadi', () {
      final f = ErrorInterceptor.mapToFailure(
        _err(
          status: 400,
          body: {
            'address_id': ['Lokatsiya tanlanmagan'],
            'store_type': 'Do‘kon turi noto‘g‘ri.',
          },
        ),
      );
      expect(f, isA<ValidationFailure>());
      final v = f as ValidationFailure;
      expect(v.forField('address_id'), 'Lokatsiya tanlanmagan');
      expect(v.forField('store_type'), 'Do‘kon turi noto‘g‘ri.');
    });

    test('ichma-ich maydonlar tekislanadi', () {
      final f =
          ErrorInterceptor.mapToFailure(
                _err(
                  status: 400,
                  body: {
                    'address': {
                      'latitude': ['Talab qilinadi'],
                    },
                  },
                ),
              )
              as ValidationFailure;
      expect(f.forField('address.latitude'), 'Talab qilinadi');
    });

    test('detail birinchi navbatda xabar bo‘ladi', () {
      final f =
          ErrorInterceptor.mapToFailure(
                _err(
                  status: 400,
                  body: {
                    'zzz': ['keyingi'],
                    'detail': ['birinchi'],
                  },
                ),
              )
              as ValidationFailure;
      expect(f.message, 'birinchi');
    });

    test('401 / 403 / 404', () {
      expect(
        ErrorInterceptor.mapToFailure(
          _err(
            status: 401,
            body: {'detail': 'Authentication credentials were not provided.'},
          ),
        ),
        isA<UnauthorizedFailure>(),
      );
      expect(
        ErrorInterceptor.mapToFailure(_err(status: 403, body: {'detail': 'x'})),
        isA<ForbiddenFailure>(),
      );
      expect(
        ErrorInterceptor.mapToFailure(
          _err(status: 404, body: {'detail': 'Not found.'}),
        ),
        isA<NotFoundFailure>(),
      );
    });

    test('429 Retry-After ni o‘qiydi', () {
      final f =
          ErrorInterceptor.mapToFailure(
                _err(
                  status: 429,
                  body: {'detail': 'Request was throttled.'},
                  headers: {
                    'retry-after': ['42'],
                  },
                ),
              )
              as ThrottledFailure;
      expect(f.retryAfter, const Duration(seconds: 42));
    });

    test('5xx ServerFailure va statusni saqlaydi', () {
      final f =
          ErrorInterceptor.mapToFailure(_err(status: 503, body: {}))
              as ServerFailure;
      expect(f.statusCode, 503);
    });
  });
}
