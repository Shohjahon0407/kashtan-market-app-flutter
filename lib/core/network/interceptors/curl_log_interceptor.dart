import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// So'rovlarni terminalga curl ko'rinishida chiqaradi — nusxa olib
/// to'g'ridan-to'g'ri qayta ishga tushirish mumkin.
///
/// FAQAT debug build'da qo'shiladi (`ApiClient` shunday yig'adi), shuning
/// uchun tokenlar release loglariga hech qachon tushmaydi.
class CurlLogInterceptor extends Interceptor {
  const CurlLogInterceptor();

  static const int _maxBodyChars = 2000;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log(_toCurl(options), name: 'api');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    developer.log(
      '← ${response.statusCode} ${response.requestOptions.uri}',
      name: 'api',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(
      '✖ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri}\n${_truncate(err.response?.data)}',
      name: 'api',
    );
    handler.next(err);
  }

  static String _toCurl(RequestOptions o) {
    final parts = <String>["curl -X ${o.method} '${o.uri}'"];
    o.headers.forEach((key, value) {
      final normalizedKey = key.toLowerCase();
      final shown = switch (normalizedKey) {
        'authorization' => 'Bearer <token>',
        'x-guest-cart-token' => '<guest-cart-token>',
        _ => value,
      };
      parts.add("  -H '$key: $shown'");
    });
    if (o.data != null) {
      parts.add("  -d '${_truncate(o.data)}'");
    }
    return parts.join(' \\\n');
  }

  static String _truncate(Object? data) {
    if (data == null) return '';
    final text = switch (data) {
      final String value => value,
      final FormData form => _formDataSummary(form),
      _ => _jsonOrString(data),
    };
    return text.length <= _maxBodyChars
        ? text
        : '${text.substring(0, _maxBodyChars)}… (${text.length} belgi)';
  }

  static String _formDataSummary(FormData form) => jsonEncode({
    for (final field in form.fields) field.key: field.value,
    'files': [
      for (final file in form.files)
        {
          'field': file.key,
          'filename': file.value.filename,
          'length': file.value.length,
        },
    ],
  });

  static String _jsonOrString(Object data) {
    try {
      return jsonEncode(data);
    } on Object {
      return data.toString();
    }
  }
}
