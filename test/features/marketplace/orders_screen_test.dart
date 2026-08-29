import 'dart:async';

import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/network/paginated.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/orders_screen.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_status_badge.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'today/history providerlari alohida pagination holatini saqlaydi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsStore.load();
      final api = _RecordingOrdersApi(paginateToday: true);
      final container = ProviderContainer(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          ordersApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      const todayQuery = (
        storeType: StoreType.grocery,
        period: OrdersPeriod.today,
      );
      const historyQuery = (
        storeType: StoreType.grocery,
        period: OrdersPeriod.history,
      );
      final todaySubscription = container.listen(
        ordersControllerProvider(todayQuery),
        (_, _) {},
      );
      final historySubscription = container.listen(
        ordersControllerProvider(historyQuery),
        (_, _) {},
      );
      addTearDown(todaySubscription.close);
      addTearDown(historySubscription.close);

      await Future.wait([
        container.read(ordersControllerProvider(todayQuery).future),
        container.read(ordersControllerProvider(historyQuery).future),
      ]);
      await container
          .read(ordersControllerProvider(todayQuery).notifier)
          .loadMore();

      expect(
        container.read(ordersControllerProvider(todayQuery)).value?.items,
        hasLength(2),
      );
      expect(
        container.read(ordersControllerProvider(historyQuery)).value?.items,
        hasLength(1),
      );
      expect(
        api.calls,
        contains((
          storeType: 'grocery',
          period: 'today',
          nextUrl: '/orders/?period=today&offset=20',
        )),
      );
    },
  );

  test('sekin eski pagination yangi refresh natijasini bosmaydi', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _RacingOrdersApi();
    final container = ProviderContainer(
      overrides: [
        prefsStoreProvider.overrideWithValue(prefs),
        ordersApiProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    const query = (storeType: StoreType.grocery, period: OrdersPeriod.today);
    final subscription = container.listen(
      ordersControllerProvider(query),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await container.read(ordersControllerProvider(query).future);
    final loadMore = container
        .read(ordersControllerProvider(query).notifier)
        .loadMore();
    await api.loadMoreStarted.future;
    await container.read(ordersControllerProvider(query).notifier).refresh();
    api.loadMoreResult.complete(
      OffsetPage(items: [_order(id: 'stale-page')], nextUrl: null, count: 2),
    );
    await loadMore;

    final state = container.read(ordersControllerProvider(query)).value!;
    expect(state.items.map((item) => item.id), ['fresh-refresh']);
    expect(state.isLoadingMore, isFalse);
  });

  testWidgets('minimal card va Today/History tablari statuslarni ko‘rsatadi', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _RecordingOrdersApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          ordersApiProvider.overrideWithValue(api),
        ],
        child: _localizedApp(const OrdersScreen(storeType: StoreType.grocery)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Bugungi'), findsOneWidget);
    expect(find.text('Tarix'), findsOneWidget);
    expect(find.text('Olma × 2'), findsOneWidget);
    expect(find.text('+1 ta mahsulot'), findsOneWidget);
    expect(find.text('Kuryer qidirilmoqda'), findsOneWidget);
    expect(find.textContaining('BK-SECRET'), findsNothing);
    expect(find.text("17\u00A0000 so'm"), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Yetkazildi'), findsOneWidget);
    final delivered = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('order-status-delivered')),
    );
    expect(
      (delivered.decoration as BoxDecoration).color,
      const Color(0xFFE2F7EB),
    );
  });

  testWidgets('disableAnimations searching va courier motionni o‘chiradi', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(
              children: [
                OrderStatusBadge(stage: CustomerOrderStage.searching),
                OrderStatusBadge(stage: CustomerOrderStage.onWay),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('order-searching-animation')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('order-on-way-animation')), findsNothing);
  });

  testWidgets('beshta status alohida rangda, faqat ikki status animatsiyali', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        const Scaffold(
          body: Column(
            children: [
              OrderStatusBadge(stage: CustomerOrderStage.searching),
              OrderStatusBadge(stage: CustomerOrderStage.accepted),
              OrderStatusBadge(stage: CustomerOrderStage.onWay),
              OrderStatusBadge(stage: CustomerOrderStage.delivered),
              OrderStatusBadge(stage: CustomerOrderStage.cancelled),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    const expected = {
      CustomerOrderStage.searching: (
        background: Color(0xFFFFF3D0),
        foreground: Color(0xFF8A5A00),
      ),
      CustomerOrderStage.accepted: (
        background: Color(0xFFE5F0FF),
        foreground: Color(0xFF175EA8),
      ),
      CustomerOrderStage.onWay: (
        background: Color(0xFFF0E8FF),
        foreground: Color(0xFF6A3FA0),
      ),
      CustomerOrderStage.delivered: (
        background: Color(0xFFE2F7EB),
        foreground: Color(0xFF087847),
      ),
      CustomerOrderStage.cancelled: (
        background: Color(0xFFFFE7E4),
        foreground: Color(0xFFB3261E),
      ),
    };
    for (final entry in expected.entries) {
      final badge = find.byKey(ValueKey('order-status-${entry.key.name}'));
      final decoration = tester.widget<DecoratedBox>(badge).decoration;
      expect((decoration as BoxDecoration).color, entry.value.background);
      final text = tester.widget<Text>(
        find.descendant(of: badge, matching: find.byType(Text)),
      );
      expect(text.style?.color, entry.value.foreground);
    }

    expect(
      find.byKey(const ValueKey('order-searching-animation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('order-on-way-animation')),
      findsOneWidget,
    );
    for (final stage in [
      CustomerOrderStage.accepted,
      CustomerOrderStage.delivered,
      CustomerOrderStage.cancelled,
    ]) {
      final badge = find.byKey(ValueKey('order-status-${stage.name}'));
      expect(
        find.descendant(of: badge, matching: find.byType(SlideTransition)),
        findsNothing,
      );
      expect(
        find.descendant(of: badge, matching: find.byType(ScaleTransition)),
        findsNothing,
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('uz'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class _RecordingOrdersApi extends Fake implements OrdersApi {
  _RecordingOrdersApi({this.paginateToday = false});

  final bool paginateToday;
  final List<({String storeType, String? period, String? nextUrl})> calls = [];

  @override
  Future<OffsetPage<OrderData>> fetch({
    required String storeType,
    String? period,
    String? nextUrl,
  }) async {
    calls.add((storeType: storeType, period: period, nextUrl: nextUrl));
    if (period == 'history') {
      return OffsetPage(
        items: [_order(status: 'delivered')],
        nextUrl: null,
        count: 1,
      );
    }
    if (nextUrl != null) {
      return OffsetPage(
        items: [_order(id: 'order-2', status: 'accepted')],
        nextUrl: null,
        count: 2,
      );
    }
    return OffsetPage(
      items: [_order()],
      nextUrl: paginateToday ? '/orders/?period=today&offset=20' : null,
      count: paginateToday ? 2 : 1,
    );
  }
}

class _RacingOrdersApi extends Fake implements OrdersApi {
  final loadMoreStarted = Completer<void>();
  final loadMoreResult = Completer<OffsetPage<OrderData>>();
  int firstPageCalls = 0;

  @override
  Future<OffsetPage<OrderData>> fetch({
    required String storeType,
    String? period,
    String? nextUrl,
  }) async {
    if (nextUrl != null) {
      loadMoreStarted.complete();
      return loadMoreResult.future;
    }
    firstPageCalls++;
    if (firstPageCalls == 1) {
      return OffsetPage(
        items: [_order(id: 'initial')],
        nextUrl: '/orders/?period=today&offset=20',
        count: 2,
      );
    }
    return OffsetPage(
      items: [_order(id: 'fresh-refresh')],
      nextUrl: null,
      count: 1,
    );
  }
}

OrderData _order({String id = 'order-1', String status = 'pending'}) =>
    OrderData.fromJson({
      'id': id,
      'order_number': 'BK-SECRET',
      'store_type': 'grocery',
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
        {
          'id': 'item-2',
          'product_id': 'product-2',
          'product_name': 'Nok',
          'quantity': 1,
          'price': '4000',
          'total_price': '4000',
          'addons': <Map<String, dynamic>>[],
        },
      ],
      'created_at': '2026-08-09T08:00:00Z',
    });
