import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/order_realtime_controller.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/order_detail_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('detail minimal: delivered hero bor, QR/timeline/confirm yo‘q', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    final api = _DeliveredOrdersApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          ordersApiProvider.overrideWithValue(api),
          orderRealtimeProvider.overrideWith(_NoopRealtimeController.new),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OrderDetailScreen(
            storeType: StoreType.grocery,
            orderId: 'order-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('order-delivered-hero')), findsOneWidget);
    expect(find.text('Yetkazildi'), findsOneWidget);
    expect(find.text('Olma × 2'), findsOneWidget);
    expect(find.text("17\u00A0000 so'm"), findsOneWidget);
    expect(find.textContaining('BK-SECRET'), findsNothing);
    expect(find.text('1234'), findsNothing);
    expect(find.text('Qabul qildim'), findsNothing);
    expect(find.text('Buyurtma tarixi'), findsNothing);
    expect(find.text("To'lov"), findsNothing);
  });

  test('uch locale yangi order statuslarini beradi', () async {
    final uz = await AppLocalizations.delegate.load(const Locale('uz'));
    final cyrl = await AppLocalizations.delegate.load(
      const Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    );
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));

    expect(uz.orderStatusDelivering, 'Yetkazilmoqda');
    expect(cyrl.orderStatusDelivering, 'Етказилмоқда');
    expect(ru.orderStatusDelivering, 'Доставляется');
  });
}

class _NoopRealtimeController extends OrderRealtimeController {
  @override
  OrderRealtimeState build() =>
      const OrderRealtimeState(status: OrderSocketStatus.disconnected);
}

class _DeliveredOrdersApi extends Fake implements OrdersApi {
  final OrderData order = OrderData.fromJson({
    'id': 'order-1',
    'order_number': 'BK-SECRET',
    'store_type': 'grocery',
    'fulfillment_type': 'delivery',
    'status': 'delivered',
    'user_status': 'delivered',
    'subtotal': '12000',
    'delivery_fee': '5000',
    'total': '17000',
    'payment_method': 'cash_to_courier',
    'payment_status': 'pending',
    'delivery_confirmation': {
      'code': '1234',
      'qr_token': 'legacy-token',
      'qr_payload': 'marketplace://order-confirm?token=legacy-token',
    },
    'simplified_timeline': [
      {'key': 'delivered', 'label': 'Yetkazildi', 'state': 'current'},
    ],
    'items': [
      {
        'id': 'item-1',
        'product_id': 'product-1',
        'product_name': 'Olma',
        'quantity': 2,
        'price': '6000',
        'total_price': '12000',
        'addons': <Map<String, dynamic>>[],
      },
    ],
    'created_at': '2026-08-09T08:00:00Z',
  });

  @override
  Future<OrderData> detail(String id) async => order;

  @override
  Future<OrderTrackingData> tracking(String id) async =>
      OrderTrackingData.fromJson({
        'status': 'delivered',
        'user_status': 'delivered',
        'store_type': 'grocery',
        'fulfillment_type': 'delivery',
      });
}
