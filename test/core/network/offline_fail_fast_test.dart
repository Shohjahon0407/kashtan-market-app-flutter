import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Har chaqiruvni sanaydi va (agar so'ralsa) uzoq kutadi.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter({this.delay = Duration.zero});

  final Duration delay;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(
  _CountingAdapter adapter, {
  required bool offline,
  void Function()? onSuccess,
  void Function()? onFailure,
}) => ApiClient.create(
  tokenStore: InMemoryTokenStore(access: 'a', refresh: 'r'),
  apiLang: () => 'uz',
  script: () => UzScript.none,
  refresh: (_) async => null,
  onSessionExpired: () async {},
  adapter: adapter,
  isOffline: () => offline,
  onNetworkSuccess: onSuccess,
  onNetworkFailure: onFailure,
);

void main() {
  test(
    'offline: so‘rov umuman yuborilmaydi va darhol NetworkFailure',
    () async {
      final adapter = _CountingAdapter(delay: const Duration(seconds: 5));
      var failures = 0;
      final client = _client(
        adapter,
        offline: true,
        onFailure: () => failures++,
      );

      final stopwatch = Stopwatch()..start();
      await expectLater(client.get('/home/'), throwsA(isA<NetworkFailure>()));
      stopwatch.stop();

      expect(adapter.calls, 0, reason: 'tarmoqqa chiqilmasligi kerak');
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 1)),
        reason: 'taymaut kutilmasligi kerak',
      );
      expect(failures, 0, reason: 'lokal reject tarmoq xatosi emas');
    },
  );

  test('online: so‘rov ketadi va muvaffaqiyat xabar qilinadi', () async {
    final adapter = _CountingAdapter();
    var successes = 0;
    final client = _client(
      adapter,
      offline: false,
      onSuccess: () => successes++,
    );

    final data = await client.get('/home/');

    expect(adapter.calls, 1);
    expect((data as Map)['ok'], isTrue);
    expect(successes, 1);
  });
}
