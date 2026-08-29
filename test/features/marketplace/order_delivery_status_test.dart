import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_delivery_status.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending delivery radar va haqiqiy elapsed timerni ko‘rsatadi', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_order(userStatus: 'reviewing')));

    expect(
      find.byKey(const ValueKey('order-searching-courier')),
      findsOneWidget,
    );
    expect(find.text('Kuryer qidirilmoqda'), findsOneWidget);
    expect(find.textContaining('Kutilmoqda:'), findsOneWidget);
  });

  testWidgets('waiting elapsed 24 soatdan keyin ham davom etadi', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _order(
          userStatus: 'reviewing',
          createdAt: DateTime.now().subtract(const Duration(hours: 26)),
        ),
      ),
    );

    expect(find.textContaining('Kutilmoqda: 26:'), findsOneWidget);
  });

  testWidgets(
    'accepted delivery yashil hero, courier, ETA va izohni ko‘rsatadi',
    (tester) async {
      final order = _order(
        userStatus: 'accepted',
        courierName: 'Ali Valiyev',
        courierPhone: '+998901234567',
        eta: 35,
        comment: 'Darvoza oldida telefon qilaman',
      );
      await tester.pumpWidget(_app(order));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const ValueKey('order-courier-accepted')),
        findsOneWidget,
      );
      expect(find.text('Kuryer buyurtmani qabul qildi'), findsOneWidget);
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.textContaining('35 daqiqa'), findsOneWidget);
      expect(find.text('Darvoza oldida telefon qilaman'), findsOneWidget);
    },
  );

  testWidgets('on-way location kelmaganida xavfsiz fallback ko‘rsatadi', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_order(userStatus: 'on_way', courierName: 'Ali')),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const ValueKey('order-courier-on-way')), findsOneWidget);
    expect(
      find.text('Kuryer lokatsiyasi vaqtincha mavjud emas'),
      findsOneWidget,
    );
  });
}

Widget _app(OrderData order) => MaterialApp(
  locale: const Locale('uz'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(
    body: SingleChildScrollView(child: OrderDeliveryStatus(order: order)),
  ),
);

OrderData _order({
  required String userStatus,
  String courierName = '',
  String courierPhone = '',
  int eta = 0,
  String comment = '',
  DateTime? createdAt,
}) => OrderData.fromJson({
  'id': 'order-1',
  'order_number': 'BK-1',
  'store_type': 'grocery',
  'fulfillment_type': 'delivery',
  'status': switch (userStatus) {
    'reviewing' => 'pending',
    'on_way' => 'out_for_delivery',
    _ => userStatus,
  },
  'user_status': userStatus,
  'status_label': userStatus,
  'payment_method': 'cash_to_courier',
  'payment_status': 'pending',
  'subtotal': '10000',
  'delivery_fee': '5000',
  'total': '15000',
  'courier_name': courierName,
  'courier_phone': courierPhone,
  'courier_eta_minutes': eta,
  'courier_comment': comment,
  'items': <Map<String, dynamic>>[],
  'created_at':
      (createdAt ?? DateTime.now().subtract(const Duration(minutes: 2)))
          .toUtc()
          .toIso8601String(),
});
