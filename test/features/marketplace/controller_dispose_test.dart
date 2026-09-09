import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/json_disk_cache.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/catalog_api.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/domain/catalog_controller.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/payments/data/payment_models.dart';
import 'package:beshkashtan_customer/features/payments/data/payments_api.dart';
import 'package:beshkashtan_customer/features/payments/domain/payme_payment_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

class _MockCatalogApi extends Mock implements CatalogApi {}

class _MockCache extends Mock implements JsonDiskCache {}

class _MockOrdersApi extends Mock implements OrdersApi {}

class _MockCartApi extends Mock implements CartApi {}

class _MockPaymentsApi extends Mock implements PaymentsApi {}

/// WebSocket ochmaydigan realtime stub — tracking controller uni kuzatadi.
class _StubRealtime extends OrderRealtimeController {
  @override
  OrderRealtimeState build() => const OrderRealtimeState();
}

ProductSummary _product(String id) => ProductSummary.fromJson({
  'id': id,
  'name': 'Mahsulot $id',
  'description': '',
  'price': '10000.00',
  'unit_display': 'dona',
  'store_type': 'household',
  'variants': <Map<String, dynamic>>[],
});

final _order = OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'household',
  'fulfillment_type': 'delivery',
  'status': 'pending',
  'status_label': 'Ko‘rib chiqilmoqda',
  'payment_method': 'payme',
  'payment_status': 'pending',
  'subtotal': '12000.00',
  'delivery_fee': '5000.00',
  'total': '17000.00',
  'items': <Map<String, dynamic>>[],
  'created_at': '2026-07-31T10:00:00Z',
});

final _tracking = OrderTrackingData.fromJson({
  'order_number': 'BK-1',
  'status': 'pending',
  'user_status': 'pending',
  'status_label': 'Kutilmoqda',
  'store_type': 'household',
  'fulfillment_type': 'delivery',
});

Future<PrefsStore> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return PrefsStore.load();
}

