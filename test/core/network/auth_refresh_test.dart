import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/interceptors/auth_interceptor.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Har so'rovni skript bo'yicha javob beradigan soxta adapter.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) =>
    ResponseBody.fromString(
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _encode(Map<String, dynamic> map) {
  final parts = map.entries.map((e) {
    final v = e.value;
    final encoded = v is String ? '"$v"' : '$v';
    return '"${e.key}":$encoded';
  });
  return '{${parts.join(',')}}';
}

void main() {
  late InMemoryTokenStore tokens;
  late int refreshCallCount;
  late int sessionExpiredCount;

  setUp(() {
    tokens = InMemoryTokenStore(access: 'eski', refresh: 'refresh-token');
    refreshCallCount = 0;
    sessionExpiredCount = 0;
  });

  test(
    'TokenRefreshClient 401ni expiry, 5xxni transient deb ajratadi',
    () async {
      final expired = TokenRefreshClient(
        adapter: _ScriptedAdapter(
          (_) => _json({'detail': 'refresh yaroqsiz'}, 401),
        ),
      );
      final unavailable = TokenRefreshClient(
        adapter: _ScriptedAdapter(
          (_) => _json({'detail': 'server xatosi'}, 503),
        ),
      );

      expect(await expired.refresh('refresh-token'), isNull);
      await expectLater(
        unavailable.refresh('refresh-token'),
        throwsA(
          isA<TokenRefreshTransientException>().having(
            (error) => error.failure,
            'failure',
            isA<ServerFailure>(),
          ),
        ),
      );
    },
  );

  ApiClient buildClient(_ScriptedAdapter adapter, {String? newAccess}) {
    return ApiClient.create(
      tokenStore: tokens,
      apiLang: () => 'uz',
      script: () => UzScript.none,
      refresh: (_) async {
        refreshCallCount++;
        // Refresh sekinroq bo'ladi — bir vaqtda kelgan 401 lar navbatga tushadi
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return newAccess;
      },
      onSessionExpired: () async {
        sessionExpiredCount++;
        await tokens.clear();
      },
      adapter: adapter,
    );
  }

  test('401 → refresh → so‘rov yangi token bilan qayta yuboriladi', () async {
    final seenAuthHeaders = <String>[];
    final adapter = _ScriptedAdapter((options) {
      final auth = options.headers['Authorization']?.toString() ?? '';
      seenAuthHeaders.add(auth);
      if (auth == 'Bearer eski') {
        return _json({'detail': 'token yaroqsiz'}, 401);
      }
      return _json({'ok': 'true'}, 200);
    });

    final client = buildClient(adapter, newAccess: 'yangi');
    final result = await client.get('/me/');

    expect(result, isA<Map<dynamic, dynamic>>());
    expect(refreshCallCount, 1);
    expect(sessionExpiredCount, 0);
    expect(seenAuthHeaders, ['Bearer eski', 'Bearer yangi']);
    expect(await tokens.readAccess(), 'yangi');
    // Refresh token o'zgarmaydi — backendda ROTATE_REFRESH_TOKENS=False
    expect(await tokens.readRefresh(), 'refresh-token');
  });

  test('bir vaqtdagi 401 lar FAQAT BITTA refresh yuboradi', () async {
    final adapter = _ScriptedAdapter((options) {
      final auth = options.headers['Authorization']?.toString() ?? '';
      if (auth == 'Bearer eski') {
        return _json({'detail': 'token yaroqsiz'}, 401);
      }
      return _json({'ok': 'true'}, 200);
    });

    final client = buildClient(adapter, newAccess: 'yangi');

    await Future.wait([
      client.get('/me/'),
      client.get('/orders/'),
      client.get('/favorites/'),
      client.get('/notifications/'),
    ]);

    expect(refreshCallCount, 1, reason: 'single-flight buzilgan');
    expect(sessionExpiredCount, 0);
  });

  test('refresh ham ishlamasa sessiya tugaydi va 401 chiqadi', () async {
    final adapter = _ScriptedAdapter(
      (_) => _json({'detail': 'token yaroqsiz'}, 401),
    );
    final client = buildClient(adapter); // newAccess = null

    await expectLater(client.get('/me/'), throwsA(isA<UnauthorizedFailure>()));
    expect(refreshCallCount, 1);
    expect(sessionExpiredCount, 1);
  });

  test('refresh transient xatosi sessiyani o‘chirmaydi', () async {
    final adapter = _ScriptedAdapter(
      (_) => _json({'detail': 'token yaroqsiz'}, 401),
    );
    final client = ApiClient.create(
      tokenStore: tokens,
      apiLang: () => 'uz',
      script: () => UzScript.none,
      refresh: (_) async => throw const TokenRefreshTransientException(
        NetworkFailure('refresh offline'),
      ),
      onSessionExpired: () async => sessionExpiredCount++,
      adapter: adapter,
    );

    await expectLater(client.get('/me/'), throwsA(isA<NetworkFailure>()));
    expect(sessionExpiredCount, 0);
    expect(await tokens.readAccess(), 'eski');
    expect(await tokens.readRefresh(), 'refresh-token');
  });

  test('yangilangandan keyin ham 401 bo‘lsa cheksiz sikl bo‘lmaydi', () async {
    // Server har doim 401 qaytaradi, hatto yangi token bilan ham.
    final adapter = _ScriptedAdapter(
      (_) => _json({'detail': 'token yaroqsiz'}, 401),
    );
    final client = buildClient(adapter, newAccess: 'yangi');

    await expectLater(client.get('/me/'), throwsA(isA<UnauthorizedFailure>()));
    // Faqat bitta refresh: `extra['auth.retried']` sentineli ikkinchisini to'sadi
    expect(refreshCallCount, 1);
    expect(sessionExpiredCount, 1);
    expect(await tokens.readAccess(), isNull);
    expect(await tokens.readRefresh(), isNull);
  });

  test('yangilangandan keyingi 403 ham sessiyani tugatadi', () async {
    final adapter = _ScriptedAdapter((options) {
      final auth = options.headers['Authorization']?.toString() ?? '';
      return auth == 'Bearer eski'
          ? _json({'detail': 'token eskirgan'}, 401)
          : _json({'detail': 'yangi token rad etildi'}, 403);
    });
    final client = buildClient(adapter, newAccess: 'yangi');

    await expectLater(client.get('/me/'), throwsA(isA<ForbiddenFailure>()));
    expect(refreshCallCount, 1);
    expect(sessionExpiredCount, 1);
    expect(await tokens.readAccess(), isNull);
  });

  test('/auth/* endpointlarida refresh urinilmaydi', () async {
    final adapter = _ScriptedAdapter(
      (_) => _json({
        'success': false,
        'message': 'OTP kodi noto‘g‘ri',
        'code': 'otp_invalid',
      }, 400),
    );
    final client = buildClient(adapter, newAccess: 'yangi');

    await expectLater(
      client.post('/auth/verify-otp/', body: {'phone_number': '+998901234567'}),
      throwsA(isA<AuthCodeFailure>()),
    );
    expect(refreshCallCount, 0);
    expect(sessionExpiredCount, 0);
  });

  test('GET so‘rovga lang qo‘shiladi, mavjud bo‘lsa tegilmaydi', () async {
    final seen = <Map<String, dynamic>>[];
    final adapter = _ScriptedAdapter((options) {
      seen.add(Map<String, dynamic>.from(options.queryParameters));
      return _json({'ok': 'true'}, 200);
    });
    final client = buildClient(adapter);

    await client.get('/home/');
    expect(seen.last['lang'], 'uz');

    await client.get('/home/', query: {'lang': 'ru'});
    expect(seen.last['lang'], 'ru', reason: 'putIfAbsent buzilgan');
  });
}
