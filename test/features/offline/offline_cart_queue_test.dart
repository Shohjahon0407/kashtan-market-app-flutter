import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
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
      ),
    ).thenAnswer((_) async {});
    when(() => api.updateQuantity(any(), any())).thenAnswer((_) async {});

    await queue.enqueueAdd(
      storeType: 'grocery',
      configuration: _configuration,
      quantity: 2,
    );
    await queue.enqueueSetQuantity('item-1', 3);

    await queue.flush();

    verifyInOrder([
      () => api.addItem(
        storeType: 'grocery',
        configuration: any(named: 'configuration'),
        quantity: 2,
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

      await queue.enqueueSetQuantity('item-1', 3);
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

    await queue.enqueueRemove('item-old');
    await queue.flush();

    expect(queue.isEmpty, isTrue, reason: 'eskirgan amal navbatni bloklamaydi');
  });

  test('set dedupe: bitta element bo‘yicha faqat oxirgi qiymat', () async {
    final (container, api, _) = await _setup();
    final queue = container.read(offlineCartQueueProvider);
    when(() => api.updateQuantity(any(), any())).thenAnswer((_) async {});

    await queue.enqueueSetQuantity('item-1', 2);
    await queue.enqueueSetQuantity('item-1', 5);
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
      ),
    );
    verify(() => api.clear('grocery')).called(1);
  });
}
