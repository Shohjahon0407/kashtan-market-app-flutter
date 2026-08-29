import 'dart:async' show TimeoutException;
import 'dart:io' show HandshakeException, HttpException, SocketException;

import 'package:dio/dio.dart';

import '../api_failure.dart';
import 'connectivity_interceptor.dart';

/// `DioException` → [ApiFailure].
///
/// Interceptor zanjirida ENG OXIRGI turadi, shunda u auth refresh urinishi
/// tugagandan keyingi YAKUNIY holatni ko'radi.
///
/// Tekshirish TARTIBI muhim: auth endpointlari ham 400 qaytaradi, lekin
/// ularning konverti DRF dan boshqacha, shuning uchun kod bo'yicha tekshiruv
/// status bo'yicha tekshiruvdan OLDIN turadi.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapToFailure(err),
        stackTrace: err.stackTrace,
      ),
    );
  }

  /// Testlardan ham to'g'ridan-to'g'ri chaqirish uchun ochiq.
  static ApiFailure mapToFailure(DioException err) {
    // 1. Bekor qilingan so'rov — bu xato emas.
    if (err.type == DioExceptionType.cancel) {
      return const CancelledFailure();
    }

    // Auth refresh kabi oldingi interceptor aniq failure turini bergan
    // bo'lsa uni original 401/unknown sifatida qayta talqin qilmaymiz.
    final propagated = err.error;
    if (propagated is ApiFailure) return propagated;

    // 2. Transport darajasidagi xatolar.
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.badCertificate:
        return NetworkFailure(_describe(err));
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
      case DioExceptionType.cancel:
      case DioExceptionType.transformTimeout:
        break;
    }

    final response = err.response;
    final status = response?.statusCode;
    final body = response?.data;

    // 3. Auth konverti: {"success": false, "message": "...", "code": "..."}
    if (body is Map) {
      final hasSuccessFalse = body['success'] == false;
      final rawCode = body['code'];
      if (hasSuccessFalse) {
        return AuthCodeFailure(
          _stringOr(body['message'], ''),
          AuthErrorCode.fromWire(rawCode is String ? rawCode : null),
        );
      }
    }

    if (status == null) {
      // MUHIM: javob YO'Q degani "internet yo'q" degani EMAS.
      // `DioExceptionType.unknown` interceptor/transformer ichida otilgan
      // HAR QANDAY lokal xatoni ham o'raydi (masalan xavfsiz ombor
      // ishlamasa). Ilgari bularning hammasi "Internet aloqasi yo'q" deb
      // ko'rsatilar edi va haqiqiy sababni yashirar edi.
      return _isTransportCause(err.error)
          ? NetworkFailure(_describe(err))
          : UnknownFailure(_describe(err));
    }

    // 4. Status bo'yicha.
    if (status == 400) {
      final fields = _extractFieldErrors(body);
      return ValidationFailure(_firstMessage(fields, body), fields);
    }
    if (status == 401) return UnauthorizedFailure(_detail(body));
    if (status == 403) return ForbiddenFailure(_detail(body));
    if (status == 404) return NotFoundFailure(_detail(body));
    if (status == 429) {
      return ThrottledFailure(_detail(body), retryAfter: _retryAfter(response));
    }
    if (status >= 500) return ServerFailure(_detail(body), status);

    return UnknownFailure(_detail(body));
  }

  // ── Yordamchilar ───────────────────────────────────────────────────────────

  /// DRF `{"field": ["msg1","msg2"], "other": "msg"}` ni tekislaydi.
  static Map<String, List<String>> _extractFieldErrors(Object? body) {
    if (body is! Map<Object?, Object?>) return const {};
    final result = <String, List<String>>{};
    body.forEach((key, value) {
      final name = key.toString();
      switch (value) {
        case final String s:
          result[name] = [s];
        case final List<Object?> list:
          final msgs = list
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
          if (msgs.isNotEmpty) result[name] = msgs;
        case final Map<Object?, Object?> nested:
          // Ichma-ich map: `{"address": {"latitude": ["..."]}}`
          nested.forEach((nk, nv) {
            final flat = '$name.$nk';
            if (nv is List<Object?>) {
              result[flat] = nv.map((e) => e.toString()).toList();
            } else {
              result[flat] = [nv.toString()];
            }
          });
        default:
          result[name] = [value.toString()];
      }
    });
    return result;
  }

  static String _firstMessage(Map<String, List<String>> fields, Object? body) {
    // `non_field_errors` va `detail` birinchi navbatda ko'rsatiladi.
    for (final key in const ['detail', 'non_field_errors']) {
      final v = fields[key];
      if (v != null && v.isNotEmpty) return v.first;
    }
    for (final entry in fields.entries) {
      if (entry.value.isNotEmpty) return entry.value.first;
    }
    return _detail(body);
  }

  static String _detail(Object? body) {
    if (body is Map) {
      final detail = body['detail'] ?? body['message'];
      if (detail != null) return detail.toString();
    }
    if (body is String && body.isNotEmpty && body.length < 300) return body;
    return '';
  }

  static Duration? _retryAfter(Response<dynamic>? response) {
    final header = response?.headers.value('retry-after');
    if (header == null) return null;
    final seconds = int.tryParse(header.trim());
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static String _stringOr(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;

  /// Sabab haqiqatan tarmoq/TLS darajasidami.
  static bool _isTransportCause(Object? cause) =>
      cause is OfflineShortCircuit ||
      cause is SocketException ||
      cause is HandshakeException ||
      cause is TimeoutException ||
      cause is HttpException;

  /// Diagnostika uchun texnik tavsif.
  ///
  /// UI buni to'g'ridan-to'g'ri ko'rsatmaydi — `failure_l10n` faqat debug
  /// build'da qo'shimcha qatorda chiqaradi.
  static String _describe(DioException err) {
    final parts = <String>[err.type.name];
    final cause = err.error;
    if (cause != null) parts.add(cause.toString());
    final message = err.message;
    if (message != null && message.isNotEmpty && cause == null) {
      parts.add(message);
    }
    return parts.join(' · ');
  }
}
