import 'dart:async';

import 'package:dio/dio.dart';

import 'connectivity_interceptor.dart';

/// FAQAT tarmoq/taymaut xatolarida qayta uradi.
///
/// 4xx va 5xx qayta urilmaydi: 400 hech qachon o'zgarmaydi, 500 esa
/// idempotent bo'lmagan POST'ni (masalan buyurtma yaratish) ikki marta
/// bajarib yuborishi mumkin.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.bareDio,
    this.maxAttempts = 2,
    this.delays = const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 900),
    ],
  });

  final Dio bareDio;
  final int maxAttempts;
  final List<Duration> delays;

  static const String _attemptKey = 'retry.attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxAttempts) {
      handler.next(err);
      return;
    }

    final delay = attempt < delays.length ? delays[attempt] : delays.last;
    await Future<void>.delayed(delay);

    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await bareDio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  static bool _isRetryable(DioException err) {
    // Offline sababli yuborilmagan so'rovni qayta urinish ma'nosiz.
    if (err.error is OfflineShortCircuit) return false;
    return _isRetryableType(err);
  }

  static bool _isRetryableType(DioException err) => switch (err.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    _ => false,
  };
}
