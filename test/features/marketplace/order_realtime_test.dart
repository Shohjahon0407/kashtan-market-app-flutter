import 'dart:async';

import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_socket_connector_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockChannel extends Mock implements WebSocketChannel {}

class _MockSink extends Mock implements WebSocketSink {}

class _DelayedTokenStore implements TokenStore {
  final access = Completer<String?>();
  int accessReads = 0;

  @override
  Future<String?> readAccess() {
    accessReads++;
    return access.future;
  }

  @override
  Future<String?> readRefresh() async => 'refresh';

  @override
  Future<void> save({required String access, required String refresh}) async {}

  @override
  Future<void> saveAccess(String access) async {}

  @override
  Future<void> clear() async {}
}

({_MockChannel channel, _MockSink sink, StreamController<dynamic> stream})
socket() {
  final channel = _MockChannel();
  final sink = _MockSink();
  // Returned to the test; every caller registers its close in addTearDown.
  // ignore: close_sinks
  final stream = StreamController<dynamic>();
  when(() => channel.stream).thenAnswer((_) => stream.stream);
  when(() => channel.sink).thenReturn(sink);
  when(() => sink.close(any(), any())).thenAnswer((_) async {});
  when(() => sink.close()).thenAnswer((_) async {});
  return (channel: channel, sink: sink, stream: stream);
}

void main() {
  test('web socket JWTni query fallbackga xavfsiz ko‘chiradi', () {
    final uri = webSocketUriWithBearer(
      Uri.parse('wss://api.beshkashtan.uz/ws/user/orders/?lang=uz'),
      {'Authorization': 'Bearer jwt-access'},
    );

    expect(uri.queryParameters['lang'], 'uz');
    expect(uri.queryParameters['token'], 'jwt-access');
  });

  test('JWT header, lifecycle event va revision ishlaydi', () async {
    final fake = socket();
    Map<String, dynamic>? headers;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'jwt-access'),
        ),
        orderSocketConnectorProvider.overrideWithValue((uri, value) {
          headers = value;
          return fake.channel;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await fake.stream.close();
    });
    final subscription = container.listen(orderRealtimeProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);

    fake.stream.add('{"type":"connection.ready","user_id":"u-1"}');
    await Future<void>.delayed(Duration.zero);
    expect(headers?['Authorization'], 'Bearer jwt-access');
    expect(
      container.read(orderRealtimeProvider).status,
      OrderSocketStatus.connected,
    );

    fake.stream.add(
      '{"type":"order_accepted","order_id":"order-1",'
      '"status":"accepted"}',
    );
    await Future<void>.delayed(Duration.zero);
    final state = container.read(orderRealtimeProvider);
    expect(state.revision, 1);
    expect(state.lastOrderId, 'order-1');
  });

  test('socket uzilganda backoff bilan qayta ulanadi', () async {
    final first = socket();
    final second = socket();
    var connections = 0;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'jwt-access'),
        ),
        orderSocketConnectorProvider.overrideWithValue((uri, headers) {
          connections++;
          return connections == 1 ? first.channel : second.channel;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await first.stream.close();
      await second.stream.close();
    });
    final subscription = container.listen(orderRealtimeProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(connections, 1);

    await first.stream.close();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(connections, 2);
  });

  test('resume token await paytida ikkinchi socket ochmaydi', () async {
    final fake = socket();
    final tokens = _DelayedTokenStore();
    var connections = 0;
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        orderSocketConnectorProvider.overrideWithValue((uri, headers) {
          connections++;
          return fake.channel;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await fake.stream.close();
    });
    final subscription = container.listen(orderRealtimeProvider, (_, _) {});
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);
    expect(tokens.accessReads, 1);
    container.read(orderRealtimeProvider.notifier).resume();
    await Future<void>.delayed(Duration.zero);
    expect(tokens.accessReads, 1, reason: 'parallel token read boshlandi');

    tokens.access.complete('jwt-access');
    await Future<void>.delayed(Duration.zero);
    expect(connections, 1);
  });
}
