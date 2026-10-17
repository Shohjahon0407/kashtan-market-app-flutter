import 'package:beshkashtan_customer/core/localization/locale_controller.dart';
import 'package:beshkashtan_customer/core/storage/account_scope.dart';
import 'package:beshkashtan_customer/core/store_scope/store_type.dart';
import 'package:beshkashtan_customer/core/ui/formatters/uzs.dart';
import 'package:beshkashtan_customer/core/ui/theme/app_theme.dart';
import 'package:beshkashtan_customer/features/cart/data/cart_models.dart';
import 'package:beshkashtan_customer/features/cart/domain/cart_controller.dart';
import 'package:beshkashtan_customer/features/catalog/data/product_models.dart';
import 'package:beshkashtan_customer/features/catalog/presentation/widgets/product_image.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_api.dart';
import 'package:beshkashtan_customer/features/checkout/data/checkout_models.dart';
import 'package:beshkashtan_customer/features/checkout/domain/addresses_controller.dart';
import 'package:beshkashtan_customer/features/checkout/domain/delivery_address_selection.dart';
import 'package:beshkashtan_customer/features/checkout/domain/order_draft_controller.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/checkout_screen.dart';
import 'package:beshkashtan_customer/features/checkout/presentation/widgets/checkout_receipt_paper.dart';
import 'package:beshkashtan_customer/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/review_draft.dart';

class _CheckoutApi extends Mock implements CheckoutApi {}

class _Cart extends CartController {
  _Cart(super.storeType, this.fixture);
  final CartData fixture;
  @override
  Future<CartState> build() async => CartState(cart: fixture);
  @override
  Future<void> refresh() async {}
}

const _address = UserAddress(
  id: 'address',
  title: 'Uy',
  latitude: 41.311,
  longitude: 69.24,
  street: 'Toshkent sh., Yangi ko‘cha',
  isDefault: true,
);
const _quote = DeliveryEstimate(
  available: true,
  detail: '',
  deliveryPrice: '5000',
);

class _Addresses extends AddressesController {
  @override
  Future<List<UserAddress>> build() async => const [_address];
  @override
  Future<void> refresh() async {}
}

