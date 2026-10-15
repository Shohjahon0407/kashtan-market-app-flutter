import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_stage_stepper.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// 4 bosqichli stepper: joriy bosqich kaliti, pulsatsiya, yakuniy holat.
void main() {
  testWidgets('tayyorlanmoqda bosqichi joriy, tasdiq o\'tilgan', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const OrderStageStepper(stage: CustomerOrderStage.accepted)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('order-stage-searching')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-stage-current-accepted')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('order-stage-onWay')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-stage-delivered')), findsOneWidget);
    expect(find.byKey(const ValueKey('order-stage-pulse')), findsOneWidget);
    // Unmount — pulsatsiya controller'i to'xtaydi.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('disableAnimations pulsatsiyani o\'chiradi', (tester) async {
    await tester.pumpWidget(
      _app(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: OrderStageStepper(stage: CustomerOrderStage.onWay),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('order-stage-current-onWay')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('order-stage-pulse')), findsNothing);
  });

  testWidgets('bekor qilingan/pickup uchun chizilmaydi', (tester) async {
    await tester.pumpWidget(
      _app(const OrderStageStepper(stage: CustomerOrderStage.cancelled)),
    );
    expect(find.byKey(const ValueKey('order-stage-searching')), findsNothing);
  });

  test('bosqich matnlari (uz)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('uz'));
    expect(
      OrderStageStepper.stageTitle(l10n, CustomerOrderStage.searching),
      'Buyurtma tasdiqlanishi kutilmoqda',
    );
    expect(
      OrderStageStepper.stageTitle(l10n, CustomerOrderStage.accepted),
      'Buyurtmangiz tayyorlanmoqda',
    );
    expect(
      OrderStageStepper.stageTitle(l10n, CustomerOrderStage.onWay),
      "Kuryer siz tomon yo'lga chiqdi",
    );
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('uz'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

// ignore: unused_element
OrderData _order({
  String status = 'pending',
  String userStatus = 'reviewing',
  String courierName = '',
  String courierPhone = '',
  String vehicle = 'car',
  String comment = '',
  String deliveryOption = 'same_day',
  DateTime? deadline,
  DateTime? deliveredAt,
  DateTime? createdAt,
  bool withAddress = true,
  bool withBranch = false,
  Map<String, dynamic>? courierLocation,
}) => OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'grocery',
  'fulfillment_type': 'delivery',
  'status': status,
  'user_status': userStatus,
  'subtotal': '12000',
  'delivery_fee': '0',
  'total': '12000',
  'payment_method': 'cash_to_courier',
  'payment_status': 'pending',
  'customer_phone': '+998901112233',
  'courier_name': courierName,
  'courier_phone': courierPhone,
  'courier_vehicle_type': vehicle,
  'courier_comment': comment,
  'courier_eta_minutes': 35,
  'delivery_option': deliveryOption,
  'delivery_deadline_at': deadline?.toUtc().toIso8601String(),
  'delivered_at': deliveredAt?.toUtc().toIso8601String(),
  'courier_location': courierLocation,
  'address': withAddress
      ? {
          'id': 'a-1',
          'title': 'Uy',
          'district': 'Parkent',
          'street': 'Mustaqillik',
          'house': '10',
          'latitude': '41.350',
          'longitude': '69.600',
          'is_default': true,
        }
      : null,
  'pickup_branch': withBranch
      ? {
          'id': 'b-1',
          'name': 'Markaz',
          'address': "Amir Temur ko'chasi 1",
          'phone': '',
          'store_name': 'Oziq-ovqat',
          'latitude': '41.320',
          'longitude': '69.550',
        }
      : null,
  'items': [
    {
      'id': 'item-1',
      'product_id': 'p-1',
      'product_name': 'Olma',
      'quantity': 2,
      'price': '6000',
      'total_price': '12000',
      'addons': <Map<String, dynamic>>[],
    },
  ],
  'created_at':
      (createdAt ?? DateTime.now().subtract(const Duration(minutes: 3)))
          .toUtc()
          .toIso8601String(),
});
