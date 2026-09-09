import 'package:dio/dio.dart';

/// Ulanish holatini tarmoq qatlamiga bog'laydi.
///
/// Only the confirmed offline gate lives here. Connectivity evidence is
/// reported by ApiClient AFTER retry/auth handling has finished.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({required this.isOffline, this.onBlocked});

  final bool Function() isOffline;
  final void Function()? onBlocked;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isOffline() && options.extra[kAllowWhenOffline] != true) {
      options.extra[kOfflineShortCircuited] = true;
      onBlocked?.call();
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
}

/// So'rovni offline holatida ham yuborishga ruxsat beruvchi bayroq.
/// Ulanish qaytganini tekshiruvchi "probe" so'rovlar uchun.
const kAllowWhenOffline = 'connectivity.allowWhenOffline';
const kOfflineShortCircuited = 'connectivity.shortCircuited';

/// Offline sababli yuborilmagan so'rov belgisi — `ErrorInterceptor` buni
/// `NetworkFailure` ga aylantiradi.
class OfflineShortCircuit implements Exception {
  const OfflineShortCircuit();

  @override
  String toString() => 'Offline: so\'rov yuborilmadi';
}
