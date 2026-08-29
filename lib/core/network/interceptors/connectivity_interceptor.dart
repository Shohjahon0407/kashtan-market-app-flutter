import 'package:dio/dio.dart';

/// Ulanish holatini tarmoq qatlamiga bog'laydi.
///
/// Ikki vazifasi bor:
///  1. **Fail-fast** — offline ekani ma'lum bo'lsa so'rov umuman yuborilmaydi.
///     Aks holda foydalanuvchi taymaut tugashini (8-15 soniya) bekorga kutadi.
///  2. **Holatni yangilash** — muvaffaqiyatli javob "online", tarmoq xatosi
///     esa "offline" signalini beradi. Aynan shu Wi-Fi bor, lekin internet
///     yo'q holatini ushlaydi (platforma signali buni ko'rmaydi).
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({
    required this.isOffline,
    required this.onSuccess,
    required this.onNetworkFailure,
  });

  final bool Function() isOffline;
  final void Function() onSuccess;
  final void Function() onNetworkFailure;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isOffline() && options.extra[kAllowWhenOffline] != true) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const OfflineShortCircuit(),
          message: 'offline',
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    onSuccess();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isTransport(err)) onNetworkFailure();
    handler.next(err);
  }

  static bool _isTransport(DioException err) => switch (err.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    _ => false,
  };
}

/// So'rovni offline holatida ham yuborishga ruxsat beruvchi bayroq.
/// Ulanish qaytganini tekshiruvchi "probe" so'rovlar uchun.
const kAllowWhenOffline = 'connectivity.allowWhenOffline';

/// Offline sababli yuborilmagan so'rov belgisi — `ErrorInterceptor` buni
/// `NetworkFailure` ga aylantiradi.
class OfflineShortCircuit implements Exception {
  const OfflineShortCircuit();

  @override
  String toString() => 'Offline: so\'rov yuborilmadi';
}
