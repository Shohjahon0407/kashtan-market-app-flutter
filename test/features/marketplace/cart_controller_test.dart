import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/cart/domain/offline_cart_queue.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCartApi extends Mock implements CartApi {}

final _product = ProductSummary.fromJson({
  'id': 'product-1',
  'name': 'Sovun',
  'description': '',
  'price': '12000.00',
  'main_image': null,
  'unit_display': 'dona',
  'is_purchasable': true,
  'store_type': 'household',
  'store': {'id': 'store-1', 'name': 'Xozmak', 'store_type': 'household'},
  'variants': <Map<String, dynamic>>[],
});

CartData _cartWithQuantity(int quantity) => CartData(
  id: 'cart-1',
  storeTypeWire: 'household',
  items: quantity == 0
      ? const []
      : [
          CartItem(
            id: 'item-1',
            product: _product,
            quantity: quantity,
            selectedAddons: const [],
            note: '',
            subtotal: '${12000 * quantity}.00',
          ),
        ],
  totalItems: quantity == 0 ? 0 : 1,
  totalQuantity: quantity,
  subtotal: '${12000 * quantity}.00',
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CartConfiguration(productId: 'fallback-product'),
    );
  });

  Future<ProviderContainer> containerWith(_MockCartApi api) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        cartApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('to‘rtta StoreType savati alohida family state oladi', () async {
    final api = _MockCartApi();
    when(() => api.fetch(any())).thenAnswer((invocation) async {
      final wire = invocation.positionalArguments.single as String;
      return CartData.empty(wire);
    });
    final container = await containerWith(api);
    final subscriptions = <ProviderSubscription<AsyncValue<CartState>>>[];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });

    for (final storeType in StoreType.values) {
      final provider = cartControllerProvider(storeType);
      subscriptions.add(container.listen(provider, (_, _) {}));
      final state = await container.read(provider.future);
      expect(state.cart.storeTypeWire, storeType.wire);
    }

    verify(() => api.fetch('grocery')).called(1);
    verify(() => api.fetch('household')).called(1);
    verify(() => api.fetch('restaurant')).called(1);
    verify(() => api.fetch('shashlik')).called(1);
  });

  test(
    'absolute quantity changes 10 to 20; no-op and invalid edits send nothing',
    () async {
      final api = _MockCartApi();
      var quantity = 10;
      when(
        () => api.fetch('household'),
      ).thenAnswer((_) async => _cartWithQuantity(quantity));
      when(() => api.updateQuantity('item-1', any())).thenAnswer((
        invocation,
      ) async {
        quantity = invocation.positionalArguments[1] as int;
      });
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final item = container.read(provider).value!.cart.items.single;
      expect(await controller.setQuantity(item, 10), isTrue);
      verifyNever(() => api.updateQuantity(any(), any()));
      expect(await controller.setQuantity(item, 20), isTrue);
      expect(container.read(provider).value!.cart.items.single.quantity, 20);
      verify(() => api.updateQuantity('item-1', 20)).called(1);
      verifyNever(
        () => api.addItem(
          storeType: any(named: 'storeType'),
          configuration: any(named: 'configuration'),
          quantity: any(named: 'quantity'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
      expect(await controller.setQuantity(item, 0), isFalse);
      expect(await controller.setQuantity(item, 1000000), isFalse);
      verifyNever(() => api.updateQuantity(any(), any()));
    },
  );

  test(
    'absolute quantity failure rolls back and keeps the original configuration',
    () async {
      final api = _MockCartApi();
      final first = _cartWithQuantity(10).items.single;
      const addon = SelectedAddon(id: 'sauce', name: 'Sauce', price: '1000');
      final configured = CartItem(
        id: 'configured',
        product: _product,
        quantity: 3,
        variant: ProductVariant.fromJson({
          'id': 'variant',
          'name': 'Variant',
          'price': '12000',
        }),
        selectedAddons: const [addon],
        note: 'Leave at gate',
        subtotal: '39000',
      );
      final fixture = _cartWithQuantity(
        10,
      ).copyWith(items: [first, configured]);
      when(() => api.fetch('household')).thenAnswer((_) async => fixture);
      when(
        () => api.updateQuantity('configured', 20),
      ).thenThrow(const ServerFailure('no', 500));
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      expect(
        await container.read(provider.notifier).setQuantity(configured, 20),
        isFalse,
      );
      final items = container.read(provider).value!.cart.items;
      expect(items.first.quantity, 10);
      expect(items.last.quantity, 3);
      expect(items.last.note, 'Leave at gate');
      expect(items.last.variant?.id, 'variant');
      expect(items.last.selectedAddons.single.id, 'sauce');
      expect(
        container.read(provider).value!.mutationFailure,
        isA<ServerFailure>(),
      );
      verifyNever(() => api.updateQuantity('item-1', any()));
    },
  );

  test(
    'successful add followed by failed GET is NOT queued for another add',
    () async {
      final api = _MockCartApi();
      var calls = 0;
      when(() => api.fetch('household')).thenAnswer((_) async {
        if (++calls > 1) throw const NetworkFailure();
        return _cartWithQuantity(0);
      });
      when(
        () => api.addItem(
          storeType: 'household',
          configuration: any(named: 'configuration'),
          quantity: 1,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {});
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      // Yozuv serverga yetdi — mahsulot savatda, shuning uchun `true`;
      // lekin GET xato bergani uchun konfiguratsiya "tasdiqlanmagan" bo'lib,
      // UI "Sotib olish"ni qayta ko'rsatmaydi (2 dona bo'lib qolmasin).
      expect(
        await container.read(provider.notifier).addProduct(_product),
        isTrue,
      );
      expect(container.read(offlineCartQueueProvider).isEmpty, isTrue);
      expect(container.read(provider).value!.busyKeys, isEmpty);
      expect(
        container.read(provider).value!.unconfirmedKeys,
        contains(CartConfiguration(productId: _product.id).identity),
      );
      expect(
        container.read(provider).value!.mutationFailure,
        isA<NetworkFailure>(),
      );
      verify(
        () => api.addItem(
          storeType: 'household',
          configuration: any(named: 'configuration'),
          quantity: 1,
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  test(
    'clear cannot race an in-flight quantity change, but is NOT dropped',
    () async {
      final api = _MockCartApi();
      final pending = Completer<void>();
      when(
        () => api.fetch('household'),
      ).thenAnswer((_) async => _cartWithQuantity(1));
      when(
        () => api.updateQuantity('item-1', 2),
      ).thenAnswer((_) => pending.future);
      when(() => api.clear('household')).thenAnswer((_) async {});
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final initial = await container.read(provider.future);
      final changing = container
          .read(provider.notifier)
          .increment(initial.cart.items.single);
      final clearing = container.read(provider.notifier).clear();

      // Miqdor so'rovi ketayotganda tozalash HALI yuborilmaydi — ikki yozuv
      // serverda bir-biriga aralashib ketmasligi kerak.
      verifyNever(() => api.clear(any()));
      // Ammo u tashlab ham yuborilmaydi: navbatda turadi va bandligi
      // ko'rinadi (foydalanuvchi tugmani bekorga bosmagan).
      expect(
        container.read(provider).value!.isBusy(CartMutationKeys.clear),
        isTrue,
      );

      pending.complete();
      await changing;
      await clearing;

      verify(() => api.clear('household')).called(1);
      expect(container.read(provider).value!.busyKeys, isEmpty);
    },
  );

  test(
    'bir xil konfiguratsiya duplicate line yaratmay, PATCH qiladi',
    () async {
      final api = _MockCartApi();
      var serverCart = _cartWithQuantity(1);
      when(() => api.fetch('household')).thenAnswer((_) async => serverCart);
      when(() => api.updateQuantity('item-1', 2)).thenAnswer((_) async {
        serverCart = _cartWithQuantity(2);
      });
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      await container.read(provider.notifier).addProduct(_product);

      expect(container.read(provider).value?.cart.totalQuantity, 2);
      verify(() => api.updateQuantity('item-1', 2)).called(1);
      verifyNever(
        () => api.addItem(
          storeType: any(named: 'storeType'),
          configuration: any(named: 'configuration'),
          quantity: any(named: 'quantity'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    },
  );

  test('ketma-ket beshta add bitta quantity=5 POST ga birlashadi', () async {
    final api = _MockCartApi();
    var serverCart = _cartWithQuantity(0);
    when(() => api.fetch('household')).thenAnswer((_) async => serverCart);
    when(
      () => api.addItem(
        storeType: 'household',
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      final quantity = invocation.namedArguments[#quantity] as int;
      serverCart = _cartWithQuantity(quantity);
    });
    final container = await containerWith(api);
    final provider = cartControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final writes = <Future<bool>>[
      for (var i = 0; i < 5; i++)
        container.read(provider.notifier).addProduct(_product),
    ];

    expect(container.read(provider).value?.cart.totalQuantity, 5);
    await Future.wait(writes);

    expect(container.read(provider).value?.cart.totalQuantity, 5);
    verify(
      () => api.addItem(
        storeType: 'household',
        configuration: any(named: 'configuration'),
        quantity: 5,
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
    verifyNever(() => api.updateQuantity(any(), any()));
  });

  test('so‘rov davomida bosilgan plus ham yo‘qolmaydi', () async {
    final api = _MockCartApi();
    final firstPatch = Completer<void>();
    var serverCart = _cartWithQuantity(1);
    final sentQuantities = <int>[];
    when(() => api.fetch('household')).thenAnswer((_) async => serverCart);
    when(() => api.updateQuantity('item-1', any())).thenAnswer((invocation) {
      final quantity = invocation.positionalArguments[1] as int;
      sentQuantities.add(quantity);
      if (quantity == 2) return firstPatch.future;
      serverCart = _cartWithQuantity(quantity);
      return Future<void>.value();
    });
    final container = await containerWith(api);
    final provider = cartControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);

    final first = container
        .read(provider.notifier)
        .increment(initial.cart.items.single);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(sentQuantities, [2]);

    final visible = container.read(provider).value!.cart.items.single;
    final second = container.read(provider.notifier).increment(visible);
    expect(container.read(provider).value!.cart.totalQuantity, 3);

    firstPatch.complete();
    await Future.wait([first, second]);

    expect(sentQuantities, [2, 3]);
    expect(container.read(provider).value!.cart.totalQuantity, 3);
  });

  test('mutation xatosida optimistik quantity rollback bo‘ladi', () async {
    // Server xatosi (5xx) — rollback. NetworkFailure esa endi rollback EMAS:
    // u oflayn navbatga tushadi (quyidagi alohida test).
    final api = _MockCartApi();
    when(
      () => api.fetch('household'),
    ).thenAnswer((_) async => _cartWithQuantity(1));
    when(
      () => api.updateQuantity('item-1', 2),
    ).thenThrow(const ServerFailure('server yiqildi', 500));
    final container = await containerWith(api);
    final provider = cartControllerProvider(StoreType.household);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);

    await container
        .read(provider.notifier)
        .increment(initial.cart.items.single);

    final result = container.read(provider).value!;
    expect(result.cart.items.single.quantity, 1);
    expect(result.mutationFailure, isA<ServerFailure>());
  });

  test(
    'quantity 1 dan kamaytirish DELETE va server reconcile qiladi',
    () async {
      final api = _MockCartApi();
      var serverCart = _cartWithQuantity(1);
      when(() => api.fetch('household')).thenAnswer((_) async => serverCart);
      when(() => api.deleteItem('item-1')).thenAnswer((_) async {
        serverCart = _cartWithQuantity(0);
      });
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);

      await container
          .read(provider.notifier)
          .decrement(initial.cart.items.single);

      expect(container.read(provider).value?.cart.items, isEmpty);
      verify(() => api.deleteItem('item-1')).called(1);
    },
  );
}
