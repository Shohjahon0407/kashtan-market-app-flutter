import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/uzbek_transliterator.dart';
import 'package:beshkashtan_customer/core/network/api_client.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/notifications/data/notifications_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Request = ({
  String method,
  String path,
  Object? body,
  Map<String, dynamic> query,
});

class _NotificationAdapter implements HttpClientAdapter {
  final requests = <_Request>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) body = jsonDecode(utf8.decode(bytes));
    }
    requests.add((
      method: options.method,
      path: options.path,
      body: body,
      query: Map<String, dynamic>.from(options.queryParameters),
    ));

    final response = switch (options.path) {
      '/notifications/' => {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [_notification()],
      },
      '/notifications/unread-count/' => {'unread_count': 4},
      '/notifications/read-all/' => {'success': true, 'updated_count': 4},
      '/notification-devices/' => {
        'id': 'device-backend-1',
        'platform': 'android',
        'device_id': 'device-local-1',
        'locale': 'uz_Cyrl',
        'is_active': true,
      },
      _ when options.path.endsWith('/read/') => {
        ..._notification(),
        'is_read': true,
      },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(response),
      options.method == 'DELETE' ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _notification() => {
  'id': 'notification-1',
  'title': 'Kuryer qabul qildi',
  'body': '20 daqiqada yetib boradi',
  'type': 'order_update',
  'event_key': 'order_accepted',
  'data': {'store_type': 'household'},
  'is_read': false,
  'related_order': 'order-1',
  'created_at': '2026-08-08T10:00:00Z',
};

void main() {
  late _NotificationAdapter adapter;
  late NotificationsApi api;

  setUp(() {
    adapter = _NotificationAdapter();
    api = NotificationsApi(
      ApiClient.create(
        tokenStore: InMemoryTokenStore(access: 'access', refresh: 'refresh'),
        apiLang: () => 'uz',
        script: () => UzScript.none,
        refresh: (_) async => null,
        onSessionExpired: () async {},
        adapter: adapter,
      ),
    );
  });

  test('list, unread, read va read-all wire contractlari', () async {
    final page = await api.fetch();
    final unread = await api.unreadCount();
    final read = await api.markRead('notification-1', lang: 'ru');
    final updated = await api.markAllRead();

    expect(page.count, 1);
    expect(page.items.single.storeTypeWire, 'household');
    expect(unread, 4);
    expect(read.isRead, isTrue);
    expect(
      adapter.requests
          .singleWhere((request) => request.path.endsWith('/read/'))
          .query['lang'],
      'ru',
      reason: 'localized POST default uz javobi bilan RU qatorni bosmasin',
    );
    expect(updated, 4);
    expect(
      adapter.requests.map((request) => request.path),
      containsAll([
        '/notifications/',
        '/notifications/unread-count/',
        '/notifications/notification-1/read/',
        '/notifications/read-all/',
      ]),
    );
  });

  test(
    'device registration and deletion use stable additive payload',
    () async {
      final device = await api.registerDevice(
        token: 'fcm-secret-token',
        platform: 'android',
        deviceId: 'device-local-1',
        appVersion: '1.0.0+1',
        locale: 'uz_Cyrl',
      );
      await api.deleteDevice(device.id);

      expect(device.id, 'device-backend-1');
      expect(adapter.requests.first.body, {
        'token': 'fcm-secret-token',
        'platform': 'android',
        'device_id': 'device-local-1',
        'app_version': '1.0.0+1',
        'locale': 'uz_Cyrl',
      });
      expect(adapter.requests.last.method, 'DELETE');
      expect(
        adapter.requests.last.path,
        '/notification-devices/device-backend-1/',
      );
    },
  );
}
