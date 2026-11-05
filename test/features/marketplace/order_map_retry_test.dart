import 'package:beshkashtan_customer/core/network/api_failure.dart';
import 'package:beshkashtan_customer/core/routing/back_navigation.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/features/orders/data/order_models.dart';
import 'package:beshkashtan_customer/features/orders/domain/orders_controller.dart';
import 'package:beshkashtan_customer/features/orders/presentation/order_map_screen.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Tracking extends OrderTrackingController {
  _Tracking(super.orderId, this.onLoad);
  final VoidCallback onLoad;
  @override
  Future<OrderTrackingData> build() async {
    onLoad();
    return OrderTrackingData.fromJson({});
  }
}

void main() {
  testWidgets(
    'map retry refetches detail and tracking without popping; back stays separate',
    (tester) async {
      var detailCalls = 0, trackingCalls = 0;
      final router = GoRouter(
        initialLocation: '/map',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home destination')),
          ),
          GoRoute(
            path: '/map',
            builder: (_, _) => const OrderMapScreen(
              storeType: StoreType.meat,
              orderId: 'order',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            orderDetailProvider('order').overrideWith((_) async {
              detailCalls++;
              throw const NetworkFailure();
            }),
            orderTrackingControllerProvider(
              'order',
            ).overrideWith(() => _Tracking('order', () => trackingCalls++)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('uz'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(detailCalls, 1);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(detailCalls, 2);
      expect(trackingCalls, 2);
      expect(AppBackCoordinator.of(router).location, '/map');
      expect(find.byType(OrderMapScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('order-map-back')));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
