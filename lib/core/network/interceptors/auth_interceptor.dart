import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/api_endpoints.dart';
import '../../storage/secure_token_store.dart';
import '../api_failure.dart';

/// Refresh so'rovini bajaradigan funksiya. Yangi access token yoki `null`.
typedef RefreshAccessToken = Future<String?> Function(String refreshToken);

/// Sessiya butunlay tugaganda chaqiriladi (refresh ham ishlamadi).
typedef OnSessionExpired = Future<void> Function();
const authOwnerKey = 'auth.owner';

/// Refresh token rad etilmadi, lekin uni tekshirish transport/5xx sabab
/// yakunlanmadi. Bunday holat user sessiyasini o'chirishga asos emas.
final class TokenRefreshTransientException implements Exception {
  const TokenRefreshTransientException(this.failure);

  final ApiFailure failure;
}

/// `Authorization: Bearer` qo'shadi va 401 da tokenni bir marta yangilab,
/// so'rovni qayta yuboradi.
///
/// [QueuedInterceptor] tanlandi: bir vaqtda bir nechta so'rov 401 olsa, dio
/// ularni navbatga qo'yadi va biz faqat bitta refresh POST yuboramiz
/// ("single-flight"). `_refreshInFlight` completer'i esa hatto navbat
/// chetlab o'tilsa ham ikkinchi refresh yuborilmasligini kafolatlaydi.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Dio bareDio,
    required RefreshAccessToken refresh,
    required OnSessionExpired onSessionExpired,
    String Function()? sessionOwner,
  }) : _tokens = tokenStore,
       _bareDio = bareDio,
       _refresh = refresh,
       _onSessionExpired = onSessionExpired,
       _sessionOwner = sessionOwner;

  final TokenStore _tokens;

  /// AuthInterceptor'siz Dio — qayta yuborish rekursiyaga tushmasligi uchun.
  final Dio _bareDio;

  final RefreshAccessToken _refresh;
  final OnSessionExpired _onSessionExpired;
  final String Function()? _sessionOwner;

  bool _isCurrent(RequestOptions options) =>
      _sessionOwner == null ||
      options.extra[authOwnerKey] == null ||
      options.extra[authOwnerKey] == _sessionOwner();

  Completer<String?>? _refreshInFlight;

  /// So'rov bir marta qayta yuborilganini belgilaydi.
  static const String _retriedKey = 'auth.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isExempt(options.path)) {
      options.extra[authOwnerKey] = _sessionOwner?.call();
      final access = await _tokens.readAccess();
      if (!_isCurrent(options)) {
        handler.reject(
          DioException(requestOptions: options, type: DioExceptionType.cancel),
        );
        return;
      }
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isCurrent(options)) {
      handler.reject(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );
      return;
    }

    final notUnauthorized = err.response?.statusCode != 401;
    final isExempt = _isExempt(options.path);
    final alreadyRetried = options.extra[_retriedKey] == true;
    final hadBearer = options.headers.containsKey('Authorization');

    if (notUnauthorized || isExempt || alreadyRetried || !hadBearer) {
      handler.next(err);
      return;
    }

    // QueuedInterceptor bir vaqtda kelgan 401 larni KETMA-KET bajaradi.
    // Ya'ni birinchisi tokenni yangilab bo'lgach, keyingilari uchun
    // `_refreshInFlight` allaqachon bo'sh bo'ladi va ular ham refresh
    // yuborishga urinardi. Shuning uchun avval oddiy tekshiruv: so'rov
    // ishlatgan token hozirgi tokendan farq qilsa — kimdir allaqachon
    // yangilagan, faqat qayta yuborish kifoya.
    final usedToken = _bearerOf(options.headers['Authorization']);
    final storedToken = await _tokens.readAccess();
    final alreadyRefreshedByPeer =
        storedToken != null &&
        storedToken.isNotEmpty &&
        storedToken != usedToken;

    String? newAccess;
    try {
      newAccess = alreadyRefreshedByPeer
          ? storedToken
          : await _refreshSingleFlight();
    } on TokenRefreshTransientException catch (transient) {
      _rejectTransient(handler, options, transient.failure, err.stackTrace);
      return;
    } on ApiFailure catch (failure) {
      _rejectTransient(handler, options, failure, err.stackTrace);
      return;
    } on Object catch (error) {
      // Noma'lum refresh transport xatosida ham xavfsiz default — sessiyani
      // saqlash va xatoni original 401 emas, retry qilinadigan network failure
      // sifatida chiqarish. Keyingi REST/WS reconciliation qayta urinadi.
      _rejectTransient(
        handler,
        options,
        NetworkFailure(error.toString()),
        err.stackTrace,
      );
      return;
    }

    if (!_isCurrent(options)) {
      handler.reject(
        DioException(requestOptions: options, type: DioExceptionType.cancel),
      );
      return;
    }
    if (newAccess == null || newAccess.isEmpty) {
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer $newAccess';
      final response = await _bareDio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      final retryStatus = e.response?.statusCode;
      if (retryStatus == 401 && _isCurrent(options)) {
        // Refresh muvaffaqiyatli bo'lsa ham yangi access token rad etildi:
        // bu endi transient emas, sessiya aniq yaroqsiz.
        await _onSessionExpired();
      }
      handler.next(e);
    }
  }

  static void _rejectTransient(
    ErrorInterceptorHandler handler,
    RequestOptions options,
    ApiFailure failure,
    StackTrace stackTrace,
  ) {
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: failure,
        stackTrace: stackTrace,
      ),
    );
  }

  static String? _bearerOf(Object? header) {
    final value = header?.toString();
    if (value == null || !value.startsWith('Bearer ')) return null;
    return value.substring('Bearer '.length);
  }

  /// Bir vaqtda faqat bitta refresh POST ketishini kafolatlaydi.
  Future<String?> _refreshSingleFlight() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<String?>();
    _refreshInFlight = completer;

    unawaited(
      _doRefresh().then(
        (value) {
          _refreshInFlight = null;
          completer.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          _refreshInFlight = null;
          completer.completeError(error, stack);
        },
      ),
    );

    return completer.future;
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokens.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final access = await _refresh(refreshToken);
    if (await _tokens.readRefresh() != refreshToken) {
      throw const CancelledFailure();
    }
    if (access == null || access.isEmpty) return null;

    // Backendda ROTATE_REFRESH_TOKENS=False — refresh token o'zgarmaydi,
    // shuning uchun faqat access yoziladi.
    await _tokens.saveAccess(access);
    return access;
  }

  static bool _isExempt(String path) =>
      Api.authExempt.any((exempt) => path.endsWith(exempt));
}
