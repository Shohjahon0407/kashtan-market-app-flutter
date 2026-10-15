import 'dart:convert';
import 'dart:math';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/device_id.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/recommendations/data/recommendations_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    Object? body;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    bodies.add(body);
    final payload = options.path.contains('/recommendations/events/')
        ? {'recorded': 1}
        : options.path.contains('/recommendations/')
        ? {
            'results': [
              {
                'id': 'p-1',
                'name': 'Choynak',
                'price': '120000.00',
                'store_type': 'household',
                'variants': <Object>[],
              },
            ],
            'personalized': true,
          }
        : {'next': null, 'results': <Object>[]};
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;

  ApiClient client({String? deviceId}) {
    adapter = _Adapter();
    return ApiClient.create(
      tokenStore: InMemoryTokenStore(),
      apiLang: () => 'uz',
      script: () => UzScript.none,
      refresh: (_) async => null,
      onSessionExpired: () async {},
      adapter: adapter,
      deviceId: () => deviceId,
    );
  }

  group('qurilma ID', () {
    test('UUID v4 formatida va prefs\'da barqaror', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final first = readOrCreateDeviceId(prefs, random: Random(1));
      expect(isValidUuid(first), isTrue);
      expect(readOrCreateDeviceId(prefs, random: Random(2)), first);
    });

    test('buzilgan qiymat almashtiriladi', () async {
      SharedPreferences.setMockInitialValues({'app.device_id': 'garbage'});
      final prefs = await PrefsStore.load();
      expect(isValidUuid(readOrCreateDeviceId(prefs)), isTrue);
    });
  });

  test('har so\'rovda X-Device-Id, ID bo\'lmasa sarlavha yo\'q', () async {
    await RecommendationsApi(client(deviceId: 'dev-1')).forYou();
    expect(adapter.requests.single.headers['X-Device-Id'], 'dev-1');

    await RecommendationsApi(client()).forYou();
    expect(adapter.requests.single.headers.containsKey('X-Device-Id'), isFalse);
  });

  test('for-you, similar va events kontrakti', () async {
    final api = RecommendationsApi(client(deviceId: 'dev-1'));
    final page = await api.forYou(
      storeType: 'household',
      limit: 10,
      offset: 20,
      session: 77,
    );
    expect(page.items.single.id, 'p-1');
    expect(adapter.requests.last.path, '/recommendations/for-you/');
    expect(adapter.requests.last.queryParameters['store_type'], 'household');
    expect(adapter.requests.last.queryParameters['limit'], 10);
    expect(adapter.requests.last.queryParameters['offset'], 20);
    expect(adapter.requests.last.queryParameters['session'], 77);

    await api.similar('p-9');
    expect(adapter.requests.last.path, '/recommendations/similar/p-9/');

    await api.postEvents([
      {'type': 'view', 'product_id': 'p-1'},
    ]);
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.bodies.last, {
      'events': [
        {'type': 'view', 'product_id': 'p-1'},
      ],
    });
  });

  test('katalog birinchi sahifada reco yuboradi, qidiruvda yo\'q', () async {
    final api = CatalogApi(client(), sessionSeed: 3, recoSession: () => 4242);
    await api.fetchProducts(storeType: 'grocery');
    expect(adapter.requests.last.queryParameters['reco'], 4242);
    expect(adapter.requests.last.queryParameters['seed'], 3);

    await api.fetchProducts(storeType: 'grocery', query: 'olma');
    expect(adapter.requests.last.queryParameters.containsKey('reco'), isFalse);
  });
}
