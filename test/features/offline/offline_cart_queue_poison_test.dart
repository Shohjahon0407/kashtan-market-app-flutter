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

/// Navbat boshidagi bitta "zaharli" amal keyingi BARCHA amallarni abadiy
/// bloklamasligi kerak (ilgari o'chirilgan mahsulotning `add` op'i 404 da
/// navbatda qolib, remove/miqdor amallari hech qachon serverga yetmasdi).
void main() {
  Future<(ProviderContainer, _MockCartApi)> setup() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _MockCartApi();
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        cartApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    return (container, api);
  }

  setUpAll(() {
    registerFallbackValue(const CartConfiguration(productId: 'x'));
  });

  test('serverda o\'chirilgan mahsulot (404) add op\'i tashlanadi, '
      'keyingi amallar yuboriladi', () async {
    final (container, api) = await setup();
    final queue = container.read(offlineCartQueueProvider);
    when(
      () => api.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(const NotFoundFailure());
    when(() => api.deleteItem('item-9')).thenAnswer((_) async {});

    await queue.enqueueAdd(
      storeType: 'household',
      configuration: const CartConfiguration(productId: 'deleted'),
      quantity: 1,
    );
    await queue.enqueueRemove('item-9');

    await queue.flush();

    expect(queue.isEmpty, isTrue);
    verify(() => api.deleteItem('item-9')).called(1);
  });

  test('qat\'iy 400 (ValidationFailure) ham add op\'ini tashlaydi', () async {
    final (container, api) = await setup();
    final queue = container.read(offlineCartQueueProvider);
    when(
      () => api.addItem(
        storeType: any(named: 'storeType'),
        configuration: any(named: 'configuration'),
        quantity: any(named: 'quantity'),
      ),
    ).thenThrow(const ValidationFailure('sotuvda yo\'q', {}));

    await queue.enqueueAdd(
      storeType: 'household',
      configuration: const CartConfiguration(productId: 'sold-out'),
      quantity: 1,
    );
    await queue.flush();

    expect(queue.isEmpty, isTrue);
  });

  test('5xx bir necha urinishdan keyin navbatni bo\'shatadi', () async {
    final (container, api) = await setup();
    final queue = container.read(offlineCartQueueProvider);
    when(
      () => api.updateQuantity('item', 2),
    ).thenThrow(const ServerFailure('', 503));
    when(() => api.deleteItem('other')).thenAnswer((_) async {});

    await queue.enqueueSetQuantity('item', 2);
    await queue.enqueueRemove('other');

    // Dastlabki urinishlarda niyat saqlanadi (vaqtinchalik xato bo'lishi mumkin).
    for (var i = 0; i < 4; i++) {
      await queue.flush();
      expect(queue.isEmpty, isFalse);
      verifyNever(() => api.deleteItem('other'));
    }
    // Chegaraga yetgach zaharli amal tashlanadi va qolgani ketadi.
    await queue.flush();
    expect(queue.isEmpty, isTrue);
    verify(() => api.deleteItem('other')).called(1);
  });

  test(
    'tarmoq xatosi urinish hisoblanmaydi — navbat to\'liq saqlanadi',
    () async {
      final (container, api) = await setup();
      final queue = container.read(offlineCartQueueProvider);
      when(
        () => api.updateQuantity('item', 2),
      ).thenThrow(const NetworkFailure());
      await queue.enqueueSetQuantity('item', 2);
      for (var i = 0; i < 10; i++) {
        await queue.flush();
      }
      expect(queue.isEmpty, isFalse);
    },
  );
}
