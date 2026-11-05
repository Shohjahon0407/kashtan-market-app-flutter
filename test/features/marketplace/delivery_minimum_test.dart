import 'dart:ui' show SemanticsAction;

import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/checkout_rules.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/delivery_minimum_progress.dart';
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

final _progress = find.byKey(const ValueKey('cart-minimum-progress'));

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String subtotal = '8000',
    String? fee = '5000',
    String? minimum = '20000',
    bool confirmed = true,
    bool reduce = false,
    double scale = 1,
    Locale locale = const Locale('uz'),
    VoidCallback? onTap,
  }) => tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduce,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DeliveryMinimumProgress(
              cart: cart(subtotal, minimum: minimum),
              deliveryFee: fee,
              isConfirmed: confirmed,
              onAddProducts: onTap ?? () {},
            ),
          ),
        ),
      ),
    ),
  );

  double bar(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .value!;

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

  testWidgets('progress animates up, hides at minimum and returns below it', (
    tester,
  ) async {
    await pump(tester);
    expect(bar(tester), .65);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .minHeight,
      4,
    );
    await pump(tester, subtotal: '12000');
    await tester.pump(const Duration(milliseconds: 150));
    expect(bar(tester), inExclusiveRange(.65, .85));
    await tester.pumpAndSettle();
    expect(bar(tester), .85);
    await pump(tester, subtotal: '15000');
    expect(_progress, findsNothing);
    expect(find.text('Minimal buyurtma summasiga yetdingiz'), findsNothing);
    await pump(tester);
    expect(bar(tester), .65);
  });

  testWidgets('unknown fee, unconfirmed state and absent policy stay hidden', (
    tester,
  ) async {
    await pump(tester, fee: null);
    expect(_progress, findsNothing);
    await pump(tester, confirmed: false);
    expect(_progress, findsNothing);
    for (final minimum in ['0', null]) {
      await pump(tester, minimum: minimum);
      expect(_progress, findsNothing);
    }
    await pump(tester, subtotal: '40000', fee: null);
    expect(_progress, findsNothing);
    await pump(tester, subtotal: '40000');
    expect(_progress, findsNothing);
  });

  testWidgets('reduced motion updates progress immediately', (tester) async {
    await pump(tester, reduce: true);
    expect(bar(tester), .65);
    await pump(tester, reduce: true, subtotal: '12000');
    await tester.pump();
    expect(bar(tester), .85);
  });

  testWidgets('screen reader exposes shortfall and actionable progress', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, onTap: () => taps++);
    final data = tester.getSemantics(_progress).getSemanticsData();
    expect(data.label, contains('7\u00a0000'));
    expect(data.value, '65%');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(_progress);
    expect(taps, 1);
    await pump(tester, subtotal: '14999.99');
    final almostMet = tester.getSemantics(_progress).getSemanticsData();
    expect(almostMet.label, contains('0.01'));
    expect(almostMet.value, '99%');
    semantics.dispose();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [320.0, 430.0]) {
      testWidgets('compact progress fits $locale $width at 2x', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var taps = 0;
        await pump(tester, locale: locale, scale: 2, onTap: () => taps++);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DeliveryMinimumProgress)),
        );
        expect(
          find.text(
            l10n.checkoutMinimumRemaining(Uzs.formatWithFraction('7000')),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.checkoutMinimumIncludesDelivery), findsNothing);
        expect(bar(tester), .65);
        await tester.tap(_progress);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
