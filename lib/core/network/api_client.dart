import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../config/api_endpoints.dart';
import '../config/app_config.dart';
import '../localization/uzbek_transliterator.dart';
import '../storage/secure_token_store.dart';
import 'api_failure.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/connectivity_interceptor.dart';
import 'interceptors/curl_log_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/lang_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/uz_script_interceptor.dart';
import 'localized_json_transformer.dart';

/// User API bilan ishlaydigan yagona HTTP klient.
///
/// Interceptor tartibi (so'rov yuqoridan pastga, javob pastdan yuqoriga):
/// ```
/// 0 CurlLog          faqat debug
/// 1 Lang             GET ga ?lang= (putIfAbsent)
/// 2 UzScriptRequest  chiquvchi matn kirill → lotin
/// 3 Auth             Bearer + 401 → single-flight refresh → 1 marta retry
/// 4 Retry            faqat network/timeout
/// 5 Error            DioException → ApiFailure (OXIRGI bo'lishi shart)
/// ```
class ApiClient {
  ApiClient._(this._dio, this.transformer);

  /// To'liq interceptor to'plami bilan klient yig'adi.
  factory ApiClient.create({
    required TokenStore tokenStore,
    required String Function() apiLang,
    required UzScript Function() script,
    required RefreshAccessToken refresh,
    required OnSessionExpired onSessionExpired,
    HttpClientAdapter? adapter,
    bool Function()? isOffline,
    void Function()? onNetworkSuccess,
    void Function()? onNetworkFailure,
  }) {
    final transformer = LocalizedJsonTransformer()..script = script();

    BaseOptions baseOptions() => BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      responseType: ResponseType.json,
      headers: apiDefaultHeaders(),
      // 4xx/5xx ni o'zimiz ErrorInterceptor'da ushlaymiz.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );

    // Qayta yuborish uchun "yalang'och" Dio: unda Auth/Retry YO'Q,
    // aks holda rekursiya bo'ladi. Lang va script kerak, chunki qayta
    // yuborilgan so'rov ham to'g'ri bo'lishi shart.
    final bareDio = Dio(baseOptions())
      ..transformer = transformer
      ..interceptors.add(LangInterceptor(apiLang))
      ..interceptors.add(UzScriptRequestInterceptor(script));
    if (adapter != null) bareDio.httpClientAdapter = adapter;

    final dio = Dio(baseOptions())..transformer = transformer;
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.addAll([
      if (kDebugMode && AppConfig.verboseNetworkLog) const CurlLogInterceptor(),
      // Eng oldinda: offline bo'lsa so'rov shu yerda to'xtaydi va foydalanuvchi
      // taymaut tugashini kutmaydi.
      if (isOffline != null)
        ConnectivityInterceptor(
          isOffline: isOffline,
          onSuccess: onNetworkSuccess ?? () {},
          onNetworkFailure: onNetworkFailure ?? () {},
        ),
      LangInterceptor(apiLang),
      UzScriptRequestInterceptor(script),
      AuthInterceptor(
        tokenStore: tokenStore,
        bareDio: bareDio,
        refresh: refresh,
        onSessionExpired: onSessionExpired,
      ),
      RetryInterceptor(bareDio: bareDio),
      const ErrorInterceptor(),
    ]);

    return ApiClient._(dio, transformer);
  }

  final Dio _dio;

  /// Til o'zgarganda [LocalizedJsonTransformer.script] shu orqali yangilanadi.
  final LocalizedJsonTransformer transformer;

  Dio get raw => _dio;

  // ── So'rov metodlari ───────────────────────────────────────────────────────
  // Hammasi `ApiFailure` tashlaydi, hech qachon `DioException` emas.

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
      cancelToken: cancelToken,
    ),
  );

  /// Sahifalashning absolut `next` URL'ini AYNAN oladi.
  ///
  /// Dio absolut URL'da `baseUrl` ni chetlab o'tadi, lekin interceptorlar
  /// baribir ishlaydi — ya'ni Bearer qo'shiladi va `lang` buzilmaydi.
  Future<dynamic> getUrl(String absoluteUrl, {CancelToken? cancelToken}) =>
      _send(() => _dio.get<dynamic>(absoluteUrl, cancelToken: cancelToken));

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.put<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
      cancelToken: cancelToken,
    ),
  );

  /// Multipart upload. [FormData] boundary'sini Dio o'zi qo'yadi; ayniqsa
  /// Flutter Web'da uni qo'lda yozish browser uploadini buzadi.
  Future<dynamic> postMultipart(
    String path, {
    required FormData body,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(contentType: Headers.multipartFormDataContentType),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.patch<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.delete<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      // ErrorInterceptor `error` ni allaqachon ApiFailure ga aylantirgan.
      final failure = e.error;
      if (failure is ApiFailure) throw failure;
      throw ErrorInterceptor.mapToFailure(e);
    }
  }
}

/// Refresh so'rovini bajaradigan minimal klient.
///
/// Ataylab [ApiClient] dan MUSTAQIL: uning o'z Dio nusxasi bor, shuning uchun
/// refresh hech qachon AuthInterceptor'ga qaytib tushmaydi.
class TokenRefreshClient {
  TokenRefreshClient({HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: apiDefaultHeaders(),
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  final Dio _dio;

  /// Yangi access token yoki `null` (refresh token aniq 401/403 bilan rad
  /// etilgan). Offline/timeout/5xx sessiyani o'chirmaslik uchun alohida
  /// [TokenRefreshTransientException] tashlaydi.
  Future<String?> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<dynamic>(
        Api.tokenRefresh,
        data: {'refresh': refreshToken},
      );
      final data = response.data;
      if (data is Map && data['access'] is String) {
        final access = data['access'] as String;
        if (access.isNotEmpty) return access;
      }
      throw const TokenRefreshTransientException(
        ServerFailure('refresh javobi access token bermadi', 502),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return null;
      final networkTypes = {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.badCertificate,
      };
      throw TokenRefreshTransientException(
        networkTypes.contains(error.type) || status == null
            ? NetworkFailure(error.message ?? '')
            : ServerFailure('', status),
      );
    }
  }
}

/// User API uchun umumiy headerlar.
///
/// Brauzerda `X-App-Client` yuborilmaydi: production CORS preflight allow-listi
/// bu custom headerni qabul qilmaydi. Auth endpointlari `client_type` ni bodyda
/// oladi, qolgan customer endpointlari esa JWT va URL namespace bilan ajraladi.
/// Native ilovalarda eski header backward compatibility uchun saqlanadi.
Map<String, String> apiDefaultHeaders({bool isWeb = kIsWeb}) => {
  'Accept': 'application/json',
  'Content-Type': 'application/json',
  if (!isWeb) 'X-App-Client': 'customer',
};
