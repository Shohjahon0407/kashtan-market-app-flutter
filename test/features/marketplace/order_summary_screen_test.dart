import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/prefs_store.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/data/orders_api.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/order_summary_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Buyurtma tafsilotlari": mahsulotlar, Jami, bepul yetkazish, to'lov usuli,
/// buyurtma raqami YO'Q.
void main() {
  testWidgets('mahsulotlar va hisob-kitob', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PrefsStore.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsStoreProvider.overrideWithValue(prefs),
          ordersApiProvider.overrideWithValue(_Api()),
        ],
        child: const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OrderSummaryScreen(
            storeType: StoreType.restaurant,
            orderId: 'order-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buyurtma tafsilotlari'), findsOneWidget);
    expect(find.text('Svadebniy plov 0,5'), findsOneWidget);
    expect(find.text('Non yarim'), findsOneWidget);
    expect(find.byKey(const ValueKey('order-summary-totals')), findsOneWidget);
    expect(find.text('Jami'), findsOneWidget);
    // Jami va Mahsulotlar — ikkalasi 40 000 (yetkazish bepul).
    expect(find.text("40\u00A0000 so'm"), findsNWidgets(2));
    expect(find.text('Bepul'), findsOneWidget);
    expect(find.text("To'lov usuli"), findsOneWidget);
    expect(find.text('Payme'), findsOneWidget);
    expect(find.textContaining('BK-SECRET'), findsNothing);
  });
}

class _Api extends Fake implements OrdersApi {
  @override
  Future<OrderData> detail(String id) async => OrderData.fromJson({
    'id': 'order-1',
    'order_number': 'BK-SECRET',
    'store_type': 'restaurant',
    'fulfillment_type': 'delivery',
    'status': 'accepted',
    'user_status': 'accepted',
    'subtotal': '40000',
    'delivery_fee': '0',
    'total': '40000',
    'payment_method': 'payme',
    'payment_status': 'paid',
    'items': [
      {
        'id': 'i-1',
        'product_id': 'p-1',
        'product_name': 'Svadebniy plov 0,5',
        'quantity': 1,
        'price': '35000',
        'total_price': '35000',
        'addons': <Map<String, dynamic>>[],
      },
      {
        'id': 'i-2',
        'product_id': 'p-2',
        'product_name': 'Non yarim',
        'quantity': 1,
        'price': '5000',
        'total_price': '5000',
        'addons': <Map<String, dynamic>>[],
      },
    ],
    'created_at': '2026-10-08T09:00:00Z',
  });
}
