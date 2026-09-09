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
        ),
      ).called(1);
    },
  );

  test(
    'clear cannot race an in-flight quantity change in the same store',
    () async {
      final api = _MockCartApi();
      final pending = Completer<void>();
      when(
        () => api.fetch('household'),
      ).thenAnswer((_) async => _cartWithQuantity(1));
      when(
        () => api.updateQuantity('item-1', 2),
      ).thenAnswer((_) => pending.future);
      final container = await containerWith(api);
      final provider = cartControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final initial = await container.read(provider.future);
      final changing = container
          .read(provider.notifier)
          .increment(initial.cart.items.single);
      await container.read(provider.notifier).clear();
      verifyNever(() => api.clear(any()));
      pending.complete();
      await changing;
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
        ),
      );
    },
  );

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
