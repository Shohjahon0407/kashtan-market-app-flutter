import 'dart:async';

import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _MockChannel extends Mock implements WebSocketChannel {}

class _MockSink extends Mock implements WebSocketSink {}

/// Ilova fonga tushganda socket, heartbeat, watchdog va 30 s REST fallback
/// to'xtaydi; resume'da qayta ulanadi. Aks holda ekran o'chiq turganda ham
/// har 30 s ro'yxatlar so'raladi (batareya/radio).
void main() {
  test('pause hamma timerni to\'xtatadi, resume qayta ulaydi', () async {
    var connects = 0;
    final streams = <StreamController<dynamic>>[];
    final sinks = <_MockSink>[];
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'jwt-access'),
        ),
        orderSocketConnectorProvider.overrideWithValue((uri, headers) {
          connects++;
          final channel = _MockChannel();
          final sink = _MockSink();
          // ignore: close_sinks
          final stream = StreamController<dynamic>();
          streams.add(stream);
          sinks.add(sink);
          when(() => channel.stream).thenAnswer((_) => stream.stream);
          when(() => channel.sink).thenReturn(sink);
          when(() => sink.close(any(), any())).thenAnswer((_) async {});
          when(() => sink.close()).thenAnswer((_) async {});
          when(() => sink.add(any<dynamic>())).thenReturn(null);
          return channel;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      for (final stream in streams) {
        await stream.close();
      }
    });
    final subscription = container.listen(orderRealtimeProvider, (_, _) {});
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    streams.single.add('{"type":"connection.ready","user_id":"u-1"}');
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(orderRealtimeProvider.notifier);
    expect(connects, 1);
    expect(notifier.hasScheduledWork, isTrue);

    notifier.pause();
    expect(notifier.isPaused, isTrue);
    expect(notifier.hasScheduledWork, isFalse);
    verify(() => sinks.first.close()).called(1);
    expect(
      container.read(orderRealtimeProvider).status,
      OrderSocketStatus.disconnected,
    );
    // Idempotent.
    notifier.pause();
    expect(connects, 1);

    notifier.resume();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.isPaused, isFalse);
    expect(connects, 2, reason: 'resume yangi socket ochadi');
    streams.last.add('{"type":"connection.ready","user_id":"u-1"}');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.hasScheduledWork, isTrue);
  });
}
