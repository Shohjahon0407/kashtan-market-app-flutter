import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/courier_card.dart';
import 'package:beshkashtan_customer/features/orders/presentation/widgets/order_tracking_panel.dart';
import 'package:beshkashtan_customer/features/payments/presentation/payme_payment_section.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kuzatuv paneli: vaqt oynasi, bosqich matni, kuryer kartasi, tafsilotlar.
void main() {
  for (final locale in [
    const Locale('uz'),
    const Locale('uz', 'Cyrl'),
    const Locale('ru'),
  ]) {
    for (final width in [320.0, 360.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'courier card uses real theme: $locale $width px ${scale}x',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            for (final phone in ['', '+998901234567']) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.light(),
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    ScriptFallbackDelegate<MaterialLocalizations>(
                      GlobalMaterialLocalizations.delegate,
                      Locale('uz'),
                    ),
                    ScriptFallbackDelegate<CupertinoLocalizations>(
                      GlobalCupertinoLocalizations.delegate,
                      Locale('uz'),
                    ),
                    ScriptFallbackDelegate<WidgetsLocalizations>(
                      GlobalWidgetsLocalizations.delegate,
                      Locale('uz'),
                    ),
                  ],
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CourierCard(
                            order: _order(
                              courierName: 'Bobur Muhammadali Abdullayev',
                              courierPhone: phone,
                              vehicle: 'motorcycle',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final card = tester.getSize(
                find.byKey(const ValueKey('order-courier-card')),
              );
              // Large accessibility text may grow vertically; do not impose
              // a fixed card height or truncate the courier's full name.
              expect(card.height, lessThan(300 + 100 * (scale - 1)));
              expect(
                tester.getSize(find.text('Bobur Muhammadali Abdullayev')).width,
                greaterThan(120),
              );
              if (phone.isNotEmpty) {
                expect(
                  tester.getSize(
                    find.byKey(const ValueKey('order-call-courier')),
                  ),
                  const Size(48, 48),
                );
                expect(find.byType(FilledButton), findsNothing);
              } else {
                expect(
                  find.byKey(const ValueKey('order-call-courier')),
                  findsNothing,
                );
              }
            }
          },
        );
      }
    }
  }
  Widget panel(OrderData order) => ProviderScope(
    child: _app(
      OrderTrackingPanel(
        order: order,
        mutating: false,
        onCancel: () {},
        onOpenSummary: () {},
      ),
    ),
  );

  testWidgets('existing Payme order keeps its data but has no payment action', (
    tester,
  ) async {
    final order = _order(paymentMethod: 'payme');
    await tester.pumpWidget(panel(order));
    await tester.pump(const Duration(milliseconds: 50));
    expect(order.paymentMethod, 'payme');
    expect(order.paymentStatus, 'pending');
    expect(find.byType(PaymePaymentSection), findsNothing);
    expect(find.textContaining('Payme'), findsNothing);
  });

  testWidgets('tasdiq kutilmoqda: vaqt yo\'q, taymer bor, kuryer yo\'q', (
    tester,
  ) async {
    await tester.pumpWidget(panel(_order()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Kuryer tasdiqlagach aniqlanadi'), findsOneWidget);
    expect(find.text('Buyurtma tasdiqlanishi kutilmoqda'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-waiting-elapsed')), findsOneWidget);
    expect(find.textContaining('Kutilmoqda: 03:'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-courier-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('order-stage-current-searching')),
      findsOneWidget,
    );
    expect(find.text('+998901112233'), findsOneWidget);
    expect(find.text('Buyurtmani bekor qilish'), findsOneWidget);
  });

  testWidgets('tayyorlanmoqda: 10 daqiqalik oyna va kuryer kartasi', (
    tester,
  ) async {
    final deadline = DateTime(2026, 10, 8, 15, 26);
    await tester.pumpWidget(
      panel(
        _order(
          status: 'accepted',
          userStatus: 'accepted',
          courierName: 'Shuhrat Aliyev',
          courierPhone: '+998901234567',
          comment: 'Darvoza oldida telefon qilaman',
          deadline: deadline,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('15:16 – 15:26'), findsOneWidget);
    expect(find.text('Yetkazib beradigan vaqtimiz'), findsOneWidget);
    expect(find.text('Buyurtmangiz tayyorlanmoqda'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-courier-card')), findsOneWidget);
    expect(find.text('Shuhrat Aliyev'), findsOneWidget);
    expect(find.text('SA'), findsOneWidget);
    expect(find.text('Kuryer · Avtomobil'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-call-courier')), findsOneWidget);
    expect(find.text('Darvoza oldida telefon qilaman'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('order-stage-current-accepted')),
      findsOneWidget,
    );
  });

  testWidgets('yo\'lda: bosqich matni va 1 kunlik buyurtmada sana matni', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        _order(
          status: 'out_for_delivery',
          userStatus: 'on_way',
          courierName: 'Ali',
          deliveryOption: 'one_day',
          deadline: DateTime.now().add(const Duration(hours: 20)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text("Kuryer siz tomon yo'lga chiqdi"), findsOneWidget);
    expect(find.text('1 kun ichida yetkaziladi'), findsOneWidget);
    expect(find.textContaining(' – '), findsNothing);
    expect(find.text('Buyurtmani bekor qilish'), findsNothing);
  });

  testWidgets('yetkazildi: vaqt bilan yashil sarlavha, bitta "Yetkazildi"', (
    tester,
  ) async {
    await tester.pumpWidget(
      panel(
        _order(
          status: 'delivered',
          userStatus: 'delivered',
          courierName: 'Ali',
          deliveredAt: DateTime(2026, 10, 8, 15, 20),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('order-delivered-hero')), findsOneWidget);
    expect(find.text('Yetkazildi · 15:20'), findsOneWidget);
    expect(find.text('Yetkazildi'), findsNothing);
    expect(find.text('Buyurtma yetkazildi'), findsOneWidget);
  });

  testWidgets('bekor qilingan: badge, stepper yo\'q', (tester) async {
    await tester.pumpWidget(
      panel(_order(status: 'cancelled', userStatus: 'cancelled')),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('order-status-cancelled')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('order-stage-searching')), findsNothing);
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
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

OrderData _order({
  String status = 'pending',
  String userStatus = 'reviewing',
  String paymentMethod = 'cash_to_courier',
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
  'payment_method': paymentMethod,
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