CartData _cart(StoreType store) => CartData(
  id: 'cart',
  storeTypeWire: store.wire,
  subtotal: '180000',
  totalItems: 1,
  totalQuantity: 2,
  items: [
    CartItem(
      id: 'item',
      quantity: 2,
      selectedAddons: const [],
      note: '',
      subtotal: '180000',
      product: ProductSummary.fromJson({
        'id': 'food',
        'name': 'Osh',
        'price': '90000',
        'unit': 'dona',
        'store_type': store.wire,
        'store': {'id': 'store', 'name': 'Store', 'store_type': store.wire},
      }),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('uz'),
  double scale = 1,
  StoreType store = StoreType.restaurant,
  CartData? cart,
  FulfillmentType fulfillment = FulfillmentType.delivery,
}) async {
  final fixture = cart ?? _cart(store);
  final api = _CheckoutApi();
  final branch = StoreBranch.fromJson({
    'id': 'pickup',
    'name': 'Filial',
    'address': 'Toshkent',
    'is_active': true,
    'is_pickup_available': true,
    'store': {'id': 'store', 'store_type': store.wire},
  });
  when(() => api.fetchBranches('store')).thenAnswer((_) async => [branch]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiLangProvider.overrideWithValue(locale.languageCode),
        accountScopeProvider.overrideWithValue('user_test'),
        checkoutApiProvider.overrideWithValue(api),
        cartControllerProvider.overrideWith2((type) => _Cart(type, fixture)),
        addressesControllerProvider.overrideWith(_Addresses.new),
        orderDraftProvider.overrideWith2(
          (type) => ReviewDraft(
            type,
            OrderDraftState(
              fulfillment: fulfillment,
              pickupBranchId: fulfillment == FulfillmentType.pickup
                  ? 'pickup'
                  : null,
              selection: DeliveryAddressSelection(
                address: _address,
                estimate: _quote,
                storeScope: deliveryStoreScope(fixture),
              ),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: CheckoutScreen(storeType: store),
          bottomNavigationBar: const SizedBox(height: 64),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('checkout-content')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
  }
  for (var attempt = 0; attempt < 60; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    final body = tester.getRect(find.byKey(const ValueKey('checkout-content')));
    await tester.dragFrom(
      Offset(body.left + 8, body.center.dy),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget, reason: key);
}

Future<void> _openReceipt(WidgetTester tester) async {
  await _scrollTo(tester, 'checkout-open-receipt');
  // With 2x text the row can be taller than the remaining body. Tap its
  // visible intersection instead of a center underneath the fixed footer.
  final row = tester.getRect(
    find.byKey(const ValueKey('checkout-open-receipt')),
  );
  final body = tester.getRect(find.byKey(const ValueKey('checkout-content')));
  final visible = row.intersect(body);
  expect(visible.height, greaterThan(0));
  await tester.tapAt(visible.center);
  await tester.pumpAndSettle();
}

void main() {
  for (final store in StoreType.values) {
    testWidgets(
      'compact review for ${store.wire} omits map and cart controls',
      (tester) async {
        await _pump(tester, store: store);
        expect(
          find.byKey(const ValueKey('checkout-delivery-map')),
          findsNothing,
        );
        expect(find.byType(SegmentedButton<FulfillmentType>), findsNothing);
        expect(
          find.byKey(const ValueKey('delivery-address-confirm')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('checkout-receipt')), findsNothing);
        expect(find.text('Osh'), findsNothing);
        expect(find.text('Uy'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('checkout-submit')),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('checkout-submit-total')))
              .data,
          Uzs.format('185000'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pickup review uses subtotal without delivery minimum or address',
    (tester) async {
      await _pump(tester, fulfillment: FulfillmentType.pickup);
      expect(find.text('Filial'), findsOneWidget);
      expect(find.text('Uy'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('checkout-submit-total')))
            .data,
        Uzs.format('180000'),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('checkout-submit')))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(430, 932),
    const Size(800, 360),
  ]) {
    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('compact review fits $size $locale at 2x', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        final footer = find.byKey(const ValueKey('checkout-submit'));
        expect(
          tester.getRect(footer).bottom,
          lessThanOrEqualTo(size.height - 64),
        );
        for (final key in [
          'checkout-products-panel',
          'checkout-payment-panel',
          'checkout-note',
          'checkout-summary',
        ]) {
          await _scrollTo(tester, key);
          expect(tester.takeException(), isNull, reason: key);
        }
        await _openReceipt(tester);
        expect(find.text('Osh'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'receipt shows configurations, units and server line prices last',
    (tester) async {
      final fixture = CartData(
        id: 'cart',
        storeTypeWire: 'restaurant',
        subtotal: '35000',
        totalItems: 2,
        totalQuantity: 5,
        items: [
          CartItem(
            id: 'kg-item',
            product: ProductSummary.fromJson({
              'id': 'beef',
              'name': 'Mol jazz kiloligi',
              'image': 'https://example.com/beef.jpg',
              'price': '10000',
              'unit': 'kg',
              'store': {'id': 'store', 'store_type': 'restaurant'},
            }),
            quantity: 2,
            selectedAddons: const [],
            note: '',
            subtotal: '20000',
          ),
          CartItem(
            id: 'variant-item',
            product: ProductSummary.fromJson({
              'id': 'food',
              'name': 'Taom',
              'price': '999999',
              'unit': 'kg',
              'store': {'id': 'store', 'store_type': 'restaurant'},
            }),
            quantity: 3,
            variant: ProductVariant.fromJson({
              'id': 'variant',
              'name': 'Kichik porsiya',
              'unit': 'dona',
              'price': '4000',
            }),
            selectedAddons: const [
              SelectedAddon(id: 'sauce', name: 'Sous', price: '1000'),
            ],
            note: 'Piyozsiz',
            subtotal: '15000',
          ),
        ],
      );
      await _pump(tester, cart: fixture);
      await _openReceipt(tester);
      final receipt = find.byKey(const ValueKey('checkout-receipt'));
      expect(tester.widget<CheckoutReceiptPaper>(receipt), isNotNull);
      final paper = tester.widget<PhysicalShape>(
        find.descendant(of: receipt, matching: find.byType(PhysicalShape)),
      );
      expect(paper.clipper, isA<ReceiptPaperClipper>());
      expect(paper.color, const Color(0xFFEEF0F3));
      final photo = tester.widget<ProductImageView>(
        find.byKey(const ValueKey('checkout-receipt-image-kg-item')),
      );
      expect(photo.imageUrl, 'https://example.com/beef.jpg');
      expect(photo.memCacheWidth, 160);
      expect(
        find.descendant(of: receipt, matching: find.byType(ProductImageView)),
        findsNWidgets(2),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CheckoutScreen)),
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.checkoutReceiptTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: receipt, matching: find.text('Mol jazz kiloligi')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.shashlikKilogramQuantity(2)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: receipt,
          matching: find.text(l10n.shashlikPieceQuantity(3)),
        ),
        findsOneWidget,
      );
      for (final text in [
        'Kichik porsiya',
        '+ Sous',
        'Piyozsiz',
        Uzs.format('20000'),
        Uzs.format('15000'),
        Uzs.format('35000'),
      ]) {
        expect(
          find.descendant(of: receipt, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: receipt, matching: find.text(Uzs.format('999999'))),
        findsNothing,
      );
      final receiptRight = tester.getRect(receipt).right - 14;
      for (final price in ['20000', '15000', '35000']) {
        expect(
          tester
              .getRect(
                find.descendant(
                  of: receipt,
                  matching: find.text(Uzs.format(price)),
                ),
              )
              .right,
          closeTo(receiptRight, .5),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('help and quick notes keep manual text and toggle suggestions', (
    tester,
  ) async {
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CheckoutScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('checkout-help')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.checkoutHelpBody), findsOneWidget);
    await tester.tap(find.text(l10n.commonClose));
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'checkout-note');
    final field = find.byKey(const ValueKey('checkout-note'));
    await tester.enterText(field, 'Eshik kodi 124');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final chip = find.widgetWithText(FilterChip, l10n.checkoutNoteNoOnion);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field).controller!.text,
      'Eshik kodi 124; ${l10n.checkoutNoteNoOnion}',
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Eshik kodi 124');
    await tester.enterText(field, List.filled(500, 'a').join());
    await tester.pump();
    expect(tester.widget<FilterChip>(chip).onSelected, isNull);
    expect(tester.takeException(), isNull);
  });
}
