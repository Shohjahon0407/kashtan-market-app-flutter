import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_rules.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/delivery_minimum_card.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CartData cart(String subtotal, {String? minimum = '20000.00'}) => CartData(
  id: 'cart',
  storeTypeWire: 'household',
  items: const [],
  totalItems: 1,
  totalQuantity: 1,
  subtotal: subtotal,
  minimumDeliveryOrderAmount: minimum,
);

bool canSubmit(
  CartData cart, {
  bool pickup = false,
  String fee = '0',
}) => CheckoutRules.canSubmit(
  fulfillmentType: pickup ? FulfillmentType.pickup : FulfillmentType.delivery,
  addressId: 'address',
  estimate: DeliveryEstimate(available: true, detail: '', deliveryPrice: fee),
  isEstimating: false,
  pickupBranchId: 'branch',
  pickupAllowed: true,
  cart: cart,
);

void main() {
  testWidgets('unconfirmed changes cannot turn minimum into a success state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeliveryMinimumCard(
            cart: cart('25000'),
            deliveryFee: '5000',
            statusOverride: 'Hisob yangilanmoqda…',
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DeliveryMinimumCard)),
    );
    expect(find.text(l10n.checkoutMinimumReached), findsNothing);
    expect(find.text('Hisob yangilanmoqda…'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
  });

  test('minimum includes confirmed delivery fee, never an invented quote', () {
    final value = cart('17000');
    expect(value.remainingForDelivery, '3000.00');
    expect(canSubmit(value), isFalse);
    expect(canSubmit(value, fee: '5000'), isTrue);
    expect(
      cart('8000').deliveryMinimumRemaining(deliveryFee: '5000'),
      '7000.00',
    );
    expect(canSubmit(cart('8000'), fee: '5000'), isFalse);
    expect(canSubmit(cart('15000'), fee: '5000'), isTrue);
    expect(canSubmit(cart('14999.99'), fee: '5000'), isFalse);
    expect(
      cart('14999.99').deliveryMinimumRemaining(deliveryFee: '5000'),
      '0.01',
    );
    expect(canSubmit(value, pickup: true), isTrue);
  });

  test('exact/above boundary, zero policy and fractional values are exact', () {
    expect(canSubmit(cart('19999.99')), isFalse);
    expect(cart('19999.99').remainingForDelivery, '0.01');
    expect(canSubmit(cart('20000')), isTrue);
    expect(canSubmit(cart('20000.01')), isTrue);
    expect(canSubmit(cart('1', minimum: '0')), isTrue);
    expect(Uzs.formatWithFraction('0.01'), '0.01 ${Uzs.suffix}');
    expect(Uzs.formatWithFraction('20000.00'), '20\u00a0000 ${Uzs.suffix}');
  });

  test('cart policy survives parsing and optimistic item changes', () {
    final value = CartData.fromJson({
      'id': 'cart',
      'store_type': 'household',
      'subtotal': '17000',
      'minimum_delivery_order_amount': '25000.00',
    });
    expect(value.minimumDeliveryOrderAmount, '25000.00');
    expect(value.copyWith(subtotal: '23000').remainingForDelivery, '2000.00');
    expect(value.removeItem('missing').minimumDeliveryOrderAmount, '25000.00');
    expect(
      CartData.fromJson({'subtotal': '17000'}).minimumDeliveryOrderAmount,
      isNull,
    );
    expect(canSubmit(cart('17000', minimum: null)), isTrue);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [320.0, 430.0]) {
      testWidgets('minimum card fits $locale $width at 2x with add action', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DeliveryMinimumCard(
                    cart: cart('8000'),
                    deliveryFee: '5000',
                    onAddProducts: () => taps++,
                  ),
                ),
              ),
            ),
          ),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DeliveryMinimumCard)),
        );
        expect(
          find.text(
            l10n.checkoutMinimumRemaining(Uzs.formatWithFraction('7000')),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .65,
        );
        await tester.tap(find.byType(TextButton));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('zero or missing minimum does not create a misleading card', (
    tester,
  ) async {
    for (final minimum in ['0', null]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DeliveryMinimumCard(cart: cart('17000', minimum: minimum)),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('checkout-delivery-minimum')),
        findsNothing,
      );
    }
  });

  testWidgets(
    'without an estimate card asks for address instead of inventing fee',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DeliveryMinimumCard(cart: cart('8000'))),
        ),
      );
      expect(
        find.text('Yetkazish narxini hisoblash uchun manzilni tanlang.'),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(DeliveryMinimumCard)),
      );
      expect(
        find.text(
          l10n.checkoutMinimumRemaining(Uzs.formatWithFraction('12000')),
        ),
        findsNothing,
      );
    },
  );
}
