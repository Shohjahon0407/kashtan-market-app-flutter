import 'dart:async';
import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/offline_cart_queue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCartApi extends Mock implements CartApi {}

final _ownerProvider = NotifierProvider<_Owner, String>(_Owner.new);

class _Owner extends Notifier<String> {
  @override
  String build() => 'user_A';
  void change(String value) => state = value;
}

Future<(ProviderContainer, _MockCartApi, PrefsStore)> _setup([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await PrefsStore.load();
  final api = _MockCartApi();
  final container = ProviderContainer(
    overrides: [
      prefsStoreProvider.overrideWithValue(prefs),
      cartApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  return (container, api, prefs);
}

const _configuration = CartConfiguration(productId: 'p1', note: 'tez');

void main() {
  test(
    'durable operation IDs are web-safe UUIDs before any HTTP request',
    () async {
      final (container, _, prefs) = await _setup();
      final queue = container.read(offlineCartQueueProvider);
      await queue.enqueueAdd(
        storeType: 'household',
        configuration: _configuration,
        quantity: 1,
      );
      final raw = prefs.getString('cart.offline_queue.v2.guest')!;
      final ops = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(ops.single['operation_id'], matches(uuid));
      expect(ops.single['idempotency_key'], matches(uuid));
      await queue.enqueueSetQuantity('second', 2, storeType: 'household');
      final saved =
          (jsonDecode(prefs.getString('cart.offline_queue.v2.guest')!) as List)
              .cast<Map<String, dynamic>>();
      expect(saved.map((op) => op['operation_id']).toSet(), hasLength(2));
      expect(saved.first['idempotency_key'], ops.first['idempotency_key']);
    },
  );
  test(
    'enqueue during flush is preserved and acknowledged by operation ID',
    () async {
      final (container, api, _) = await _setup();
      final queue = container.read(offlineCartQueueProvider);
      final pending = Completer<void>();
      when(
        () => api.updateQuantity('first', 2),
      ).thenAnswer((_) => pending.future);
      when(
        () => api.updateQuantity('second', 3),
      ).thenThrow(const ServerFailure('retry', 503));
      await queue.enqueueSetQuantity('first', 2, storeType: 'household');
      final flushing = queue.flush();
      await Future<void>.delayed(Duration.zero);
      await queue.enqueueSetQuantity('second', 3, storeType: 'household');
      pending.complete();
      await flushing;
      expect(queue.isEmpty, isFalse);
      when(() => api.updateQuantity('second', 3)).thenAnswer((_) async {});
      await queue.flush();
      expect(queue.isEmpty, isTrue);
      verify(() => api.updateQuantity('first', 2)).called(1);
      verify(() => api.updateQuantity('second', 3)).called(2);
    },
  );

  test('429/500/auth failures retain queued intents', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    await queue.enqueueSetQuantity('item', 2, storeType: 'household');
    for (final failure in [
      const ThrottledFailure('retry'),
      const ServerFailure('', 500),
      const UnauthorizedFailure(),
    ]) {
      when(() => api.updateQuantity('item', 2)).thenThrow(failure);
      await queue.flush();
      expect(queue.isEmpty, isFalse);
    }
  });

  test(
    'account B cannot see or flush A intents; A can resume after login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _MockCartApi();
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(api),
          accountScopeProvider.overrideWith((ref) => ref.watch(_ownerProvider)),
        ],
      );
      addTearDown(container.dispose);
      final a = container.read(offlineCartQueueProvider);
      await a.enqueueSetQuantity('A-item', 2, storeType: 'household');
      container.read(_ownerProvider.notifier).change('user_B');
      await container.pump();
      expect(container.read(offlineCartQueueProvider).isEmpty, isTrue);
      await a.flush();
      verifyNever(() => api.updateQuantity(any(), any()));
      container.read(_ownerProvider.notifier).change('user_A');
      await container.pump();
      final restored = container.read(offlineCartQueueProvider);
      expect(restored.isEmpty, isFalse);
      when(() => api.updateQuantity('A-item', 2)).thenAnswer((_) async {});
      await restored.flush();
      expect(restored.isEmpty, isTrue);
    },
  );

  setUpAll(() {
    registerFallbackValue(_configuration);
  });

  test('navbat diskda saqlanadi va qayta yuklanganda ham turadi', () async {
    final (container, _, prefs) = await _setup();
    final queue = container.read(offlineCartQueueProvider);

    await queue.enqueueAdd(
      storeType: 'grocery',
      configuration: _configuration,
      quantity: 2,
    );
    expect(queue.isEmpty, isFalse);

    // Xuddi shu prefs bilan yangi container — ilova qayta ochilgani kabi.
    final api2 = _MockCartApi();
    final container2 = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        cartApiProvider.overrideWithValue(api2),
      ],
    );
    addTearDown(container2.dispose);
    expect(container2.read(offlineCartQueueProvider).isEmpty, isFalse);
  });

  test('flush: amallar tartib bilan yuboriladi va navbat bo‘shaydi', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    when(
      () => api.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async {});
    when(() => api.updateQuantity(any(), any())).thenAnswer((_) async {});

    await queue.enqueueAdd(
      storeType: 'grocery',
      configuration: _configuration,
      quantity: 2,
    );
    await queue.enqueueSetQuantity('item-1', 3, storeType: 'household');

    await queue.flush();

    verifyInOrder([
      () => api.addItem(
        storeType: 'grocery',
        configuration: any(named: 'configuration'),
        quantity: 2,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
      () => api.updateQuantity('item-1', 3),
    ]);
    expect(queue.isEmpty, isTrue);
  });

  test(
    'flush: hali oflayn bo‘lsa navbat SAQLANADI va ikki marta yuborilmaydi',
    () async {
      final (container, api, _) = await _setup();
      final queue = container.read(offlineCartQueueProvider);
      when(
        () => api.updateQuantity(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));

      await queue.enqueueSetQuantity('item-1', 3, storeType: 'household');
      await queue.flush();

      expect(queue.isEmpty, isFalse, reason: 'amal yo‘qolmasligi kerak');

      // Internet qaytdi — endi ketadi, faqat BIR marta qo'shimcha.
      when(() => api.updateQuantity(any(), any())).thenAnswer((_) async {});
      await queue.flush();
      expect(queue.isEmpty, isTrue);
      verify(() => api.updateQuantity('item-1', 3)).called(2); // 1 xato + 1 OK
    },
  );

  test('flush: 4xx (element yo‘q) amalni tashlab yuboradi', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    when(() => api.deleteItem(any())).thenThrow(const NotFoundFailure('yo‘q'));

    await queue.enqueueRemove('item-old', storeType: 'household');
    await queue.flush();

    expect(queue.isEmpty, isTrue, reason: 'eskirgan amal navbatni bloklamaydi');
  });

  test('set dedupe: bitta element bo‘yicha faqat oxirgi qiymat', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    when(() => api.updateQuantity(any(), any())).thenAnswer((_) async {});

    await queue.enqueueSetQuantity('item-1', 2, storeType: 'household');
    await queue.enqueueSetQuantity('item-1', 5, storeType: 'household');
    await queue.flush();

    verify(() => api.updateQuantity('item-1', 5)).called(1);
    verifyNever(() => api.updateQuantity('item-1', 2));
  });

  test('clear do‘konning oldingi amallarini yutadi', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    when(() => api.clear(any())).thenAnswer((_) async {});

    await queue.enqueueAdd(
      storeType: 'grocery',
      configuration: _configuration,
      quantity: 1,
    );
    await queue.enqueueClear('grocery');
    await queue.flush();

    verifyNever(
      () => api.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    );
    verify(() => api.clear('grocery')).called(1);
  });
}
