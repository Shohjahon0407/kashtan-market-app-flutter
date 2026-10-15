import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/network_providers.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/storage/secure_token_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_api.dart';
import 'package:beshkashtan_customer/features/auth/data/auth_models.dart';
import 'package:beshkashtan_customer/features/auth/domain/auth_controller.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_api.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/home/data/home_api.dart';
import 'package:beshkashtan_customer/features/home/data/home_models.dart';
import 'package:beshkashtan_customer/features/home/domain/home_controller.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/orders_screen.dart';
import 'package:beshkashtan_customer/features/recommendations/domain/interaction_tracker.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_recommendations_api.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockHomeApi extends Mock implements HomeApi {}

class _MockCartApi extends Mock implements CartApi {}

const _user = AuthUser(
  id: 'u-1',
  phoneNumber: '+998901234567',
  firstName: 'Ali',
  lastName: 'Valiyev',
  role: UserRole.customer,
  isPhoneVerified: true,
  requiresOnboarding: false,
  missingFields: [],
);

const _home = HomeData(
  banners: [],
  storeHub: [
    StoreHubItem(
      storeType: StoreType.grocery,
      storeTypeWire: 'grocery',
      label: 'Oziq-ovqat',
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 0,
    ),
    StoreHubItem(
      storeType: StoreType.meat,
      storeTypeWire: 'meat',
      label: "Go'sht",
      subtitle: '',
      imageUrl: null,
      accentColor: null,
      sortOrder: 1,
    ),
  ],
);