/// Foydalanuvchi so'rov paytida ekrandan chiqib ketdi (autoDispose provider
/// yo'q bo'ldi), so'ng javob keldi — hech qaysi controller
/// UnmountedRefException tashlamasligi kerak (Riverpod 3 buni release'da ham
/// tashlaydi va Crashlytics'ga fatal sifatida tushardi).
void main() {
  setUpAll(() {
    registerFallbackValue(FulfillmentType.delivery);
  });

  test(
    'catalog: applyFilter va loadMore dispose\'dan keyin jim tugaydi',
    () async {
      final api = _MockCatalogApi();
      final cache = _MockCache();
      when(() => cache.read(any())).thenAnswer((_) async => null);
      when(() => api.fetchProducts(storeType: 'household')).thenAnswer(
        (_) async => CursorPage(items: [_product('a')], nextUrl: 'next'),
      );
      final filtered = Completer<CursorPage<ProductSummary>>();
      when(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: 'tools',
          query: '',
        ),
      ).thenAnswer((_) => filtered.future);
      final more = Completer<CursorPage<ProductSummary>>();
      when(
        () => api.fetchProducts(storeType: 'household', nextUrl: 'next'),
      ).thenAnswer((_) => more.future);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(await _prefs()),
          catalogApiProvider.overrideWithValue(api),
          jsonDiskCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final provider = catalogControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      final loadingMore = notifier.loadMore();
      final filtering = notifier.applyFilter(categoryId: 'tools');
      sub.close();
      await Future<void>.delayed(Duration.zero);

      more.complete(CursorPage(items: [_product('b')], nextUrl: null));
      filtered.completeError(const ServerFailure('', 500));
      await expectLater(loadingMore, completes);
      await expectLater(filtering, completes);
    },
  );

  test(
    'catalog: ayni filtrni yangilash xatosi ro\'yxatni o\'chirmaydi',
    () async {
      final api = _MockCatalogApi();
      final cache = _MockCache();
      when(() => cache.read(any())).thenAnswer((_) async => null);
      // Bitta stub: build (1-chaqiruv) muvaffaqiyatli, refresh (2-chaqiruv)
      // tarmoq xatosi. Alohida stub'lar bir-birini bosib ketadi (defaultlar).
      var calls = 0;
      when(
        () => api.fetchProducts(
          storeType: 'household',
          categoryId: any(named: 'categoryId'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async {
        if (++calls == 1) {
          return CursorPage(items: [_product('a')], nextUrl: null);
        }
        throw const NetworkFailure();
      });
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(await _prefs()),
          catalogApiProvider.overrideWithValue(api),
          jsonDiskCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final provider = catalogControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);

      await container.read(provider.notifier).refresh();

      expect(calls, 2);
      final state = container.read(provider);
      expect(state.hasError, isFalse);
      expect(state.value!.items.map((item) => item.id), ['a']);
    },
  );

  test(
    'checkout: buyurtma yaratilgach ekran yopilsa ham order qaytadi',
    () async {
      final cartApi = _MockCartApi();
      final ordersApi = _MockOrdersApi();
      when(
        () => cartApi.fetch('household'),
      ).thenAnswer((_) async => CartData.empty('household'));
      final creating = Completer<OrderData>();
      when(
        () => ordersApi.create(
          storeType: any(named: 'storeType'),
          fulfillmentType: any(named: 'fulfillmentType'),
          paymentMethod: any(named: 'paymentMethod'),
          addressId: any(named: 'addressId'),
          pickupBranchId: any(named: 'pickupBranchId'),
          note: any(named: 'note'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) => creating.future);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(await _prefs()),
          cartApiProvider.overrideWithValue(cartApi),
          ordersApiProvider.overrideWithValue(ordersApi),
        ],
      );
      addTearDown(container.dispose);
      final provider = checkoutControllerProvider(StoreType.household);
      final sub = container.listen(provider, (_, _) {});

      final submitting = container
          .read(provider.notifier)
          .submit(
            fulfillmentType: FulfillmentType.delivery,
            paymentMethod: PaymentMethod.cash,
            addressId: 'addr-1',
          );
      sub.close();
      await Future<void>.delayed(Duration.zero);
      creating.complete(_order);

      expect((await submitting)?.id, 'order-1');
    },
  );

  test(
    'checkout: idempotency kaliti ekran qayta ochilganda ham saqlanadi',
    () async {
      final cartApi = _MockCartApi();
      final ordersApi = _MockOrdersApi();
      when(
        () => cartApi.fetch('household'),
      ).thenAnswer((_) async => CartData.empty('household'));
      final keys = <String?>[];
      when(
        () => ordersApi.create(
          storeType: any(named: 'storeType'),
          fulfillmentType: any(named: 'fulfillmentType'),
          paymentMethod: any(named: 'paymentMethod'),
          addressId: any(named: 'addressId'),
          pickupBranchId: any(named: 'pickupBranchId'),
          note: any(named: 'note'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        keys.add(invocation.namedArguments[#idempotencyKey] as String?);
        if (keys.length < 3) throw const NetworkFailure();
        return _order;
      });
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(await _prefs()),
          cartApiProvider.overrideWithValue(cartApi),
          ordersApiProvider.overrideWithValue(ordersApi),
        ],
      );
      addTearDown(container.dispose);
      final provider = checkoutControllerProvider(StoreType.household);

      Future<OrderData?> attempt(String note) async {
        final sub = container.listen(provider, (_, _) {});
        try {
          return await container
              .read(provider.notifier)
              .submit(
                fulfillmentType: FulfillmentType.delivery,
                paymentMethod: PaymentMethod.cash,
                addressId: 'addr-1',
                note: note,
              );
        } finally {
          // Savatga qaytish = checkout provider'i dispose bo'ladi.
          sub.close();
          await Future<void>.delayed(Duration.zero);
        }
      }

      await expectLater(attempt('tez'), throwsA(isA<NetworkFailure>()));
      await expectLater(attempt('tez!'), throwsA(isA<NetworkFailure>()));
      expect(await attempt('tez!'), isNotNull);

      expect(keys, hasLength(3));
      expect(
        keys.toSet(),
        hasLength(1),
        reason: 'timeout + izoh o\'zgarishi = ayni kalit',
      );

      // Muvaffaqiyatdan keyin yangi buyurtma yangi kalit oladi.
      await attempt('yangi');
      expect(keys.last, isNot(keys.first));
    },
  );

  test('payme: startPayment dispose\'dan keyin jim tugaydi', () async {
    final paymentsApi = _MockPaymentsApi();
    final ordersApi = _MockOrdersApi();
    final creating = Completer<PaymePaymentCreateResult>();
    when(
      () => paymentsApi.createPaymePayment('order-1'),
    ).thenAnswer((_) => creating.future);
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(await _prefs()),
        paymentsApiProvider.overrideWithValue(paymentsApi),
        ordersApiProvider.overrideWithValue(ordersApi),
        paymentUrlLauncherProvider.overrideWithValue(
          (_, {LaunchMode mode = LaunchMode.platformDefault}) async => true,
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = paymePaymentControllerProvider('order-1');
    final sub = container.listen(provider, (_, _) {});
    final starting = container.read(provider.notifier).startPayment();
    sub.close();
    await Future<void>.delayed(Duration.zero);

    creating.complete(
      const PaymePaymentCreateResult(
        paymentId: 'pay-1',
        paymentUrl: 'https://checkout.paycom.uz/abc',
        status: PaymentStatus.pending,
      ),
    );
    await expectLater(starting, completes);
  });

  test(
    'tracking: poll javobi dispose\'dan keyin jim tugaydi, taymer qolmaydi',
    () async {
      final ordersApi = _MockOrdersApi();
      var calls = 0;
      final pending = Completer<OrderTrackingData>();
      when(() => ordersApi.tracking('order-1')).thenAnswer((_) {
        calls++;
        return calls == 1 ? Future.value(_tracking) : pending.future;
      });
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(await _prefs()),
          ordersApiProvider.overrideWithValue(ordersApi),
          orderRealtimeProvider.overrideWith(_StubRealtime.new),
        ],
      );
      addTearDown(container.dispose);
      final provider = orderTrackingControllerProvider('order-1');
      final sub = container.listen(provider, (_, _) {});
      await container.read(provider.future);

      final refreshing = container.read(provider.notifier).refresh();
      sub.close();
      await Future<void>.delayed(Duration.zero);
      pending.complete(_tracking);
      await expectLater(refreshing, completes);
      expect(calls, 2);
    },
  );
}
