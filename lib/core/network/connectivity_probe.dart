import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

enum ProbeResult { healthy, serviceUnavailable, unreachable }

/// Independent of JWT, API retries, cached responses and the offline gate.
class ConnectivityProbe {
  ConnectivityProbe({HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static const timeout = Duration(seconds: 4);
  final Dio _dio;
  CancelToken? _cancel;

  Future<ProbeResult> check() async {
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final response = await _dio
          .get<dynamic>(
            '${AppConfig.backendOrigin}/health/',
            // Unique URL bypasses browser/proxy caches without a custom header:
            // Cache-Control request headers require a CORS preflight that the
            // existing public health endpoint does not allow.
            queryParameters: {'_probe': DateTime.now().microsecondsSinceEpoch},
            cancelToken: cancel,
          )
          .timeout(
            timeout,
            onTimeout: () {
              cancel.cancel('probe timeout');
              throw TimeoutException('probe timeout');
            },
          );
      final Object? data = response.data;
      return response.statusCode == 200 && data is Map && data['status'] == 'ok'
          ? ProbeResult.healthy
          : ProbeResult.serviceUnavailable;
    } on Object {
      return ProbeResult.unreachable;
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  void cancel() => _cancel?.cancel('probe paused');

  void dispose() {
    cancel();
    _dio.close(force: true);
  }
}

final connectivityProbeProvider = Provider<ConnectivityProbe>((ref) {
  final probe = ConnectivityProbe();
  ref.onDispose(probe.dispose);
  return probe;
});