/// Home'dagi Buyurtmalar tabi: barcha do'konlar bitta ro'yxatda, kartada
/// do'kon nomi; badge — faol buyurtmalar soni; mehmon uchun so'rov yo'q.
void main() {
  test('storeType null → so\'rovda store_type yuborilmaydi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _RecordingOrdersApi();
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        ordersApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      ordersControllerProvider(allOrderQueries.first),
      (_, _) {},
    );
    addTearDown(sub.close);
    await container.read(
      ordersControllerProvider(allOrderQueries.first).future,
    );
    expect(api.calls.single, (storeType: null, period: 'today'));
  });

  test('orderQueriesAffectedBy — do\'kon + umumiy ro\'yxat', () {
    final queries = orderQueriesAffectedBy(StoreType.meat).toList();
    expect(queries, hasLength(4));
    expect(queries.where((q) => q.storeType == StoreType.meat), hasLength(2));
    expect(queries.where((q) => q.storeType == null), hasLength(2));
  });

  test('faol buyurtma — yetkazilgan/bekor emas', () {
    expect(isActiveCustomerOrder(_order(id: 'a', status: 'pending')), isTrue);
    expect(isActiveCustomerOrder(_order(id: 'b', status: 'accepted')), isTrue);
    expect(
      isActiveCustomerOrder(_order(id: 'c', status: 'delivered')),
      isFalse,
    );
    expect(
      isActiveCustomerOrder(_order(id: 'd', status: 'cancelled')),
      isFalse,
    );
  });

  testWidgets(
    'barcha do\'konlar ro\'yxati kartada do\'kon nomini ko\'rsatadi',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _RecordingOrdersApi();
      final homeApi = _MockHomeApi();
      when(() => homeApi.fetch()).thenAnswer((_) async => _home);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs),
            ordersApiProvider.overrideWithValue(api),
            homeApiProvider.overrideWithValue(homeApi),
            recommendationsApiProvider.overrideWithValue(
              FakeRecommendationsApi(),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('uz'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: OrdersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('OZIQ-OVQAT'), findsOneWidget);
      // m-1 va m-2 — ikkala go'sht buyurtmasida ham yorliq.
      expect(find.text("GO'SHT"), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('order-store-label-g-1')),
        findsOneWidget,
      );
    },
  );

  test('badge: mehmon uchun 0 va so\'rov yo\'q; kirganda faol soni', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _RecordingOrdersApi();
    final authApi = _MockAuthApi();
    when(() => authApi.me()).thenAnswer((_) async => _user);
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        ordersApiProvider.overrideWithValue(api),
        authApiProvider.overrideWithValue(authApi),
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(access: 'a', refresh: 'r'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(activeOrdersCountProvider, (_, _) {});
    addTearDown(sub.close);

    expect(container.read(activeOrdersCountProvider), 0);
    await Future<void>.delayed(Duration.zero);
    expect(api.calls, isEmpty);

    await container.read(authControllerProvider.notifier).restoreSession();
    await container.read(
      ordersControllerProvider((
        storeType: null,
        period: OrdersPeriod.today,
      )).future,
    );
    // g-1 pending + m-1 accepted faol, m-2 delivered emas.
    expect(container.read(activeOrdersCountProvider), 2);
    expect(api.calls.single, (storeType: null, period: 'today'));
  });

  testWidgets(
    'buyurtmalar ostida tavsiya kartalari, scroll bilan davom etadi',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final homeApi = _MockHomeApi();
      final cartApi = _MockCartApi();
      when(() => homeApi.fetch()).thenAnswer((_) async => _home);
      when(() => cartApi.fetch(any())).thenAnswer(
        (invocation) async =>
            CartData.empty(invocation.positionalArguments.first as String),
      );
      final reco = FakeRecommendationsApi()
        ..pagedItems = [
          for (var i = 0; i < 30; i++)
            ProductSummary.fromJson({
              'id': 'r$i',
              'name': 'Tavsiya $i',
              'price': '15000.00',
              'store_type': i.isEven ? 'grocery' : 'meat',
              'is_purchasable': true,
              'variants': <Object>[],
            }),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsStoreProvider.overrideWithValue(prefs),
            ordersApiProvider.overrideWithValue(_RecordingOrdersApi()),
            homeApiProvider.overrideWithValue(homeApi),
            cartApiProvider.overrideWithValue(cartApi),
            recommendationsApiProvider.overrideWithValue(reco),
          ],
          child: const MaterialApp(
            locale: Locale('uz'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: OrdersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Avval buyurtmalar, keyin "Sizga yoqishi mumkin".
      final orderTop = tester.getTopLeft(
        find.byKey(const ValueKey('order-store-label-g-1')),
      );
      final header = find.byKey(const ValueKey('orders-recommended-header'));
      expect(header, findsOneWidget);
      expect(find.text('Sizga yoqishi mumkin'), findsOneWidget);
      expect(tester.getTopLeft(header).dy, greaterThan(orderTop.dy));
      expect(
        find.byKey(const ValueKey('orders-recommended-r0')),
        findsOneWidget,
      );

      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(reco.forYouRequests.map((r) => r.offset), [0, 20]);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('orders-recommended-r29')),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      expect(
        find.byKey(const ValueKey('orders-recommended-r29')),
        findsOneWidget,
      );
    },
  );
}

class _RecordingOrdersApi extends Fake implements OrdersApi {
  final List<({String? storeType, String? period})> calls = [];

  @override
  Future<OffsetPage<OrderData>> fetch({
    String? storeType,
    String? period,
    String? nextUrl,
  }) async {
    calls.add((storeType: storeType, period: period));
    if (period == 'history') {
      return const OffsetPage(items: [], nextUrl: null, count: 0);
    }
    return OffsetPage(
      items: [
        _order(id: 'g-1', status: 'pending', storeType: 'grocery'),
        _order(id: 'm-1', status: 'accepted', storeType: 'meat'),
        _order(id: 'm-2', status: 'delivered', storeType: 'meat'),
      ],
      nextUrl: null,
      count: 3,
    );
  }
}

OrderData _order({
  required String id,
  required String status,
  String storeType = 'grocery',
}) => OrderData.fromJson({
  'id': id,
  'order_number': 'BK-1',
  'store_type': storeType,
  'fulfillment_type': 'delivery',
  'status': status,
  'user_status': status,
  'subtotal': '12000',
  'delivery_fee': '5000',
  'total': '17000',
  'items': [
    {
      'id': 'item-1',
      'product_id': 'product-1',
      'product_name': 'Olma',
      'quantity': 2,
      'price': '4000',
      'total_price': '8000',
      'addons': <Map<String, dynamic>>[],
    },
  ],
  'created_at': '2026-09-19T10:00:00Z',
});
