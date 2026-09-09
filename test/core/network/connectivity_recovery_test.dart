import 'dart:async';
import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/connectivity_probe.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, [Map<String, dynamic>? data]) =>
    ResponseBody.fromString(
      jsonEncode(data ?? {'status': 'ok'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient _client(
  _Adapter adapter, {
  void Function()? success,
  void Function()? failure,
  void Function(int)? http,
  bool Function()? offline,
  String Function()? owner,
}) => ApiClient.create(
  tokenStore: InMemoryTokenStore(access: 'old', refresh: 'refresh'),
  apiLang: () => 'uz',
  script: () => UzScript.none,
  refresh: (_) async => 'new',
  onSessionExpired: () async {},
  adapter: adapter,
  isOffline: offline ?? () => false,
  onNetworkSuccess: success,
  onNetworkFailure: failure,
  onHttpResponse: http,
  sessionOwner: owner,
);

void main() {
  test('non-idempotent POST/PATCH do not replay on a timeout', () async {
    final adapter = _Adapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final client = _client(adapter);
    await expectLater(
      client.post('/cart/items/'),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      client.patch('/cart/items/one/'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(adapter.calls.length, 2);
  });

  test(
    'explicit idempotency key allows checkout retry with the same key',
    () async {
      var count = 0;
      final adapter = _Adapter((options) {
        if (++count == 1) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json(200);
      });
      await _client(
        adapter,
      ).post('/orders/', headers: {'Idempotency-Key': 'same-intent'});
      expect(adapter.calls.length, 2);
      expect(
        adapter.calls.every(
          (o) => o.headers['Idempotency-Key'] == 'same-intent',
        ),
        isTrue,
      );
    },
  );

  test(
    'late response from account A is discarded after switching to B',
    () async {
      var owner = 'A';
      final pending = Completer<ResponseBody>();
      final arrived = Completer<void>();
      final adapter = _Adapter((_) {
        arrived.complete();
        return pending.future;
      });
      final request = _client(adapter, owner: () => owner).get('/addresses/');
      final expectation = expectLater(
        request,
        throwsA(isA<CancelledFailure>()),
      );
      await arrived.future;
      owner = 'B';
      pending.complete(_json(200, {'private': 'A'}));
      await expectation;
    },
  );

  test(
    '403 after successful token refresh does not log the user out',
    () async {
      var expirations = 0;
      final adapter = _Adapter(
        (options) =>
            _json(options.headers['Authorization'] == 'Bearer new' ? 403 : 401),
      );
      final client = ApiClient.create(
        tokenStore: InMemoryTokenStore(access: 'old', refresh: 'refresh'),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => 'new',
        onSessionExpired: () async {
          expirations++;
        },
        adapter: adapter,
      );
      await expectLater(
        client.get('/protected/'),
        throwsA(isA<ForbiddenFailure>()),
      );
      expect(expirations, 0);
    },
  );

  test('timeout → successful retry → next request reaches server', () async {
    var attempts = 0;
    var offline = false;
    var failures = 0;
    var successes = 0;
    final adapter = _Adapter((options) {
      if (++attempts == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return _json(200);
    });
    final client = _client(
      adapter,
      offline: () => offline,
      success: () {
        successes++;
        offline = false;
      },
      failure: () {
        failures++;
        offline = true;
      },
    );
    await client.get('/home/');
    expect(offline, isFalse);
    expect(
      failures,
      0,
      reason: 'intermediate retry failure must not be reported',
    );
    expect(successes, 1);
    await client.get('/home/');
    expect(adapter.calls.length, 3);
    expect(successes, 2);
  });

  test('auth replay success reports connectivity once', () async {
    var success = 0;
    final adapter = _Adapter(
      (o) => _json(o.headers['Authorization'] == 'Bearer new' ? 200 : 401),
    );
    await _client(adapter, success: () => success++).get('/profile/');
    expect(adapter.calls.length, 2);
    expect(success, 1);
  });

  test('final transport failure reports once after retries finish', () async {
    var failures = 0;
    final adapter = _Adapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    await expectLater(
      _client(adapter, failure: () => failures++).get('/home/'),
      throwsA(isA<NetworkFailure>()),
    );
    expect(adapter.calls.length, greaterThan(1));
    expect(failures, 1);
  });

  test(
    'late failed request cannot override a newer successful request',
    () async {
      final delayed = Completer<void>();
      var failures = 0;
      final adapter = _Adapter((options) async {
        if (options.path == '/slow/') {
          await delayed.future;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json(200);
      });
      final client = _client(adapter, failure: () => failures++);
      final slow = expectLater(
        client.get('/slow/'),
        throwsA(isA<NetworkFailure>()),
      );
      await client.get('/home/');
      delayed.complete();
      await slow;
      expect(failures, 0);
    },
  );

  for (final status in [400, 401, 403, 429, 500]) {
    test('HTTP $status is reachable, not a transport failure', () async {
      var failures = 0;
      final statuses = <int>[];
      final adapter = _Adapter((_) => _json(status));
      await expectLater(
        _client(
          adapter,
          failure: () => failures++,
          http: statuses.add,
        ).get('/auth/test/'),
        throwsA(isA<ApiFailure>()),
      );
      expect(failures, 0);
      expect(statuses, [status]);
    });
  }

  test(
    'cancel and synthetic offline reject do not count as transport failures',
    () async {
      var failures = 0;
      var requestsBlocked = false;
      final adapter = _Adapter((_) => _json(200));
      final client = _client(
        adapter,
        failure: () => failures++,
        offline: () => requestsBlocked,
      );
      final cancel = CancelToken()..cancel();
      await expectLater(
        client.get('/home/', cancelToken: cancel),
        throwsA(isA<CancelledFailure>()),
      );
      requestsBlocked = true;
      await expectLater(client.get('/home/'), throwsA(isA<NetworkFailure>()));
      expect(failures, 0);
      expect(adapter.calls, isEmpty);
    },
  );

  test('probe is an uncached unauthenticated health request', () async {
    final adapter = _Adapter((_) => _json(200));
    final probe = ConnectivityProbe(adapter: adapter);
    addTearDown(probe.dispose);
    expect(await probe.check(), ProbeResult.healthy);
    final request = adapter.calls.single;
    expect(request.uri.path, '/health/');
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.headers.containsKey('X-Guest-Cart-Token'), isFalse);
    expect(request.headers.containsKey('Cache-Control'), isFalse);
    expect(request.queryParameters, contains('_probe'));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await probe.check();
    expect(adapter.calls.last.uri, isNot(request.uri));
  });

  test(
    'probe classifies HTTP failure and captive-portal HTML separately from offline',
    () async {
      for (final response in [
        _json(503),
        ResponseBody.fromString('<html>login</html>', 200),
      ]) {
        final probe = ConnectivityProbe(adapter: _Adapter((_) => response));
        expect(await probe.check(), ProbeResult.serviceUnavailable);
        probe.dispose();
      }
    },
  );

  testWidgets('health probe has a 4s total deadline and no retries', (
    tester,
  ) async {
    final pending = Completer<ResponseBody>();
    final adapter = _Adapter((_) => pending.future);
    final probe = ConnectivityProbe(adapter: adapter);
    final future = probe.check();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(await future, ProbeResult.unreachable);
    expect(adapter.calls.length, 1);
    pending.complete(_json(200));
    probe.dispose();
    await tester.pump();
  });
}
