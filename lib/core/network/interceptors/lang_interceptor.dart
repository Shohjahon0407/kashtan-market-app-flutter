import 'package:dio/dio.dart';

/// GET so'rovlariga `?lang=` qo'shadi.
///
/// `putIfAbsent` MUHIM: sahifalashning `next` URL'lari allaqachon `lang` ni
/// olib yuradi; uni qayta yozish server keshining kalitini o'zgartirib,
/// cursor uzluksizligini buzishi mumkin.
class LangInterceptor extends Interceptor {
  LangInterceptor(this._apiLang);

  /// Joriy `lang` qiymatini beradi — FAQAT `uz` yoki `ru`.
  /// `uz-Cyrl` hech qachon yuborilmaydi (backend uni bilmaydi va jimgina
  /// `uz` ga tushadi, lekin kesh kalitini keraksiz ikkiga bo'ladi).
  final String Function() _apiLang;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() == 'GET') {
      options.queryParameters.putIfAbsent('lang', _apiLang);
    }
    handler.next(options);
  }
}
