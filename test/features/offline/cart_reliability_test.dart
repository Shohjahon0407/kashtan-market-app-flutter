import 'dart:async';
import 'dart:convert';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/offline_cart_queue.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends Mock implements CartApi {}

void main() {
  const config = CartConfiguration(productId: 'p');
  setUpAll(() => registerFallbackValue(config));

  test(
    'guest journal moves durably before merge token is acknowledged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      await prefs.setString(
        'cart.offline_queue.v2.guest',
        jsonEncode([
          {
            'type': 'add',
            'operation_id': 'guest-op',
            'idempotency_key': 'key',
            'store_type': 'household',
            'product_id': 'p',
            'quantity': 1,
          },
        ]),
      );
      final api = _Api();
      when(() => api.mergeGuestCart()).thenAnswer((_) async => true);
      when(() => api.completeGuestMerge()).thenAnswer((_) async {
        expect(
          prefs.getString('cart.offline_queue.v2.user_A'),
          contains('guest-op'),
        );
        expect(prefs.getString('cart.offline_queue.v2.guest'), isNull);
      });
      when(
        () => api.addItem(
          storeType: 'household',
          configuration: any(named: 'configuration'),
          quantity: 1,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(const NetworkFailure());
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(api),
          accountScopeProvider.overrideWithValue('user_A'),
        ],
      );
      addTearDown(container.dispose);
      await container.read(guestCartCoordinatorProvider).mergeIfNeeded();
      expect(container.read(offlineCartQueueProvider).isEmpty, isFalse);
      verify(() => api.completeGuestMerge()).called(1);
    },
  );

  test(
    'late merge completion cannot adopt guest work into a different account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      await prefs.setString('cart.offline_queue.v2.guest', '[]');
      final api = _Api();
      final pending = Completer<bool>();
      when(() => api.mergeGuestCart()).thenAnswer((_) => pending.future);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(api),
          accountScopeProvider.overrideWithValue('user_A'),
        ],
      );
      addTearDown(container.dispose);
      final merging = container
          .read(guestCartCoordinatorProvider)
          .mergeIfNeeded();
      container.updateOverrides([
        prefsStoreProvider.overrideWithValue(prefs),
        cartApiProvider.overrideWithValue(api),
        accountScopeProvider.overrideWithValue('user_B'),
      ]);
      await container.pump();
      pending.complete(true);
      await merging;
      expect(prefs.getString('cart.offline_queue.v2.guest'), '[]');
      expect(prefs.getString('cart.offline_queue.v2.user_B'), isNull);
      verifyNever(() => api.completeGuestMerge());
    },
  );

  test('lost POST response and restart replay the persisted key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _Api();
    final keys = <String>[];
    var committed = false;
    when(
      () => api.addItem(
        storeType: 'household',
        configuration: any(named: 'configuration'),
        quantity: 1,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((call) async {
      final stored =
          jsonDecode(prefs.getString('cart.offline_queue.v2.guest')!) as List;
      expect(
        (stored.single as Map<String, dynamic>)['idempotency_key'],
        call.namedArguments[#idempotencyKey],
      );
      keys.add(call.namedArguments[#idempotencyKey] as String);
      if (!committed) {
        committed = true;
        throw const NetworkFailure();
      }
    });
    ProviderContainer open() => ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        cartApiProvider.overrideWithValue(api),
      ],
    );
    final first = open();
    await expectLater(
      first
          .read(offlineCartQueueProvider)
          .submitAdd(
            storeType: 'household',
            configuration: config,
            quantity: 1,
          ),
      throwsA(isA<NetworkFailure>()),
    );
    first.dispose();
    final second = open();
    addTearDown(second.dispose);
    await second.read(offlineCartQueueProvider).flush();
    expect(keys.length, 2);
    expect(keys.first, keys.last);
    expect(second.read(offlineCartQueueProvider).isEmpty, isTrue);
  });

  test(
    'clear waits for an in-flight add and removes same-store stale sets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _Api();
      final pending = Completer<void>();
      final started = Completer<void>();
      final calls = <String>[];
      when(
        () => api.addItem(
          storeType: 'household',
          configuration: any(named: 'configuration'),
          quantity: 1,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        started.complete();
        await pending.future;
        calls.add('add');
      });
      when(() => api.clear('household')).thenAnswer((_) async {
        calls.add('clear');
      });
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(offlineCartQueueProvider);
      final add = queue.submitAdd(
        storeType: 'household',
        configuration: config,
        quantity: 1,
      );
      await started.future;
      await queue.enqueueSetQuantity('stale', 2, storeType: 'household');
      final clear = queue.submitClear('household');
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      pending.complete();
      await Future.wait([add, clear]);
      expect(calls, ['add', 'clear']);
      expect(queue.isEmpty, isTrue);
      verifyNever(() => api.updateQuantity('stale', 2));
    },
  );

  test(
    'checkout disk intent preserves original payload across restart and account changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final first = CheckoutIdempotencyStore(prefs, 'A');
      final entry = await first.prepare(StoreType.household, {
        'revision': 4,
        'address': 'old',
        'note': 'old',
      });
      final restarted = CheckoutIdempotencyStore(prefs, 'A');
      expect(
        await restarted.prepare(StoreType.household, {
          'revision': 9,
          'address': 'new',
        }),
        entry,
      );
      expect(
        CheckoutIdempotencyStore(prefs, 'B').pending(StoreType.household),
        isNull,
      );
      await restarted.acknowledge(StoreType.household);
      final next = await restarted.prepare(StoreType.household, {
        'revision': 9,
      });
      expect(next['key'], isNot(entry['key']));
    },
  );
  test(
    'guest retry adjusts only guest quantity after merging into an existing line',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _Api();
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          cartApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final queue = container.read(offlineCartQueueProvider);
      var offline = true;
      when(
        () => api.addItem(
          storeType: 'household',
          configuration: any(named: 'configuration'),
          quantity: 2,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        if (offline) throw const NetworkFailure();
      });
      when(() => api.addedItemId(any())).thenReturn('merged');
      when(() => api.addedQuantityOffset(any())).thenReturn(4);
      when(() => api.fetch('household')).thenAnswer(
        (_) async => CartData.fromJson({
          'items': [
            {
              'id': 'merged',
              'product': {
                'id': 'p',
                'name': 'p',
                'store_type': 'household',
                'price': '1000',
              },
              'quantity': 6,
              'subtotal': '6000',
            },
          ],
        }),
      );
      when(() => api.updateQuantity('merged', 7)).thenAnswer((_) async {});
      await expectLater(
        queue.submitAdd(
          storeType: 'household',
          configuration: config,
          quantity: 2,
        ),
        throwsA(isA<NetworkFailure>()),
      );
      await queue.enqueueAdd(
        storeType: 'household',
        configuration: config,
        quantity: 3,
      );
      offline = false;
      await queue.flush();
      verify(() => api.updateQuantity('merged', 7)).called(1);
      expect(queue.isEmpty, isTrue);
    },
  );
}
